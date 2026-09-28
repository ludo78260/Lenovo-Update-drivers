@echo off
title Desinstallation Lenovo Vantage + SuHelper avec Surveillance

REM Recuperer le chemin du dossier courant
set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%

REM Verifier que le script PowerShell existe
if not exist "%SCRIPT_DIR%\Uninstall-Vantage.ps1" (
    echo ERREUR: Script PowerShell introuvable !
    echo Fichier attendu : "%SCRIPT_DIR%\Uninstall-Vantage.ps1"
    exit /b 1
)

REM Verifier que le desinstallateur existe
if not exist "%SCRIPT_DIR%\VantageInstaller.exe" (
    echo ERREUR: VantageInstaller.exe introuvable !
    echo Fichier attendu : "%SCRIPT_DIR%\VantageInstaller.exe"
    exit /b 1
)

REM Execution du script PowerShell
powershell.exe -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Uninstall-Vantage.ps1"

set POWERSHELL_ERROR=%ERRORLEVEL%

exit /b %POWERSHELL_ERROR%