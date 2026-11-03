$ErrorActionPreference = 'Stop'
$node = Join-Path $env:ProgramFiles 'nodejs\node.exe'
if (Test-Path $node) { exit 0 }
$version = '22.23.4'
$url = "https://nodejs.org/dist/v$version/node-v$version-x64.msi"
$msi = Join-Path $env:TEMP "SEZ-Node-$version-x64.msi"
Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
$proc = Start-Process msiexec.exe -ArgumentList @('/i', "`"$msi`"", '/qn', '/norestart') -Wait -PassThru
Remove-Item $msi -Force -ErrorAction SilentlyContinue
if ($proc.ExitCode -ne 0) { throw "Falha ao instalar Node.js. Código: $($proc.ExitCode)" }
if (-not (Test-Path $node)) { throw 'Node.js não foi localizado após a instalação.' }
