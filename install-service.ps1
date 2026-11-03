$ErrorActionPreference = 'Stop'

$serviceName = 'SEZPrintService'
$displayName = 'SEZ Print Service'
$description = 'Serviço local de impressão do Smart EZ ERP. Inicia com o Windows, antes do login.'
$exe = Join-Path $PSScriptRoot 'SEZPrintServiceHost.exe'

if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "Executável do serviço não encontrado: $exe"
}

# Remove uma instalação anterior e aguarda o Service Control Manager liberar o nome.
$existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existing) {
    if ($existing.Status -ne 'Stopped') {
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        $existing.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(20))
    }

    & "$env:WINDIR\System32\sc.exe" delete $serviceName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Não foi possível remover o serviço anterior (sc.exe: $LASTEXITCODE)."
    }

    $deleted = $false
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Milliseconds 500
        if (-not (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) {
            $deleted = $true
            break
        }
    }
    if (-not $deleted) {
        throw 'O Windows ainda está liberando o registro da instalação anterior. Reinicie o computador e execute o instalador novamente.'
    }
}

# New-Service grava o caminho binário corretamente, inclusive quando Program Files contém espaços.
$binaryPath = '"' + $exe + '"'
New-Service -Name $serviceName -BinaryPathName $binaryPath -DisplayName $displayName -Description $description -StartupType Automatic -ErrorAction Stop | Out-Null

$service = Get-Service -Name $serviceName -ErrorAction Stop
if (-not $service) {
    throw 'O Windows não confirmou a criação do serviço SEZ Print Service.'
}

# Reiniciar o processo do serviço quando o host falhar.
& "$env:WINDIR\System32\sc.exe" failure $serviceName 'reset=' '86400' 'actions=' 'restart/5000/restart/15000/restart/30000' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Falha ao configurar recuperação automática (sc.exe: $LASTEXITCODE)."
}

& "$env:WINDIR\System32\sc.exe" failureflag $serviceName '1' | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Falha ao ativar sinalização de recuperação (sc.exe: $LASTEXITCODE)."
}

Set-Service -Name $serviceName -StartupType Automatic -ErrorAction Stop
Start-Service -Name $serviceName -ErrorAction Stop

$deadline = (Get-Date).AddSeconds(20)
do {
    Start-Sleep -Milliseconds 500
    $service = Get-Service -Name $serviceName -ErrorAction Stop
    if ($service.Status -eq 'Running') { break }
} while ((Get-Date) -lt $deadline)

if ($service.Status -ne 'Running') {
    throw "O serviço foi criado, mas não iniciou. Estado atual: $($service.Status). Consulte os logs em ProgramData\SmartEZ\SEZ Print Service\logs."
}

Write-Host 'SEZ Print Service instalado e iniciado.'
Write-Host 'Inicialização: Automática (antes do login).'
Write-Host 'Conta: LocalSystem.'
Write-Host 'Recuperação: reiniciar após falhas.'
