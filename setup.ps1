$ErrorActionPreference = "Stop"

$SetupUrl  = "https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/setup.ps1"
$NsiUrl    = "https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/nsi"
$Distro    = "Debian"
$WslUser   = "padawan"
$WslPass   = "padawan"

function Write-Red($msg) { Write-Host $msg -ForegroundColor Red }

try {

# Élévation automatique si pas admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs `
        -ArgumentList "-ExecutionPolicy Bypass -Command `"irm '$SetupUrl' | iex`""
    exit
}

# 1. VSCode
if (-not (Get-Command code -ErrorAction SilentlyContinue)) {
    Write-Host "Installation de VSCode..."
    winget install -e --id Microsoft.VisualStudioCode --silent `
        --accept-package-agreements --accept-source-agreements
}

# 2. Fonctionnalités Windows pour WSL
$needsRestart = $false
foreach ($feature in @("Microsoft-Windows-Subsystem-Linux", "VirtualMachinePlatform")) {
    if ((Get-WindowsOptionalFeature -Online -FeatureName $feature).State -ne "Enabled") {
        Write-Host "Activation de $feature..."
        Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart | Out-Null
        $needsRestart = $true
    }
}

if ($needsRestart) {
    Write-Red ""
    Write-Red "REDEMARREZ VOTRE ORDINATEUR ET RELANCEZ LA COMMANDE."
    Write-Red ""
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}

# 3. WSL version 2 par défaut
wsl --set-default-version 2 | Out-Null

# 4. Installation et initialisation silencieuse de Debian
$installed = wsl --list --quiet 2>&1
if ($installed -notmatch $Distro) {
    Write-Host "Installation de Debian..."
    wsl --install -d $Distro --no-launch
}
# initialize sans OOBE (root par défaut jusqu'à l'étape 7)
debian install --root | Out-Null

# 5. Utilisateur padawan
debian run id -u $WslUser 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Création de l'utilisateur $WslUser..."
    debian run useradd -m -s /bin/bash $WslUser
    debian run bash -c "echo '${WslUser}:${WslPass}' | chpasswd"
    debian run usermod -aG sudo $WslUser
}

# 6. Téléchargement de nsi
Write-Host "Installation de nsi..."
debian run bash -c "curl -fsSL $NsiUrl -o /usr/local/bin/nsi && chmod +x /usr/local/bin/nsi"

# 7. Installation des outils de base (encore en root)
Write-Host "Installation des outils de base..."
debian run nsi install base

# 8. Définir padawan comme utilisateur par défaut
debian config --default-user $WslUser

Write-Host ""
Write-Host "Installation terminée !" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Red "ERREUR : $_"
    Write-Host ""
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}
