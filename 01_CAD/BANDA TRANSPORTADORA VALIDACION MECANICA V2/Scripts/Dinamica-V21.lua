local M = {}
local rpmARad = 2 * math.pi / 60

local function limite(x, lo, hi)
    return math.max(lo, math.min(hi, x))
end

function M.estado()
    return {wM = 0, wR = 0, vB = 0, aM = 0, aR = 0, aB = 0, par = 0, apoyo = 0, acople = 0, traccion = 0}
end

local function datosApoyos(config, orden, movimiento)
    local normales = orden.factorNormales or 1
    local variacion = orden.factorFriccionApoyos or 1
    local carga = 9.81 * math.max(0, orden.cargaKg or 0) * config.banda.pesoCargaDistribuido / #config.apoyos
    local sum = config.banda.fuerzaBaseN
    for _, a in ipairs(config.apoyos) do
        local normal = math.max(0, a.normalN * normales + carga)
        sum = sum + normal * variacion * (movimiento and a.muDinamica or a.muEstatica)
    end
    return sum
end

local function avanzar(s, p, c, dt)
    local r = p.rodillo.radioM
    local jm = p.inercias.motorKgM2
    local jr = p.inercias.motrizKgM2
    local mb = p.inercias.masaEquivalenteBandaKg
    local entrada = limite((c.rpm or 0) / p.motor.referenciaMaxRpm, -1, 1)
    local w0 = p.motor.vacioEscenarioRpm * rpmARad
    local T = p.motor.parBloqueoNm * limite(entrada - s.wM / w0, -1, 1)
    local Tm = T - p.motor.perdidaViscosaNmS * s.wM
    local Tr = -p.rodillo.perdidaViscosaNmS * s.wR
    local factor = limite(c.factorCapacidadPrisionero or 1, 0, 1)
    local rigido = factor >= 1 and not c.acopleAbierto
    local je, estacionario = jr, math.abs(s.vB) < 0.0005
    local impulsoSoporte, impulsoTraccion, transferencia = 0, 0, 0
    local wM, wR
    if rigido then
        je = jm + jr
        wR = (jm * s.wM + jr * s.wR + dt * (Tm + Tr)) / je
        wM = wR
    else
        wM, wR = s.wM + dt * Tm / jm, s.wR + dt * Tr / jr
        local maxPar = c.acopleAbierto and 0 or factor * p.acople.capacidadEscenarioNm
        local equiv = 1 / (1 / jm + 1 / jr)
        local k = p.acople.amortiguamientoNmS * dt
        transferencia = limite((wM - wR) * k * equiv / (equiv + k), -maxPar * dt, maxPar * dt)
        wM, wR = wM - transferencia / jm, wR + transferencia / jr
    end

    local v = s.vB
    local limiteSoporte = dt * (datosApoyos(p, c, not estacionario) + math.max(0, c.atascoN or 0))
    local desliza = math.abs(r * s.wR - s.vB) > 0.001
    local mu = desliza and p.banda.muDinamicaPOM or p.banda.muEstaticaPOM
    local limiteTraccion = dt * math.max(0, c.factorTraccion or 1) * p.banda.pretensionRamaFlojaN *
        (math.exp(mu * p.banda.envolturaMotrizRad) - 1)
    for _ = 1, 12 do
        -- Proyección de impulsos de Coulomb con límites de fuerza sobre la banda, incluidos los seis apoyos.
        local siguiente = limite(impulsoSoporte - mb * v, -limiteSoporte, limiteSoporte)
        v = v + (siguiente - impulsoSoporte) / mb
        impulsoSoporte = siguiente
        siguiente = limite(impulsoTraccion + (r * wR - v) / (r * r / je + 1 / mb), -limiteTraccion, limiteTraccion)
        local cambio = siguiente - impulsoTraccion
        wR, v = wR - r * cambio / je, v + cambio / mb
        impulsoTraccion = siguiente
    end
    if rigido then
        wM = wR
        transferencia = jr * (wR - s.wR) - Tr * dt + r * impulsoTraccion
    end
    s.wM, s.wR, s.vB = wM, wR, v
    s.aM, s.aR, s.aB = s.aM + dt*wM, s.aR + dt*wR, s.aB + dt*v
    s.par = T
    s.apoyo, s.acople, s.traccion = -impulsoSoporte/dt, transferencia/dt, impulsoTraccion/dt
end

function M.paso(s, p, c, dt)
    local n = math.max(1, math.ceil(dt / 0.002))
    for _ = 1, n do avanzar(s, p, c, dt / n) end
    return s
end

function M.observar(s, radio)
    return {motorRPM = s.wM / rpmARad, motrizRPM = s.wR / rpmARad, bandaMps = s.vB,
        diferenciaAcopleRPM = (s.wM - s.wR) / rpmARad, deslizamientoMps = radio * s.wR - s.vB,
        parMotorNm = s.par, parAcopleNm = s.acople, fuerzaResistenteN = s.apoyo, fuerzaTraccionN = s.traccion}
end

return M
