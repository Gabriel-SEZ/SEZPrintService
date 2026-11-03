$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# O SEZ Print Service roda como serviço nativo do Windows.
$nodeCandidates = @(
    (Join-Path $env:ProgramFiles 'nodejs\node.exe'),
    (Join-Path ([Environment]::GetEnvironmentVariable('ProgramFiles(x86)')) 'nodejs\node.exe')
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }

$node = $nodeCandidates | Select-Object -First 1
$version = '22.23.3'
if (-not $node) {
    $url = "https://nodejs.org/dist/v$version/node-v$version-x64.msi"
    $expectedSha256 = '1c0efc8449987e7da5d184786a0a96da83ffa11d334421201e5c09b93017cb8d'
    $msi = Join-Path $env:TEMP "SEZ-Node-$version-x64.msi"
    try {
        Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing
        $actualSha256 = (Get-FileHash -LiteralPath $msi -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualSha256 -ne $expectedSha256) { throw 'O SHA-256 do instalador Node.js não corresponde ao arquivo oficial.' }
        $arguments = '/i "' + $msi + '" /qn /norestart'
        $proc = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
        if ($proc.ExitCode -notin @(0, 3010)) { throw "Falha ao instalar Node.js. Código: $($proc.ExitCode)" }
    }
    finally {
        Remove-Item -LiteralPath $msi -Force -ErrorAction SilentlyContinue
    }
    $node = Join-Path $env:ProgramFiles 'nodejs\node.exe'
    if (-not (Test-Path -LiteralPath $node)) { throw 'Node.js não foi localizado após a instalação.' }
}

$nodeMajor = (& $node --version).Trim() -replace '^v(\d+)\..*$', '$1'
if ([int]$nodeMajor -lt 20) { throw 'SEZ Print Service requer Node.js 20 ou superior.' }

# Baixa a versão portátil oficial do SumatraPDF para impressão silenciosa.
$toolsDir = Join-Path $PSScriptRoot 'tools'
$sumatraExe = Join-Path $toolsDir 'SumatraPDF.exe'
if (-not (Test-Path -LiteralPath $sumatraExe -PathType Leaf)) {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
    $sumatraVersion = '3.6.1'
    $sumatraUrl = "https://www.sumatrapdfreader.org/dl/rel/$sumatraVersion/SumatraPDF-$sumatraVersion-64.zip"
    $zip = Join-Path $env:TEMP "SEZ-SumatraPDF-$sumatraVersion-x64.zip"
    $extractDir = Join-Path $env:TEMP "SEZ-SumatraPDF-$sumatraVersion"
    try {
        Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        Invoke-WebRequest -Uri $sumatraUrl -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath $extractDir -Force
        $candidate = Get-ChildItem -LiteralPath $extractDir -Filter 'SumatraPDF.exe' -File -Recurse |
            Select-Object -First 1
        if (-not $candidate) { throw 'O pacote oficial SumatraPDF não contém SumatraPDF.exe.' }
        Copy-Item -Path (Join-Path $candidate.DirectoryName '*') -Destination $toolsDir -Recurse -Force
    }
    finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extractDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
if (-not (Test-Path -LiteralPath $sumatraExe -PathType Leaf)) { throw 'Motor SumatraPDF não foi instalado.' }

Write-Host "Node.js: $(& $node --version)"
Write-Host "SumatraPDF: $sumatraVersion"
Write-Host 'Componentes de impressão preparados.'
