local sim = require('sim')
local root, config, state, dyn, casos, casoActual
local accion, pruebas, caja, cajaAlias, inicio, ultimaMuestra, servoActual, golpe, fotoBajoCamara
local joints, placas, obstaculos, quietos, fr, cotas, angulos
local prefijo = '/Banda_Clasificadora_V2/'
local resultado, cronometroServo, ordenServoAnterior, inicioOrdenServo, servoObjetivoLocal = {}, nil, 0, 0, 0

local function clamp(x, lo, hi) return math.max(lo, math.min(hi, x)) end
local function signo(x) return x > 0 and 1 or (x < 0 and -1 or 0) end

local function cruz(a, b)
    return {a[2]*b[3]-a[3]*b[2], a[3]*b[1]-a[1]*b[3], a[1]*b[2]-a[2]*b[1]}
end

local function norm(a)
    local d=math.sqrt(a[1]^2+a[2]^2+a[3]^2)
    return {a[1]/d,a[2]/d,a[3]/d}
end

local function foto(nombre, objetivo, desplazamiento, ancho)
    if not os.getenv('BANDA_V21') then return end
    local ok, err = pcall(function()
        local sensor=sim.createVisionSensor(1+4+64+128,{1000,640,0,0},{0.01,4,ancho,0.01,0,0,0.81,0.87,0.92,0,0})
        local v=norm({-desplazamiento[1],-desplazamiento[2],-desplazamiento[3]})
        local x=norm(cruz({0,0,1},v))
        local y=cruz(v,x)
        local p={objetivo[1]+desplazamiento[1],objetivo[2]+desplazamiento[2],objetivo[3]+desplazamiento[3]}
        sim.setObjectMatrix(sensor,{x[1],y[1],v[1],p[1],x[2],y[2],v[2],p[2],x[3],y[3],v[3],p[3]},sim.handle_world)
        sim.handleVisionSensor(sensor)
        local bytes,res=sim.getVisionSensorImg(sensor)
        local archivo=assert(io.open(os.getenv('BANDA_V21')..'/Capturas/'..nombre,'wb'))
        archivo:write(tostring(sim.saveImage(bytes,res,0,'.png',-1)))
        archivo:close()
        sim.removeObjects({sensor})
    end)
    resultado.fotos=resultado.fotos or {}
    resultado.fotos[#resultado.fotos+1]={archivo=nombre,ok=ok,detalle=ok and '' or tostring(err),tiempoS=sim.getSimulationTime()}
end

local function colocarCaja()
    caja=sim.createPrimitiveShape(sim.primitiveshape_cuboid,dyn.objeto.dimensionesM,0)
    sim.setObjectAlias(caja,cajaAlias)
    sim.setShapeMass(caja,dyn.objeto.masaKg)
    sim.setObjectInt32Param(caja,sim.shapeintparam_static,0)
    sim.setObjectInt32Param(caja,sim.shapeintparam_respondable,1)
    sim.setObjectSpecialProperty(caja,sim.objectspecialproperty_collidable)
    sim.setEngineFloatParam(sim.bullet_body_friction,caja,dyn.objeto.parametroBulletObjeto)
    sim.setShapeColor(caja,nil,sim.colorcomponent_ambient_diffuse,{0.89,0.38,0.09})
    local p=placas[1].inicio
    local dir=placas[1].direccion
    local x=p[1]+0.020
    local altura=p[3]+(dir[3]/dir[1])*(x-p[1])+dyn.objeto.dimensionesM[3]/2+0.0008
    sim.setObjectPosition(caja,{x,p[2],altura},sim.handle_world)
    accion.inicial=sim.getObjectPosition(caja,sim.handle_world)
end

local function reiniciarCaso(t)
    local c=casos[casoActual]
    if not c then return false end
    state=Dinamica.estado()
    inicio, ultimaMuestra, servoActual, golpe, fotoBajoCamara = t, -1, 0, nil, false
    cronometroServo=nil
    accion={caso=c.id,consignaRPM=c.rpm,orden=c,lecturas={},contactos={},penetracionesGeometricas={},servoObjetivo=c.servoGrad or 0,
        cruzaCamara=false,tocaDesviador=false,finRamal=false,anguloMaxErrorGrad=0,derivaFijosM=0}
    return true
end

function sysCall_init()
    root=sim.getObject('/Banda_Clasificadora_V2')
    config=sim.readCustomTableData(root,'BANDA_V21')
    dyn=config.parametros
    state=Dinamica.estado()
    local names={'salida_D4','motriz','conducido','intermedio_1','intermedio_2','intermedio_3','desviador','encoder'}
    joints={}
    for _,name in ipairs(names) do joints[name]=sim.getObject(prefijo..'Junta_'..name) end
    placas={}
    fr={sim.shapefloatparam_init_velocity_x,sim.shapefloatparam_init_velocity_y,sim.shapefloatparam_init_velocity_z}
    for _,p in ipairs(config.proxies) do
        p.handle=sim.getObject(prefijo..p.alias)
        placas[#placas+1]=p
    end
    obstaculos={}
    for nombre,alias in pairs(config.colisiones) do
        local path=nombre=='Desviador:1' and prefijo..'Junta_desviador/'..alias or prefijo..alias
        obstaculos[sim.getObject(path)]=nombre
    end
    cotas={desviador=sim.getObject(prefijo..'Junta_desviador/'..config.roles['Desviador:1'])}
    angulos={lo=dyn.servo.derechaGrad,hi=dyn.servo.izquierdaGrad}
    quietos={}
    for _,name in ipairs(config.fijos) do
        local h=sim.getObject(prefijo..name)
        quietos[h]=sim.getObjectMatrix(h,sim.handle_world)
    end
    pruebas=sim.readCustomTableData(root,'PRUEBA_V21') or {}
    servoActual=0
    cajaAlias='Objeto_de_ensayo_22mm'
    if not pruebas.activada then return end
    casos={}
    for _, rpm in ipairs({50,100,150,170}) do casos[#casos+1]={id='Referencia_'..rpm,rpm=rpm,duracion=2.2} end
    casos[#casos+1]={id='Apoyos_con_resistencia',rpm=170,duracion=2.8,cargaKg=0.08,factorFriccionApoyos=1.8}
    casos[#casos+1]={id='Atasco',rpm=170,duracion=2.0,atascoN=5}
    casos[#casos+1]={id='Prisionero_aflojado',rpm=170,duracion=2.2,factorCapacidadPrisionero=0.12}
    casos[#casos+1]={id='Acople_abierto',rpm=170,duracion=2.2,acopleAbierto=true}
    casos[#casos+1]={id='Traccion_reducida',rpm=170,duracion=2.2,factorTraccion=0.065}
    casos[#casos+1]={id='Deriva_encoder_sintetica',rpm=170,duracion=2.2,observacionSintetica=true,derivaEncoder=25}
    casos[#casos+1]={id='Transporte_neutro',rpm=170,duracion=6.5,objeto=true,servoGrad=0}
    casos[#casos+1]={id='Clasificacion_derecha',rpm=170,duracion=6.5,objeto=true,servoGrad=angulos.lo}
    casos[#casos+1]={id='Clasificacion_izquierda',rpm=170,duracion=6.5,objeto=true,servoGrad=angulos.hi}
    casos[#casos+1]={id='Transporte_50',rpm=50,duracion=16,objeto=true,servoGrad=0}
    casos[#casos+1]={id='Transporte_100',rpm=100,duracion=8,objeto=true,servoGrad=0}
    casos[#casos+1]={id='Transporte_150',rpm=150,duracion=6.5,objeto=true,servoGrad=0}
    resultado={casos={},escena='Banda_clasificadora_V2.ttt',dinamicaMotorYBanda='impulsos de fricción y modelo torsional equivalente',
        motorDinamicoDeObjetos=sim.getInt32Param(sim.intparam_dynamic_engine),parametros=dyn,fotos={}}
    casoActual=1
    reiniciarCaso(0)
    foto('13-Escena-CoppeliaSim.png',{0,placas[1].inicio[2],0.085},{0.47,-0.50,0.43},0.85)
end

local function medirComparacion(obs, medicion, orden)
    -- Las mediciones se comparan con los estados calculados y quedan fuera de su integración.
    local out={}
    if medicion.motorRPM and not orden.encoderSinDatos then out.residuoMotorRPM=medicion.motorRPM+(orden.derivaEncoder or 0)-obs.motorRPM end
    if medicion.motrizRPM then out.residuoRodilloRPM=medicion.motrizRPM-obs.motrizRPM end
    if medicion.bandaMps then out.residuoBandaMps=medicion.bandaMps-obs.bandaMps end
    if medicion.servoGrad then out.residuoServoGrad=medicion.servoGrad-servoActual end
    out.sinDatosEncoder=orden.encoderSinDatos==true
    out.comunicacionVigente=medicion.comunicacionVigente
    return out
end

function sysCall_actuation()
    if pruebas.activada and not accion then return end
    local t,dt=sim.getSimulationTime(),sim.getSimulationTimeStep()
    local orden=sim.readCustomTableData(root,'CONSIGNAS_LOCALES') or {}
    local servoObjetivo=clamp(tonumber(orden.desviadorGrad) or 0,angulos.lo,angulos.hi)
    if pruebas.activada then
        orden=casos[casoActual]
        local edad=t-inicio
        if orden.objeto and edad>=0.65 and not caja then colocarCaja() end
        if orden.objeto and accion.cruzaCamara and not cronometroServo then cronometroServo=t end
        local retirar=golpe and t-golpe>0.75 or edad>orden.duracion-0.45
        servoObjetivo=(cronometroServo and t-cronometroServo>=dyn.servo.retardoS+(orden.retardoServoS or 0) and not retirar) and orden.servoGrad or 0
        if caja then
            local objetoPos=sim.getObjectPosition(caja,sim.handle_world)
            if objetoPos[1]<placas[#placas].fin[1] then orden.cargaKg=dyn.objeto.masaKg else orden.cargaKg=0 end
        end
    else
        if servoObjetivo~=ordenServoAnterior then ordenServoAnterior=servoObjetivo; inicioOrdenServo=t end
        if t-inicioOrdenServo>=dyn.servo.retardoS+math.max(0,orden.retardoServoS or 0) then servoObjetivoLocal=servoObjetivo end
        servoObjetivo=servoObjetivoLocal
    end
    Dinamica.paso(state,dyn,orden,dt)
    local function set(j,v) sim.setJointPosition(j, math.atan(math.sin(v),math.cos(v))) end
    set(joints.salida_D4,-state.aM)
    set(joints.motriz,-state.aR)
    set(joints.conducido,-state.aB/0.015)
    for i=1,3 do set(joints['intermedio_'..i],-state.aB/0.014) end
    local limitado=clamp(servoObjetivo-servoActual,-dyn.servo.velocidadGradS*dt,dyn.servo.velocidadGradS*dt)
    servoActual=servoActual+limitado
    sim.setJointPosition(joints.desviador,math.rad(servoActual))
    if math.abs(limitado)>1e-10 then sim.resetDynamicObject(cotas.desviador) end
    for _,p in ipairs(placas) do
        sim.resetDynamicObject(p.handle)
        for i=1,3 do sim.setObjectFloatParam(p.handle,fr[i],p.direccion[i]*state.vB) end
    end
    local observacion=Dinamica.observar(state,dyn.rodillo.radioM)
    observacion.servoGrad=servoActual
    sim.writeCustomTableData(root,'ESTADO_ESPERADO_V21',observacion)
    local medicion=sim.readCustomTableData(root,'MEDICIONES_LOCALES_V21') or {}
    if pruebas.activada and orden.observacionSintetica then medicion={motorRPM=observacion.motorRPM,motrizRPM=observacion.motrizRPM} end
    local residuos=medirComparacion(observacion,medicion,orden)
    sim.writeCustomTableData(root,'RESIDUOS_V21',residuos)
    if pruebas.activada and orden.observacionSintetica then accion.residuoObservado=residuos end
    if pruebas.activada then
        accion.anguloMaxErrorGrad=math.max(accion.anguloMaxErrorGrad,math.abs(math.deg(sim.getJointPosition(joints.desviador))-servoActual))
        if not orden.acopleAbierto and (orden.factorCapacidadPrisionero or 1)==1 then
            local d=sim.getJointPosition(joints.salida_D4)-sim.getJointPosition(joints.motriz)
            accion.errorMaxAcopleRad=math.max(accion.errorMaxAcopleRad or 0,math.abs(math.atan(math.sin(d),math.cos(d))))
        end
    end
end

local function guardarResultados()
    sim.writeCustomTableData(root,'RESULTADOS_V21',resultado)
    local ruta=os.getenv('BANDA_V21')
    if ruta then
        package.path=os.getenv('BANDA_COPPELIA_V21')..'/luarocks/share/lua/5.3/?.lua;'..package.path
        local json=require('dkjson')
        local f=assert(io.open(ruta..'/EXPORTACION_COPPELIASIM/Resultados-V21.json','wb'))
        f:write(json.encode(resultado,{indent=true}));f:close()
    end
    sim.stopSimulation()
end

local function detectarContactos(t)
    local chequeados={}
    for i=0,63 do
        local coll, punto=sim.getContactInfo(sim.handle_all,caja,i)
        if not coll or #coll==0 then break end
        local h=coll[1]==caja and coll[2] or coll[1]
        local nombre=obstaculos[h]
        if nombre then
            accion.contactos[nombre]=(accion.contactos[nombre] or 0)+1
            if not chequeados[h] then
                chequeados[h]=true
                local inter=sim.checkCollision(caja,h)
                if inter>0 then accion.penetracionesGeometricas[nombre]=(accion.penetracionesGeometricas[nombre] or 0)+1 end
            end
            if nombre=='Desviador:1' then
                if not golpe then
                    golpe=t
                    accion.primerContactoDesviador={t=t-inicio,contactoM=punto,servoGrad=servoActual}
                end
                accion.tocaDesviador=true
            end
        end
    end
end

function sysCall_sensing()
    if not pruebas.activada or not accion then return end
    local t=sim.getSimulationTime()
    local edad=t-inicio
    local c=casos[casoActual]
    local p=caja and sim.getObjectPosition(caja,sim.handle_world) or nil
    if p then
        if p[1]>=config.ejeInspeccion[1] and p[3]>config.ejeInspeccion[3]+0.006 and math.abs(p[2]-config.ejeInspeccion[2])<0.045 then
            accion.cruzaCamara=true
            accion.tCruceCamaraS=accion.tCruceCamaraS or edad
        end
        if p[1]>=placas[#placas].fin[1]-0.003 then accion.finRamal=true end
        detectarContactos(t)
        if c.id=='Transporte_neutro' and accion.cruzaCamara and not fotoBajoCamara then
            fotoBajoCamara=true
            foto('14-Objeto-sobre-ramal.png',p,{0.30,-0.31,0.30},0.43)
        end
        if c.id=='Transporte_neutro' and accion.finRamal and not accion.fotografioSalida then
            accion.fotografioSalida=true
            foto('15-Objeto-zona-desviador.png',p,{0.19,-0.18,0.18},0.33)
        end
        if c.id=='Clasificacion_derecha' then
            local k=math.floor((edad-0.65)/0.35)
            if k>=0 and k<=16 and k~=(accion.fotograma or -1) then
                accion.fotograma=k
                foto(('Recorrido/Derecha-%02d.png'):format(k),{0.04,placas[1].inicio[2],0.10},{0.46,-0.49,0.41},0.87)
            end
        end
    end
    if edad-ultimaMuestra>=0.19 then
        ultimaMuestra=edad
        local q=Dinamica.observar(state,dyn.rodillo.radioM)
        q.t=edad; q.servoGrad=servoActual; q.objetoM=p
        accion.lecturas[#accion.lecturas+1]=q
        for h, inicial in pairs(quietos) do
            local m=sim.getObjectMatrix(h,sim.handle_world)
            for i=4,12,4 do accion.derivaFijosM=math.max(accion.derivaFijosM,math.abs(m[i]-inicial[i])) end
        end
    end
    if edad+sim.getSimulationTimeStep()/2<c.duracion then return end
    accion.estadoFinal=Dinamica.observar(state,dyn.rodillo.radioM)
    accion.retornoServoGrad=servoActual
    if p then
        accion.finalM=p
        accion.lateralMm=1000*(p[2]-accion.inicial[2])
        accion.avanceMm=1000*(p[1]-accion.inicial[1])
        accion.salidaCompleta=accion.finRamal and accion.tocaDesviador and p[1]>config.centroDesviador[1]+0.015
        accion.ladoEsperado=signo(c.servoGrad)
        accion.ladoObservado=math.abs(accion.lateralMm)<8 and 0 or signo(accion.lateralMm)
        accion.clasificacionVerificada=accion.salidaCompleta and accion.ladoEsperado==accion.ladoObservado
        sim.removeObjects({caja}); caja=nil
    end
    resultado.casos[#resultado.casos+1]=accion
    casoActual=casoActual+1
    if not reiniciarCaso(t) then accion=nil; guardarResultados() end
end
