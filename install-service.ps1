$ErrorActionPreference = 'Stop'

$logDir = Join-Path $env:ProgramData 'SmartEZ\SEZ Print Service\logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir 'service-install.log'
function Write-Step([string]$Message) {
    $line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '] ' + $Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

try {
Write-Step 'Iniciando registro do serviço SEZ Print Service 0.4.5.'

$serviceName = 'SEZPrintService'
$displayName = 'SEZ Print Service'
$description = 'Serviço local de impressão silenciosa do Smart EZ ERP. Inicia com o Windows.'
$exe = Join-Path $PSScriptRoot 'SEZPrintServiceHost.exe'
$node = Join-Path $PSScriptRoot 'runtime\node.exe'

$required = @(
    (Join-Path $PSScriptRoot 'server.js'),
    (Join-Path $PSScriptRoot 'print-engine.js'),
    (Join-Path $PSScriptRoot 'tools\SumatraPDF.exe'),
    $node,
    $exe
)
foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Arquivo obrigatório do SEZ Print Service não encontrado: $file"
    } else {
        Write-Step "Arquivo confirmado: $file"
    }
}
if (-not (Test-Path -LiteralPath $node -PathType Leaf)) {
    throw "Runtime Node.js embarcado não encontrado: $node"
}
$nodeVersion = (& $node --version 2>&1 | Out-String).Trim()
if ($nodeVersion -notmatch '^v22\.') {
    throw "Versão do runtime Node.js embarcado inesperada: $nodeVersion"
}
Write-Step "Runtime Node.js pronto: $nodeVersion"

$existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existing) {
    if ($existing.Status -ne 'Stopped') {
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        $existing.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(20))
    }
    & "$env:WINDIR\System32\sc.exe" delete $serviceName | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Não foi possível remover o serviço anterior (sc.exe: $LASTEXITCODE)." }
    Write-Step 'Serviço anterior removido.'
    $deleted = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 500
        if (-not (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) { $deleted = $true; break }
    }
    if (-not $deleted) { throw 'O Windows ainda está liberando o registro do serviço anterior. Reinicie e execute novamente.' }
}

$binaryPath = '"' + $exe + '"'
New-Service -Name $serviceName -BinaryPathName $binaryPath -DisplayName $displayName -Description $description -StartupType Automatic -ErrorAction Stop | Out-Null
$service = Get-Service -Name $serviceName -ErrorAction Stop
if (-not $service) { throw 'O Windows não confirmou a criação do serviço SEZ Print Service.' }
Write-Step 'Serviço do Windows registrado.'

& "$env:WINDIR\System32\sc.exe" failure $serviceName 'reset=' '86400' 'actions=' 'restart/5000/restart/15000/restart/30000' | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Falha ao configurar recuperação automática (sc.exe: $LASTEXITCODE)." }
& "$env:WINDIR\System32\sc.exe" failureflag $serviceName '1' | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Falha ao ativar sinalização de recuperação (sc.exe: $LASTEXITCODE)." }

Set-Service -Name $serviceName -StartupType Automatic -ErrorAction Stop
Start-Service -Name $serviceName -ErrorAction Stop
$deadline = (Get-Date).AddSeconds(25)
do {
    Start-Sleep -Milliseconds 500
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    if ($service.Status -eq 'Running') { break }
} while ((Get-Date) -lt $deadline)
if ($service.Status -ne 'Running') {
    throw 'O serviço foi criado, mas não iniciou. Consulte %ProgramData%\SmartEZ\SEZ Print Service\logs.'
}

Write-Step 'SEZ Print Service instalado e iniciado.'
Write-Step 'Inicialização automática; conta LocalSystem; recuperação após falhas habilitada.'
}
catch {
    $detail = $_.Exception.ToString()
    try { Write-Step ("FALHA: " + $detail) } catch { }
    Write-Error ("Falha ao registrar o serviço. Consulte: " + $logFile + " — " + $_.Exception.Message)
    exit 1
}
