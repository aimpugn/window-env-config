# Windows Nushell environment config

This folder is a portable Windows setup bundle for Nushell, Windows Terminal,
Oh My Posh, completions, aliases, and small CLI tools.

## Install

Run `setup.bat` from this directory.

The setup script first restores missing executables into `bin` from
`tool-manifest.json`, then runs `install.nu` with that portable `nu.exe`.

By default the installed tools home is:

```text
%USERPROFILE%\VscodeProjects\configs\tools
```

Set `WINDOW_ENV_CONFIG_HOME` before running setup if you want a different target
directory.

## What gets installed

- `assets` contains Nushell config, completions, custom commands, and Oh My Posh
  themes.
- `bin` is restored locally from GitHub release assets and then copied into the
  tools home.
- Nushell `config.nu`, `env.nu`, and Windows Terminal `settings.json` are backed
  up with a timestamp suffix before being replaced.

The portable bin set currently restores `nu`, Nushell plugins, `oh-my-posh`,
`rg`, `bat`, `jq`, `yq`, `tre`, and `xh`.
