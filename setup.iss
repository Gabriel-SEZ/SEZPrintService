[Setup]
AppId={{E2D1F55B-79B2-4A9B-9E6A-2B7B6D8D1201}
AppName=SEZ Print Service
AppVersion=0.3.1
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
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install-runtime.ps1"""; StatusMsg: "Preparando o mecanismo de impressão..."; Flags: runhidden waituntilterminated
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\install-service.ps1"""; StatusMsg: "Registrando serviço automático do Windows..."; Flags: runhidden waituntilterminated
Filename: "{sys}\mmc.exe"; Parameters: """{sys}\services.msc"""; Description: "Abrir gerenciamento do SEZ Print Service"; Flags: postinstall nowait skipifsilent

[UninstallRun]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -File ""{app}\uninstall-service.ps1"""; Flags: runhidden waituntilterminated
