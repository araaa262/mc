@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Minecraft Java + Bedrock Server
color 0A

:: ============================================================
:: CONFIG
:: ============================================================
set "SERVER_DIR=%~dp0MinecraftServer"
set "JAVA_PORT=25565"
set "BEDROCK_PORT=19132"
set "MIN_RAM=2G"
set "MAX_RAM=4G"

echo.
echo ============================================================
echo       MINECRAFT JAVA + BEDROCK SERVER INSTALLER
echo ============================================================
echo.
echo Java Port    : %JAVA_PORT% TCP
echo Bedrock Port : %BEDROCK_PORT% UDP
echo RAM          : %MIN_RAM% - %MAX_RAM%
echo ============================================================
echo.

:: ============================================================
:: ADMIN CHECK
:: ============================================================
net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo.
    echo [ERROR] Jalankan file ini sebagai Administrator.
    echo.
    echo Klik kanan file BAT ^> Run as administrator
    echo.
    pause
    exit /b 1
)

:: ============================================================
:: CREATE SERVER FOLDER
:: ============================================================
echo [1/9] Membuat folder server...

if not exist "%SERVER_DIR%" mkdir "%SERVER_DIR%"
if not exist "%SERVER_DIR%\plugins" mkdir "%SERVER_DIR%\plugins"

cd /d "%SERVER_DIR%"

echo.
echo Folder server:
echo %SERVER_DIR%
echo.

:: ============================================================
:: CHECK WINGET
:: ============================================================
echo [2/9] Mengecek winget...

where winget >nul 2>&1

if errorlevel 1 (
    echo.
    echo [ERROR] winget tidak ditemukan.
    echo.
    echo Pastikan Windows App Installer tersedia.
    echo.
    pause
    exit /b 1
)

echo winget OK.
echo.

:: ============================================================
:: CHECK JAVA 25
:: ============================================================
echo [3/9] Mengecek Java...

set "JAVA_OK=0"

where java >nul 2>&1

if not errorlevel 1 (
    java -version 2>&1 | findstr /C:"25." >nul

    if not errorlevel 1 (
        set "JAVA_OK=1"
        echo Java 25 sudah tersedia.
    )
)

if "%JAVA_OK%"=="0" (
    echo.
    echo Java 25 belum ditemukan.
    echo Menginstall Eclipse Temurin Java 25...
    echo.

    winget install ^
        --id EclipseAdoptium.Temurin.25.JDK ^
        --exact ^
        --accept-package-agreements ^
        --accept-source-agreements ^
        --silent

    if errorlevel 1 (
        echo.
        echo [ERROR] Gagal menginstall Java 25.
        echo.
        echo Install Java 25 secara manual lalu jalankan script lagi.
        echo.
        pause
        exit /b 1
    )

    echo.
    echo Java berhasil diinstall.
    echo.

    :: Refresh environment
    set "PATH=%PATH%;C:\Program Files\Eclipse Adoptium\jdk-25-hotspot\bin"
)

where java >nul 2>&1

if errorlevel 1 (
    echo.
    echo [ERROR] Java belum masuk PATH.
    echo.
    echo Tutup CMD ini lalu jalankan BAT kembali sebagai Administrator.
    echo.
    pause
    exit /b 1
)

echo.
java -version
echo.

:: ============================================================
:: DOWNLOAD PAPER TERBARU
:: ============================================================
echo [4/9] Mencari Paper terbaru...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$h=@{'User-Agent'='MinecraftServerInstaller/1.0'}; ^
$r=Invoke-RestMethod -Headers $h -Uri 'https://fill.papermc.io/v3/projects/paper'; ^
$v=$r.versions.PSObject.Properties.Name | Select-Object -Last 1; ^
Set-Content 'paper-version.txt' $v"

if not exist "paper-version.txt" (
    echo.
    echo [ERROR] Tidak bisa mendapatkan versi Paper.
    pause
    exit /b 1
)

set /p PAPER_VERSION=<paper-version.txt

echo Paper version:
echo %PAPER_VERSION%
echo.

:: ============================================================
:: DOWNLOAD PAPER BUILD
:: ============================================================
echo Download Paper...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$h=@{'User-Agent'='MinecraftServerInstaller/1.0'}; ^
$v='%PAPER_VERSION%'; ^
$r=Invoke-RestMethod -Headers $h -Uri ('https://fill.papermc.io/v3/projects/paper/versions/'+$v+'/builds'); ^
$b=$r | Where-Object {$_.channel -eq 'STABLE'} | Select-Object -First 1; ^
if (!$b) {throw 'Paper stable build tidak ditemukan'}; ^
Write-Host ('Build: '+$b.id); ^
Invoke-WebRequest -Headers $h -Uri $b.downloads.'server:default'.url -OutFile 'paper.jar'"

if not exist "paper.jar" (
    echo.
    echo [ERROR] Paper gagal didownload.
    pause
    exit /b 1
)

echo Paper berhasil.
echo.

:: ============================================================
:: DOWNLOAD GEYSER
:: ============================================================
echo [5/9] Download Geyser...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$u='https://api.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot'; ^
Invoke-WebRequest -Uri $u -OutFile 'plugins\Geyser-Spigot.jar'"

if not exist "plugins\Geyser-Spigot.jar" (
    echo.
    echo [ERROR] Geyser gagal didownload.
    pause
    exit /b 1
)

echo Geyser berhasil.
echo.

:: ============================================================
:: DOWNLOAD FLOODGATE
:: ============================================================
echo [6/9] Download Floodgate...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$u='https://api.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot'; ^
Invoke-WebRequest -Uri $u -OutFile 'plugins\floodgate-spigot.jar'"

