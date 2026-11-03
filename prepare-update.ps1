param(
    [string]$LogFile = ''
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($LogFile)) {
    $logDir = Join-Path $env:ProgramData 'SmartEZ\SEZ Print Service\logs'
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    $LogFile = Join-Path $logDir 'upgrade-stop.log'
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
    Write-Step 'Iniciando pré-atualização do SEZ Print Service 0.4.6.'
    Write-Step "Conta efetiva: $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    Write-Step "Diretório do instalador: $PSScriptRoot"

    $serviceName = 'SEZPrintService'
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($service) {
        Write-Step "Serviço encontrado. Estado inicial: $($service.Status)"
        if ($service.Status -ne 'Stopped') {
            Write-Step 'Solicitando parada normal do serviço.'
            Stop-Service -Name $serviceName -Force -ErrorAction Stop

            $deadline = (Get-Date).AddSeconds(30)
            do {
                Start-Sleep -Milliseconds 300
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if (-not $service -or $service.Status -eq 'Stopped') { break }
            } while ((Get-Date) -lt $deadline)

            if ($service -and $service.Status -ne 'Stopped') {
                throw "O serviço não parou em 30 segundos. Estado atual: $($service.Status)"
            }
            Write-Step 'O Service Control Manager confirmou o estado Stopped.'
        }
    } else {
        Write-Step 'Serviço SEZPrintService não está registrado. Verificando processo residual.'
    }

    $hostProcesses = @(Get-Process -Name 'SEZPrintServiceHost' -ErrorAction SilentlyContinue)
    foreach ($process in $hostProcesses) {
        Write-Step "Processo host detectado: PID $($process.Id). Aguardando encerramento."
        try {
            if (-not $process.HasExited) { [void]$process.WaitForExit(7000) }
        } catch {
            Write-Step "Aviso ao aguardar PID $($process.Id): $($_.Exception.Message)"
        }

        try {
            if (-not $process.HasExited) {
                Write-Step "PID $($process.Id) permaneceu ativo. Encerrando o processo residual após a parada do serviço."
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
                [void]$process.WaitForExit(5000)
            }
        } catch {
            throw "Não foi possível encerrar o processo host PID $($process.Id): $($_.Exception.Message)"
        }
    }

    Start-Sleep -Milliseconds 1000
    $remaining = @(Get-Process -Name 'SEZPrintServiceHost' -ErrorAction SilentlyContinue)
    if ($remaining.Count -gt 0) {
        $pids = ($remaining | ForEach-Object { $_.Id }) -join ', '
        throw "Ainda existem processos SEZPrintServiceHost em execução. PID(s): $pids"
    }

    Write-Step 'Nenhum processo SEZPrintServiceHost permanece ativo.'
    Write-Step 'Pré-atualização concluída. O executável pode ser substituído.'
    exit 0
}
catch {
    $detail = $_.Exception.ToString()
    try { Write-Step ("FALHA: " + $detail) } catch { }
    [Console]::Error.WriteLine("Falha na pré-atualização. Log: $LogFile")
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
