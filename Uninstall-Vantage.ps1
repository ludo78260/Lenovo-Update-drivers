# Script de désinstallation de Lenovo Vantage avec SuHelper
# Nécessite une exécution en tant qu'Administrateur.

param(
    [string]$LogPath = "C:\_Build\Logs\Uninstall-Vantage.log",
    [string]$UninstallPath = "VantageInstaller.exe"
)

$ErrorActionPreference = "Continue"
$Script:StartTime = Get-Date
$Script:LogEntries = @()

# ------------------------------------------------------------
# FONCTION : Écriture dans le log personnalisé
# ------------------------------------------------------------
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [string]$Color = "White"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    $Script:LogEntries += $LogEntry
    
    if ($Color -ne "White") {
        Write-Host $LogEntry -ForegroundColor $Color
    } else {
        Write-Host $LogEntry
    }
}

# ------------------------------------------------------------
# FONCTION : Sauvegarde du log
# ------------------------------------------------------------
function Save-Log {
    param([string]$Path = $LogPath)
    
    try {
        $LogDir = Split-Path $Path -Parent
        if (!(Test-Path $LogDir)) {
            New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
            Write-Log "Dossier de logs cree : $LogDir" -Level "INFO" -Color "Green"
        }
        $Script:LogEntries | Out-File -FilePath $Path -Encoding UTF8 -Force
        Write-Host ""
        Write-Host "Log sauvegarde : $Path" -ForegroundColor Green
    } catch {
        Write-Host "ERREUR lors de la sauvegarde du log : $_" -ForegroundColor Red
    }
}

