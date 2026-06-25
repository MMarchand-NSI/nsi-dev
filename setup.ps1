$ErrorActionPreference = "Stop"

try {

$SetupUrl  = "https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/setup.ps1"
$NsiUrl    = "https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/nsi"
$Distro    = "Debian"
$WslUser   = "padawan"
$WslPass   = "padawan"

function Write-Red($msg) { Write-Host $msg -ForegroundColor Red }

function Invoke-Native {
    & $args[0] $args[1..($args.Count-1)]
    if ($LASTEXITCODE -ne 0) { throw "Echec (code $LASTEXITCODE) : $args" }
}

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
    Invoke-Native winget install -e --id Microsoft.VisualStudioCode --silent `
        --accept-package-agreements --accept-source-agreements
}
Invoke-Native code --install-extension ms-vscode-remote.remote-wsl
Invoke-Native code --install-extension ms-python.python
Invoke-Native code --install-extension tomoki1207.pdf

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
Invoke-Native wsl --set-default-version 2

# 4. Installation de Debian
$prevEncoding = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::Unicode
$wslDistros = wsl --list --quiet 2>&1
[Console]::OutputEncoding = $prevEncoding
if ($wslDistros -notcontains $Distro) {
    Write-Host "Installation de Debian..."
    Invoke-Native wsl --install -d $Distro --no-launch
}
# Première initialisation en root (bypasse l'OOBE)
Invoke-Native wsl -d $Distro -u root -- true

# 5. Utilisateur padawan
Write-Host "Configuration de l'utilisateur $WslUser..."
Invoke-Native wsl -d $Distro -u root -- bash -c "useradd -m -s /bin/bash $WslUser 2>/dev/null; echo '${WslUser}:${WslPass}' | chpasswd; usermod -aG sudo $WslUser"

# 6. Téléchargement de nsi
Write-Host "Installation de nsi..."
Invoke-Native wsl -d $Distro -u root -- bash -c "apt-get update -qq && apt-get install -y -qq curl && curl -fsSL $NsiUrl -o /usr/local/bin/nsi && chmod +x /usr/local/bin/nsi"

# 7. Sudo sans mot de passe pour padawan
Invoke-Native wsl -d $Distro -u root -- bash -c "echo '$WslUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$WslUser && chmod 440 /etc/sudoers.d/$WslUser"

# 8. Installation des outils de base en tant que padawan
Write-Host "Installation des outils de base..."
Invoke-Native wsl -d $Distro -u $WslUser -- sudo nsi install base

# Révocation du sudo sans mot de passe
Invoke-Native wsl -d $Distro -u root -- rm -f /etc/sudoers.d/$WslUser

# Dossier de travail
Invoke-Native wsl -d $Distro -u $WslUser -- mkdir -p /home/$WslUser/PROG-NSI

# 9. Définir padawan comme utilisateur par défaut via wsl.conf
Invoke-Native wsl -d $Distro -u root -- bash -c "printf '[user]\ndefault=$WslUser\n' > /etc/wsl.conf"
Invoke-Native wsl --terminate $Distro

Write-Host ""
Write-Host "Installation terminée !" -ForegroundColor Green

# Ouverture de VSCode dans WSL
Invoke-Native wsl -d $Distro -u $WslUser -- bash -c "code ~/PROG-NSI"

} catch {
    Write-Host ""
    Write-Red "ERREUR : $_"
    Write-Host ""
    Read-Host "Appuyez sur Entree pour quitter"
    exit 1
}
Read-Host "Appuyez sur Entree pour quitter"
