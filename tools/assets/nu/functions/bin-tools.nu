# Portable bin tool downloader.
#
# These commands are sourced by configs/config.nu. They do not run during shell
# startup; call them only when you want to refresh tools/bin.

def bin-tools-registry [] {
    [
        {
            name: "nu"
            repo: "nushell/nushell"
            asset: "^nu-.*-x86_64-pc-windows-msvc\\.zip$"
            exe: "nu.exe"
            target: "nu.exe"
            winget: "Nushell.Nushell"
            extra: ["nu_plugin_*.exe"]
        }
        {
            name: "oh-my-posh"
            repo: "JanDeDobbeleer/oh-my-posh"
            asset: "^posh-windows-amd64\\.exe$"
            exe: "posh-windows-amd64.exe"
            target: "oh-my-posh.exe"
            winget: "JanDeDobbeleer.OhMyPosh"
            extra: []
        }
        {
            name: "rg"
            repo: "BurntSushi/ripgrep"
            asset: "^ripgrep-.*-x86_64-pc-windows-msvc\\.zip$"
            exe: "rg.exe"
            target: "rg.exe"
            winget: "BurntSushi.ripgrep.MSVC"
            extra: []
        }
        {
            name: "bat"
            repo: "sharkdp/bat"
            asset: "^bat-.*-x86_64-pc-windows-msvc\\.zip$"
            exe: "bat.exe"
            target: "bat.exe"
            winget: "sharkdp.bat"
            extra: []
        }
        {
            name: "jq"
            repo: "jqlang/jq"
            asset: "^jq-windows-amd64\\.exe$"
            exe: "jq-windows-amd64.exe"
            target: "jq.exe"
            winget: "jqlang.jq"
            extra: []
        }
        {
            name: "yq"
            repo: "mikefarah/yq"
            asset: "^yq_windows_amd64\\.exe$"
            exe: "yq_windows_amd64.exe"
            target: "yq.exe"
            winget: "MikeFarah.yq"
            extra: []
        }
        {
            name: "tre"
            repo: "dduan/tre"
            asset: "^tre-.*-x86_64-pc-windows-msvc\\.zip$"
            exe: "tre.exe"
            target: "tre.exe"
            winget: "dduan.tre"
            extra: []
        }
        {
            name: "xh"
            repo: "ducaale/xh"
            asset: "^xh-.*-x86_64-pc-windows-msvc\\.zip$"
            exe: "xh.exe"
            target: "xh.exe"
            winget: "ducaale.xh"
            extra: []
        }
        {
            name: "delta"
            repo: "dandavison/delta"
            asset: "^delta-.*-x86_64-pc-windows-msvc\\.zip$"
            exe: "delta.exe"
            target: "delta.exe"
            winget: "dandavison.delta"
            extra: []
        }
    ]
}

def value-or [value fallback] {
    if ($value | is-empty) {
        $fallback
    } else {
        $value
    }
}

def default-bin-asset-pattern [] {
    "(?i).*(x86_64.*windows|windows.*x86_64|x86_64.*msvc|windows.*amd64|win64|win-x64).*(\\.zip|\\.exe)$"
}

def bin-tools-dir [] {
    let configured = ($env.WINDOW_ENV_CONFIG_BIN_DIR? | default "")

    if ($configured | is-empty) {
        let tools_dir = ($env.WINDOW_ENV_CONFIG_TOOLS_DIR? | default "")

        if ($tools_dir | is-empty) {
            error make {msg: "WINDOW_ENV_CONFIG_BIN_DIR is not set. Run setup.bat first, or set WINDOW_ENV_CONFIG_TOOLS_DIR / WINDOW_ENV_CONFIG_BIN_DIR before using install-bin-tool."}
        }

        [ $tools_dir "bin" ] | path join
    } else {
        $configured
    }
}

def temp-dir [] {
    let root = (
        if not (($env.TEMP? | default "") | is-empty) {
            $env.TEMP
        } else if not (($env.TMP? | default "") | is-empty) {
            $env.TMP
        } else if not (($env.TMPDIR? | default "") | is-empty) {
            $env.TMPDIR
        } else if not (($nu.temp-dir? | default "") | is-empty) {
            $nu.temp-dir
        } else {
            error make {msg: "Could not find a temporary directory. Set TEMP or TMP before using install-bin-tool."}
        }
    )

    [ $root $"window-env-config-(random uuid)" ] | path join
}

def resolve-bin-tool [
    name: string
    repo: string
    asset: string
    exe: string
    target: string
    winget: string
] {
    let matched = (bin-tools-registry | where name == $name)
    let base = if (($matched | length) > 0) {
        $matched | first
    } else {
        {
            name: $name
            repo: ""
            asset: ""
            exe: $"($name).exe"
            target: $"($name).exe"
            winget: $name
            extra: []
        }
    }

    let resolved_repo = (value-or $repo $base.repo)
    let resolved_exe = (value-or $exe $base.exe)
    let resolved_target = (value-or $target (value-or $base.target $resolved_exe))

    {
        name: $name
        repo: $resolved_repo
        asset: (value-or $asset (value-or $base.asset (default-bin-asset-pattern)))
        exe: $resolved_exe
        target: $resolved_target
        winget: (value-or $winget $base.winget)
        extra: $base.extra
    }
}

