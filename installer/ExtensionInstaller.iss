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

[Code]
var
  RemoveUserData: Boolean;

function HasCommandLineSwitch(const Expected: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
  begin
    if CompareText(ParamStr(I), Expected) = 0 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    if UninstallSilent then
      RemoveUserData := HasCommandLineSwitch('/REMOVEUSERDATA=1')
    else
      RemoveUserData :=
        MsgBox('Удалить также настройки и рабочие данные ExtensionInstaller?' + #13#10 + #13#10 +
          'Будет удалена папка:' + #13#10 +
          ExpandConstant('{localappdata}\ExtensionInstaller'),
          mbConfirmation, MB_YESNO) = IDYES;
  end;

  if (CurUninstallStep = usPostUninstall) and RemoveUserData then
  begin
    DataDir := ExpandConstant('{localappdata}\ExtensionInstaller');
    if DirExists(DataDir) then
    begin
      if not DelTree(DataDir, True, True, True) then
        MsgBox('Не удалось полностью удалить рабочие данные:' + #13#10 + DataDir,
          mbError, MB_OK);
    end;
  end;
end;
