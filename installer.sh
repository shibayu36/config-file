#!/bin/sh

# homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# development fundamental
brew install coreutils
brew install autoconf
brew install automake
brew install pkg-config
brew install gnutls
brew install texinfo
brew install git
brew install libxml2
brew install openssl
brew install shared-mime-info
brew install libjpeg
brew install little-cms2

# for zshrc
brew install zplug
brew install tmux
brew install git-secrets
brew install peco
brew install anyenv
anyenv install plenv
anyenv install rbenv
anyenv install nodenv
anyenv install pyenv

brew install direnv
brew install keychain
brew install memcached
brew install redis
brew install go
brew install cmigemo
brew install sshuttle
brew install yarn
brew install mysql@5.6
brew install ctags-exuberant
brew install tig
brew install awscli
brew install mycli

brew install amazon-ecs-cli
brew install telnet
brew install mackerelio/mackerel-agent/mackerel-agent
brew install mackerelio/mackerel-agent/mkr
brew install hub
brew install prettier
brew install tree
brew install gibo
brew install colordiff
brew install aws/tap/aws-sam-cli
brew install awslogs
brew install terraform
brew install scalacenter/bloop/bloop
brew install weaveworks/tap/eksctl
brew install aws-iam-authenticator
brew install graphviz
brew install itchyny/tap/gojq
brew install github/gh/gh
brew install envchain
brew install Songmu/tap/blogsync
brew install git-subrepo
brew install htop
brew install heroku/brew/heroku

brew install --cask session-manager-plugin
brew install --cask wireshark
brew install --cask adoptopenjdk8
brew install --cask sequel-pro
brew install --cask spotify
brew install --cask jasper
brew install --cask night-owl
brew install --cask postman
brew install --cask tableplus
brew install --cask steam
brew install --cask clipy
brew install --cask asana
brew install --cask istat-menus
brew install --cask realforce

# mysqlenv
curl -kL http://bit.ly/mysqlenv | bash
