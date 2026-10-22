; MyOpenKey Inno Setup 6 Script
; Per-user installer for MyOpenKey (Win32)

#ifndef MyAppVersion
  #define MyAppVersion GetEnv("MYOPENKEY_VERSION")
#endif
#if MyAppVersion == ""
  #define MyAppVersion "0.0.0"
#endif

#ifndef MyAppExe
  #define MyAppExe GetEnv("MYOPENKEY_EXE")
#endif
#if MyAppExe == ""
  #define MyAppExe "..\..\..\..\build\Release\MyOpenKey.exe"
#endif

#define MyAppName "MyOpenKey"
#define MyAppPublisher "Huỳnh Quốc Đạt"
#define MyAppPublisherURL "https://hqd.vn"
#define MyAppId "{{7E68F5DC-9F59-4B52-8CE8-6A2B6A310237}"

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppPublisherURL}
AppSupportURL={#MyAppPublisherURL}
AppUpdatesURL={#MyAppPublisherURL}
DefaultDirName={localappdata}\Programs\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=..\..\..\..\LICENSE
OutputDir=..\..\..\..\dist
OutputBaseFilename=MyOpenKey-{#MyAppVersion}-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
; Official Inno Setup distribution only bundles English.isl; Vietnamese is unofficial.
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startup"; Description: "Khởi động cùng Windows"; GroupDescription: "Tùy chọn bổ sung:"

[Files]
Source: "{#MyAppExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\MyOpenKey.exe"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\MyOpenKey.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "MyOpenKey"; ValueData: """{app}\MyOpenKey.exe"""; Flags: uninsdeletevalue; Tasks: startup

[Run]
Filename: "{app}\MyOpenKey.exe"; Description: "Chạy MyOpenKey"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/IM MyOpenKey.exe /F"; Flags: runhidden; RunOnceId: "KillMyOpenKeyBeforeUninstall"
