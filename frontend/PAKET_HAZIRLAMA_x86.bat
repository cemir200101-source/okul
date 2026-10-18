@echo off
chcp 65001 >nul
echo ==========================================
echo OKUL ANALİZ - x86 (32-bit) PAKET
echo ==========================================
echo.
echo DIKKAT: Flutter varsayilan olarak x86 desteklemiyor!
echo Bu script CMake ayarlarini degistirecek.
echo.
pause

echo [1/5] Flutter clean yapiliyor...
call flutter clean
echo.

echo [2/5] CMakeLists.txt dosyalari yedekleniyor...
if exist "windows\runner\CMakeLists.txt.backup" (
    echo Yedek zaten var, atlanıyor...
) else (
    copy "windows\runner\CMakeLists.txt" "windows\runner\CMakeLists.txt.backup" >nul
    echo Yedek olusturuldu.
)
echo.

echo [3/5] CMakeLists.txt'yi 32-bit icin degistiriyorum...
echo.
echo Bu adim DENEYSEL! Calismayabilir.
echo.

REM Visual Studio'yu x86 modunda çağır
echo [4/5] x86 build baslatiliyor...
echo.

set FLUTTER_BUILD_MODE=release
set FLUTTER_TARGET_PLATFORM=windows-x86

REM CMake'e 32-bit derlemesi yaptır
call flutter build windows --release

if errorlevel 1 (
    echo.
    echo HATA: x86 build basarisiz!
    echo.
    echo SEBEP: Flutter sadece x64 destekliyor.
    echo.
    echo COZUM: Manuel Visual Studio build gerekli.
    echo Alternatif: UWP (Microsoft Store) uygulamasi yapabilirsiniz.
    echo.
    pause
    exit /b 1
)

echo.
echo [5/5] ZIP olusturuluyor...
echo.

:: Eğer build klasörü x86 ise
if exist "build\windows\x86\runner\Release\" (
    copy /Y "%USERPROFILE%\Desktop\TEST_UYGULAMA.bat" "build\windows\x86\runner\Release\" >nul 2>&1
    copy /Y "%USERPROFILE%\Desktop\KURULUM_BILGISI.txt" "build\windows\x86\runner\Release\" >nul 2>&1
    copy /Y "%USERPROFILE%\Desktop\BYPASS_GUVENLIK.bat" "build\windows\x86\runner\Release\" >nul 2>&1

    cd build\windows\x86\runner\Release
    powershell -command "Compress-Archive -Path * -DestinationPath '..\..\..\..\..\OkulAnaliz_Windows_x86.zip' -Force"
    cd ..\..\..\..\..\

    echo.
    echo Basarili: OkulAnaliz_Windows_x86.zip olusturuldu!
) else (
    echo HATA: x86 klasoru bulunamadi.
    echo Flutter sadece x64 build yapti.
)

echo.
pause
