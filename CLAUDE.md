# Objectif

Un élève dispose de deux commandes à copier-coller dans un terminal pour accéder à un environnement de développement complet.

Ce sont de jeunes élèves débutants, il faut que ça soit facile d'utilisation et idempotent.

## Commandes de bootstrap

**Windows** (cmd.exe ou PowerShell) :
```
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/...setup.ps1 | iex"
```

**Mac / Linux** :
```
curl -fsSL https://raw.githubusercontent.com/.../nsi | sudo bash -s -- install base
```

Les scripts sont servis depuis GitHub raw (branche main), sans releases à gérer.

## OS
### Windows

`setup.ps1` est un script PowerShell idempotent qui :

1. Installe VSCode via `winget`
2. Vérifie que WSL2 est actif et apporte les modifications nécessaires
3. Si des modifications sont apportées, affiche un message en ROUGE demandant de redémarrer et de relancer la commande, puis pause et s'arrête
4. Installe WSL Debian : `wsl --install Debian`
5. Configure l'utilisateur padawan / padawan en ligne de commande
6. Télécharge `nsi` depuis GitHub raw dans `/usr/local/bin/nsi` via WSL et le rend exécutable
7. Lance `nsi install base` sous WSL en tant que padawan

### Linux / Mac

`nsi` est un script shell unique auto-contenu qui :

- Détecte l'OS (apt / dnf / brew)
- Détecte WSL
- Est idempotent (vérifie avant d'agir)
- Gère install et remove par composant

Il est téléchargé dans `/usr/local/bin` et rendu exécutable.

## Composants

### base
- vscode (ignoré si WSL)
- git
- uv
- graphviz
- gh-cli

### autres composants (installables individuellement)
- gleam + erlang
- postgresql (configuration développeur, sans sécurités, avec un superuser simple)
- openjdk
- nasm

## Interface nsi

```
nsi install base
nsi remove base
nsi install gleam
nsi remove gleam
# etc.
nsi update
```

`nsi update` retélécharge le script depuis GitHub raw et remplace `/usr/local/bin/nsi`.

## Structure du repo

```
repo/
  setup.ps1       # bootstrap Windows
  nsi       # script shell principal (Linux / Mac / WSL)
```
