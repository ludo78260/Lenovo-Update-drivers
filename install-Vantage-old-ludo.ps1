# Script d'installation de Lenovo Vantage avec SuHelper
# Nécessite une exécution en tant qu'Administrateur.

param(
    [string]$LogPath = "C:\_Build\Logs\Install-Vantage.log",
    [string]$InstallPath = "VantageInstaller.exe"
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
# FONCTION : Exécution avec surveillance
# ------------------------------------------------------------
function Invoke-WithMonitoring {
    param(
        [string]$FilePath,
        [string]$Arguments
    )
    
    Write-Log "========================================" -Level "INFO" -Color "Cyan"
    Write-Log "DEBUT DE L'INSTALLATION" -Level "INFO" -Color "Cyan"
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
    
    # Surveillance avant installation
    Write-Log "SURVEILLANCE : Etat avant installation" -Level "INFO" -Color "Cyan"
    $ProcessesBefore = Get-Process | ForEach-Object { $_.ProcessName }
    Write-Log "Nombre de processus actifs : $($ProcessesBefore.Count)" -Level "INFO" -Color "White"
    
    $LenovoServicesBefore = Get-Service -Name "Lenovo*" -ErrorAction SilentlyContinue
    if ($LenovoServicesBefore) {
        Write-Log "Services Lenovo trouves avant installation :" -Level "INFO" -Color "White"
        foreach ($svc in $LenovoServicesBefore) {
            Write-Log "  - $($svc.DisplayName) ($($svc.Name)) : $($svc.Status)" -Level "INFO" -Color "White"
        }
    } else {
        Write-Log "Aucun service Lenovo trouve avant installation" -Level "INFO" -Color "White"
    }
    Write-Log "" -Level "INFO" -Color "White"
    
    # Lancement de l'installation
    Write-Log "LANCEMENT DE L'INSTALLATEUR..." -Level "INFO" -Color "Green"
    Write-Log "Commande : $FilePath $Arguments" -Level "INFO" -Color "Cyan"
    Write-Log "" -Level "INFO" -Color "White"
    
    $StartTime = Get-Date
    
    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        
        $EndTime = Get-Date
        $Duration = $EndTime - $StartTime
        
        Write-Log "" -Level "INFO" -Color "White"
        Write-Log "========================================" -Level "INFO" -Color "Cyan"
        Write-Log "FIN DE L'INSTALLATION" -Level "INFO" -Color "Cyan"
        Write-Log "========================================" -Level "INFO" -Color "Cyan"
        Write-Log "Heure de fin : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -Level "INFO" -Color "White"
        Write-Log "Duree d'execution : $($Duration.ToString('hh\:mm\:ss'))" -Level "INFO" -Color "White"
        Write-Log "Code de retour : $($process.ExitCode)" -Level "INFO" -Color "Yellow"
        
        if ($process.ExitCode -eq 0) {
            Write-Log "SUCCES : Installation terminee avec succes !" -Level "SUCCESS" -Color "Green"
        } else {
            Write-Log "ERREUR : L'installation a echoue (code $($process.ExitCode))" -Level "ERROR" -Color "Red"
        }
        
    } catch {
        Write-Log "ERREUR CRITIQUE : $_" -Level "ERROR" -Color "Red"
        $process = $null
    }
    Write-Log "" -Level "INFO" -Color "White"
    
    # Surveillance après installation
    Write-Log "SURVEILLANCE : Etat apres installation" -Level "INFO" -Color "Cyan"
    
    $ProcessesAfter = Get-Process | ForEach-Object { $_.ProcessName }
    $NewProcesses = Compare-Object -ReferenceObject $ProcessesBefore -DifferenceObject $ProcessesAfter | Where-Object { $_.SideIndicator -eq "=>" }
    if ($NewProcesses) {
        Write-Log "Nouveaux processus detectes :" -Level "INFO" -Color "White"
        foreach ($proc in $NewProcesses) {
            Write-Log "  + $($proc.InputObject)" -Level "INFO" -Color "Green"
        }
    } else {
        Write-Log "Aucun nouveau processus detecte" -Level "INFO" -Color "White"
    }
    
    $LenovoServicesAfter = Get-Service -Name "Lenovo*" -ErrorAction SilentlyContinue
    if ($LenovoServicesAfter) {
        Write-Log "Services Lenovo trouves apres installation :" -Level "INFO" -Color "White"
        foreach ($svc in $LenovoServicesAfter) {
            Write-Log "  - $($svc.DisplayName) ($($svc.Name)) : $($svc.Status)" -Level "INFO" -Color "White"
        }
    } else {
        Write-Log "Aucun service Lenovo trouve apres installation" -Level "INFO" -Color "White"
    }
    
    # Verification des dossiers d'installation
    $PotentialPaths = @(
        "C:\Program Files\Lenovo\Vantage",
        "C:\Program Files (x86)\Lenovo\Vantage",
        "C:\ProgramData\Lenovo\Vantage"
    )
    Write-Log "" -Level "INFO" -Color "White"
    Write-Log "Verification des dossiers d'installation..." -Level "INFO" -Color "White"
    foreach ($path in $PotentialPaths) {
        if (Test-Path $path) {
            try {
                $items = Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 5
                Write-Log "  Dossier $path existe" -Level "INFO" -Color "Green"
                if ($items) {
                    Write-Log "    Fichiers trouves (premiers) :" -Level "INFO" -Color "White"
                    foreach ($item in $items) {
                        $SizeKB = [math]::Round($item.Length / 1KB, 2)
                        Write-Log "      - $($item.Name) ($SizeKB KB)" -Level "INFO" -Color "White"
                    }
                }
            } catch {
                Write-Log "  Dossier $path existe (acces limite)" -Level "INFO" -Color "Yellow"
            }
        }
    }
    
    # Verification des logs Lenovo par defaut
    $DefaultLogPath = "$env:ProgramData\Lenovo\Vantage\AddinData\LenovoSystemUpdateAddin\logs"
    if (Test-Path $DefaultLogPath) {
        Write-Log "" -Level "INFO" -Color "White"
        Write-Log "Logs Lenovo trouves dans l'emplacement par defaut :" -Level "INFO" -Color "Cyan"
        try {
            $LogFiles = Get-ChildItem -Path $DefaultLogPath -File
            foreach ($file in $LogFiles) {
                $SizeKB = [math]::Round($file.Length / 1KB, 2)
                Write-Log "  - $($file.Name) ($SizeKB KB) - Modifie : $($file.LastWriteTime)" -Level "INFO" -Color "White"
            }
        } catch {
            Write-Log "  Impossible de lire le contenu du dossier" -Level "WARN" -Color "Yellow"
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
Write-Host "INSTALLATION LENOVO VANTAGE + SUHELPER" -ForegroundColor Cyan
Write-Host "AVEC SURVEILLANCE COMPLETE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ETAPE 0 : Verification des prerequis
Write-Log "ETAPE 0 : Verification des prerequis" -Level "INFO" -Color "Cyan"

if (!(Test-Path $InstallPath)) {
    Write-Log "ERREUR : $InstallPath introuvable !" -Level "ERROR" -Color "Red"
    Save-Log -Path $LogPath
    exit 1
} else {
    Write-Log "Installateur trouve : $InstallPath" -Level "SUCCESS" -Color "Green"
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

# ETAPE 1 : Activation des logs via le registre
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

# ETAPE 2 : Installation avec surveillance
Write-Log "ETAPE 2 : Lancement de l'installation avec surveillance" -Level "INFO" -Color "Cyan"

$Arguments = '/quiet Install -Vantage -SuHelper -LogLevel Debug -OutputPath "C:\_Build\Logs\Install-Vantage.log"'
$ExitCode = Invoke-WithMonitoring -FilePath $InstallPath -Arguments $Arguments

# FIN - Affichage du résultat
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SCRIPT TERMINE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Log genere : $LogPath" -ForegroundColor Green
Write-Host "Code de retour final : $ExitCode" -ForegroundColor Yellow
Write-Host ""

if ($ExitCode -eq 0) {
    Write-Host "INSTALLATION REUSSIE !" -ForegroundColor Green
} else {
    Write-Host "INSTALLATION ECHOUE (code $ExitCode)" -ForegroundColor Red
    Write-Host "Consultez le log pour plus de details : $LogPath" -ForegroundColor Yellow
}

exit $ExitCode