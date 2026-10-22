#ifndef StudioVersion
  #error StudioVersion is required
#endif
#ifndef Architecture
  #error Architecture is required
#endif

[Setup]
AppId={{19B552B3-1E67-4D97-95B6-8265A42C8F72}
AppName=Norna Studio
AppVersion={#StudioVersion}
AppPublisher=NornaKit
AppPublisherURL=https://nornakit.com
AppSupportURL=https://github.com/dufu1991/nornakit/issues
DefaultDirName={localappdata}\Programs\Norna Studio
DefaultGroupName=Norna Studio
PrivilegesRequired=lowest
MinVersion=10.0.22000
#if Architecture == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#else
ArchitecturesAllowed=x64compatible and not arm64
ArchitecturesInstallIn64BitMode=x64compatible
#endif
OutputDir={#OutputDirectory}
OutputBaseFilename=NornaStudio-windows-{#Architecture}-{#StudioVersion}-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\..\website\dist\favicon.ico
UninstallDisplayIcon={app}\NornaStudio.exe
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes
SetupLogging=yes
LicenseFile=..\..\LICENSE

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; Flags: unchecked

[Files]
Source: "{#SourceDirectory}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Norna Studio"; Filename: "{app}\NornaStudio.exe"
Name: "{autodesktop}\Norna Studio"; Filename: "{app}\NornaStudio.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\NornaStudio.exe"; Description: "{cm:LaunchProgram,Norna Studio}"; Flags: nowait postinstall skipifsilent
