function fzf-git-recent-branches () {
    local selected_branch=$(git for-each-ref --format='%(refname)' --sort=-committerdate refs/heads | \
        perl -pne 's{^refs/heads/}{}' | \
        fzf)
    if [ -n "$selected_branch" ]; then
        BUFFER="git checkout ${selected_branch}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-git-recent-branches

function fzf-git-recent-all-branches () {
    local selected_branch=$(git for-each-ref --format='%(refname)' --sort=-committerdate refs/heads refs/remotes | \
        perl -pne 's{^refs/(heads|remotes)/}{}' | \
        fzf)
    if [ -n "$selected_branch" ]; then
        BUFFER="git checkout -t ${selected_branch}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-git-recent-all-branches

# open PRを全件取得すると大きなリポジトリでは十数秒かかるため、前回の一覧をキャッシュしてすぐ表示し、
# 裏で取り直した一覧に差し替える。取得はfzfの外で始める。fzfのreload内で始めると、fzfを閉じたときに打ち切られるため。
function fzf-git-recent-pull-requests () {
    local remote_url=$(git remote get-url origin 2>/dev/null)
    if [ -z "$remote_url" ]; then
        zle -M "origin remote not found"
        return
    fi
    local cache_dir=~/.cache/gh-pr-list
    local cache="$cache_dir/${remote_url//[\/:]/_}"
    mkdir -p "$cache_dir"

    (
        gh pr list --json number,title,author --template '{{range .}}{{printf "%.0f (%s) %s\n" .number .author.login .title}}{{end}}' --limit 10000 > "$cache.$$" 2>/dev/null \
            && mv "$cache.$$" "$cache" \
            || rm -f "$cache.$$"
    ) &!
    local fetch_pid=$!

    local selected_pr_number=$(cat "$cache" 2>/dev/null | \
        fzf --bind "load:unbind(load)+reload-sync(while kill -0 $fetch_pid 2>/dev/null; do sleep 0.3; done; cat ${(q)cache} 2>/dev/null)" | \
        awk '{ print $1 }')
    if [ -n "$selected_pr_number" ]; then
        BUFFER="gh pr checkout ${selected_pr_number}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-git-recent-pull-requests