# ------------------------------------------------------------
# FONCTION : Désinstallation avec surveillance
# ------------------------------------------------------------
function Invoke-UninstallWithMonitoring {
    param(
        [string]$FilePath,
        [string]$Arguments
    )
    
    Write-Log "========================================" -Level "INFO" -Color "Cyan"
    Write-Log "DEBUT DE LA DESINSTALLATION" -Level "INFO" -Color "Cyan"
    Write-Log "========================================" -Level "INFO" -Color "Cyan"
    Write-Log "Fichier : $FilePath" -Level "INFO" -Color "White"
    Write-Log "Arguments : $Arguments" -Level "INFO" -Color "White"
    Write-Log "Heure de debut : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO" -Color "White"
    Write-Log "" -Level "INFO" -Color "White"
    
    if (!(Test-Path $FilePath)) {
        Write-Log "ERREUR : Fichier introuvable !" -Level "ERROR" -Color "Red"
        Write-Log "Chemin recherche : $FilePath" -Level "ERROR" -Color "Red"
        return 1
    }
    
    try {
        $FileInfo = Get-Item $FilePath
        $SizeMB = [math]::Round($FileInfo.Length / 1MB, 2)
        Write-Log "Taille du fichier : $SizeMB MB" -Level "INFO" -Color "White"
        Write-Log "Date de modification : $($FileInfo.LastWriteTime)" -Level "INFO" -Color "White"
        Write-Log "" -Level "INFO" -Color "White"
    } catch {
        Write-Log "Impossible de lire les informations du fichier" -Level "WARN" -Color "Yellow"
    }
    
    # Surveillance avant désinstallation
    Write-Log "SURVEILLANCE : Etat avant desinstallation" -Level "INFO" -Color "Cyan"
    $ProcessesBefore = Get-Process | ForEach-Object { $_.ProcessName }
    Write-Log "Nombre de processus actifs : $($ProcessesBefore.Count)" -Level "INFO" -Color "White"
    
    $LenovoServicesBefore = Get-Service -Name "Lenovo*" -ErrorAction SilentlyContinue
    if ($LenovoServicesBefore) {
        Write-Log "Services Lenovo trouves avant desinstallation :" -Level "INFO" -Color "White"
        foreach ($svc in $LenovoServicesBefore) {
            Write-Log "  - $($svc.DisplayName) ($($svc.Name)) : $($svc.Status)" -Level "INFO" -Color "White"
        }
    } else {
        Write-Log "Aucun service Lenovo trouve avant desinstallation" -Level "INFO" -Color "White"
    }
    Write-Log "" -Level "INFO" -Color "White"
    
    # Lancement de la désinstallation
    Write-Log "LANCEMENT DE LA DESINSTALLATION..." -Level "INFO" -Color "Green"
    Write-Log "Commande : $FilePath $Arguments" -Level "INFO" -Color "Cyan"
    Write-Log "" -Level "INFO" -Color "White"
    
    $StartTime = Get-Date
    
    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        
        $EndTime = Get-Date
        $Duration = $EndTime - $StartTime
        
        Write-Log "" -Level "INFO" -Color "White"
        Write-Log "========================================" -Level "INFO" -Color "Cyan"
        Write-Log "FIN DE LA DESINSTALLATION" -Level "INFO" -Color "Cyan"
        Write-Log "========================================" -Level "INFO" -Color "Cyan"
        Write-Log "Heure de fin : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO" -Color "White"
        Write-Log "Duree d'execution : $($Duration.ToString('hh\:mm\:ss'))" -Level "INFO" -Color "White"
        Write-Log "Code de retour : $($process.ExitCode)" -Level "INFO" -Color "Yellow"
        
        if ($process.ExitCode -eq 0) {
            Write-Log "SUCCES : Desinstallation terminee avec succes !" -Level "SUCCESS" -Color "Green"
        } else {
            Write-Log "ERREUR : La desinstallation a echoue (code $($process.ExitCode))" -Level "ERROR" -Color "Red"
        }
        
    } catch {
        Write-Log "ERREUR CRITIQUE : $_" -Level "ERROR" -Color "Red"
        $process = $null
    }
    Write-Log "" -Level "INFO" -Color "White"
    
    # Surveillance après désinstallation
    Write-Log "SURVEILLANCE : Etat apres desinstallation" -Level "INFO" -Color "Cyan"
    
    $ProcessesAfter = Get-Process | ForEach-Object { $_.ProcessName }
    $RemovedProcesses = Compare-Object -ReferenceObject $ProcessesBefore -DifferenceObject $ProcessesAfter | Where-Object { $_.SideIndicator -eq "<=" }
    if ($RemovedProcesses) {
        Write-Log "Processus supprimes :" -Level "INFO" -Color "White"
        foreach ($proc in $RemovedProcesses) {
            Write-Log "  - $($proc.InputObject)" -Level "INFO" -Color "Red"
        }
    } else {
        Write-Log "Aucun processus supprime" -Level "INFO" -Color "White"
    }
    
    $NewProcesses = Compare-Object -ReferenceObject $ProcessesBefore -DifferenceObject $ProcessesAfter | Where-Object { $_.SideIndicator -eq "=>" }
    if ($NewProcesses) {
        Write-Log "Nouveaux processus detectes :" -Level "INFO" -Color "White"
        foreach ($proc in $NewProcesses) {
            Write-Log "  + $($proc.InputObject)" -Level "INFO" -Color "Green"
        }
    }
    
    $LenovoServicesAfter = Get-Service -Name "Lenovo*" -ErrorAction SilentlyContinue
    if ($LenovoServicesAfter) {
        Write-Log "Services Lenovo trouves apres desinstallation :" -Level "INFO" -Color "White"
        foreach ($svc in $LenovoServicesAfter) {
            Write-Log "  - $($svc.DisplayName) ($($svc.Name)) : $($svc.Status)" -Level "INFO" -Color "White"
        }
    } else {
        Write-Log "Aucun service Lenovo trouve apres desinstallation" -Level "INFO" -Color "White"
    }
    
    # Verification que les dossiers ont ete supprimes
    $PotentialPaths = @(
        "C:\Program Files\Lenovo\Vantage",
        "C:\Program Files (x86)\Lenovo\Vantage",
        "C:\ProgramData\Lenovo\Vantage"
    )
    Write-Log "" -Level "INFO" -Color "White"
    Write-Log "Verification des dossiers de desinstallation..." -Level "INFO" -Color "White"
    foreach ($path in $PotentialPaths) {
        if (Test-Path $path) {
            Write-Log "  Dossier $path existe encore" -Level "WARN" -Color "Yellow"
        } else {
            Write-Log "  Dossier $path a ete supprime" -Level "INFO" -Color "Green"
        }
    }
    
    Write-Log "" -Level "INFO" -Color "White"
    Save-Log -Path $LogPath
    
    Write-Log "========================================" -Level "INFO" -Color "Cyan"
    Write-Log "FIN DE LA SURVEILLANCE" -Level "INFO" -Color "Cyan"
    Write-Log "========================================" -Level "INFO" -Color "Cyan"
    
    return $process.ExitCode
}

