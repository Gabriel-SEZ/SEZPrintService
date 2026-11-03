[Setup]
AppId={{E2D1F55B-79B2-4A9B-9E6A-2B7B6D8D1201}
AppName=SEZ Print Service
AppVersion=0.4.6
AppPublisher=Smart EZ
DefaultDirName={autopf}\SEZ Print Service
DefaultGroupName=SEZ Print Service
OutputDir=dist
OutputBaseFilename=SEZ-Print-Service-Setup-0.4.6
Compression=lzma2
SolidCompression=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
WizardStyle=modern
UninstallDisplayIcon={app}\SEZPrintServiceHost.exe

[Files]
Source: "server.js"; DestDir: "{app}"; Flags: ignoreversion
Source: "print-engine.js"; DestDir: "{app}"; Flags: ignoreversion
Source: "package.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "install-service.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "uninstall-service.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "prepare-update.ps1"; Flags: dontcopy
Source: "service-host\SEZPrintServiceHost.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "runtime\*"; DestDir: "{app}\runtime"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "tools\*"; DestDir: "{app}\tools"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "LEIA-ME.txt"; DestDir: "{app}"; Flags: ignoreversion
Source: "LICENSE-SUMATRAPDF.txt"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\SEZ Print Service - Gerenciar serviço"; Filename: "{sys}\mmc.exe"; Parameters: """{sys}\services.msc"""

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
      IntToStr(ResultCode) + '. Consulte o log: ' +
      ExpandConstant('{commonappdata}\SmartEZ\SEZ Print Service\logs\service-install.log') + '.');
end;

function AppendUpgradeLog(const LogFile, Message: String): Boolean;
var
  Line: String;
begin
  Line := GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + ' ' + Message + #13#10;
  Result := SaveStringToFile(LogFile, Line, True);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
  PowerShellPath: String;
  Parameters: String;
  LogDir: String;
  LogFile: String;
  ScriptFile: String;
begin
  Result := '';
  LogDir := ExpandConstant('{commonappdata}\SmartEZ\SEZ Print Service\logs');
  LogFile := LogDir + '\upgrade-stop.log';

  if not ForceDirectories(LogDir) then
  begin
    Result := 'Não foi possível criar a pasta de diagnóstico: ' + LogDir;
    Exit;
  end;

  if not AppendUpgradeLog(LogFile, 'O instalador iniciou a preparação da atualização 0.4.6.') then
  begin
    Result := 'Não foi possível gravar o log de atualização: ' + LogFile;
    Exit;
  end;

  try
    ExtractTemporaryFile('prepare-update.ps1');
  except
    Result := 'Não foi possível extrair prepare-update.ps1. Consulte: ' + LogFile;
    AppendUpgradeLog(LogFile, 'FALHA: ExtractTemporaryFile prepare-update.ps1.');
    Exit;
  end;

  ScriptFile := ExpandConstant('{tmp}\prepare-update.ps1');
  if not FileExists(ScriptFile) then
  begin
    Result := 'O script de atualização não foi encontrado em ' + ScriptFile + '. Consulte: ' + LogFile;
    AppendUpgradeLog(LogFile, 'FALHA: arquivo temporário prepare-update.ps1 ausente.');
    Exit;
  end;
  AppendUpgradeLog(LogFile, 'Script prepare-update.ps1 extraído para: ' + ScriptFile);

  PowerShellPath := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
  if not FileExists(PowerShellPath) then
  begin
    Result := 'Windows PowerShell não foi encontrado em ' + PowerShellPath + '. Consulte: ' + LogFile;
    AppendUpgradeLog(LogFile, 'FALHA: powershell.exe não encontrado.');
    Exit;
  end;

  Parameters := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
    ScriptFile + '" -LogFile "' + LogFile + '"';

  AppendUpgradeLog(LogFile, 'Iniciando PowerShell para parar o serviço anterior.');
  if not Exec(PowerShellPath, Parameters, ExpandConstant('{tmp}'),
    SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    AppendUpgradeLog(LogFile, 'FALHA: não foi possível iniciar powershell.exe.');
    Result := 'Não foi possível iniciar a rotina de parada do serviço. Consulte: ' + LogFile;
    Exit;
  end;

  AppendUpgradeLog(LogFile, 'PowerShell terminou com código de saída: ' + IntToStr(ResultCode));

  if ResultCode <> 0 then
  begin
    Result := 'Não foi possível liberar SEZPrintServiceHost.exe. Consulte o diagnóstico: ' + LogFile;
    Exit;
  end;

  AppendUpgradeLog(LogFile, 'Pré-atualização concluída. O Setup pode substituir os arquivos.');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    RunPowerShellScript('install-service.ps1', 'Instalação do serviço SEZ Print Service');
  end;
end;
