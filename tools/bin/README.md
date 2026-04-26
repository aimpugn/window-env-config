# Portable binaries

This directory is intentionally kept almost empty in Git.

Run `tools\setup.bat` or `tools\bootstrap-tools.ps1` on Windows to restore the
portable executables listed in `tools\tool-manifest.json`:

- `nu.exe` and `nu_plugin_*.exe`
- `oh-my-posh.exe`
- `rg.exe`
- `bat.exe`
- `jq.exe`
- `yq.exe`
- `tre.exe`
- `xh.exe`

The binaries are ignored by Git because they are large and reproducible from the
manifest.
