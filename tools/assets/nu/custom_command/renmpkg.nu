#!/usr/bin/env nu

# Java/Spring 패키지명을 일괄 변경합니다.
# 기본은 dry-run이며, 실제 반영은 --apply를 지정해야 합니다.
#
# 사용 예시:
#   nu renm_pkg.nu --to kr.co.company.fds
#   nu renm_pkg.nu --from kr.co.abc.xyz --to kr.co.company.fds --apply
#   nu renm_pkg.nu --to kr.co.company.fds --root . --apply
#
# 추가 규칙:
# - 패키지명 변경과 함께 회사 도메인 루트도 함께 바꿉니다.
# - 예: `kr.co.abc.xyz` -> `abc.co.kr`, `kr.co.company.fds` -> `company.co.kr`

def validate-package [name: string, pkg: string] {
    let cleaned = ($pkg | str trim)
    if ($cleaned | is-empty) {
        error make {msg: $"($name) is required"}
    }

    let parts = ($cleaned | split row ".")
    if (($parts | length) == 0) {
        error make {msg: $"($name) must contain at least one segment"}
    }

    let has_empty = ($parts | any {|p| ($p | str trim | is-empty)})
    if $has_empty {
        error make {msg: $"($name) has an empty segment: ($pkg)"}
    }

    # Java 식별자 최소 규칙(첫 글자 숫자 금지)
    let invalid = (
        $parts
        | where {|p|
            let first = ($p | str substring 0..0)
            (($p | str contains " ") or ($first in ["0" "1" "2" "3" "4" "5" "6" "7" "8" "9"]))
        }
    )
    if (($invalid | length) > 0) {
        error make {msg: $"($name) has invalid segment(s): ($invalid | str join ', ')"}
    }

    $cleaned
}

def package-domain-root-parts [pkg_parts: list<string>] {
    if (($pkg_parts | length) >= 3) {
        return ($pkg_parts | first 3)
    }

    $pkg_parts
}

def reverse-domain-from-package-parts [pkg_parts: list<string>] {
    package-domain-root-parts $pkg_parts
        | reverse
        | str join "."
}

def text-files [root_abs: string] {
    # NOTE:
    # - Nu의 `glob`는 wax 문법을 사용하며, Windows의 절대 경로(`C:\...`)처럼
    #   드라이브 레터/백슬래시가 포함된 문자열을 그대로 패턴으로 받으면 파싱에 실패할 수 있습니다.
    # - 그래서 "루트로 cd -> 상대 glob -> 절대 경로 정규화(path expand)" 방식으로 파일 목록을 만듭니다.
    #   (Nu 버전에 따라 glob 출력이 상대/절대가 달라질 수 있으므로, 항상 절대 경로로 맞춥니다.)
    do {
        cd $root_abs
        glob $"**/*.{java,xml,yml,yaml,properties,md,txt,json,sql,toml,gradle,kts,nu,sh,ps1,cmd,bat}" --exclude [
            "**/.git/**"
            "**/target/**"
            "**/.m2/**"
            "**/build/**"
            "**/.idea/**"
            "**/.vscode/**"
            "**/scripts/renm_pkg.nu"
        ] --no-dir
            | each {|p| $p | path expand }
    }
}

def replace-in-file [
    file: string,
    from_pkg: string,
    to_pkg: string,
    from_path_slash: string,
    to_path_slash: string,
    from_path_backslash: string,
    to_path_backslash: string,
    from_path_double_backslash: string,
    to_path_double_backslash: string,
    from_domain: string,
    to_domain: string,
    apply: bool
] {
    let original = (open --raw $file)
    let updated = (
        $original
        | str replace --all $from_pkg $to_pkg
        | str replace --all $from_path_slash $to_path_slash
        | str replace --all $from_path_backslash $to_path_backslash
        | str replace --all $from_path_double_backslash $to_path_double_backslash
        | str replace --all $from_domain $to_domain
    )

    if $updated != $original {
        if $apply {
            $updated | save --force $file
        }
        { changed: true, file: $file }
    } else {
        { changed: false, file: $file }
    }
}

