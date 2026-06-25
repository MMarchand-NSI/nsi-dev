#!/usr/bin/env bash
set -euo pipefail

GITHUB_RAW_URL="https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/nsi"
SETTINGS_URL="https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/settings.json"
PYPROJECT_URL="https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/pyproject.toml"
INSTALL_PATH="/usr/local/bin/nsi"

# --- Détection OS ---

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }
is_mac() { [[ "$OSTYPE" == "darwin"* ]]; }
has_apt() { command -v apt-get &>/dev/null; }
has_dnf() { command -v dnf &>/dev/null; }
has_brew() { command -v brew &>/dev/null; }

ensure_brew() {
    has_brew && return 0
    is_mac || return 0
    echo "Installation de Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

_pkg_upgraded=false
pkg_install() {
    if is_mac; then ensure_brew; fi
    if has_apt; then
        if [[ "$_pkg_upgraded" == false ]]; then
            DEBIAN_FRONTEND=noninteractive apt-get update -qq
            DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq
            _pkg_upgraded=true
        fi
        DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
    elif has_dnf; then
        if [[ "$_pkg_upgraded" == false ]]; then
            dnf upgrade -y
            _pkg_upgraded=true
        fi
        dnf install -y "$@"
    elif has_brew; then
        if [[ "$_pkg_upgraded" == false ]]; then
            brew update
            brew upgrade
            _pkg_upgraded=true
        fi
        brew install "$@"
    else
        echo "Gestionnaire de paquets non supporté" >&2; exit 1
    fi
}

pkg_remove() {
    if has_apt; then
        DEBIAN_FRONTEND=noninteractive apt-get remove -y "$@"
    elif has_dnf; then
        dnf remove -y "$@"
    elif has_brew; then
        brew uninstall "$@"
    fi
}

# --- wget ---

install_wget() {
    command -v wget &>/dev/null && return 0
    pkg_install wget
}

remove_wget() { pkg_remove wget; }

# --- git ---

install_git() {
    command -v git &>/dev/null && return 0
    pkg_install git
}

remove_git() { pkg_remove git; }

# --- uv ---

install_uv() {
    command -v uv &>/dev/null && return 0
    curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh
}

remove_uv() { rm -f /usr/local/bin/uv /usr/local/bin/uvx; }

# --- graphviz ---

install_graphviz() {
    command -v dot &>/dev/null && return 0
    pkg_install graphviz
}

remove_graphviz() { pkg_remove graphviz; }

# --- gh-cli ---

install_gh() {
    command -v gh &>/dev/null && return 0
    if has_apt; then
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
            | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
            > /etc/apt/sources.list.d/github-cli.list
        _pkg_upgraded=false
        pkg_install gh
    elif has_dnf; then
        dnf install -y 'dnf-command(config-manager)'
        dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
        dnf install -y gh
    elif has_brew; then
        brew install gh
    fi
}

remove_gh() {
    if has_apt; then
        apt-get remove -y gh
        rm -f /etc/apt/sources.list.d/github-cli.list \
              /usr/share/keyrings/githubcli-archive-keyring.gpg
    elif has_dnf; then
        dnf remove -y gh
    elif has_brew; then
        brew uninstall gh
    fi
}

# --- vscode ---

install_vscode() {
    is_wsl && return 0
    command -v code &>/dev/null && return 0
    if has_brew; then
        brew install --cask visual-studio-code
    elif command -v snap &>/dev/null; then
        snap install code --classic
    else
        echo "Installation de VSCode non supportée sur cet OS" >&2
    fi
}

remove_vscode() {
    is_wsl && return 0
    if has_brew; then
        brew uninstall --cask visual-studio-code
    elif command -v snap &>/dev/null; then
        snap remove code
    fi
}

# --- base ---

install_base() {
    install_wget
    install_git
    install_uv
    install_graphviz
    install_gh
    install_vscode
}

remove_base() {
    remove_wget
    remove_git
    remove_uv
    remove_graphviz
    remove_gh
    remove_vscode
}

# --- gleam ---

install_gleam() {
    if has_brew; then
        brew list gleam &>/dev/null || brew install gleam
        return 0
    fi
    command -v erl &>/dev/null || pkg_install erlang
    if command -v gleam &>/dev/null; then return 0; fi
    local version arch
    version=$(curl -fsSL https://api.github.com/repos/gleam-lang/gleam/releases/latest \
        | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
    case "$(uname -m)" in
        x86_64)  arch="x86_64-unknown-linux-musl" ;;
        aarch64) arch="aarch64-unknown-linux-musl" ;;
        *) echo "Architecture non supportée pour gleam: $(uname -m)" >&2; exit 1 ;;
    esac
    curl -fsSL "https://github.com/gleam-lang/gleam/releases/download/v${version}/gleam-v${version}-${arch}.tar.gz" \
        | tar xz -C /usr/local/bin gleam
}

remove_gleam() {
    if has_brew; then brew uninstall gleam erlang; return; fi
    rm -f /usr/local/bin/gleam
    pkg_remove erlang
}

# --- postgresql ---

