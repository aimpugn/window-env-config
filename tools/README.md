# Windows Nushell environment config

This folder is a portable Windows setup bundle for Nushell, Windows Terminal,
Oh My Posh, completions, aliases, and small CLI tools.

## Install

Run `setup.bat` from this directory.

The setup script runs `install.nu` with the portable `bin\nu.exe`.

The `tools` directory itself is the portable tools home. Put this directory
where you want to keep it, then run `setup.bat` from inside it.

## What gets installed

- `assets` contains Nushell config, completions, custom commands, and Oh My Posh
  themes.
- `bin` contains portable executables that are too large to keep in Git.
- Nushell `config.nu`, `env.nu`, and Windows Terminal `settings.json` are backed
  up with a timestamp suffix before being replaced.

The expected portable bin set is `nu`, Nushell plugins, `oh-my-posh`, `rg`,
`bat`, `jq`, `yq`, `tre`, `xh`, and `delta`.

After setup has installed the Nushell config, portable tools can be refreshed
from inside Nushell:

```nu
list-bin-tools
install-bin-tool rg
install-bin-tool delta
install-default-bin-tools
```

For a GitHub release that is not in the default registry, pass the repository.
If the release uses a normal Windows x64 zip or exe asset and the executable is
`<name>.exe`, the defaults are usually enough:

```nu
install-bin-tool fd --repo sharkdp/fd
install-bin-repo dandavison/delta
```

When a release uses a different asset name or executable name, provide the
pattern explicitly:

```nu
install-bin-tool mytool --repo owner/repo --asset '.*windows.*amd64.*\.zip$' --exe mytool.exe
```

If you prefer Windows Package Manager instead of copying a portable exe into
`bin`, use the winget method:

```nu
install-bin-tool rg --method winget
install-bin-tool custom --method winget --winget Some.PackageId
```

## oh-my-posh

### theme 적용하기

```sh
# oh-my-posh init nu --config path\to\themes\peru.omp.json
oh-my-posh init nu --config C:\Users\rody\Workspace\window-env-config\tools\assets\oh-my-posh\themes\peru.omp.json
```
