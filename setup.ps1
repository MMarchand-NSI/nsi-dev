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

Set-PSDebug -Trace 1

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

# 4. Installation et initialisation de Debian
$installed = wsl --list --quiet 2>&1
if ($installed -notmatch $Distro) {
    Write-Host "Installation de Debian..."
    wsl --install -d $Distro --no-launch
}
# Première initialisation en root (bypasse l'OOBE)
wsl -d $Distro -u root -- true

# 5. Utilisateur padawan (idempotent : création uniquement si inexistant)
Write-Host "Configuration de l'utilisateur $WslUser..."
wsl -d $Distro -u root -- bash -c "id -u $WslUser >/dev/null 2>&1 || (useradd -m -s /bin/bash $WslUser && echo '${WslUser}:${WslPass}' | chpasswd && usermod -aG sudo $WslUser)"

# 6. Téléchargement de nsi
Write-Host "Installation de nsi..."
wsl -d $Distro -u root -- bash -c "curl -fsSL $NsiUrl -o /usr/local/bin/nsi && chmod +x /usr/local/bin/nsi"

# 7. Sudo sans mot de passe pour padawan
wsl -d $Distro -u root -- bash -c "echo '$WslUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$WslUser && chmod 440 /etc/sudoers.d/$WslUser"

# 8. Installation des outils de base en tant que padawan
Write-Host "Installation des outils de base..."
wsl -d $Distro -u $WslUser -- sudo nsi install base

# Révocation du sudo sans mot de passe
wsl -d $Distro -u root -- rm -f /etc/sudoers.d/$WslUser

# 9. Définir padawan comme utilisateur par défaut via wsl.conf
wsl -d $Distro -u root -- bash -c "printf '[user]\ndefault=$WslUser\n' > /etc/wsl.conf"
wsl --terminate $Distro

Write-Host ""
Write-Host "Installation terminée !" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Red "ERREUR : $_"
    Write-Host ""
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}
