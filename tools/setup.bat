@echo off
setlocal
cd /d "%~dp0"

echo Bootstrapping portable CLI tools into .\bin ...
powershell -NoProfile -ExecutionPolicy Bypass -File ".\bootstrap-tools.ps1"
if errorlevel 1 (
    echo Failed to bootstrap tools.
    pause
    exit /b 1
)

echo Running Nushell installer ...
".\bin\nu.exe" --no-config-file ".\install.nu"
if errorlevel 1 (
    echo Installation failed.
    pause
    exit /b 1
)

pause
