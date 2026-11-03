$ErrorActionPreference = 'Stop'
$logDir = Join-Path $env:ProgramData 'SmartEZ\SEZ Print Service\logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir 'upgrade-stop.log'

function Write-Step([string]$Message) {
    $line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '] ' + $Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

try {
    Write-Step 'Preparando atualização: interrompendo versão anterior do serviço.'
    $serviceName = 'SEZPrintService'
    $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue

    if ($service -and $service.Status -ne 'Stopped') {
        Stop-Service -Name $serviceName -Force -ErrorAction Stop
        $deadline = (Get-Date).AddSeconds(30)
        do {
            Start-Sleep -Milliseconds 300
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if (-not $service -or $service.Status -eq 'Stopped') { break }
        } while ((Get-Date) -lt $deadline)

        if ($service -and $service.Status -ne 'Stopped') {
            throw "O serviço não parou dentro do limite. Estado atual: $($service.Status)"
        }
    }
    Write-Step 'Serviço parado ou já estava parado.'

    # O host é o processo que mantém o próprio EXE aberto como serviço Windows.
    $hostProcesses = @(Get-Process -Name 'SEZPrintServiceHost' -ErrorAction SilentlyContinue)
    foreach ($process in $hostProcesses) {
        Write-Step "Aguardando liberação do processo host PID $($process.Id)."
        try {
            if (-not $process.HasExited) {
                $process.WaitForExit(5000)
            }
        } catch { }
        if (-not $process.HasExited) {
            Write-Step "Processo host PID $($process.Id) ainda ativo após Stop-Service; encerrando o processo residual."
            Stop-Process -Id $process.Id -Force -ErrorAction Stop
        }
    }

    Start-Sleep -Milliseconds 800
    $remaining = @(Get-Process -Name 'SEZPrintServiceHost' -ErrorAction SilentlyContinue)
    if ($remaining.Count -gt 0) {
        throw 'O executável SEZPrintServiceHost.exe ainda está em uso após a parada do serviço.'
    }

    Write-Step 'Host liberado. A atualização pode substituir SEZPrintServiceHost.exe.'
    exit 0
}
catch {
    $detail = $_.Exception.ToString()
    try { Write-Step ("FALHA: " + $detail) } catch { }
    Write-Error ("Não foi possível preparar a atualização. Consulte: " + $logFile + " — " + $_.Exception.Message)
    exit 1
}
