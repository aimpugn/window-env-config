# Windows Nushell environment config

This folder is a portable Windows setup bundle for Nushell, Windows Terminal,
Oh My Posh, completions, aliases, and small CLI tools.

## Install

Run `setup.bat` from this directory.

The setup script runs `install.nu` with the portable `bin\nu.exe`.

By default the installed tools home is:

```text
%USERPROFILE%\VscodeProjects\configs\tools
```

Set `WINDOW_ENV_CONFIG_HOME` before running setup if you want a different target
directory.

## What gets installed

- `assets` contains Nushell config, completions, custom commands, and Oh My Posh
  themes.
- `bin` contains portable executables that are too large to keep in Git.
- Nushell `config.nu`, `env.nu`, and Windows Terminal `settings.json` are backed
  up with a timestamp suffix before being replaced.

The expected portable bin set is `nu`, Nushell plugins, `oh-my-posh`, `rg`,
`bat`, `jq`, `yq`, `tre`, and `xh`.
