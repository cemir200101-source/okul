@echo off
chcp 65001 >nul
echo ==========================================
echo OKUL ANALIZ - WINDOWS PAKET HAZIRLAMA
echo ==========================================
echo.
echo NOT: Flutter sadece x64 (64-bit) destekler.
echo 32-bit icin: 32BIT_NASIL_YAPILIR.txt dosyasina bakin
echo.

echo [1/3] Flutter Clean...
call flutter clean
echo.

echo [2/3] x64 (64-bit) Build yapiliyor...
echo (Bu 2-3 dakika surebilir)
echo.

call flutter build windows --release

if errorlevel 1 (
    echo.
    echo HATA: Build basarisiz!
    pause
    exit /b 1
)

echo Build tamamlandi!
echo.

echo [3/3] Yardimci dosyalar kopyalaniyor ve ZIP olusturuluyor...
echo.

REM Yardimci dosyalari kopyala
copy /Y "%USERPROFILE%\Desktop\TEST_UYGULAMA.bat" "build\windows\x64\runner\Release\" >nul 2>&1
copy /Y "%USERPROFILE%\Desktop\KURULUM_BILGISI.txt" "build\windows\x64\runner\Release\" >nul 2>&1
copy /Y "%USERPROFILE%\Desktop\CALISTIR_GUVENLI.bat" "build\windows\x64\runner\Release\" >nul 2>&1
copy /Y "%USERPROFILE%\Desktop\YONETICI_OLARAK_CALISTIR.bat" "build\windows\x64\runner\Release\" >nul 2>&1
copy /Y "%USERPROFILE%\Desktop\TEST_BASIT.bat" "build\windows\x64\runner\Release\" >nul 2>&1
copy /Y "%USERPROFILE%\Desktop\BYPASS_GUVENLIK.bat" "build\windows\x64\runner\Release\" >nul 2>&1
copy /Y "%USERPROFILE%\Desktop\HATA_LOGLARINI_GOR.bat" "build\windows\x64\runner\Release\" >nul 2>&1

REM ZIP olustur
cd build\windows\x64\runner\Release
powershell -command "Compress-Archive -Path * -DestinationPath '..\..\..\..\..\OkulAnaliz_Windows_x64.zip' -Force"
cd ..\..\..\..\..\

echo.
echo ==========================================
echo TAMAMLANDI!
echo ==========================================
echo.
echo Olusturulan paket:
echo   OkulAnaliz_Windows_x64.zip
echo.
echo UYARI: Bu paket sadece 64-bit Windows icin!
echo.
echo 32-bit kullanicilar icin alternatifler:
echo   1. Web versiyonunu kullanabilirler (tarayicidan)
echo   2. 32BIT_NASIL_YAPILIR.txt dosyasina bakin
echo.
pause
