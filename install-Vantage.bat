@echo off

REM Recuperer le chemin du dossier courant
set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

REM Verifier que le script PowerShell existe
if not exist "%SCRIPT_DIR%\Install-Vantage.ps1" exit /b 1

REM Verifier que l'installateur existe
if not exist "%SCRIPT_DIR%\VantageInstaller.exe" exit /b 1

REM Execution du script PowerShell - Totalement silencieux
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Install-Vantage.ps1" -WindowStyle Hidden

exit /b %ERRORLEVEL%