def dir-entry-paths [dir_abs: string] {
    if (not ($dir_abs | path exists)) {
        return []
    }

    do {
        cd $dir_abs
        ls -a
            | get name
            | each {|name| [$dir_abs, $name] | path join }
    }
}

def planned-retained-entries [
    current_abs: string,
    created_dir_abs: string
] {
    let relative = (
        do -i { $created_dir_abs | path relative-to $current_abs }
        | default "__outside__"
    )
    if $relative == "__outside__" {
        return []
    }

    let parts = ($relative | path split)
    if (($parts | length) == 0) {
        return [$current_abs]
    }

    [([$current_abs, ($parts | first)] | path join)]
}

def preview-prunable-parent-dirs [
    removed_dir_abs: string,
    created_dir_abs: string,
    stop_abs: string
] {
    mut current = ($removed_dir_abs | path dirname)
    mut removed_child = $removed_dir_abs
    mut prunable = []

    while $current != $stop_abs {
        let remaining = (
            (
                dir-entry-paths $current
                | where {|entry| $entry != $removed_child}
            ) ++ (planned-retained-entries $current $created_dir_abs)
        )
        if (($remaining | length) > 0) {
            break
        }

        $prunable = ($prunable | append $current)
        $removed_child = $current

        let next = ($current | path dirname)
        if $next == $current {
            break
        }
        $current = $next
    }

    $prunable
}

def prune-empty-parent-dirs [
    removed_dir_abs: string,
    stop_abs: string
] {
    mut current = ($removed_dir_abs | path dirname)
    mut pruned = []

    while $current != $stop_abs {
        if (not ($current | path exists)) {
            break
        }

        let entries = (dir-entry-paths $current)
        if (($entries | length) > 0) {
            break
        }

        rm -r --force $current
        $pruned = ($pruned | append $current)

        let next = ($current | path dirname)
        if $next == $current {
            break
        }
        $current = $next
    }

    $pruned
}

def move-package-tree [
    root_abs: string,
    base_rel: string,
    from_parts: list<string>,
    to_parts: list<string>,
    apply: bool
] {
    let base_abs = ([$root_abs, $base_rel] | path join)
    let src = (([$base_abs] ++ $from_parts) | path join)
    let dst = (([$base_abs] ++ $to_parts) | path join)

    if (not ($src | path exists)) {
        return {
            base: $base_rel,
            source_exists: false,
            source: $src,
            target: $dst,
            moved: false,
            mode: "skip",
            pruned_dirs: []
        }
    }

    if (not $apply) {
        return {
            base: $base_rel,
            source_exists: true,
            source: $src,
            target: $dst,
            moved: false,
            mode: "dry-run",
            pruned_dirs: (preview-prunable-parent-dirs $src $dst $base_abs)
        }
    }

    if (not (($dst | path dirname) | path exists)) {
        mkdir ($dst | path dirname)
    }

    if (not ($dst | path exists)) {
        mv $src $dst
        let pruned_dirs = (prune-empty-parent-dirs $src $base_abs)
        return {
            base: $base_rel,
            source_exists: true,
            source: $src,
            target: $dst,
            moved: true,
            mode: "rename-dir",
            pruned_dirs: $pruned_dirs
        }
    }

    # 타깃 디렉터리가 이미 있으면 파일 단위로 병합 이동
    let files = (do {
        cd $src
        glob "**/*" --no-dir
            | each {|p| $p | path expand }
    })
    for f in $files {
        let rel = ($f | path relative-to $src)
        let target_file = ([$dst, $rel] | path join)
        let target_parent = ($target_file | path dirname)

        if (not ($target_parent | path exists)) {
            mkdir $target_parent
        }

        mv --force $f $target_file
    }

    rm -r --force $src
    let pruned_dirs = (prune-empty-parent-dirs $src $base_abs)

    {
        base: $base_rel,
        source_exists: true,
        source: $src,
        target: $dst,
        moved: true,
        mode: "merge-files",
        merged_files: ($files | length),
        pruned_dirs: $pruned_dirs
    }
}

