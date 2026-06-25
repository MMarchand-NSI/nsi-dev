# Objectif

Un élève dispose de deux commandes à copier-coller dans un terminal pour accéder à un environnement de développement complet.

Ce sont de jeunes élèves débutants, il faut que ça soit facile d'utilisation et idempotent.

## Commandes de bootstrap

**Windows** (cmd.exe ou PowerShell) :
```
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/setup.ps1 | iex"
```

**Mac / Linux** :
```
curl -fsSL https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/nsi | sudo bash -s -- install base
```

Les scripts sont servis depuis GitHub raw (branche main), sans releases à gérer.

## OS

### Windows

`setup.ps1` est un script PowerShell idempotent qui :

1. Installe VSCode via `winget` + extension `ms-vscode-remote.remote-wsl`
2. Vérifie que WSL2 est actif ; si des fonctionnalités manquent, affiche un message en ROUGE demandant de redémarrer et de relancer la commande, puis s'arrête
3. Installe WSL Debian : `wsl --install -d Debian`
4. Configure l'utilisateur `padawan` / `padawan` en ligne de commande
5. Accorde temporairement le sudo sans mot de passe, puis installe les outils via `sudo nsi install base`, et révoque le sudo sans mot de passe
6. Définit `padawan` comme utilisateur par défaut (via `/etc/wsl.conf` + clé de registre `DefaultUid`)
7. Ouvre une console Debian interactive qui lance automatiquement `nsi git`, puis laisse un shell interactif (`exec bash`) une fois la configuration terminée

### Linux / Mac

`nsi` est un script shell unique auto-contenu qui :

- Détecte l'OS (apt / dnf / brew)
- Détecte WSL
- Est idempotent (vérifie avant d'agir)
- Gère install et remove par composant
- Se met à jour via `nsi update` (curl + tee + exit 0 immédiat pour éviter la relecture du fichier remplacé)

Il est téléchargé dans `/usr/local/bin` et rendu exécutable.

## Composants

### base
- vscode (ignoré si WSL — VSCode est déjà installé côté Windows)
- git
- uv (installé dans `/usr/local/bin` via `UV_INSTALL_DIR`)
- graphviz
- gh-cli

### autres composants (installables individuellement)
- `gleam` — Gleam + Erlang
- `postgresql` — configuration développeur sans sécurité, avec superuser `dev`/`dev`
- `openjdk` — JDK complet
- `nasm` — assembleur x86
- `rust` — Rust via rustup, installé dans `/usr/local/rustup` et `/usr/local/cargo` (accessible à tous les utilisateurs), binaires symlinkés dans `/usr/local/bin`
- `prolog` — SWI-Prolog (`swipl`)
- `c` — GCC/G++/Make (`build-essential` sur Debian, `gcc gcc-c++ make` sur Fedora, Xcode CLT sur macOS)

## Interface nsi

```
nsi install base
nsi remove base
nsi install gleam
nsi remove gleam
# etc.
nsi update
```

`nsi update` retélécharge le script depuis GitHub raw, remplace `/usr/local/bin/nsi` et termine immédiatement (`exit 0`).

## Structure du repo

```
repo/
  setup.ps1         # bootstrap Windows
  nsi               # script shell principal (Linux / Mac / WSL)
  settings.json     # paramètres VSCode déployés dans .vscode/ du dépôt élève
  extensions.json   # recommandations d'extensions VSCode
  tasks.json        # tâche VSCode : nsi pull automatique à l'ouverture
  pyproject.toml    # projet Python uv déployé dans le dépôt élève
  .gitignore        # gitignore Python/Gleam/Rust/Java déployé dans le dépôt élève
  .gitattributes    # force LF pour les scripts shell, CRLF pour .ps1
```

## Gestion de git

```
nsi git         # configuration initiale
nsi push        # commit horodaté + push
nsi pull        # pull
nsi settings    # redéploie settings.json / extensions.json / tasks.json / pyproject.toml / .gitignore
```

### `nsi git`

Interdit à root. Configure git et authentifie GitHub. Demande interactivement :
- le nom d'utilisateur GitHub
- l'adresse email GitHub
- un token d'accès personnel (portées `repo` et `admin:org`, créé sur https://github.com/settings/tokens)
- le nom du dépôt GitHub (validé : pas de `..`, pas de suffixe `.git`)

Si le dépôt existe déjà sur GitHub → clone dans `~/nom-du-depot`.
Sinon → crée le dépôt privé avec un premier commit (README + pyproject.toml + .gitignore).

Dans les deux cas, déploie `.vscode/settings.json`, `.vscode/extensions.json`, `.vscode/tasks.json`, `pyproject.toml`, `.gitignore`, lance `uv sync`, puis ouvre VSCode dans le dossier.

### `nsi push`

Équivalent de `git add -A && git commit -m "Sauvegarde du <date>" && git push`. Ne produit pas d'erreur si rien n'a changé.

### `nsi pull`

Équivalent de `git pull`.

## Paramètres VSCode déployés (`settings.json`)

- `files.autoSave: afterDelay` (1 s) — sauvegarde automatique
- `git.autofetch: true` — synchronisation automatique avec le remote
- `files.exclude` — masque `.vscode/`, `pyproject.toml`, `.gitignore` dans l'Explorer
- Désactivation de Copilot, télémétrie, suggestions IA

## Extensions VSCode

- **Installée automatiquement** (setup.ps1) : `ms-vscode-remote.remote-wsl`
- **Recommandées** (extensions.json, VSCode propose à l'ouverture du dépôt) :
  `tomoki1207.pdf`, `ms-python.python`, `ms-vscode.test-adapter-converter`,
  `hbenl.vscode-test-explorer`, `iterteam.dependi`, `aaron-bond.better-comments`,
  `tamasfe.even-better-toml`, `sanaajani.taskrunnercode`