# ------------------------------------------------------------
# EXECUTION PRINCIPALE
# ------------------------------------------------------------
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "DESINSTALLATION LENOVO VANTAGE + SUHELPER" -ForegroundColor Cyan
Write-Host "AVEC SURVEILLANCE COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ETAPE 0 : Verification des prerequis
Write-Log "ETAPE 0 : Verification des prerequis" -Level "INFO" -Color "Cyan"

if (!(Test-Path $UninstallPath)) {
    Write-Log "ERREUR : $UninstallPath introuvable !" -Level "ERROR" -Color "Red"
    Save-Log -Path $LogPath
    exit 1
} else {
    Write-Log "Desinstallateur trouve : $UninstallPath" -Level "SUCCESS" -Color "Green"
}
Write-Log "" -Level "INFO" -Color "White"

# Creation du dossier de logs
Write-Log "ETAPE 0b : Preparation du dossier de logs" -Level "INFO" -Color "Cyan"
$LogDir = Split-Path $LogPath -Parent
if (!(Test-Path $LogDir)) {
    try {
        New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
        Write-Log "Dossier de logs cree : $LogDir" -Level "INFO" -Color "Green"
    } catch {
        Write-Log "Impossible de creer le dossier $LogDir. Verifiez les permissions." -Level "ERROR" -Color "Red"
        Save-Log -Path $LogPath
        exit 1
    }
} else {
    Write-Log "Dossier de logs existant : $LogDir" -Level "INFO" -Color "White"
}
Write-Log "" -Level "INFO" -Color "White"

# ETAPE 1 : Activation des logs via le registre (pour la desinstallation)
Write-Log "ETAPE 1 : Activation de la journalisation dans le registre" -Level "INFO" -Color "Cyan"
$RegPath = "HKLM:\SOFTWARE\WOW6432Node\Lenovo\SystemUpdateAddin\Logs"
$RegValue = "EnableLogs"
$RegData = "True"

try {
    if (!(Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
        Write-Log "Cle de registre creee : $RegPath" -Level "INFO" -Color "Green"
    }
    New-ItemProperty -Path $RegPath -Name $RegValue -Value $RegData -PropertyType String -Force | Out-Null
    Write-Log "Valeur '$RegValue' = '$RegData' definie avec succes." -Level "SUCCESS" -Color "Green"
} catch {
    Write-Log "ERREUR CRITIQUE : Impossible d'ecrire dans le registre. Verifiez les droits administrateur." -Level "ERROR" -Color "Red"
    Save-Log -Path $LogPath
    exit 1
}
Write-Log "" -Level "INFO" -Color "White"

# ETAPE 2 : Desinstallation avec surveillance
Write-Log "ETAPE 2 : Lancement de la desinstallation avec surveillance" -Level "INFO" -Color "Cyan"

# Arguments pour la désinstallation
$Arguments = '/quiet Uninstall -Vantage -SuHelper -LogLevel Debug -OutputPath "C:\_Build\Logs\Uninstall-Vantage.log"'
$ExitCode = Invoke-UninstallWithMonitoring -FilePath $UninstallPath -Arguments $Arguments

# FIN - Affichage du résultat
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SCRIPT TERMINE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Log genere : $LogPath" -ForegroundColor Green
Write-Host "Code de retour final : $ExitCode" -ForegroundColor Yellow
Write-Host ""

if ($ExitCode -eq 0) {
    Write-Host "DESINSTALLATION REUSSIE !" -ForegroundColor Green
} else {
    Write-Host "DESINSTALLATION ECHOUE (code $ExitCode)" -ForegroundColor Red
    Write-Host "Consultez le log pour plus de details : $LogPath" -ForegroundColor Yellow
}

exit $ExitCode