#!/bin/bash
set -eu

# homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# development fundamental
brew install coreutils
brew install autoconf
brew install automake
brew install pkg-config
brew install gnutls
brew install texinfo
brew install gettext
brew install git
brew install git-delta
brew install libxml2
brew install openssl
brew install shared-mime-info
brew install libjpeg
brew install little-cms2

brew install --cask raycast
brew install --cask karabiner-elements

# for zshrc
brew install zplug
brew install tmux
brew install git-secrets
git secrets --install ~/.git-templates/git-secrets
brew install fzf
brew install bat
brew install ghq
brew install asdf
asdf plugin add ruby https://github.com/asdf-vm/asdf-ruby.git
asdf plugin add nodejs https://github.com/asdf-vm/asdf-nodejs.git
asdf plugin add perl
asdf plugin-add python

brew install direnv
brew install keychain
# brew install memcached
# brew install redis
brew install go
brew install cmigemo
brew install sshuttle
brew install yarn
# brew install mysql@5.7
brew install universal-ctags
brew install tig
brew install awscli
# brew install mycli

# brew install amazon-ecs-cli
brew install telnet
# brew install mackerelio/mackerel-agent/mackerel-agent
# brew install mackerelio/mackerel-agent/mkr
# brew install hub
brew install prettier
brew install tree
brew install gibo
brew install colordiff
brew install aws/tap/aws-sam-cli
# brew install awslogs
brew install terraform
# brew install scalacenter/bloop/bloop
# brew install weaveworks/tap/eksctl
# brew install aws-iam-authenticator
brew install graphviz
brew install gojq
brew install gh
brew install envchain
# brew install Songmu/tap/blogsync
# brew install git-subrepo
brew install htop
# brew install heroku/brew/heroku
brew install wget
brew install itchyny/tap/fillin
brew install mkcert
brew install findutils
brew install protobuf
brew install git-lfs

# brew install helm
# helm plugin install https://github.com/jkroepke/helm-secrets
brew install sops
# brew install yq

brew install golangci-lint

brew install --cask obsidian
brew install --cask aws-vault
brew install --cask session-manager-plugin
brew install --cask wireshark
# brew install --cask adoptopenjdk8
# brew install --cask sequel-pro
brew install --cask spotify
# brew install --cask jasper
# brew install --cask night-owl
brew install --cask docker
# brew install --cask clipy
brew install --cask istat-menus
brew install --cask authy
brew install --cask bartender
# brew install --cask postman
brew install --cask tableplus
brew install --cask steam
brew install --cask asana
brew install --cask realforce
brew install --cask deepl
brew install --cask discord
# brew install --cask krisp

# mysqlenv
# curl -kL http://bit.ly/mysqlenv | bash

# diff-highlight
# https://udomomo.hatenablog.com/entry/2019/12/01/181404
# sudo ln -s /usr/local/share/git-core/contrib/diff-highlight/diff-highlight /usr/local/bin/diff-highlight
