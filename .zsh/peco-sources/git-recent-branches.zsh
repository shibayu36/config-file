function peco-git-recent-branches () {
    local selected_branch=$(git for-each-ref --format='%(refname)' --sort=-committerdate refs/heads | \
        perl -pne 's{^refs/heads/}{}' | \
        peco)
    if [ -n "$selected_branch" ]; then
        BUFFER="git checkout ${selected_branch}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N peco-git-recent-branches

function peco-git-recent-all-branches () {
    local selected_branch=$(git for-each-ref --format='%(refname)' --sort=-committerdate refs/heads refs/remotes | \
        perl -pne 's{^refs/(heads|remotes)/}{}' | \
        peco)
    if [ -n "$selected_branch" ]; then
        BUFFER="git checkout -t ${selected_branch}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N peco-git-recent-all-branches

function peco-git-recent-pull-requests () {
    local selected_pr_number=$(hub pr list --sort updated --format "%pC%>(8)%i%Creset  %t (by @%au)%n" | peco | sed -r 's/^ +#([0-9]+).*$/\1/')
    if [ -n "$selected_pr_number" ]; then
        BUFFER="hub pr checkout ${selected_pr_number}"
        zle accept-line
    fi
    zle clear-screen
}
zle -N peco-git-recent-pull-requests
