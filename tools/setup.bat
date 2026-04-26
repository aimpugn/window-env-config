@echo off
setlocal
cd /d "%~dp0"

echo Restoring portable CLI tools into .\bin ...
powershell -NoProfile -ExecutionPolicy Bypass -File ".\bootstrap-tools.ps1" -BestEffort
if errorlevel 1 (
    echo Failed to restore tools.
    pause
    exit /b 1
)

if not exist ".\bin\nu.exe" (
    echo .\bin\nu.exe was not found.
    pause
    exit /b 1
)

".\bin\nu.exe" install.nu
if errorlevel 1 (
    echo Installation failed.
    pause
    exit /b 1
)

pause