install_postgresql() {
    command -v psql &>/dev/null && return 0
    pkg_install postgresql
    if has_apt; then
        service postgresql start || true
        su -c "psql -c \"ALTER USER postgres PASSWORD 'postgres';\"" postgres || true
        su -c "psql -c \"CREATE ROLE dev SUPERUSER LOGIN PASSWORD 'dev';\"" postgres 2>/dev/null || true
    fi
    code --install-extension ms-ossdata.vscode-pgsql 2>/dev/null || true
}

remove_postgresql() { pkg_remove postgresql; }

# --- openjdk ---

install_openjdk() {
    command -v javac &>/dev/null && return 0
    if has_apt; then
        pkg_install default-jdk
    elif has_brew; then
        brew install openjdk
        brew link --force --overwrite openjdk
    fi
}

remove_openjdk() {
    if has_apt; then pkg_remove default-jdk
    elif has_brew; then brew uninstall openjdk; fi
}

# --- nasm ---

install_nasm() {
    command -v nasm &>/dev/null && return 0
    pkg_install nasm
}

remove_nasm() { pkg_remove nasm; }

# --- settings ---

cmd_settings() {
    mkdir -p .vscode
    curl -fsSL "$SETTINGS_URL" -o .vscode/settings.json
    curl -fsSL "$PYPROJECT_URL" -o pyproject.toml
    echo "Paramètres appliqués dans $(pwd)"
}

# --- update ---

cmd_update() {
    echo "Mise à jour de nsi..."
    curl -fsSL "$GITHUB_RAW_URL" | sudo tee "$INSTALL_PATH" > /dev/null
    sudo chmod +x "$INSTALL_PATH"
    echo "nsi mis à jour."
}

# --- push / pull ---

cmd_push() {
    git add -A
    git commit -m "Sauvegarde du $(date '+%Y-%m-%d %H:%M')" || true
    git push
}

cmd_pull() {
    git pull
}

# --- git ---

cmd_git() {
    echo ""
    echo "Configuration de Git et GitHub"
    echo "=============================="
    echo ""
    echo "Il te faut un token d'accès personnel GitHub."
    echo "Pour en créer un :"
    echo "  1. Va sur https://github.com/settings/tokens"
    echo "  2. Clique sur 'Generate new token (classic)'"
    echo "  3. Donne-lui un nom (ex: 'NSI'), sélectionne les portées 'repo' et 'admin:org'"
    echo "  4. Clique sur 'Generate token' et copie-le IMMEDIATEMENT
     ATTENTION : le token ne s'affiche qu'une seule fois, il sera impossible de le retrouver ensuite !"
    echo ""
    read -rp "Nom d'utilisateur GitHub : " github_user
    read -rp "Adresse email GitHub     : " github_email
    read -rp "Token GitHub             : " github_token

    git config --global user.name  "$github_user"
    git config --global user.email "$github_email"

    echo "$github_token" | gh auth login --with-token

    echo ""
    if gh repo view "$github_user/PROG-NSI" &>/dev/null; then
        echo "Repo PROG-NSI trouvé sur GitHub. Récupération en local..."
        tmp=$(mktemp -d)
        gh repo clone "$github_user/PROG-NSI" "$tmp/PROG-NSI"
        rm -rf ~/PROG-NSI
        mv "$tmp/PROG-NSI" ~/PROG-NSI
        rmdir "$tmp"
    else
        echo "Création du repo PROG-NSI sur GitHub..."
        mkdir -p ~/PROG-NSI
        cd ~/PROG-NSI
        git init
        git branch -M main
        echo "# PROG-NSI" > README.md
        git add README.md
        git commit -m "Initial commit"
        gh repo create PROG-NSI --private --source . --remote origin --push
    fi

    echo ""
    echo "Git et GitHub configurés pour $github_user."
    echo "Dossier de travail : ~/PROG-NSI"
}

# --- auto-install si lancé hors /usr/local/bin ---

SELF="$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")"
if [[ "$SELF" != "$INSTALL_PATH" ]]; then
    echo "Installation de nsi dans $INSTALL_PATH..."
    curl -fsSL "$GITHUB_RAW_URL" -o "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"
    exec "$INSTALL_PATH" "$@"
fi

# --- Dispatch ---

cmd="${1:-}"
component="${2:-}"

case "$cmd" in
    install)
        case "$component" in
            base)       install_base ;;
            gleam)      install_gleam ;;
            postgresql) install_postgresql ;;
            openjdk)    install_openjdk ;;
            nasm)       install_nasm ;;
            *) echo "Composant inconnu: $component" >&2; exit 1 ;;
        esac
        ;;
    remove)
        case "$component" in
            base)       remove_base ;;
            gleam)      remove_gleam ;;
            postgresql) remove_postgresql ;;
            openjdk)    remove_openjdk ;;
            nasm)       remove_nasm ;;
            *) echo "Composant inconnu: $component" >&2; exit 1 ;;
        esac
        ;;
    update)
        cmd_update
        ;;
    git)
        cmd_git
        ;;
    push)
        cmd_push
        ;;
    pull)
        cmd_pull
        ;;
    settings)
        cmd_settings
        ;;
    *)
        echo "Usage: nsi install|remove base|gleam|postgresql|openjdk|nasm" >&2
        echo "       nsi update" >&2
        echo "       nsi git" >&2
        echo "       nsi push | nsi pull" >&2
        echo "       nsi settings" >&2
        exit 1
        ;;
esac
