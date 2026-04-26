# gb -vv | lines | where $it =~ "gone]" | each {|line| git branch -D ($line | split row ' ' | get 2) }
export def prune-gone-branches [] {
  gf --all --prune
  gb -vv |
    lines |
    where $it =~ 'gone\]' |
    each {|line|
        let branch_info = ($line | str replace -r '^\*\s+' '' | split column ' ' --collapse-empty BranchName Hash Status1 Status2)
        let branch_name = $branch_info.BranchName | get 0;
        git branch -D $branch_name
    }
}

# git push --set-upstream origin (git symbolic-ref --short HEAD)
export def gpsuo [] {
    git push --set-upstream origin (git symbolic-ref --short HEAD)
}
