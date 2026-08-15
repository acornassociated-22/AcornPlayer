; Inno Setup script for the Acorn Player Windows installer.
; Build: ISCC.exe /DAppVersion=1.0.0 packaging\windows\acorn-player.iss
#define AppName "Acorn Player"
#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
AppId={{7F3C1E42-9B84-4C2F-A1D6-5E0A7C9D2B31}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher=Acorn Associated
AppPublisherURL=https://acornassociated.org/
AppSupportURL=https://github.com/acornassociated-22/AcornPlayer/issues
DefaultDirName={autopf}\Acorn Player
DefaultGroupName=Acorn Player
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\acorn_player.exe
UninstallDisplayName={#AppName}
OutputDir=..\..\releases
OutputBaseFilename=acorn-player_{#AppVersion}_windows_x64_setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\acorn_player.exe"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\acorn_player.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\acorn_player.exe"; Description: "Launch {#AppName}"; Flags: nowait postinstall skipifsilent
