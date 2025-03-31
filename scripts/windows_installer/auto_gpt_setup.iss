; Auto-GPT Windows Installer Script
; For use with Inno Setup

#define MyAppName "Auto-GPT"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Auto-GPT Community"
#define MyAppURL "https://github.com/Significant-Gravitas/Auto-GPT"
#define MyAppExeName "run_auto_gpt.bat"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
AppId={{53F6BC9C-2164-47BD-A486-242A72128667}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=Auto-GPT_Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=admin
SetupIconFile=auto_gpt_icon.ico
UninstallDisplayIcon={app}\auto_gpt_icon.ico
WizardStyle=modern
WizardImageFile=installer_image.bmp
WizardSmallImageFile=installer_small.bmp

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Icon and resources
Source: "auto_gpt_icon.ico"; DestDir: "{app}"; Flags: ignoreversion
; Batch files
Source: "run_auto_gpt.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "update_auto_gpt.bat"; DestDir: "{app}"; Flags: ignoreversion
Source: "setup_env.bat"; DestDir: "{app}"; Flags: ignoreversion
; Python scripts
Source: "install_dependencies.py"; DestDir: "{app}"; Flags: ignoreversion
Source: "check_requirements.py"; DestDir: "{app}"; Flags: ignoreversion
; Configuration
Source: ".env.template"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\auto_gpt_icon.ico"
Name: "{group}\Setup Environment"; Filename: "{app}\setup_env.bat"; IconFilename: "{app}\auto_gpt_icon.ico"
Name: "{group}\Update Auto-GPT"; Filename: "{app}\update_auto_gpt.bat"; IconFilename: "{app}\auto_gpt_icon.ico"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\auto_gpt_icon.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\setup_env.bat"; Description: "Setup environment and install dependencies"; Flags: runhidden
Filename: "{app}\setup_env.bat"; Description: "Configure your OpenAI API Key"; Flags: runasoriginaluser postinstall
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Auto-GPT"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\auto_gpt_workspace"
Type: filesandordirs; Name: "{app}\.env"
Type: filesandordirs; Name: "{app}\logs"
