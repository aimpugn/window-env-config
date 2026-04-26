# Portable binaries

This directory is intentionally kept almost empty in Git.

Put the portable executables here before running `tools\setup.bat`:

- `nu.exe` and `nu_plugin_*.exe`
- `oh-my-posh.exe`
- `rg.exe`
- `bat.exe`
- `jq.exe`
- `yq.exe`
- `tre.exe`
- `xh.exe`
- `delta.exe`

The binaries are ignored by Git because they are large.

After setup has loaded the included Nushell config, run `install-bin-tool rg`,
`install-bin-tool delta`, or `install-default-bin-tools` to download the common
portable tools from GitHub releases. Use `install-bin-tool <name> --method
winget` when you want Windows Package Manager to install a package instead.
