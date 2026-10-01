#ifndef MyAppVersion
  #define MyAppVersion "3.0.2-preview"
#endif

#define MyAppName "ExtensionInstaller"
#define MyAppPublisher "lvlaksim1"
#define MyAppURL "https://github.com/lvlaksim1/extension-installer"
#define MyAppId "{{79735245-B74E-5117-B1EF-A58BDC270FC7}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={localappdata}\Programs\ExtensionInstaller
DefaultGroupName=ExtensionInstaller
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=..\dist
OutputBaseFilename=ExtensionInstaller_Setup_v{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UsePreviousAppDir=yes
CloseApplications=yes
RestartApplications=no
UninstallDisplayName=ExtensionInstaller
CreateUninstallRegKey=yes
SetupLogging=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Files]
Source: "..\src\ExtensionInstaller.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\ReleaseInstaller.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\src\ExtensionInstaller.vbs"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\catalog\extensions.json"; DestDir: "{app}\catalog"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\ExtensionInstaller"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\ExtensionInstaller.vbs"""; WorkingDir: "{app}"
Name: "{autodesktop}\ExtensionInstaller"; Filename: "{sys}\wscript.exe"; Parameters: """{app}\ExtensionInstaller.vbs"""; WorkingDir: "{app}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Создать ярлык на рабочем столе"; GroupDescription: "Дополнительные ярлыки:"; Flags: unchecked

[Run]
Filename: "{sys}\wscript.exe"; Parameters: """{app}\ExtensionInstaller.vbs"""; Description: "Запустить ExtensionInstaller"; Flags: nowait postinstall skipifsilent
