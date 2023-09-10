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

function fzf-git-recent-pull-requests () {
    local selected_pr_number=$(gh pr list --json number,title,author --template '{{range .}}{{printf "%.0f (%s) %s\n" .number .author.login .title}}{{end}}' --limit 50 --search 'sort:updated-desc' | fzf | awk '{ print $1 }')
    if [ -n "$selected_pr_number" ]; then
        BUFFER="gh pr checkout ${selected_pr_number}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N fzf-git-recent-pull-requests
