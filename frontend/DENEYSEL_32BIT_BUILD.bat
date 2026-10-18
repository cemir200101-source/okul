@echo off
chcp 65001 >nul
echo ==========================================
echo DENEYSEL 32-BIT BUILD
echo ==========================================
echo.
echo UYARI: Bu script MUHTEMELEN CALISMAYACAK!
echo Flutter resmi olarak x86 (32-bit) desteklemiyor.
echo.
echo Bu sadece bir deneme. Basarısız olursa normal.
echo.
pause

echo.
echo [1/6] Visual Studio x86 Developer Command Prompt kontrolu...
where cl.exe >nul 2>&1
if %errorlevel% NEQ 0 (
    echo.
    echo HATA: Visual Studio x86 Developer Command Prompt bulunamadi!
    echo.
    echo Bu script'i su sekilde calistirmalisiniz:
    echo   1. Baslat Menusu'nde arayin: "x86 Native Tools Command Prompt for VS 2022"
    echo   2. Yonetici olarak calistirin
    echo   3. cd C:\Users\PC\Desktop\yazilim\okul\frontend
    echo   4. DENEYSEL_32BIT_BUILD.bat
    echo.
    pause
    exit /b 1
)

echo x86 ortam algilandi!
echo.

echo [2/6] Yedek olusturuluyor...
if not exist "windows\CMakeLists.txt.backup" (
    copy "windows\CMakeLists.txt" "windows\CMakeLists.txt.backup" >nul
)
if not exist "windows\runner\CMakeLists.txt.backup" (
    copy "windows\runner\CMakeLists.txt" "windows\runner\CMakeLists.txt.backup" >nul
)
echo Yedekler olusturuldu.
echo.

echo [3/6] CMakeLists.txt dosyalari degistiriliyor...
REM Bu adım PowerShell ile yapılacak
powershell -Command "(Get-Content 'windows\CMakeLists.txt') -replace 'x64', 'Win32' | Set-Content 'windows\CMakeLists.txt'"
powershell -Command "(Get-Content 'windows\runner\CMakeLists.txt') -replace 'x64', 'Win32' | Set-Content 'windows\runner\CMakeLists.txt'"
echo Dosyalar degistirildi.
echo.

echo [4/6] Flutter clean...
call flutter clean
echo.

echo [5/6] x86 Build baslatiliyor...
echo Bu adim MUHTEMELEN BASARISIZ OLACAK.
echo.

REM Manuel CMake
cmake -S windows -B build\windows\x86 -G "Visual Studio 17 2022" -A Win32 -DCMAKE_BUILD_TYPE=Release

if errorlevel 1 (
    echo.
    echo ============================================
    echo BEKLENDIGII GIBI BASARISIZ OLDU!
    echo ============================================
    echo.
    echo SEBEP: Flutter engine sadece x64 olarak geliyor.
    echo.
    echo COZUM: Web versiyonu kullanin.
    echo.
    goto RESTORE
)

REM CMake build
cmake --build build\windows\x86 --config Release --target INSTALL

if errorlevel 1 (
    echo.
    echo Build basarisiz!
    goto RESTORE
)

echo.
echo [6/6] Flutter assets kopyalaniyor...
call flutter build windows --release
xcopy /E /I /Y build\flutter_assets build\windows\x86\runner\Release\data\flutter_assets

echo.
echo ==========================================
echo INANILMAZ! BASARILI OLDU!
echo ==========================================
echo.
echo 32-bit exe dosyası:
echo   build\windows\x86\runner\Release\okul_analiz_app.exe
echo.
echo Bunu 32-bit Windows'ta test edin!
echo.

:RESTORE
echo.
echo Orijinal dosyalar geri yukleniyor...
if exist "windows\CMakeLists.txt.backup" (
    copy /Y "windows\CMakeLists.txt.backup" "windows\CMakeLists.txt" >nul
)
if exist "windows\runner\CMakeLists.txt.backup" (
    copy /Y "windows\runner\CMakeLists.txt.backup" "windows\runner\CMakeLists.txt" >nul
)
echo Geri yukleme tamamlandi.
echo.

pause
