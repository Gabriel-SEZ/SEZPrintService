$ErrorActionPreference = 'Stop'
$serviceName = 'SEZPrintService'
$displayName = 'SEZ Print Service'
$exe = Join-Path $PSScriptRoot 'SEZPrintServiceHost.exe'
if (-not (Test-Path $exe)) { throw "Executável do serviço não encontrado: $exe" }
$existing = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($existing) {
  if ($existing.Status -ne 'Stopped') { Stop-Service -Name $serviceName -Force }
  & sc.exe delete $serviceName | Out-Null
  Start-Sleep -Seconds 2
}
$binPathArg = 'binPath= "' + $exe + '"'
& sc.exe create $serviceName $binPathArg 'start= auto' "DisplayName= $displayName" 'obj= LocalSystem' | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Falha ao criar serviço Windows (sc.exe: $LASTEXITCODE)." }
& sc.exe description $serviceName 'Serviço local de impressão do Smart EZ ERP. Inicia com o Windows, antes do login.' | Out-Null
& sc.exe failure $serviceName reset= 86400 actions= restart/5000/restart/15000/restart/30000 | Out-Null
& sc.exe failureflag $serviceName 1 | Out-Null
& sc.exe config $serviceName 'start= auto' | Out-Null
Start-Service -Name $serviceName
$svc = Get-Service -Name $serviceName
if ($svc.Status -ne 'Running') { throw 'O serviço SEZ Print Service não iniciou.' }
Write-Host 'SEZ Print Service instalado como serviço automático do Windows.'
