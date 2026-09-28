# ============================================
# INSTALLATION LENOVO VANTAGE + CONFIG BIOS-ONLY (CORRIGÉ)
# ============================================

$basePath = "C:\_Build\LENOVO-AUTO\20.2511.24.0.20251217075118"

$installerPath = Join-Path $basePath "VantageInstaller.exe"
$logPath = "C:\Logs\Install-Vantage.log"
$biosScriptPath = "C:\Scripts\Update-BIOS.ps1"
$reportPath = "C:\_Build\Logs"
$reportFile = Join-Path $reportPath "Installation-Report_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt"

New-Item -Path $reportPath -ItemType Directory -Force | Out-Null
New-Item -Path "C:\Logs" -ItemType Directory -Force | Out-Null
New-Item -Path "C:\Scripts" -ItemType Directory -Force | Out-Null

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "INSTALLATION LENOVO VANTAGE (BIOS-ONLY)" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# ETAPE 1 : POLITIQUES BIOS-ONLY (CORRIGÉ)
# ============================================

Write-Host "ETAPE 1 : Configuration des politiques BIOS-only" -ForegroundColor Yellow

$regPath = "HKLM:\SOFTWARE\Policies\Lenovo\Commercial Vantage"
New-Item -Path $regPath -Force -ErrorAction SilentlyContinue | Out-Null

# Activation du filtrage
Set-ItemProperty -Path $regPath -Name "SystemUpdateFilter" -Value 1 -Type DWord -Force

# === BIOS activé (tous les niveaux) ===
Set-ItemProperty -Path $regPath -Name "SystemUpdateFilter.critical.BIOS"    -Value 1 -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "SystemUpdateFilter.recommended.BIOS" -Value 1 -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "SystemUpdateFilter.optional.BIOS"    -Value 1 -Type DWord -Force

# === Tout le reste désactivé ===
$categories = @("driver", "firmware", "application", "others")
foreach ($cat in $categories) {
    Set-ItemProperty -Path $regPath -Name "SystemUpdateFilter.critical.$cat"    -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "SystemUpdateFilter.recommended.$cat" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regPath -Name "SystemUpdateFilter.optional.$cat"    -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
}

# Autres paramètres
Set-ItemProperty -Path $regPath -Name "AutoUpdateEnabled"         -Value 1 -Type DWord -Force
Set-ItemProperty -Path $regPath -Name "DisableUpdateNotifications" -Value 1 -Type DWord -Force

Write-Host "  ✅ Filtrage configuré : BIOS uniquement (clés SystemUpdateFilter.*)" -ForegroundColor Green

# Vérification rapide
Write-Host "  Vérification des clés :" -ForegroundColor DarkGray
Get-ItemProperty -Path $regPath | Select-Object SystemUpdateFilter*, *BIOS* | Format-List | Out-Host

Write-Host ""

# Redémarrage du service pour prendre en compte les nouvelles politiques
Write-Host "  Redémarrage du service LenovoVantageService..." -ForegroundColor Yellow
try {
    Restart-Service -Name "LenovoVantageService" -Force -ErrorAction Stop
    Write-Host "  Service redémarré avec succès" -ForegroundColor Green
} catch {
    Write-Host "  ⚠ Impossible de redémarrer le service (peut-être pas encore installé)" -ForegroundColor Yellow
}

Write-Host ""

# ============================================
# ETAPE 2 : IMPORT DES POLITIQUES
# ============================================

$regFile = Join-Path $basePath "sample-policy-config.reg"
if (Test-Path $regFile) {
    Write-Host "Importation de sample-policy-config.reg..." -ForegroundColor Yellow
    reg import $regFile 2>&1 | Out-Null
    Write-Host "  sample-policy-config.reg importé (attention : peut écraser certaines clés)" -ForegroundColor Green
}
Write-Host ""

# ============================================
# ETAPE 3 : INSTALLATION
# ============================================

