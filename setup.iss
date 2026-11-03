[Setup]
AppId={{E2D1F55B-79B2-4A9B-9E6A-2B7B6D8D1201}
AppName=SEZ Print Service
AppVersion=0.3.2
AppPublisher=Smart EZ
DefaultDirName={autopf}\SEZ Print Service
DefaultGroupName=SEZ Print Service
OutputDir=dist
OutputBaseFilename=SEZ-Print-Service-Setup
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
UninstallDisplayIcon={app}\SEZ-Print-Service.ico

[Files]
Source: "server.js"; DestDir: "{app}"; Flags: ignoreversion
Source: "package.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "install-runtime.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "install-service.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "uninstall-service.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "service-host\SEZPrintServiceHost.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "LEIA-ME.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\SEZ Print Service - Gerenciar serviço"; Filename: "{sys}\mmc.exe"; Parameters: """{sys}\services.msc"""

[Run]
Filename: "{sys}\mmc.exe"; Parameters: """{sys}\services.msc"""; Description: "Abrir gerenciamento do SEZ Print Service"; Flags: postinstall nowait skipifsilent

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\uninstall-service.ps1"""; Flags: runhidden waituntilterminated


[Code]
procedure RunPowerShellScript(const ScriptName, FriendlyName: string);
var
  ResultCode: Integer;
  PowerShellPath: string;
  Parameters: string;
begin
  PowerShellPath := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
  Parameters := '-NoProfile -ExecutionPolicy Bypass -File "' +
    ExpandConstant('{app}') + '\' + ScriptName + '"';

  if not Exec(PowerShellPath, Parameters, ExpandConstant('{app}'),
    SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    RaiseException('Não foi possível executar: ' + FriendlyName + '.');

  if ResultCode <> 0 then
    RaiseException(FriendlyName + ' falhou. Código de saída: ' +
      IntToStr(ResultCode) + '. O serviço não foi confirmado como instalado.');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    RunPowerShellScript('install-runtime.ps1', 'Preparação do Node.js');
    RunPowerShellScript('install-service.ps1', 'Instalação do serviço SEZ Print Service');
  end;
end;
