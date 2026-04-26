export def --env workspaces [...args: string] {
    cd ([$nu.home-dir "dev/eclipse/Workspaces" ...$args] | path join)
}

# Go to eclipse's default workspace
export def --env default_workspace [] {
    workspaces "Default"
}

# 이클립스 Default Workspace 하위의 `kcf-firmbanking-service` 리파지토리로 이동
export def --env kfs [] {
    workspaces "Default" "kcf-firmbanking-service"
}

# 이클립스 Default Workspace 하위의 `kcf-firmbanking-service` 리파지토리로 이동
export def --env kfb [] {
    workspaces "Default" "kcf-firmbanking-batch"
}

# 주어진 `file_path` 경로의 json 파일를 열어서 `keys` 배열을 순회하며 해당하는 값을 찾아서 리턴합니다.
#
# Example:
# ❯ [key1] | reduce --fold $data {|it, acc| $acc | get $it}
# ╭──────┬──────────────────────────────╮
# │      │ ╭──────┬───────────────────╮ │
# │ key2 │ │      │ ╭───────┬───────╮ │ │
# │      │ │ key3 │ │ value │ value │ │ │
# │      │ │      │ ╰───────┴───────╯ │ │
# │      │ ╰──────┴───────────────────╯ │
# ╰──────┴──────────────────────────────╯
#
# ❯ [key1 key2] | reduce --fold $data {|it, acc| $acc | get $it}
# ╭──────┬───────────────────╮
# │      │ ╭───────┬───────╮ │
# │ key3 │ │ value │ value │ │
# │      │ ╰───────┴───────╯ │
# ╰──────┴───────────────────╯
export def open-json-and-get-by-keys [
    file_path: path # `json` 파일 경로
    ...keys: string # 재귀적으로 탐색하려는 `key` 배열
] {
    if not ($file_path | path join | path exists) {
        print -e $"($file_path) 파일이 존재하지 않습니다"
        return null
    }

    # `each` 명령어를 사용하여 키 리스트를 순회하며 순차적으로 데이터 조회
    let result = (
        $keys
        | reduce --fold (open $file_path) {|key, accumulated_data|
                $accumulated_data | get $key
            }
    )

    return $result
}

export def --env use-java [target_version: string] {
    let version = ($target_version | str trim)

    let jdk_home = ([$env.USERPROFILE, "dev", "jdk"] | path join)
    let managed_homes = {
        "17": $"([$jdk_home, "17.0.8.0.7"] | path join)",
        "21": $"([$jdk_home, "graalvm-jdk-21"] | path join)",
        "24": $"([$jdk_home, "24.0.2"] | path join)",
        "25": $"([$jdk_home, "graalvm-jdk-25"] | path join)",
    }

    let supported_versions = $managed_homes | columns

    if ($version not-in $supported_versions) {
        error make {
            msg: $"($target_version) is empty",
            help: $"($supported_versions | str join ', ') 버전만 사용 가능합니다."
        }
    }

    let managed_bins = (
        $managed_homes
        | items {|k, v|
            {key:$k, value:([$v, "bin"] | path join ) }
        }
        | reduce --fold {} {|row, acc|
            $acc | upsert $row.key $row.value
        }
    )

    # 여러 프로그램들이 `PATH` 외에 `JAVA_HOME`를 사용하여 `java.exe`를 찾기 때문에
    # `JAVA_HOME` 역시 갱신합니다.
    $env.JAVA_HOME = $managed_homes | get $version

    # bin 경로를 정규화합니다
    let normalized_manged_bins = $managed_bins | items {|k, v| norm-with-path $v } | uniq

    # 기존 jdk/bin 경로 제거하고 현재 새로 설정하는 jdk/bin 경로를 설정합니다.
    $env.Path = (
        $env.Path
        | where {|p| (norm-with-path $p) not-in $normalized_manged_bins }
        | prepend ($managed_bins | get $version)
        | uniq
    )

    $env.JAVA_HOME
    which java
    java --version
}

def norm-with-path [p: string] {
    $p | path expand
    | str replace -a "/" "\\"
    | str trim --right --char "\\" # 끝 '\' 제거
    | str downcase
}
