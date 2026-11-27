local sim = require('sim')
local root = assert(os.getenv('BANDA_V21'), 'Falta la ruta del proyecto')
local export = root .. '/EXPORTACION_COPPELIASIM/'
local install = assert(os.getenv('BANDA_COPPELIA_V21'))
package.path = install .. '/luarocks/share/lua/5.3/?.lua;' .. package.path
local json = require('dkjson')

local function read(path)
    local f = assert(io.open(path, 'rb'))
    local data = f:read('*a')
    f:close()
    return data
end

local function write(path, data)
    local f = assert(io.open(path, 'wb'))
    f:write(data)
    f:close()
end

local function stl(path, scale)
    local data = read(path)
    local count = string.unpack('<I4', data, 81)
    assert(#data == 84 + 50 * count, 'STL incorrecto: ' .. path)
    local vertices, indices, known = {}, {}, {}
    for offset = 85, #data - 49, 50 do
        for j = 0, 2 do
            local pos = offset + 12 + 12 * j
            local key = data:sub(pos, pos + 11)
            local index = known[key]
            if not index then
                local x, y, z = string.unpack('<fff', key)
                index = #vertices // 3
                vertices[#vertices + 1] = x * scale
                vertices[#vertices + 1] = y * scale
                vertices[#vertices + 1] = z * scale
                known[key] = index
            end
            indices[#indices + 1] = index
        end
    end
    return {vertices = vertices, indices = indices}
end

local function bounds(vertices, m)
    local lo, hi = {math.huge, math.huge, math.huge}, {-math.huge, -math.huge, -math.huge}
    for i = 1, #vertices, 3 do
        local x, y, z = vertices[i], vertices[i + 1], vertices[i + 2]
        for axis = 1, 3 do
            local k = (axis - 1) * 4
            local p = m[k + 1] * x + m[k + 2] * y + m[k + 3] * z + m[k + 4]
            lo[axis], hi[axis] = math.min(lo[axis], p), math.max(hi[axis], p)
        end
    end
    return {lo[1], lo[2], lo[3], hi[1], hi[2], hi[3]}
end

local function createAxis(parent, alias, p, v, cyclic, lower, upper)
    local j = sim.createJoint(sim.joint_revolute, sim.jointmode_kinematic, 0, {0.01, 0.004})
    sim.setObjectAlias(j, alias)
    local cross = math.sqrt(v[1] * v[1] + v[2] * v[2])
    local m = {1,0,0,0, 0,1,0,0, 0,0,1,0}
    if cross > 1e-10 then
        m = sim.buildMatrix({0,0,0}, {0,0,0})
        m = sim.rotateAroundAxis(m, {-v[2] / cross, v[1] / cross, 0}, {0,0,0}, math.atan(cross, v[3]))
    elseif v[3] < 0 then
        m = sim.buildMatrix({0,0,0}, {math.pi,0,0})
    end
    m[4], m[8], m[12] = p[1], p[2], p[3]
    sim.setObjectMatrix(j, m, sim.handle_world)
    sim.setObjectParent(j, parent, true)
    sim.setJointInterval(j, cyclic, cyclic and {-math.pi, 2 * math.pi} or {lower, upper - lower})
    return j, m
end

local function main()
    local m = assert(json.decode(read(export .. 'Manifiesto.json')))
    local parametros = assert(json.decode(read(export .. 'Parametros_V21.json')))
    local ref = m.ReferenciasFuncionales
    local scale = m.FactorMmAMetros
    local frame = {1,0,0,0, 0,0,-1,0, 0,1,0,-ref.PisoCadYMm * scale}
    local margenInicial=sim.getEngineFloatParam(sim.bullet_global_collisionmarginfactor,-1)
    sim.setEngineFloatParam(sim.bullet_global_collisionmarginfactor,-1,0.025)
    local margenActivo=sim.getEngineFloatParam(sim.bullet_global_collisionmarginfactor,-1)
    sim.setFloatProperty(sim.handle_scene,'dynamicsStepSize',0.0025)
    local function position(p) return {p[1] * scale, -p[3] * scale, (p[2] - ref.PisoCadYMm) * scale} end
    local function direction(v) return {v[1], -v[3], v[2]} end
    local assembly = sim.createDummy(0.002)
    sim.setObjectAlias(assembly, 'Banda_Clasificadora_V2')
    sim.setObjectInt32Param(assembly, sim.objintparam_visibility_layer, 0)
    local catalogue, source = {}, {}
    for _, part in ipairs(m.Piezas) do catalogue[part.ArchivoCAD] = part end
    local joints = {
        ['Eje_salida_D4_19'] = 'Junta_salida_D4', ['Eje_encoder_7'] = 'Junta_encoder',
        ['rodillo con rodamiento:2'] = 'Junta_motriz', ['rodillo con rodamiento 2:1'] = 'Junta_conducido',
        ['Rodillos mitad banda:1'] = 'Junta_intermedio_1', ['Rodillos mitad banda:2'] = 'Junta_intermedio_2',
        ['Rodillos mitad banda:3'] = 'Junta_intermedio_3', ['Desviador:1'] = 'Junta_desviador',
    }
    local axes, records, fixed, collisions, roles, handles = {}, {}, {}, {}, {}, {}
    local mechanicalLimits = ref.AngulosDesviador
    for _, instance in ipairs(m.Instancias) do
        local alias = joints[instance.Instancia]
        if alias then
            local servo = alias == 'Junta_desviador'
            local roll = alias:find('motriz') or alias:find('conducido') or alias:find('intermedio')
            local p = servo and ref.CentroDesviadorMm or instance.PuntoEjeGlobalMm
            local v = servo and ref.EjeDesviador or ((roll or alias == 'Junta_salida_D4') and {0, 0, 1} or instance.EjeGlobal)
            axes[alias] = createAxis(assembly, alias, position(p), direction(v), not servo,
                math.rad(mechanicalLimits.DerechaEnsayoGrad), math.rad(mechanicalLimits.IzquierdaEnsayoGrad))
        end
    end
    local maxError = 0
    for i, instance in ipairs(m.Instancias) do
        local part = assert(catalogue[instance.ArchivoCAD])
        local geo = source[part.ArchivoCAD]
        if not geo then
            geo = stl(export .. part.Malla, scale)
            source[part.ArchivoCAD] = geo
        end
        local shape = sim.createShape(0, math.rad(25), geo.vertices, geo.indices)
        handles[i]=shape
        local shapeOffset = sim.getObjectMatrix(shape, sim.handle_world)
        local localMat = {table.unpack(instance.MatrizGlobal3x4Mm)}
        for k = 4, 12, 4 do localMat[k] = localMat[k] * scale end
        local world = sim.multiplyMatrices(frame, localMat)
        sim.setObjectMatrix(shape, sim.multiplyMatrices(world, shapeOffset), sim.handle_world)
        local partAlias = ('CAD_%02d_%s'):format(i, instance.Instancia:gsub('[^%w_]', '_'))
        sim.setObjectAlias(shape, partAlias)
        roles[instance.Instancia] = partAlias
        sim.setShapeColor(shape, nil, sim.colorcomponent_ambient_diffuse, {part.RGB[1]/255, part.RGB[2]/255, part.RGB[3]/255})
        sim.setShapeColor(shape, nil, sim.colorcomponent_specular, {0.12, 0.12, 0.12})
        local joint = axes[joints[instance.Instancia]]
        if instance.Instancia == 'Disco_magnetico_8' then joint = axes.Junta_encoder end
        if instance.Instancia == 'Prisionero_M3x4:1' then joint = axes.Junta_motriz end
        sim.setObjectParent(shape, joint or assembly, true)
        if not joint then fixed[#fixed + 1] = partAlias end
        local name = instance.Instancia
        local collider = name == 'Desviador:1' or name:match('^palito arriba') or name:match('^Riel Banda') or
            name:match('^Pieza8:') or name:match('^Cabezal camara:') or name:match('^Camara:') or
            name:match('^Laiminamodific:') or name:match('^Paralela_diseno:') or name:match('^SERVOMOTOR:')
        if collider then
            sim.setObjectInt32Param(shape, sim.shapeintparam_static, 1)
            sim.setObjectInt32Param(shape, sim.shapeintparam_respondable, 1)
            sim.setObjectSpecialProperty(shape, sim.objectspecialproperty_collidable)
            collisions[name] = partAlias
        end
        local initial = bounds(geo.vertices, world)
        local actual = bounds(sim.getShapeMesh(shape), sim.getObjectMatrix(shape, sim.handle_world))
        local error = 0
        for k = 1, 6 do error = math.max(error, math.abs(initial[k] - actual[k])) end
        assert(error < 0.00015, 'Desfase de importación: ' .. instance.Instancia .. ' ' .. error .. ' m')
        maxError = math.max(error, maxError)
        records[#records + 1] = {Instancia = instance.Instancia, Alias = partAlias, CajaM = actual, ErrorMm = 1000 * error}
    end
    local mallas={paresConEnvolventeComun=0,contactosTriangulares={}}
    for i=1,#records do
        for k=i+1,#records do
            local a,b=m.Instancias[i],m.Instancias[k]
            if not catalogue[a.ArchivoCAD].BRep or not catalogue[b.ArchivoCAD].BRep then
                local u,v=records[i].CajaM,records[k].CajaM
                local candidatos=true
                for j=1,3 do if u[j]>v[j+3] or v[j]>u[j+3] then candidatos=false end end
                if candidatos then
                    mallas.paresConEnvolventeComun=mallas.paresConEnvolventeComun+1
                    local inter=sim.checkCollision(handles[i],handles[k])
                    if inter>0 then mallas.contactosTriangulares[#mallas.contactosTriangulares+1]={A=a.Instancia,B=b.Instancia} end
                end
            end
        end
    end
    write(export..'Mallas-V21.json',json.encode(mallas,{indent=true}))
    local sheetPoints = {position(ref.RamalSuperiorSegmentosMm[1][1])}
    for _, segment in ipairs(ref.RamalSuperiorSegmentosMm) do
        local pt = position(segment[2])
        if pt[1] - sheetPoints[#sheetPoints][1] > 0.0004 then sheetPoints[#sheetPoints + 1] = pt end
    end
    local proxies = {}
    for i = 1, #sheetPoints - 1 do
        local p, q = sheetPoints[i], sheetPoints[i+1]
        local dx, dz = q[1] - p[1], q[3] - p[3]
        local span = math.sqrt(dx * dx + dz * dz)
        local tilt = -math.atan(dz, dx)
        local thickness = 0.001
        local proxy = sim.createPrimitiveShape(sim.primitiveshape_cuboid, {span, ref.AnchoBandaMm * scale, thickness}, 0)
        local proxyAlias = 'Banda_contacto_' .. i
        sim.setObjectAlias(proxy, proxyAlias)
        sim.setObjectOrientation(proxy, {0, tilt, 0}, sim.handle_world)
        sim.setObjectPosition(proxy, {(p[1]+q[1])/2-math.sin(tilt)*thickness/2,p[2],
            (p[3]+q[3])/2-math.cos(tilt)*thickness/2}, sim.handle_world)
        sim.setObjectParent(proxy, assembly, true)
        sim.setObjectInt32Param(proxy, sim.shapeintparam_static, 1)
        sim.setObjectInt32Param(proxy, sim.shapeintparam_respondable, 1)
        sim.setObjectInt32Param(proxy, sim.objintparam_visibility_layer, 0)
        sim.setEngineFloatParam(sim.bullet_body_friction, proxy, parametros.ensayo.objeto.parametroBulletBanda)
        proxies[#proxies+1] = {alias=proxyAlias,direccion={dx/span,0,dz/span},inicio=p,fin=q}
    end
    local ejesCad = {motriz=position(ref.OrigenMotrizMm),conducido=position(ref.OrigenConducidoMm)}
    local d = sim.createDummy(0.008)
    sim.setObjectAlias(d, 'Referencia_optica_provisional')
    local optical = direction(ref.CamaraDireccionProvisional)
    local testPosition = position(ref.CamaraOrigenOpticoProvisionalMm)
    local opticsMatrix = sim.buildMatrix(testPosition, {math.pi, math.asin(optical[1]), 0})
    sim.setObjectMatrix(d, opticsMatrix, sim.handle_world)
    sim.setObjectParent(d, assembly, true)
    sim.writeCustomTableData(d, 'EJE_OPTICO', {posicionM = testPosition, direccion = optical, FOV = 'pendiente'})

    local function ixx(file, min)
        local meta = assert(catalogue[file],file)
        return math.max(min or 0, assert(meta.InerciaLocalKgM2)[1])
    end
    local c = parametros.ensayo
    c.inercias = {motorKgM2=ixx('Eje_salida_D4.ipt', 0) + c.motor.inerciaReflejadaExtraKgM2,
        motrizKgM2=ixx('rodillo con rodamiento.ipt', 0.000004),
        masaEquivalenteBandaKg = catalogue['Banda.ipt'].MasaKg + ixx('rodillo con rodamiento 2.ipt', 0)/0.015^2 +
            3*ixx('Rodillos mitad banda.ipt', 0)/0.014^2}
    local tornillo = catalogue['Prisionero_M3x4.ipt']
    if tornillo then
        local cm = tornillo.CentroMasaLocalMm
        c.inercias.motrizKgM2 = c.inercias.motrizKgM2 + tornillo.InerciaLocalKgM2[1] + tornillo.MasaKg * (cm[2]^2+cm[3]^2)/1000000
    end
    c.banda.envolturaMotrizRad = ref.EnvolturaMotrizRad
    c.servo.derechaGrad = mechanicalLimits.DerechaEnsayoGrad
    c.servo.izquierdaGrad = mechanicalLimits.IzquierdaEnsayoGrad
    local d4=roles['Eje_salida_D4_19']
    assert(d4 and roles['Prisionero_M3x4:1'] and #records==61, 'Grafo CAD V2 incompleto')
    local script = 'local Dinamica = (function()\n' .. read(root .. '/Scripts/Dinamica-V21.lua') .. '\nend)()\n' .. read(root .. '/Scripts/Control-V21.lua')
    local control = sim.createScript(sim.scripttype_simulation, script, 0, 'lua')
    sim.setObjectAlias(control, 'Control_local')
    sim.setObjectParent(control, assembly, true)
    sim.writeCustomTableData(assembly, 'BANDA_V21', {fijos = fixed, roles = roles, colisiones = collisions, proxies = proxies,
        ejeInspeccion = position(ref.CamaraInterseccionRamalMm), ejes = ejesCad, centroDesviador=position(ref.CentroDesviadorMm),
        neutralCad = ref.AnguloDesviadorLecturaGrad, parametros = c})
    sim.writeCustomTableData(assembly, 'CONSIGNAS_LOCALES', {rpm = 0, desviadorGrad = 0, cargaKg = 0, acopleAbierto = false})
    local desc = sim.getObject('/Banda_Clasificadora_V2/Junta_desviador/' .. roles['Desviador:1'])
    sim.setEngineFloatParam(sim.bullet_body_friction, desc, c.objeto.parametroBulletDesviador)
    write(export .. 'Banda_clasificadora_V2.ttt', tostring(sim.saveScene()))
    write(export .. 'Recomposicion-V21.json', json.encode({Instancias = records, MaximoErrorMm = maxError * 1000,
        TransformacionMarcoMetros = frame, Archivo = 'Banda_clasificadora_V2.ttt', Cantidad = #records,
        Colisiones=collisions, Ramal=proxies, ParametrosEjecutables=c,
        Bullet={FactorMargenAnterior=margenInicial,FactorMargenActivo=margenActivo,PasoColisionS=0.0025}}, {indent = true}))
end

local ok, errorMessage = xpcall(main, debug.traceback)
write(export .. 'Construccion.log', ok and 'Escena guardada y transformaciones comprobadas.' or errorMessage)
sim.quitSimulator()