def latest-release-assets [repo: string] {
    let api = $"https://api.github.com/repos/($repo)/releases/latest"

    ^curl -L --fail --silent --show-error -H "User-Agent: window-env-config" $api
        | from json
        | get assets
}

def select-release-asset [assets: list<any>, pattern: string] {
    let candidates = (
        $assets
        | where {|asset|
            (($asset.name =~ $pattern)
                and (not ($asset.name =~ "(?i)(sha256|checksum|\\.asc|\\.sig)$")))
        }
    )

    if (($candidates | length) == 0) {
        error make {msg: $"No release asset matched pattern: ($pattern)"}
    }

    $candidates | first
}

def copy-bin-file [source: string, target: string, force: bool] {
    if (($target | path exists) and (not $force)) {
        print $"Already exists: ($target). Use --force to overwrite."
        false
    } else {
        if ($target | path exists) {
            rm -f $target
        }

        cp $source $target
        true
    }
}

def copy-zip-tool [archive: string, spec: record, bin_dir: string, force: bool, work_dir: string] {
    let extract_dir = ([ $work_dir "extract" ] | path join)
    mkdir $extract_dir
    ^tar -xf $archive -C $extract_dir

    let matches = (glob ([ $extract_dir "**" $spec.exe ] | path join))
    if (($matches | length) == 0) {
        error make {msg: $"Could not find ($spec.exe) in downloaded archive."}
    }

    let target_path = ([ $bin_dir $spec.target ] | path join)
    let copied = (copy-bin-file ($matches | first) $target_path $force)

    for pattern in $spec.extra {
        let extra_matches = (glob ([ $extract_dir "**" $pattern ] | path join))

        for extra in $extra_matches {
            let extra_target = ([ $bin_dir ($extra | path basename) ] | path join)
            copy-bin-file $extra $extra_target $force | ignore
        }
    }

    $copied
}

def install-github-bin-tool [spec: record, force: bool] {
    if ($spec.repo | is-empty) {
        error make {msg: $"Repository is required for ($spec.name). Pass --repo owner/name or add it to bin-tools-registry."}
    }

    let bin_dir = (bin-tools-dir)
    mkdir $bin_dir

    let target_path = ([ $bin_dir $spec.target ] | path join)
    if (($target_path | path exists) and (not $force)) {
        print $"Already exists: ($target_path). Use --force to overwrite."
        return {name: $spec.name, status: "skipped", path: $target_path}
    }

    let work_dir = (temp-dir)
    mkdir $work_dir

    let assets = (latest-release-assets $spec.repo)
    let asset = (select-release-asset $assets $spec.asset)
    let download_path = ([ $work_dir $asset.name ] | path join)

    print $"Downloading ($spec.name) from ($spec.repo): ($asset.name)"
    ^curl -L --fail --silent --show-error -o $download_path $asset.browser_download_url

    let copied = if (($asset.name | str downcase) | str ends-with ".zip") {
        copy-zip-tool $download_path $spec $bin_dir $force $work_dir
    } else {
        copy-bin-file $download_path $target_path $force
    }

    rm -rf $work_dir

    if $copied {
        print $"Installed: ($target_path)"
        {name: $spec.name, status: "installed", path: $target_path}
    } else {
        {name: $spec.name, status: "skipped", path: $target_path}
    }
}

def install-winget-bin-tool [spec: record] {
    let package = (value-or $spec.winget $spec.name)

    print $"Installing via winget: ($package)"
    ^winget install $package --accept-package-agreements --accept-source-agreements
}

export def list-bin-tools [] {
    bin-tools-registry | select name repo asset exe target winget
}

export def install-bin-tool [
    name: string
    --repo: string = ""
    --asset: string = ""
    --exe: string = ""
    --target: string = ""
    --method: string = "github"
    --winget: string = ""
    --force
] {
    let spec = (resolve-bin-tool $name $repo $asset $exe $target $winget)

    if $method == "github" {
        install-github-bin-tool $spec $force
    } else if $method == "winget" {
        install-winget-bin-tool $spec
    } else {
        error make {msg: $"Unknown install method: ($method). Use github or winget."}
    }
}

export def install-bin-repo [
    repo: string
    --name: string = ""
    --asset: string = ""
    --exe: string = ""
    --target: string = ""
    --force
] {
    let inferred_name = if ($name | is-empty) {
        $repo | split row "/" | last
    } else {
        $name
    }

    install-bin-tool $inferred_name --repo $repo --asset $asset --exe $exe --target $target --force=$force
}

export def install-default-bin-tools [
    --force
    --include-nu
] {
    let tools = if $include_nu {
        bin-tools-registry
    } else {
        bin-tools-registry | where name != "nu"
    }

    for tool in $tools {
        install-bin-tool $tool.name --force=$force
    }
}
