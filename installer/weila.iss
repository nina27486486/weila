#ifndef MyAppVersion
  #error MyAppVersion must be supplied by the build script
#endif

#ifndef SourceDir
  #error SourceDir must be supplied by the build script
#endif

#ifndef OutputDir
  #error OutputDir must be supplied by the build script
#endif

[Setup]
AppId={{18B8E9C7-F74B-413A-AE3E-6A002938FF67}
AppName=Weila
AppVersion={#MyAppVersion}
AppVerName=Weila {#MyAppVersion}
AppPublisher=Weila
AppPublisherURL=https://github.com/nina27486486/weila
AppSupportURL=https://github.com/nina27486486/weila/issues
AppUpdatesURL=https://github.com/nina27486486/weila/releases/latest
DefaultDirName={localappdata}\Programs\Weila
DefaultGroupName=Weila
DisableProgramGroupPage=yes
LicenseFile=..\LICENSE
OutputDir={#OutputDir}
OutputBaseFilename=weila-{#MyAppVersion}-windows-x64-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\weila.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
SetupArchitecture=x64
CloseApplications=yes
CloseApplicationsFilter=weila.exe
RestartApplications=no
UsePreviousAppDir=yes
UsePreviousGroup=yes
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Weila"; Filename: "{app}\weila.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\Weila"; Filename: "{app}\weila.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\weila.exe"; Description: "{cm:LaunchProgram,Weila}"; Flags: nowait postinstall skipifsilent
