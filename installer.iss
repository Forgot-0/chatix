#define MyAppName "Chatix"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Chatix"
#define MyAppExeName "chatix.exe"

[Setup]
AppId={{CHATIX-APP-ID-123456}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}

DefaultDirName={autopf}\Chatix
DefaultGroupName=Chatix

OutputDir=build\installer
OutputBaseFilename=Chatix-Setup

Compression=lzma
SolidCompression=yes

ArchitecturesInstallIn64BitMode=x64

WizardStyle=modern

UninstallDisplayName=Chatix
Uninstallable=yes

[Files]
Source: "build\windows\x64\runner\Release\*"; \
    DestDir: "{app}"; \
    Flags: recursesubdirs ignoreversion

[Icons]
Name: "{autodesktop}\Chatix"; \
    Filename: "{app}\chatix.exe"; \
    WorkingDir: "{app}"

Name: "{group}\Chatix"; \
    Filename: "{app}\chatix.exe"; \
    WorkingDir: "{app}"

[Run]
Filename: "{app}\chatix.exe"; \
    Description: "Запустить Chatix"; \
    Flags: nowait postinstall skipifsilent