export def main [
    --from(-f): string = "kr.co.abc.xyz",   # 기존 패키지명
    --to(-t): string,                       # 바꾸려는 패키지명
    --root(-r): string = ".",               # 적용할 경로
    --apply(-a)                             # 변경 사항 적용
] {
    let from_pkg = (validate-package "from" $from)
    let to_pkg = (validate-package "to" $to)

    if $from_pkg == $to_pkg {
        error make {msg: "from and to are the same"}
    }

    let root_abs = ($root | path expand)
    if (not ($root_abs | path exists)) {
        error make {msg: $"root path does not exist: ($root_abs)"}
    }
    if (($root_abs | path type) != "dir") {
        error make {msg: $"root path is not a directory: ($root_abs)"}
    }

    let from_parts = ($from_pkg | split row ".")
    let to_parts = ($to_pkg | split row ".")

    let from_path_slash = ($from_parts | str join "/")
    let to_path_slash = ($to_parts | str join "/")
    let from_path_backslash = ($from_parts | str join "\\")
    let to_path_backslash = ($to_parts | str join "\\")
    let from_path_double_backslash = ($from_parts | str join "\\\\")
    let to_path_double_backslash = ($to_parts | str join "\\\\")
    let from_domain = (reverse-domain-from-package-parts $from_parts)
    let to_domain = (reverse-domain-from-package-parts $to_parts)

    print ""
    print "[rename-package] Plan"
    print $"  root        : ($root_abs)"
    print $"  from package: ($from_pkg)"
    print $"  to package  : ($to_pkg)"
    print $"  from domain : ($from_domain)"
    print $"  to domain   : ($to_domain)"
    print $"  mode        : (if $apply { 'APPLY' } else { 'DRY-RUN' })"
    print ""

    let files = (text-files $root_abs)
    let changed = (
        $files
        | each {|f|
            replace-in-file $f $from_pkg $to_pkg $from_path_slash $to_path_slash $from_path_backslash $to_path_backslash $from_path_double_backslash $to_path_double_backslash $from_domain $to_domain $apply
        }
        | where changed == true
    )

    let base_roots = [
        "src/main/java"
        "src/test/java"
        "src/main/resources"
        "src/test/resources"
    ]

    let move_results = (
        $base_roots
        | each {|b| move-package-tree $root_abs $b $from_parts $to_parts $apply }
    )
    let pruned_dirs = (
        $move_results
        | get pruned_dirs
        | flatten
    )

    print "[rename-package] Summary"
    print $"  changed files : ($changed | length)"

    let existing_sources = ($move_results | where source_exists == true)
    let moved = ($move_results | where moved == true)

    print $"  package roots : ($existing_sources | length) found / ($moved | length) moved"
    print $"  empty dirs    : ($pruned_dirs | length) (if $apply { 'pruned' } else { 'planned' })"

    if (not $apply) {
        print ""
        print "[dry-run] preview of changed files (up to 20)"
        ($changed | first 20 | get file | each {|f| print $"  - ($f)" })

        if (($changed | length) > 20) {
            print $"  ... and (($changed | length) - 20) more"
        }

        if (($pruned_dirs | length) > 0) {
            print ""
            print "[dry-run] preview of empty legacy package dirs to prune (up to 20)"
            ($pruned_dirs | first 20 | each {|dir| print $"  - ($dir)" })

            if (($pruned_dirs | length) > 20) {
                print $"  ... and (($pruned_dirs | length) - 20) more"
            }
        }

        print ""
        print "Run again with --apply to perform the replacement."
    } else {
        print ""
        print "[apply] package rename completed."
    }

    {
        root: $root_abs,
        from: $from_pkg,
        to: $to_pkg,
        mode: (if $apply { "apply" } else { "dry-run" }),
        changed_files: ($changed | length),
        moved_roots: ($moved | length),
        pruned_dirs: ($pruned_dirs | length)
    }
}
