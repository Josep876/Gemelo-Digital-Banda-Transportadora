param(
    [Parameter(Mandatory)][ValidateSet('crear','validar')][string]$Modo,
    [string]$Instalacion = (Join-Path $env:ProgramFiles 'CoppeliaRobotics\CoppeliaSimEdu')
)
$ErrorActionPreference = 'Stop'
$proyecto = Split-Path -Parent $PSScriptRoot
$simulador = (Resolve-Path -LiteralPath $Instalacion).Path
$exe = Join-Path $simulador 'coppeliaSim.exe'
$env:BANDA_V21 = $proyecto
$env:BANDA_COPPELIA_V21 = $simulador
[void](New-Item -ItemType Directory -Path (Join-Path $proyecto 'Capturas\Recorrido') -Force)
$script = if ($Modo -eq 'crear') { 'Crear-escena-V21.lua' } else { 'Validar-escena-V21.lua' }
$codigo = "-cassert(loadfile(os.getenv('BANDA_V21')..'/Scripts/$script'))()"
$argumentos = @('-h', '-vwarnings', '-xerrors', '-GwsRemoteApi.autoStart=false', '-GzmqRemoteApi.autoStart=false', $codigo)
if ($Modo -eq 'validar') { $argumentos += @('-s83000','-q') }
$registro = Join-Path $proyecto ('EXPORTACION_COPPELIASIM\Consola-' + $Modo + '.log')
$errores = Join-Path $proyecto ('EXPORTACION_COPPELIASIM\Consola-' + $Modo + '-errores.log')
$proceso = Start-Process -FilePath $exe -ArgumentList $argumentos -WindowStyle Hidden -WorkingDirectory $simulador -PassThru -RedirectStandardOutput $registro -RedirectStandardError $errores
if (!$proceso.WaitForExit(55000)) {
    Write-Warning ('CoppeliaSim excedió 55 segundos. Identificador de la sesión de prueba ' + $proceso.Id)
    exit 124
}
if (Test-Path -LiteralPath $registro) { Get-Content -LiteralPath $registro -Tail 15 }
if (Test-Path -LiteralPath $errores) { Get-Content -LiteralPath $errores -Tail 15 }
exit $proceso.ExitCode
