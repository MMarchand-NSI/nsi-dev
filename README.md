# NSI Dev — Installation de l'environnement

## Windows

Dans **cmd.exe** ou **PowerShell** :

```
powershell -ExecutionPolicy Bypass -c "irm https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/setup.ps1 | iex"
```

## Mac / Linux

```
curl -fsSL https://raw.githubusercontent.com/MMarchand-NSI/nsi-dev/main/nsi | sudo bash -s -- install base
```
