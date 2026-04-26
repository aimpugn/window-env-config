# 다음과 같은 구조로 패키징되어 있다고 가정합니다.
# ├─assets
# │  ├─configs
# │  └─themes
# ├─bin
# └─programs
#     └─terminal
#
# 경로 설정
let home = $env.USERPROFILE
let toolsDir = $"(pwd)"

print $"toolsDir: ($toolsDir)"

# Assets 디렉토리
let assetsDir = [ $toolsDir "assets" ] | path join
let configDir = [ $assetsDir "configs" ] | path join
let defaultNuConfig = [ $configDir "config.nu" ] | path join
let defaultNuEnv = [ $configDir "env.nu" ] | path join
let defaultTerminalSettings = [ $configDir "terminal.settings.json" ] | path join

# bin 디렉토리
let binDir = [ $toolsDir "bin" ] | path join
let expectedBinFiles = [
    "nu.exe"
    "oh-my-posh.exe"
    "rg.exe"
    "bat.exe"
    "jq.exe"
    "yq.exe"
    "tre.exe"
    "xh.exe"
    "delta.exe"
]

# Windows Terminal Path
let localWindowTerminalPath = [ $env.LOCALAPPDATA "Microsoft" "Windows Terminal" ] | path join

# programs 디렉토리
let programsDir = [ $toolsDir "programs" ] | path join
let terminalDir = [ $programsDir "terminal" ] | path join

# Windows Terminal 설정 파일 경로 찾기 (안전한 검색)
let localWindowTerminalSettingPath = if $localWindowTerminalPath != "" {
    [ $localWindowTerminalPath "settings.json" ] | path join
} else {
    print "Windows Terminal 설정 파일을 찾을 수 없습니다."; ""
}

print $"configDir: ($configDir)"
print $"defaultTerminalSettings: ($defaultTerminalSettings)"
print $"binDir: ($binDir)"
print $"localWindowTerminalPath: ($localWindowTerminalPath)"


# 디렉토리 생성 (존재 여부 확인 후 생성)
print "Create Directories..."
for dir in [$toolsDir, $binDir, $programsDir, $assetsDir, $terminalDir] {
    if not ($dir | path exists) {
        mkdir $dir
        print $"Created: ($dir)"
    } else {
        print $"Already exists: ($dir)"
    }
}

# 파일 복사 (존재 여부 확인 후 실행)
print $"Copying assets, bin, programs into ($toolsDir)..."
for dir in ["assets", "bin", "programs"] {
    let src = $"./($dir)"
    let dst = [ $toolsDir $dir ] | path join

    if ($src | path exists) {
        if (($src | path expand) == ($dst | path expand)) {
            print $"Already in place: ($src)"
        } else {
            cp -r -u $src $toolsDir
            print $"Copied: ($src) -> ($toolsDir)"
        }
    } else {
        print $"Skipping: ($src) does not exist"
    }
}

check_bin_files $binDir $expectedBinFiles

# 파일 백업 및 덮어쓰기 함수
def backup_and_overwrite [file_path: string, backup_suffix: string, source_file: string] {
    if ($file_path | path exists) {
        let backup_path = $"($file_path).($backup_suffix)"
        cp $file_path $backup_path
        print $"Backup created: ($backup_path)"
    } else {
        print $"No existing file to backup: ($file_path)"
    }

    if ($source_file | path exists) {
        print $"Overwriting: ($file_path) -> ($source_file)"
        render_source $source_file | save -f $file_path
    } else {
        print $"Source file not found: ($source_file)"
    }
}

def render_source [source_file: string] {
    let toolsDirForConfig = (
        $toolsDir
        | path expand
        | str replace --all "\\" "/"
    )

    open --raw $source_file
        | str replace --all "__WINDOW_ENV_CONFIG_TOOLS_DIR__" $toolsDirForConfig
}

def check_bin_files [bin_dir: string, expected_files: list<string>] {
    let missing = (
        $expected_files
        | each {|file|
            let target_path = [ $bin_dir $file ] | path join

            if not ($target_path | path exists) {
                $file
            }
        }
        | compact
    )

    if (($missing | length) > 0) {
        print $"Missing tool binaries: ($missing | str join ', ')"
        print "setup 후 Nushell에서 `install-default-bin-tools` 또는 `install-bin-tool <name>`으로 받을 수 있습니다."
    } else {
        print "All expected tool binaries are present."
    }
}

# 백업 및 덮어쓰기 실행
let backupSuffix = (date now | format date "%Y%m%d_%H%M%S")

print "Backing up and Overwriting Nushell configs..."
backup_and_overwrite $nu.config-path $backupSuffix $defaultNuConfig
backup_and_overwrite $nu.env-path $backupSuffix $defaultNuEnv

if $localWindowTerminalSettingPath != "" {
    print "Backing up and Overwriting Windows Terminal settings..."
    backup_and_overwrite $localWindowTerminalSettingPath $backupSuffix $defaultTerminalSettings
} else {
    print "Windows Terminal 설정 파일이 존재하지 않아 스킵합니다."
}

print "Done"