if not exist "plugins\floodgate-spigot.jar" (
    echo.
    echo [ERROR] Floodgate gagal didownload.
    pause
    exit /b 1
)

echo Floodgate berhasil.
echo.

:: ============================================================
:: EULA
:: ============================================================
echo [7/9] Membuat konfigurasi...

(
echo eula=true
) > eula.txt

(
echo server-port=%JAVA_PORT%
echo server-ip=
echo online-mode=true
echo enable-status=true
echo motd=Java + Bedrock Server
echo max-players=20
echo difficulty=normal
echo gamemode=survival
echo spawn-protection=0
echo pvp=true
echo view-distance=10
echo simulation-distance=8
) > server.properties

:: ============================================================
:: FIREWALL
:: ============================================================
echo.
echo Membuka Windows Firewall...

netsh advfirewall firewall delete rule name="Minecraft Java Server" >nul 2>&1
netsh advfirewall firewall delete rule name="Minecraft Bedrock Server" >nul 2>&1

netsh advfirewall firewall add rule ^
name="Minecraft Java Server" ^
dir=in ^
action=allow ^
protocol=TCP ^
localport=%JAVA_PORT% >nul

netsh advfirewall firewall add rule ^
name="Minecraft Bedrock Server" ^
dir=in ^
action=allow ^
protocol=UDP ^
localport=%BEDROCK_PORT% >nul

echo Firewall OK.
echo.

:: ============================================================
:: FIRST START
:: ============================================================
echo [8/9] Menjalankan server pertama kali...
echo.
echo Tunggu sampai muncul:
echo.
echo     Done
echo.
echo Setelah itu server akan dihentikan.
echo.

java -Xms%MIN_RAM% -Xmx%MAX_RAM% -jar paper.jar --nogui

:: ============================================================
:: CONFIG GEYSER
:: ============================================================
echo.
echo Mengatur Geyser...

set "GEYSER_CONFIG=%SERVER_DIR%\plugins\Geyser-Spigot\config.yml"

if exist "%GEYSER_CONFIG%" (

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$p='%GEYSER_CONFIG%'; ^
    $s=Get-Content $p -Raw; ^
    $s=$s -replace '(?m)^(\s*port:\s*)[0-9]+\s*$', '${1}%BEDROCK_PORT%'; ^
    $s=$s -replace '(?m)^(\s*auth-type:\s*).*$','${1}floodgate'; ^
    Set-Content $p $s"

    echo Geyser dikonfigurasi.
) else (
    echo.
    echo [WARNING] Config Geyser belum ditemukan.
    echo Geyser akan membuatnya saat server dijalankan.
)

:: ============================================================
:: CREATE START.BAT
:: ============================================================
echo.
echo Membuat start.bat...

(
echo @echo off
echo setlocal EnableDelayedExpansion
echo title Minecraft Java + Bedrock Server
echo cd /d "%%~dp0"
echo.
echo :: Cari IP LAN PC
echo set "LOCAL_IP="
echo.
echo for /f "tokens=2 delims=:" %%%%A in ^('ipconfig ^| findstr /C:"IPv4 Address" /C:"IPv4 Address ."'^) do ^(
echo     set "TEMP_IP=%%%%A"
echo     set "TEMP_IP=!TEMP_IP: =!"
echo     if not "!TEMP_IP:~0,3!"=="127" set "LOCAL_IP=!TEMP_IP!"
echo ^)
echo.
echo if "!LOCAL_IP!"=="" set "LOCAL_IP=IP-TIDAK-TERDETEKSI"
echo.
echo cls
echo.
echo echo ==========================================
echo echo       MINECRAFT SERVER ONLINE
echo echo ==========================================
echo echo.
echo echo PC LAN IP:
echo echo.
echo echo     !LOCAL_IP!
echo echo.
echo echo ------------------------------------------
echo echo JAVA:
echo echo.
echo echo     !LOCAL_IP!:%JAVA_PORT%
echo echo.
echo echo ANDROID / BEDROCK:
echo echo.
echo echo     Address : !LOCAL_IP!
echo echo     Port    : %BEDROCK_PORT%
echo echo.
echo echo ==========================================
echo echo        SERVER SIAP DIMAINKAN
echo echo ==========================================
echo echo.
echo echo Ketik "stop" untuk mematikan server.
echo echo.
echo.
echo java -Xms%MIN_RAM% -Xmx%MAX_RAM% -jar paper.jar --nogui
echo.
echo pause
) > start.bat

:: ============================================================
:: CREATE UPDATE SCRIPT
:: ============================================================
(
echo @echo off
echo cd /d "%%~dp0"
echo echo Updating Geyser...
echo powershell -NoProfile -ExecutionPolicy Bypass -Command "$u='https://api.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot'; Invoke-WebRequest -Uri $u -OutFile 'plugins\Geyser-Spigot.jar'"
echo echo Updating Floodgate...
echo powershell -NoProfile -ExecutionPolicy Bypass -Command "$u='https://api.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot'; Invoke-WebRequest -Uri $u -OutFile 'plugins\floodgate-spigot.jar'"
echo echo.
echo echo Update selesai.
echo pause
) > update-plugins.bat

:: ============================================================
:: FINAL INFORMATION
:: ============================================================
echo.
echo ============================================================
echo             INSTALLASI SELESAI
echo ============================================================
echo.
echo Folder:
echo %SERVER_DIR%
echo.
echo Java:
echo TCP %JAVA_PORT%
echo.
echo Android:
echo UDP %BEDROCK_PORT%
echo.
echo File menjalankan server:
echo start.bat
echo.
echo ============================================================
echo.

:: ============================================================
:: START SERVER
:: ============================================================
echo [9/9] Menjalankan server...
echo.

call start.bat

endlocal
