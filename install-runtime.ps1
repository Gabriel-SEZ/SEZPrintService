$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$logDir = Join-Path $env:ProgramData 'SmartEZ\SEZ Print Service\logs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir 'installer-components.log'
$transcriptStarted = $false

function Write-Step([string]$Message) {
    $line = '[' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + '] ' + $Message
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    Write-Host $line
}

function Find-Node {
    $bases = @(
        $env:ProgramW6432,
        $env:ProgramFiles,
        [Environment]::GetEnvironmentVariable('ProgramFiles(x86)'),
        $env:LOCALAPPDATA
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique

    foreach ($base in $bases) {
        $candidate = Join-Path $base 'nodejs\node.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }

    $command = Get-Command node.exe -ErrorAction SilentlyContinue
    if ($command -and $command.Source -and (Test-Path -LiteralPath $command.Source -PathType Leaf)) {
        return $command.Source
    }
    return $null
}

try {
    try {
        Start-Transcript -LiteralPath $logFile -Append -Force | Out-Null
        $transcriptStarted = $true
    } catch { }

    Write-Step 'Iniciando preparação dos componentes do SEZ Print Service 0.4.1.'

    # Node.js 22.23.3 x64 — SHA-256 publicado no anúncio oficial da versão.
    $nodeVersion = '22.23.3'
    $expectedNodeSha256 = '1c0efc8449987e7da5d184786a0a96da83ffa11d334421201e5c09b93017cb8d'
    $node = Find-Node
    $nodeNeedsInstall = $true

    if ($node) {
        $installedVersion = (& $node --version 2>&1 | Out-String).Trim()
        Write-Step "Node.js encontrado: $node ($installedVersion)"
        if ($installedVersion -match '^v?(\d+)\.') {
            if ([int]$Matches[1] -ge 20) {
                $nodeNeedsInstall = $false
                Write-Step 'Node.js compatível já instalado; instalação será preservada.'
            } else {
                Write-Step 'Node.js antigo detectado. Será atualizado para a versão 22 LTS.'
            }
        } else {
            Write-Step 'Versão Node.js existente não pôde ser identificada. Será reinstalado o runtime suportado.'
        }
    } else {
        Write-Step 'Node.js não encontrado. Baixando instalador oficial.'
    }

    if ($nodeNeedsInstall) {
        $url = "https://nodejs.org/dist/v$nodeVersion/node-v$nodeVersion-x64.msi"
        $msi = Join-Path $env:TEMP "SEZ-Node-$nodeVersion-x64.msi"
        $msiLog = Join-Path $env:TEMP "SEZ-Node-$nodeVersion-msi.log"

        try {
            Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing -TimeoutSec 180
            if (-not (Test-Path -LiteralPath $msi -PathType Leaf)) { throw 'O download do Node.js não criou o arquivo MSI.' }
            $actualNodeSha256 = (Get-FileHash -LiteralPath $msi -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actualNodeSha256 -ne $expectedNodeSha256) {
                throw "SHA-256 do Node.js não confere. Obtido: $actualNodeSha256"
            }
            Write-Step 'Download do Node.js concluído e SHA-256 confirmado.'

            $msiexec = Join-Path $env:WINDIR 'System32\msiexec.exe'
            $arguments = '/i "' + $msi + '" /qn /norestart /l*v "' + $msiLog + '"'
            $proc = Start-Process -FilePath $msiexec -ArgumentList $arguments -Wait -PassThru
            Write-Step "Instalador MSI do Node.js finalizou com código $($proc.ExitCode)."

            if ($proc.ExitCode -notin @(0, 3010, 1641, 1638)) {
                throw "MSI do Node.js falhou com código $($proc.ExitCode). Log MSI: $msiLog"
            }
        }
        finally {
            Remove-Item -LiteralPath $msi -Force -ErrorAction SilentlyContinue
        }

        $node = Find-Node
        if (-not $node) {
            throw "Node.js não foi localizado após a instalação. Consulte o log MSI: $msiLog"
        }
    }

    $installedVersion = (& $node --version 2>&1 | Out-String).Trim()
    if ($installedVersion -notmatch '^v?(\d+)\.' -or [int]$Matches[1] -lt 20) {
        throw "Versão Node.js incompatível após preparação: $installedVersion"
    }
    Write-Step "Node.js pronto: $installedVersion em $node"

    # SumatraPDF 3.6.1 x64 — download portátil oficial com hash conferido.
    $sumatraVersion = '3.6.1'
    $expectedSumatraSha256 = '98b33a518d42986856d225064b0cd2d3643ecf78cbf84ab873d26cc51877a544'
    $toolsDir = Join-Path $PSScriptRoot 'tools'
    $sumatraExe = Join-Path $toolsDir 'SumatraPDF.exe'
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null

    if (Test-Path -LiteralPath $sumatraExe -PathType Leaf) {
        Write-Step 'SumatraPDF portátil já existe; verificando arquivo.'
    } else {
        Write-Step 'Baixando SumatraPDF portátil 64-bit do site oficial.'
        $sumatraUrl = "https://www.sumatrapdfreader.org/dl/rel/$sumatraVersion/SumatraPDF-$sumatraVersion-64.zip"
        $zip = Join-Path $env:TEMP "SEZ-SumatraPDF-$sumatraVersion-x64.zip"
        $extractDir = Join-Path $env:TEMP "SEZ-SumatraPDF-$sumatraVersion"

        try {
            Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
            Invoke-WebRequest -Uri $sumatraUrl -OutFile $zip -UseBasicParsing -TimeoutSec 180
            if (-not (Test-Path -LiteralPath $zip -PathType Leaf)) { throw 'O download SumatraPDF não criou o arquivo ZIP.' }

            $actualSumatraSha256 = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actualSumatraSha256 -ne $expectedSumatraSha256) {
                throw "SHA-256 do SumatraPDF não confere. Obtido: $actualSumatraSha256"
            }
            Write-Step 'Download SumatraPDF concluído e SHA-256 confirmado.'

            Expand-Archive -LiteralPath $zip -DestinationPath $extractDir -Force
            $candidate = Get-ChildItem -LiteralPath $extractDir -Filter 'SumatraPDF.exe' -File -Recurse |
                Select-Object -First 1
            if (-not $candidate) {
                $candidate = Get-ChildItem -LiteralPath $extractDir -Filter 'SumatraPDF-*.exe' -File -Recurse |
                    Select-Object -First 1
            }
            if (-not $candidate) { throw 'O ZIP oficial não contém o executável SumatraPDF esperado.' }

            Copy-Item -LiteralPath $candidate.FullName -Destination $sumatraExe -Force
            $portableFiles = Get-ChildItem -LiteralPath $candidate.DirectoryName -File |
                Where-Object { $_.FullName -ne $candidate.FullName }
            foreach ($item in $portableFiles) {
                Copy-Item -LiteralPath $item.FullName -Destination $toolsDir -Force
            }
        }
        finally {
            Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
            Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if (-not (Test-Path -LiteralPath $sumatraExe -PathType Leaf)) {
        throw 'SumatraPDF não foi localizado após a preparação.'
    }
    Write-Step "SumatraPDF pronto: $sumatraExe"
    Write-Step 'Preparação dos componentes concluída com sucesso.'
    exit 0
}
catch {
    $detail = $_.Exception.ToString()
    Write-Step ("FALHA: " + $detail)
    Write-Error ("Falha ao preparar os componentes. Detalhes em: " + $logFile + " — " + $_.Exception.Message)
    exit 1
}
finally {
    if ($transcriptStarted) {
        try { Stop-Transcript | Out-Null } catch { }
    }
}
