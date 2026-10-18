; Okul Analiz App - Windows Installer Script
; Inno Setup ile kullanilir

#define MyAppName "Okul Analiz"
#define MyAppVersion "0.608"
#define MyAppPublisher "Cati Deneme"
#define MyAppExeName "okul_analiz_app.exe"

[Setup]
; Temel bilgiler
AppId={{8A5F2B1D-9C3E-4F7A-B6D8-1E9A4C7F2B5D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
OutputDir=build\windows\installer
OutputBaseFilename=OkulAnalizSetup_{#MyAppVersion}
Compression=lzma
SolidCompression=yes
WizardStyle=modern

; İkonlar (varsa)
; SetupIconFile=assets\icon.ico
; UninstallDisplayIcon={app}\{#MyAppExeName}

; Gereksinimler
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaüstünde kısayol oluştur"; GroupDescription: "Ek seçenekler:"; Flags: unchecked

[Files]
; Tüm Release klasörünü kopyala
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Başlat menüsü kısayolu
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Kaldır"; Filename: "{uninstallexe}"

; Masaüstü kısayolu (kullanıcı seçerse)
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Kurulum sonrası uygulamayı başlat (isteğe bağlı)
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Code]
// Visual C++ Runtime kontrolü
function VCRedistNeedsInstall: Boolean;
var
  Version: String;
begin
  // VC++ 2015-2022 yüklü mü kontrol et
  if RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
    Result := False
  else
    Result := True;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;

  // VC++ Runtime kontrolü
  if VCRedistNeedsInstall then
  begin
    if MsgBox('Bu uygulama Microsoft Visual C++ 2015-2022 Redistributable gerektirir.' + #13#10 +
              'Yüklü değil. Kuruluma devam edilsin mi?' + #13#10 + #13#10 +
              'Evet derseniz, kurulum tamamlandıktan sonra VC++ Redistributable indirmeniz gerekecek.',
              mbConfirmation, MB_YESNO) = IDNO then
      Result := False;
  end;
end;
