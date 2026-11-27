local sim=require('sim')
local raiz=assert(os.getenv('BANDA_V21'))
local ruta=raiz..'/EXPORTACION_COPPELIASIM/'
local funcion=function()
    local f=assert(io.open(ruta..'Banda_clasificadora_V2.ttt','rb'))
    local datos=f:read('*a');f:close()
    sim.loadScene(tobuffer(datos))
    local a=sim.getObject('/Banda_Clasificadora_V2')
    local config=sim.readCustomTableData(a,'BANDA_V21')
    assert(math.abs(config.neutralCad)<0.01 and #config.fijos==51,'La escena no conserva las posiciones guardadas')
    sim.writeCustomTableData(a,'PRUEBA_V21',{activada=true})
end
local ok,msg=xpcall(funcion,debug.traceback)
local log=assert(io.open(ruta..'Reapertura-V21.log','wb'));log:write(ok and 'Escena reabierta. Ensayos previstos ejecutándose.' or msg);log:close()
if ok then sim.startSimulation() else sim.quitSimulator() end
