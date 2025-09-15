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
brew install pam-reattach

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
brew install go
brew install cmigemo
brew install sshuttle
brew install universal-ctags
brew install tig
brew install awscli
brew install mycli

brew install telnet
brew install prettier
brew install tree
brew install gibo
brew install colordiff
brew install terraform
brew install graphviz
brew install gojq
brew install gh
brew install envchain
brew install Songmu/tap/blogsync
brew install htop
brew install wget
brew install itchyny/tap/fillin
brew install mkcert
brew install findutils
brew install protobuf
brew install git-lfs
brew install starship
brew install jordanbaird-ice
brew install uv

brew install sops

brew install golangci-lint

brew install --cask fig
brew install --cask obsidian
brew install --cask aws-vault
brew install --cask session-manager-plugin
brew install --cask wireshark
brew install --cask spotify
brew install --cask docker
brew install --cask istat-menus
brew install --cask authy
brew install --cask steam
brew install --cask asana
brew install --cask realforce
brew install --cask deepl
brew install --cask discord
brew install --cask homebrew/cask-fonts/font-hack-nerd-font
brew install --cask git-credential-manager
brew install --cask claude
