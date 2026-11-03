[Setup]
AppId={{E2D1F55B-79B2-4A9B-9E6A-2B7B6D8D1201}
AppName=SEZ Print Service
AppVersion=0.4.7
AppPublisher=Smart EZ
DefaultDirName={autopf}\SEZ Print Service
DefaultGroupName=SEZ Print Service
OutputDir=dist
OutputBaseFilename=SEZ-Print-Service-Setup-0.4.7
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
function AppendSetupLog(const LogFile, Message: String): Boolean;
var
  Line: String;
begin
  Line := GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + ' ' + Message + #13#10;
  Result := SaveStringToFile(LogFile, Line, True);
end;

procedure RunPowerShellScript(const ScriptName, FriendlyName: string);
var
  ResultCode: Integer;
  PowerShellPath: String;
  Parameters: String;
  LogDir: String;
  LogFile: String;
  ScriptPath: String;
begin
  LogDir := ExpandConstant('{commonappdata}\SmartEZ\SEZ Print Service\logs');
  LogFile := LogDir + '\service-install.log';
  ScriptPath := ExpandConstant('{app}') + '\' + ScriptName;
  PowerShellPath := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');

  if not ForceDirectories(LogDir) then
    RaiseException('Não foi possível criar a pasta de diagnóstico: ' + LogDir);

  if not AppendSetupLog(LogFile, 'O instalador iniciou a etapa: ' + FriendlyName + ' (versão 0.4.7).') then
    RaiseException('Não foi possível criar/gravar o log de instalação: ' + LogFile);

  AppendSetupLog(LogFile, 'Identidade do instalador: ' + GetEnv('USERNAME'));
  AppendSetupLog(LogFile, 'Diretório de instalação: ' + ExpandConstant('{app}'));
  AppendSetupLog(LogFile, 'Script esperado: ' + ScriptPath);

  if not FileExists(ScriptPath) then
  begin
    AppendSetupLog(LogFile, 'FALHA: o script de instalação não existe no destino.');
    RaiseException(FriendlyName + ' não foi executada porque o script não foi encontrado. Consulte: ' + LogFile);
  end;

  if not FileExists(PowerShellPath) then
  begin
    AppendSetupLog(LogFile, 'FALHA: Windows PowerShell não encontrado: ' + PowerShellPath);
    RaiseException('Windows PowerShell não encontrado. Consulte: ' + LogFile);
  end;

  Parameters := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
    ScriptPath + '" -LogFile "' + LogFile + '"';

  AppendSetupLog(LogFile, 'Executando: ' + PowerShellPath + ' ' + Parameters);

  if not Exec(PowerShellPath, Parameters, ExpandConstant('{app}'),
    SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    AppendSetupLog(LogFile, 'FALHA: Exec não conseguiu iniciar o PowerShell. Código Win32: ' + IntToStr(ResultCode));
    RaiseException(FriendlyName + ' não conseguiu iniciar o PowerShell. Consulte: ' + LogFile);
  end;

  AppendSetupLog(LogFile, 'PowerShell terminou. Código de saída: ' + IntToStr(ResultCode));

  if ResultCode <> 0 then
    RaiseException(FriendlyName + ' falhou. Código de saída: ' +
      IntToStr(ResultCode) + '. O diagnóstico está em: ' + LogFile);

  AppendSetupLog(LogFile, 'Etapa concluída com sucesso: ' + FriendlyName + '.');
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

  if not AppendSetupLog(LogFile, 'O instalador iniciou a preparação da atualização 0.4.7.') then
  begin
    Result := 'Não foi possível gravar o log de atualização: ' + LogFile;
    Exit;
  end;

  try
    ExtractTemporaryFile('prepare-update.ps1');
  except
    Result := 'Não foi possível extrair prepare-update.ps1. Consulte: ' + LogFile;
    AppendSetupLog(LogFile, 'FALHA: ExtractTemporaryFile prepare-update.ps1.');
    Exit;
  end;

  ScriptFile := ExpandConstant('{tmp}\prepare-update.ps1');
  if not FileExists(ScriptFile) then
  begin
    Result := 'O script de atualização não foi encontrado em ' + ScriptFile + '. Consulte: ' + LogFile;
    AppendSetupLog(LogFile, 'FALHA: arquivo temporário prepare-update.ps1 ausente.');
    Exit;
  end;
  AppendSetupLog(LogFile, 'Script prepare-update.ps1 extraído para: ' + ScriptFile);

  PowerShellPath := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
  if not FileExists(PowerShellPath) then
  begin
    Result := 'Windows PowerShell não foi encontrado em ' + PowerShellPath + '. Consulte: ' + LogFile;
    AppendSetupLog(LogFile, 'FALHA: powershell.exe não encontrado.');
    Exit;
  end;

  Parameters := '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "' +
    ScriptFile + '" -LogFile "' + LogFile + '"';

  AppendSetupLog(LogFile, 'Iniciando PowerShell para parar o serviço anterior.');
  if not Exec(PowerShellPath, Parameters, ExpandConstant('{tmp}'),
    SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    AppendSetupLog(LogFile, 'FALHA: não foi possível iniciar powershell.exe.');
    Result := 'Não foi possível iniciar a rotina de parada do serviço. Consulte: ' + LogFile;
    Exit;
  end;

  AppendSetupLog(LogFile, 'PowerShell terminou com código de saída: ' + IntToStr(ResultCode));

  if ResultCode <> 0 then
  begin
    Result := 'Não foi possível liberar SEZPrintServiceHost.exe. Consulte o diagnóstico: ' + LogFile;
    Exit;
  end;

  AppendSetupLog(LogFile, 'Pré-atualização concluída. O Setup pode substituir os arquivos.');
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    RunPowerShellScript('install-service.ps1', 'Instalação do serviço SEZ Print Service');
  end;
end;
