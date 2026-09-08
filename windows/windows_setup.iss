#define SourcePath ".."

#ifndef KINOS_VERSION
  #define KINOS_VERSION "latest"
#endif

[Setup]
AppId={{D573EDD5-117A-47AD-88AC-62C8EBD11DC7}
AppName="Kinos"
AppVersion={#KINOS_VERSION}
AppPublisher="DonutWare"
AppPublisherURL="https://github.com/DonutWare/Fladder"
AppSupportURL="https://github.com/DonutWare/Fladder"
AppUpdatesURL="https://github.com/DonutWare/Fladder"
DefaultDirName={localappdata}\Programs\Kinos
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputBaseFilename=kinos_setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

SetupLogging=yes
UninstallLogging=yes
UninstallDisplayName="Kinos"
UninstallDisplayIcon={app}\kinos.exe
SetupIconFile="{#SourcePath}\icons\production\kinos_icon.ico"
LicenseFile="{#SourcePath}\LICENSE"
WizardImageFile={#SourcePath}\assets\windows-installer\fladder-installer-100.bmp,{#SourcePath}\assets\windows-installer\fladder-installer-125.bmp,{#SourcePath}\assets\windows-installer\fladder-installer-150.bmp

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourcePath}\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Kinos"; Filename: "{app}\kinos.exe"
Name: "{autodesktop}\Kinos"; Filename: "{app}\kinos.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\kinos.exe"; Description: "{cm:LaunchProgram,Kinos}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  case CurUninstallStep of
    usUninstall:
      begin
        if MsgBox('Would you like to delete the application''s data? This action cannot be undone. Synced files will remain unaffected.', mbConfirmation, MB_YESNO) = IDYES then
        begin
            if DelTree(ExpandConstant('{localappdata}\DonutWare'), True, True, True) = False then
            begin
                Log(ExpandConstant('{localappdata}\DonutWare could not be deleted. Skipping...'));
            end;
        end;
      end;
  end;
end;
