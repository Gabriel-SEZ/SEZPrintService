$ErrorActionPreference = 'Continue'
$serviceName = 'SEZPrintService'
$svc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
if ($svc) {
  if ($svc.Status -ne 'Stopped') { Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue }
  & sc.exe delete $serviceName | Out-Null
}
