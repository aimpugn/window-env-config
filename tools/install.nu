const SOURCE_TOOLS_DIR = path self .

def main [
    --target-dir: string = ""
    --nu-config-path: string = ""
    --nu-env-path: string = ""
    --terminal-settings-path: string = ""
    --allow-missing-tools
    --skip-terminal-settings
] {
    let home = ($env.USERPROFILE? | default $nu.home-dir)
    let default_target_dir = ([$home "VscodeProjects" "configs" "tools"] | path join)
    let tools_dir = if ($target_dir | str trim | is-empty) {
        ($env.WINDOW_ENV_CONFIG_HOME? | default $default_target_dir)
    } else {
        $target_dir
    }

    let source_tools_dir = ($SOURCE_TOOLS_DIR | path expand)
    let target_tools_dir = ($tools_dir | path expand)
    let assets_dir = [$target_tools_dir "assets"] | path join
    let config_dir = [$assets_dir "configs"] | path join
    let default_nu_config = [$config_dir "config.nu"] | path join
    let default_nu_env = [$config_dir "env.nu"] | path join
    let default_terminal_settings = [$config_dir "terminal.settings.json"] | path join
    let bin_dir = [$target_tools_dir "bin"] | path join
    let nu_config_path = if ($nu_config_path | str trim | is-empty) { $nu.config-path } else { $nu_config_path }
    let nu_env_path = if ($nu_env_path | str trim | is-empty) { $nu.env-path } else { $nu_env_path }

    print $"sourceToolsDir: ($source_tools_dir)"
    print $"targetToolsDir: ($target_tools_dir)"
    print $"binDir: ($bin_dir)"

    print "Create target directories..."
    for dir in [$target_tools_dir, $assets_dir, $bin_dir] {
        ensure-dir $dir
    }

    print "Copying package payload..."
    for dir in ["assets", "bin", "programs"] {
        copy-payload-dir $dir $source_tools_dir $target_tools_dir
    }
    for file in ["setup.bat", "install.nu", "bootstrap-tools.ps1", "tool-manifest.json", "README.md"] {
        copy-support-file $file $source_tools_dir $target_tools_dir
    }

    let missing = missing-tools $bin_dir ([$source_tools_dir "tool-manifest.json"] | path join)
    if (($missing | length) > 0) {
        print $"Missing tool binaries after copy: ($missing | str join ', ')"
        print "Run tools\\bootstrap-tools.ps1 again after network access is available."
        if not $allow_missing_tools {
            error make {
                msg: "Required tool binaries are missing."
                help: "Run setup.bat or bootstrap-tools.ps1 first, or pass --allow-missing-tools for template-only verification."
            }
        }
    }

    let backup_suffix = (date now | format date "%Y%m%d_%H%M%S")

    print "Backing up and rendering Nushell configs..."
    backup-and-render $nu_config_path $backup_suffix $default_nu_config $target_tools_dir
    backup-and-render $nu_env_path $backup_suffix $default_nu_env $target_tools_dir

    if not $skip_terminal_settings {
        let terminal_setting_path = if ($terminal_settings_path | str trim | is-empty) {
            windows-terminal-setting-path
        } else {
            $terminal_settings_path
        }
        if ($terminal_setting_path | is-empty) {
            print "Windows Terminal settings path was not detected. Skipping terminal settings."
        } else {
            print "Backing up and rendering Windows Terminal settings..."
            backup-and-render $terminal_setting_path $backup_suffix $default_terminal_settings $target_tools_dir
        }
    }

    if (($missing | length) == 0) {
        print "All manifest tool binaries are present."
    }
    print "Done"
}

def ensure-dir [dir: string] {
    if not ($dir | path exists) {
        mkdir $dir
        print $"Created: ($dir)"
    } else {
        print $"Already exists: ($dir)"
    }
}

def copy-payload-dir [
    name: string,
    source_root: string,
    target_root: string
] {
    let src = [$source_root $name] | path join
    let dst = [$target_root $name] | path join

    if not ($src | path exists) {
        print $"Skipping missing payload: ($src)"
        return
    }

    if (same-path $src $dst) {
        print $"Already in place: ($dst)"
        return
    }

    cp -r -u $src $target_root
    print $"Copied: ($src) -> ($target_root)"
}

def copy-support-file [
    name: string,
    source_root: string,
    target_root: string
] {
    let src = [$source_root $name] | path join
    let dst = [$target_root $name] | path join

    if not ($src | path exists) {
        return
    }

    if (same-path $src $dst) {
        return
    }

    cp -u $src $target_root
}

def backup-and-render [
    file_path: string,
    backup_suffix: string,
    source_file: string,
    tools_dir: string
] {
    ensure-dir ($file_path | path dirname)

    if ($file_path | path exists) {
        let backup_path = $"($file_path).($backup_suffix)"
        cp $file_path $backup_path
        print $"Backup created: ($backup_path)"
    } else {
        print $"No existing file to backup: ($file_path)"
    }

    if ($source_file | path exists) {
        let rendered = render-template $source_file $tools_dir
        $rendered | save --force $file_path
        print $"Rendered: ($source_file) -> ($file_path)"
    } else {
        print $"Source file not found: ($source_file)"
    }
}

def render-template [
    source_file: string,
    tools_dir: string
] {
    let tools_dir_for_config = (
        $tools_dir
        | path expand
        | str replace --all "\\" "/"
    )

    open --raw $source_file
        | str replace --all "__WINDOW_ENV_CONFIG_TOOLS_DIR__" $tools_dir_for_config
}

def windows-terminal-setting-path [] {
    let local_app_data = ($env.LOCALAPPDATA? | default "")
    if ($local_app_data | str trim | is-empty) {
        return ""
    }

    let candidates = [
        ([$local_app_data "Packages" "Microsoft.WindowsTerminal_8wekyb3d8bbwe" "LocalState" "settings.json"] | path join)
        ([$local_app_data "Packages" "Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe" "LocalState" "settings.json"] | path join)
        ([$local_app_data "Microsoft" "Windows Terminal" "settings.json"] | path join)
    ]

    let existing = ($candidates | where {|path| $path | path exists})
    if (($existing | length) > 0) {
        return ($existing | first)
    }

    $candidates | first
}

def missing-tools [
    bin_dir: string,
    manifest_path: string
] {
    if not ($manifest_path | path exists) {
        return []
    }

    let manifest = open $manifest_path
    $manifest.tools
    | each {|tool|
        let target_name = (try { $tool.targetName } catch { $tool.exeName })
        let target_path = [$bin_dir $target_name] | path join
        if not ($target_path | path exists) {
            $target_name
        }
    }
    | compact
}

def same-path [
    left: string,
    right: string
] {
    (normalize-path $left) == (normalize-path $right)
}

def normalize-path [path_value: string] {
    $path_value
        | path expand
        | str replace --all "/" "\\"
        | str trim --right --char "\\"
        | str downcase
}
