#!/bin/sh

# homebrew
/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

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

brew install peco
brew install anyenv
brew install direnv
brew install zplug
brew install keychain
brew install tmux
brew install memcached
brew install redis
brew install go
brew install cmigemo
brew install sshuttle
brew install mysqlenv
brew install yarn
brew install mysql@5.6
brew install ctags-exuberant
brew install tig
brew install awscli
brew cask install session-manager-plugin

brew install --HEAD motemen/furoshiki2/furoshiki2

brew install amazon-ecs-cli
brew install jq
brew install telnet
brew install mackerelio/mackerel-agent/mackerel-agent
brew install mackerelio/mackerel-agent/mkr
brew install hub

brew cask install adoptopenjdk8
brew cask install sequel-pro
brew cask install spotify
