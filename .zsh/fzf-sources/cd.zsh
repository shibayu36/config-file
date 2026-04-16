function fzf-cd () {
    setopt localoptions pipefail no_aliases

    # git repo 配下なら、C-@ でそのrepo内のディレクトリ一覧に切り替えできるようにする
    local fzf_opts=()
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$git_root" ]; then
        # git ls-files の各ファイルの親ディレクトリを列挙（repo root からの相対パス）
        local dirname_awk='{ if (match($0, "/")) { sub("/[^/]*$", ""); print } else print "." }'
        local repo_src="git -C ${(q-)git_root} ls-files | awk ${(q-)dirname_awk} | sort -u"
        fzf_opts=(--bind "ctrl-space:reload($repo_src)+change-prompt(repo> )")
    fi

    # cdr の出力は '~/...' 形式なので $HOME/ に展開して絶対パスに揃える
    # git worktree (git wt) で作成したディレクトリは候補から除外
    local selected_dir
    selected_dir=$(
        (cdr -l | awk '{ print $2 }' | sed "s|^~/|$HOME/|"; ghq list --full-path) | grep -v '/.worktrees/' |
        fzf "${fzf_opts[@]}"
    )
    if [ -n "$selected_dir" ]; then
        # repo配下モードで選ばれた候補は相対パスなので、git_root を前置して絶対パス化
        if [[ "$selected_dir" != /* ]]; then
            selected_dir="$git_root/$selected_dir"
        fi
        BUFFER="cd ${selected_dir}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-cd
