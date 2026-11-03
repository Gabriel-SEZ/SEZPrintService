param(
    [string]$LogFile = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($LogFile)) {
    $logDir = Join-Path $env:ProgramData 'SmartEZ\SEZ Print Service\logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $LogFile = Join-Path $logDir 'service-install.log'
} else {
    $logDir = Split-Path -Parent $LogFile
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Write-Step([string]$Message) {
    $line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '] ' + $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8 -ErrorAction Stop
    Write-Host $line
}

try {
    Write-Step 'Iniciando registro do serviço SEZ Print Service 0.4.7.'
    Write-Step "Identidade: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Step "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Step "Diretório de instalação: $PSScriptRoot"

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
            throw "Arquivo obrigatório não encontrado: $file"
        }
        $item = Get-Item -LiteralPath $file
        Write-Step "Arquivo confirmado: $($item.FullName) ($($item.Length) bytes)"
    }

    $nodeVersion = (& $node --version 2>&1 | Out-String).Trim()
    $nodeExit = $LASTEXITCODE
    Write-Step "Node.js retornou '$nodeVersion', código $nodeExit."
    if ($nodeExit -ne 0 -or $nodeVersion -notmatch '^v22\.') {
        throw "Runtime Node.js inválido. Saída: $nodeVersion; código: $nodeExit"
    }

    $existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($existing) {
        Write-Step "Serviço antigo encontrado: $($existing.Status)."
        if ($existing.Status -ne 'Stopped') {
            Stop-Service -Name $serviceName -Force -ErrorAction Stop
            $existing.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(20))
        }

        & "$env:WINDIR\System32\sc.exe" delete $serviceName 2>&1 |
            ForEach-Object { Write-Step "sc delete: $_" }
        $scExit = $LASTEXITCODE
        if ($scExit -ne 0) {
            throw "Não foi possível remover o serviço anterior. sc.exe retornou $scExit."
        }

        $deleted = $false
        for ($i = 0; $i -lt 40; $i++) {
            Start-Sleep -Milliseconds 500
            if (-not (Get-Service -Name $serviceName -ErrorAction SilentlyContinue)) {
                $deleted = $true
                break
            }
        }
        if (-not $deleted) {
            throw 'O Windows ainda está liberando o registro do serviço anterior.'
        }
        Write-Step 'Registro anterior removido.'
    } else {
        Write-Step 'Não havia serviço anterior registrado.'
    }

    $binaryPath = '"' + $exe + '"'
    Write-Step "Criando serviço. BinaryPathName=$binaryPath"
    $newServiceArgs = @{
        Name = $serviceName
        BinaryPathName = $binaryPath
        DisplayName = $displayName
        Description = $description
        StartupType = 'Automatic'
        ErrorAction = 'Stop'
    }
    New-Service @newServiceArgs | Out-Null

    $service = Get-Service -Name $serviceName -ErrorAction Stop
    Write-Step "Serviço registrado. Estado: $($service.Status); StartType: $($service.StartType)."

    & "$env:WINDIR\System32\sc.exe" failure $serviceName reset= 86400 actions= restart/5000/restart/15000/restart/30000 2>&1 |
        ForEach-Object { if ($_ -and $_.Trim()) { Write-Step "sc failure: $_" } }
    $scExit = $LASTEXITCODE
    Write-Step "sc failure terminou com código $scExit."
    if ($scExit -ne 0) { throw "Falha ao configurar recuperação automática. sc.exe retornou $scExit." }

    & "$env:WINDIR\System32\sc.exe" failureflag $serviceName 1 2>&1 |
        ForEach-Object { if ($_ -and $_.Trim()) { Write-Step "sc failureflag: $_" } }
    $scExit = $LASTEXITCODE
    Write-Step "sc failureflag terminou com código $scExit."
    if ($scExit -ne 0) { throw "Falha ao ativar recuperação automática. sc.exe retornou $scExit." }

    Set-Service -Name $serviceName -StartupType Automatic -ErrorAction Stop
    Write-Step 'StartupType automático configurado.'

    Write-Step 'Solicitando início do serviço.'
    Start-Service -Name $serviceName -ErrorAction Stop

    $deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 500
        $service = Get-Service -Name $serviceName -ErrorAction Stop
        if ($service.Status -eq 'Running') { break }
    } while ((Get-Date) -lt $deadline)

    if ($service.Status -ne 'Running') {
        $cim = Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue
        if ($cim) {
            Write-Step "Win32_Service: State=$($cim.State); StartMode=$($cim.StartMode); ExitCode=$($cim.ExitCode); ServiceSpecificExitCode=$($cim.ServiceSpecificExitCode); ProcessId=$($cim.ProcessId); PathName=$($cim.PathName)"
        }
        throw "O serviço não chegou ao estado Running. Estado: $($service.Status)."
    }

    $cim = Get-CimInstance Win32_Service -Filter "Name='$serviceName'" -ErrorAction SilentlyContinue
    if ($cim) {
        Write-Step "Serviço ativo. PID=$($cim.ProcessId); PathName=$($cim.PathName)"
    }
    Write-Step 'SEZ Print Service instalado e iniciado com sucesso.'
    exit 0
}
catch {
    $detail = $_.Exception.ToString()
    try { Write-Step ("FALHA: " + $detail) } catch { }

    try {
        $svc = Get-Service -Name 'SEZPrintService' -ErrorAction SilentlyContinue
        if ($svc) { Write-Step "Estado do serviço após falha: $($svc.Status)." }
    } catch { }

    try {
        $events = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            ProviderName = 'Service Control Manager'
            StartTime = (Get-Date).AddMinutes(-10)
        } -MaxEvents 8 -ErrorAction SilentlyContinue
        foreach ($event in $events) {
            Write-Step ("SCM Event ID " + $event.Id + ": " + ($event.Message -replace '\r?\n', ' '))
        }
    } catch { }

    [Console]::Error.WriteLine("Falha ao registrar o serviço. Log: $LogFile")
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