Write-Host "ETAPE 3 : Installation de Lenovo Vantage" -ForegroundColor Yellow
if (Test-Path $installerPath) {
    Write-Host "  Lancement de l'installation..." -ForegroundColor Yellow
    
    $result = Start-Process -FilePath $installerPath -ArgumentList "Install -Vantage -SuHelper -LogLevel Debug -OutputPath `"$logPath`"" -Wait -PassThru
    
    if ($result.ExitCode -eq 0) {
        Write-Host "  Installation réussie !" -ForegroundColor Green
        
        $service = Get-Service -Name "LenovoVantageService" -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq "Stopped") {
            Start-Service -Name "LenovoVantageService"
            Write-Host "  Service LenovoVantageService démarré" -ForegroundColor Green
        }
        elseif ($service) {
            Write-Host "  Service LenovoVantageService déjà en cours" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠ Service LenovoVantageService non trouvé" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "  Installation échouée (code: $($result.ExitCode))" -ForegroundColor Red
        Write-Host "     Consultez le log : $logPath" -ForegroundColor Yellow
        exit $result.ExitCode
    }
}
else {
    Write-Error "Installateur introuvable : $installerPath"
    exit 1
}
Write-Host ""

# ============================================
# ETAPE 4 : CREATION SCRIPT BIOS
# ============================================

Write-Host "ETAPE 4 : Création du script de mise à jour BIOS" -ForegroundColor Yellow
if (Test-Path $biosScriptPath) {
    Write-Host "  Script Update-BIOS.ps1 déjà présent" -ForegroundColor Green
}
else {
    Write-Host "  Création du script Update-BIOS.ps1..." -ForegroundColor Yellow
    
    $biosScriptContent = @'
# ============================================
# SCRIPT DE MISE À JOUR DU BIOS - LENOVO
# ============================================

param(
    [switch]$Force,
    [string]$LogPath = "C:\Logs\BIOS-Update.log"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    switch ($Level) {
        "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
        "ERROR"   { Write-Host $logEntry -ForegroundColor Red }
        "WARNING" { Write-Host $logEntry -ForegroundColor Yellow }
        default   { Write-Host $logEntry -ForegroundColor White }
    }
    Add-Content -Path $LogPath -Value $logEntry
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-SUHelper {
    $suhelperPaths = @(
        "C:\Program Files\Lenovo\SystemUpdate\suhelper.exe",
        "C:\Program Files (x86)\Lenovo\SystemUpdate\suhelper.exe"
    )
    
    foreach ($path in $suhelperPaths) {
        if (Test-Path $path) {
            Write-Log "SUHelper trouvé : $path" "SUCCESS"
            return $path
        }
    }
    
    Write-Log "SUHelper non trouvé." "ERROR"
    return $null
}

$logDir = Split-Path $LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

Write-Log "==========================================" "INFO"
Write-Log "SCRIPT DE MISE A JOUR DU BIOS LENOVO" "INFO"
Write-Log "==========================================" "INFO"

if (-not (Test-Administrator)) {
    Write-Log "Ce script doit être exécuté en tant qu'Administrateur !" "ERROR"
    exit 1
}

Write-Log "Droits administrateur vérifiés" "SUCCESS"

$suhelper = Test-SUHelper
if (-not $suhelper) {
    Write-Log "Veuillez installer Lenovo Vantage avant d'exécuter ce script." "ERROR"
    exit 1
}

$battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
if ($battery -and -not $battery.PowerOnline) {
    Write-Log "ATTENTION : L'ordinateur n'est pas branché sur secteur !" "WARNING"
    if (-not $Force) {
        $response = Read-Host "Voulez-vous continuer quand même ? (O/N)"
        if ($response -ne "O" -and $response -ne "o") {
            Write-Log "Installation annulée par l'utilisateur." "INFO"
            exit 0
        }
    }
}

Write-Log "Installation des mises à jour BIOS..." "INFO"

try {
    $process = Start-Process -FilePath $suhelper -ArgumentList "-Action=Install", "-LogLevel=Debug" -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0) {
        Write-Log "Mise à jour BIOS terminée avec succès !" "SUCCESS"
        Write-Log "Un redémarrage peut être nécessaire." "WARNING"
        exit 0
    }
    else {
        Write-Log "Échec de l'installation (code: $($process.ExitCode))" "ERROR"
        exit 1
    }
}
catch {
    Write-Log "Erreur : $_" "ERROR"
    exit 1
}
'@

    $biosScriptContent | Out-File -FilePath $biosScriptPath -Encoding UTF8 -Force
    Write-Host "  Script Update-BIOS.ps1 créé" -ForegroundColor Green
}
Write-Host ""

# ============================================
# ETAPE 5 : TACHE PLANIFIEE
# ============================================

Write-Host "ETAPE 5 : Création de la tâche planifiée" -ForegroundColor Yellow

$taskName = "Lenovo-BIOS-Update"
$taskDescription = "Met à jour automatiquement le BIOS Lenovo"

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "  Ancienne tâche supprimée" -ForegroundColor Yellow
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$biosScriptPath`" -LogPath `"C:\Logs\BIOS-Update.log`""
$triggerNow = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(15)

Write-Host "  Premier déclencheur : dans 15 minutes" -ForegroundColor Green

$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $triggerNow -Principal $principal -Settings $settings -Description $taskDescription -Force | Out-Null

$schtasksCmd = "schtasks /change /tn `"$taskName`" /addtrigger /sc monthly /mo 1 /d 1 /st 03:00"
Invoke-Expression $schtasksCmd | Out-Null

if ($?) {
    Write-Host "  Tâche planifiée créée avec succès : $taskName" -ForegroundColor Green
    Write-Host "     - Première exécution : dans 15 minutes" -ForegroundColor Green
    Write-Host "     - Exécution mensuelle : 1er jour du mois à 3h" -ForegroundColor Green
}
else {
    Write-Host "  ⚠ Erreur lors de la création du déclencheur mensuel" -ForegroundColor Yellow
}
Write-Host ""

# ============================================
# ETAPE 6 : VERIFICATION
# ============================================

Write-Host "ETAPE 6 : Vérification de la tâche planifiée" -ForegroundColor Yellow
Start-Sleep -Seconds 3

$taskCheck = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($taskCheck) {
    Write-Host "  ✅ La tâche '$taskName' existe" -ForegroundColor Green
    $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
    if ($taskInfo) {
        Write-Host "     - Prochaine exécution : $($taskInfo.NextRunTime)" -ForegroundColor White
        Write-Host "     - Dernière exécution : $($taskInfo.LastRunTime)" -ForegroundColor White
    }
}
else {
    Write-Host "  ❌ La tâche '$taskName' n'a pas été trouvée" -ForegroundColor Red
}
Write-Host ""

# ============================================
# ETAPE 7 : RAPPORT
# ============================================

Write-Host "ETAPE 7 : Génération du rapport" -ForegroundColor Yellow

$reportContent = @"
=========================================
RAPPORT D'INSTALLATION LENOVO VANTAGE
=========================================

Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Ordinateur: $env:COMPUTERNAME

Résumé:
--------
Lenovo Vantage: $(if ($result.ExitCode -eq 0) { "INSTALLÉ" } else { "ÉCHEC" })
Tâche planifiée: $(if ($taskCheck) { "CRÉÉE" } else { "NON CRÉÉE" })

Configuration BIOS-only appliquée :
- SystemUpdateFilter = 1
- BIOS (critical/recommended/optional) = 1
- Drivers / Firmware / Applications = 0

Logs:
------
Installation: $logPath
BIOS Update: C:\Logs\BIOS-Update.log

Commandes utiles:
-----------------
Forcer l'exécution: Start-ScheduledTask -TaskName '$taskName'
Vérifier l'état: Get-ScheduledTask -TaskName '$taskName'
Ouvrir le log: Get-Content '$logPath' -Tail 20
=========================================
"@

$reportContent | Out-File -FilePath $reportFile -Encoding UTF8
Write-Host "  Rapport généré : $reportFile" -ForegroundColor Green
Write-Host ""

# ============================================
# FIN
# ============================================

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "INSTALLATION TERMINEE AVEC SUCCES" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Résumé :" -ForegroundColor Yellow
Write-Host "  ✅ Lenovo Vantage installé" -ForegroundColor Green
Write-Host "  ✅ Politiques BIOS-only configurées (clés correctes)" -ForegroundColor Green
if ($taskCheck) {
    Write-Host "  ✅ Tâche planifiée créée" -ForegroundColor Green
}
else {
    Write-Host "  ❌ Tâche planifiée non créée" -ForegroundColor Red
}
Write-Host ""

Write-Host "Logs :" -ForegroundColor Yellow
Write-Host "  - Installation : $logPath" -ForegroundColor White
Write-Host "  - Rapport     : $reportFile" -ForegroundColor White
Write-Host ""

Write-Host "Pour lancer une mise à jour immédiate :" -ForegroundColor Yellow
Write-Host "  & `"$biosScriptPath`"" -ForegroundColor White
Write-Host ""

Write-Host "Pour forcer l'exécution de la tâche planifiée :" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor White
Write-Host ""

Write-Host "Pour ouvrir le rapport :" -ForegroundColor Yellow
Write-Host "  Invoke-Item '$reportFile'" -ForegroundColor White
Write-Host ""