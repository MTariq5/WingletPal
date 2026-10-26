#ifndef PackageDir
  #error PackageDir must point to the deployed application folder.
#endif
#ifndef AppVersion
  #define AppVersion "0.1.1"
#endif

[Setup]
AppId={{73829368-55C2-4685-AB38-9E34349D824C}
AppName=WingletPal
AppVersion={#AppVersion}
AppPublisher=Mohamed Tarek
AppPublisherURL=https://github.com/MTariq5/WingletPal
DefaultDirName={localappdata}\Programs\WingletPal
DefaultGroupName=WingletPal
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=.
OutputBaseFilename=WingletPal-{#AppVersion}-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\Resources\app\wingletpal.ico
UninstallDisplayIcon={app}\WingletPal.exe
CloseApplications=yes
RestartApplications=no
InfoBeforeFile=install-info.txt

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Shortcuts:"; Flags: unchecked

[Files]
Source: "{#PackageDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\WingletPal"; Filename: "{app}\WingletPal.exe"; WorkingDir: "{app}"
Name: "{group}\Uninstall WingletPal"; Filename: "{uninstallexe}"
Name: "{autodesktop}\WingletPal"; Filename: "{app}\WingletPal.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\WingletPal.exe"; Description: "Launch WingletPal"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent
