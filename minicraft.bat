@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Minecraft Java + Bedrock Server Installer
color 0A

:: ============================================================
:: CONFIG
:: ============================================================
set "SERVER_DIR=%~dp0MinecraftServer"
set "JAVA_PORT=25565"
set "BEDROCK_PORT=19132"
set "MIN_RAM=2G"
set "MAX_RAM=4G"
set "PAPER_USER_AGENT=MinecraftServerInstaller/2.0 (https://github.com/)"

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
    for /f "tokens=3" %%V in ('java -version 2^>^&1 ^| findstr /C:"version"') do (
        set "JAVA_VERSION=%%V"
    )

    echo Java terdeteksi: !JAVA_VERSION!

    java -version 2>&1 | findstr /C:"25." >nul
    if not errorlevel 1 set "JAVA_OK=1"
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
        --accept-source-agreements

    if errorlevel 1 (
        echo.
        echo [ERROR] Gagal menginstall Java 25.
        echo Install Java 25 secara manual lalu jalankan BAT lagi.
        echo.
        pause
        exit /b 1
    )

    echo.
    echo Java berhasil diinstall.
    echo Memuat ulang PATH...

    :: Lokasi umum Temurin Java 25
    for /d %%J in ("C:\Program Files\Eclipse Adoptium\jdk-25*") do (
        if exist "%%~fJ\bin\java.exe" (
            set "JAVA_HOME=%%~fJ"
            set "PATH=%%~fJ\bin;!PATH!"
            goto :JAVA_PATH_READY
        )
    )
)

:JAVA_PATH_READY
where java >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Java belum masuk PATH.
    echo Tutup jendela ini lalu jalankan BAT kembali sebagai Administrator.
    echo.
    pause
    exit /b 1
)

echo.
java -version
echo.

:: ============================================================
:: DOWNLOAD PAPER TERBARU - STABLE
:: ============================================================
echo [4/9] Mencari Paper stable terbaru...

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$ErrorActionPreference='Stop'; ^
$h=@{'User-Agent'='%PAPER_USER_AGENT%'}; ^
$r=Invoke-RestMethod -Headers $h -Uri 'https://fill.papermc.io/v3/projects/paper'; ^
$versions=@($r.versions.PSObject.Properties.Value | ForEach-Object { $_ }) | ForEach-Object { $_ } | Where-Object { $_ -is [string] }; ^
if (-not $versions) { throw 'Daftar versi Paper kosong' }; ^
$v=$versions | Sort-Object { try { [version]$_ } catch { [version]'0.0' } } -Descending | Select-Object -First 1; ^
Set-Content -Encoding ascii 'paper-version.txt' $v; ^
Write-Host ('Paper version: '+$v)"

if errorlevel 1 (
    echo.
    echo [ERROR] Tidak bisa mendapatkan versi Paper.
    pause
    exit /b 1
)

if not exist "paper-version.txt" (
    echo.
    echo [ERROR] paper-version.txt tidak dibuat.
    pause
    exit /b 1
)

set /p PAPER_VERSION=<paper-version.txt

if "%PAPER_VERSION%"=="" (
    echo.
    echo [ERROR] Versi Paper kosong.
    pause
    exit /b 1
)

echo Paper version:
echo %PAPER_VERSION%
echo.

:: ============================================================
:: DOWNLOAD PAPER BUILD STABLE
:: ============================================================
echo Download Paper stable...

if exist "paper.jar" del /q "paper.jar" >nul 2>&1

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$ErrorActionPreference='Stop'; ^
$h=@{'User-Agent'='%PAPER_USER_AGENT%'}; ^
$v='%PAPER_VERSION%'; ^
$r=Invoke-RestMethod -Headers $h -Uri ('https://fill.papermc.io/v3/projects/paper/versions/'+$v+'/builds'); ^
$b=@($r | Where-Object {$_.channel -eq 'STABLE'}) | Select-Object -First 1; ^
if (-not $b) { throw 'Paper stable build tidak ditemukan' }; ^
Write-Host ('Build: '+$b.id); ^
$u=$b.downloads.'server:default'.url; ^
if (-not $u) { throw 'URL download Paper tidak ditemukan' }; ^
Invoke-WebRequest -Headers $h -Uri $u -OutFile 'paper.jar'"

if errorlevel 1 (
    echo.
    echo [ERROR] Paper gagal didownload.
    pause
    exit /b 1
)

if not exist "paper.jar" (
    echo.
    echo [ERROR] paper.jar tidak ditemukan setelah download.
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
"$ErrorActionPreference='Stop'; ^
$u='https://api.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot'; ^
Invoke-WebRequest -Uri $u -OutFile 'plugins\Geyser-Spigot.jar'"

if errorlevel 1 (
    echo.
    echo [ERROR] Geyser gagal didownload.
    pause
    exit /b 1
)

if not exist "plugins\Geyser-Spigot.jar" (
    echo.
    echo [ERROR] Geyser-Spigot.jar tidak ditemukan.
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
"$ErrorActionPreference='Stop'; ^
$u='https://api.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot'; ^
Invoke-WebRequest -Uri $u -OutFile 'plugins\floodgate-spigot.jar'"

if errorlevel 1 (
    echo.
    echo [ERROR] Floodgate gagal didownload.
    pause
    exit /b 1
)

if not exist "plugins\floodgate-spigot.jar" (
    echo.
    echo [ERROR] floodgate-spigot.jar tidak ditemukan.
    pause
    exit /b 1
)

echo Floodgate berhasil.
echo.

:: ============================================================
:: EULA + SERVER CONFIG
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

if errorlevel 1 echo [WARNING] Rule Java Firewall gagal dibuat.

netsh advfirewall firewall add rule ^
name="Minecraft Bedrock Server" ^
dir=in ^
action=allow ^
protocol=UDP ^
localport=%BEDROCK_PORT% >nul

if errorlevel 1 echo [WARNING] Rule Bedrock Firewall gagal dibuat.

echo Firewall selesai.
echo.

:: ============================================================
:: FIRST START
:: ============================================================
echo [8/9] Menjalankan server pertama kali...
echo.
echo Server akan membuat konfigurasi Paper, Geyser, dan Floodgate.
echo Tunggu sampai muncul "Done", lalu ketik:
echo.
echo     stop
echo.
echo Jangan tutup jendela dengan tombol X.
echo.

java -Xms%MIN_RAM% -Xmx%MAX_RAM% -jar paper.jar --nogui

if errorlevel 1 (
    echo.
    echo [WARNING] Server berhenti dengan kode error %errorlevel%.
    echo Cek pesan error di atas sebelum melanjutkan.
    echo.
    pause
)

:: ============================================================
:: CONFIG GEYSER
:: ============================================================
echo.
echo Mengatur Geyser...

set "GEYSER_CONFIG=%SERVER_DIR%\plugins\Geyser-Spigot\config.yml"

if exist "%GEYSER_CONFIG%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop'; ^
    $p='%GEYSER_CONFIG%'; ^
    $s=Get-Content $p -Raw; ^
    $s=$s -replace '(?m)^(\s*port:\s*)[0-9]+\s*$', '${1}%BEDROCK_PORT%'; ^
    $s=$s -replace '(?m)^(\s*auth-type:\s*).*$','${1}floodgate'; ^
    Set-Content -Encoding utf8 $p $s"

    if errorlevel 1 (
        echo [WARNING] Konfigurasi Geyser gagal diubah otomatis.
        echo Kamu masih bisa mengaturnya secara manual di:
        echo %GEYSER_CONFIG%
    ) else (
        echo Geyser dikonfigurasi.
    )
) else (
    echo.
    echo [WARNING] Config Geyser belum ditemukan.
    echo Jalankan start.bat sekali lagi agar Geyser membuat config.
)

:: ============================================================
:: CREATE START.BAT
:: ============================================================
echo.
echo Membuat start.bat...

(
echo @echo off
echo setlocal EnableExtensions EnableDelayedExpansion
echo title Minecraft Java + Bedrock Server
echo cd /d "%%~dp0"
echo.
echo :: Cari IP LAN menggunakan PowerShell agar tidak bergantung bahasa Windows
echo set "LOCAL_IP="
echo for /f "usebackq delims=" %%%%A in ^(`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 ^| Where-Object {$_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' -and $_.PrefixOrigin -ne 'WellKnown'} ^| Select-Object -First 1 -ExpandProperty IPAddress)"`^) do set "LOCAL_IP=%%%%A"
echo.
echo if "!LOCAL_IP!"=="" set "LOCAL_IP=IP-TIDAK-TERDETEKSI"
echo.
echo cls
echo echo ==========================================
echo echo       MINECRAFT SERVER ONLINE
echo echo ==========================================
echo echo.
echo echo PC LAN IP:
echo echo     !LOCAL_IP!
echo echo.
echo echo JAVA:
echo echo     !LOCAL_IP!:%JAVA_PORT%
echo echo.
echo echo ANDROID / BEDROCK:
echo echo     Address : !LOCAL_IP!
echo echo     Port    : %BEDROCK_PORT%
echo echo.
echo echo ==========================================
echo echo        SERVER SIAP DIMAINKAN
echo echo ==========================================
echo echo.
echo echo Ketik "stop" untuk mematikan server.
echo echo.
echo java -Xms%MIN_RAM% -Xmx%MAX_RAM% -jar paper.jar --nogui
echo.
echo pause
) > start.bat

:: ============================================================
:: CREATE UPDATE-PLUGINS.BAT
:: ============================================================
(
echo @echo off
echo setlocal
echo cd /d "%%~dp0"
echo echo Updating Geyser...
echo powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $u='https://api.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot'; Invoke-WebRequest -Uri $u -OutFile 'plugins\Geyser-Spigot.jar'"
echo if errorlevel 1 echo [ERROR] Geyser gagal diupdate.
echo echo Updating Floodgate...
echo powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $u='https://api.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot'; Invoke-WebRequest -Uri $u -OutFile 'plugins\floodgate-spigot.jar'"
echo if errorlevel 1 echo [ERROR] Floodgate gagal diupdate.
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
echo Bedrock:
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
