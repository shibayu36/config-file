# path_helperを無効にする
setopt no_global_rcs

export MANPATH=/opt/local/man:/usr/local/man:/usr/share/man:/usr/local/share/man:$MANPATH
export TERM=xterm-color
export LC_ALL=en_US.UTF-8
export LANG=ja_JP.UTF-8
export XDG_DATA_HOME=/opt/local/share
export PERLDOC_PAGER=lv
export RLWRAP_HOME=$HOME/.rlwrap
export XDG_DATA_HOME=/usr/local/share
export XDG_DATA_DIRS=/usr/local/share

# Path config
export PATH=~/development/src/github.com/hatena/mackerel-operation-tools/bin:~/.local/bin:/Users/shibayu36/development/apache-maven/bin:/Users/shibayu36/development/Hatena/servers/bin:/usr/local/share/python:$HOME/bin:/usr/local/bin:/usr/local/sbin:/opt/local/bin:/usr/bin:/usr/sbin:/opt/local/sbin:/bin:/sbin

# homebrew
eval "$(/opt/homebrew/bin/brew shellenv)"

# asdf
. /opt/homebrew/opt/asdf/libexec/asdf.sh

# mysqlenv
# source ~/.mysqlenv/etc/bashrc

# Go PATH
export GOPATH=$HOME/development/go
export GOROOT=/usr/local/opt/go/libexec
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# Scala
export SCALA_HOME=/usr/local/opt/scala
export PATH=$PATH:$SCALA_HOME/bin

# Python
# virtualenvでpromptを変更しない
export VIRTUAL_ENV_DISABLE_PROMPT=1
export PATH=$PATH:$HOME/.poetry/bin

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

# openssl
OPENSSL_PATH=/usr/local/opt/openssl
if [ -d "$OPENSSL_PATH" ];then
  export PATH=$OPENSSL_PATH/bin:$PATH
  export LD_LIBRARY_PATH=$OPENSSL_PATH/lib:$LD_LIBRARY_PATH
  export LIBRARY_PATH=$OPENSSL_PATH/lib:$LIBRARY_PATH
  export CPATH=$OPENSSL_PATH/include:$LD_LIBRARY_PATH
fi

# texinfo
export PATH="/usr/local/opt/texinfo/bin:$PATH"

# cheat
export CHEATPATH="/Users/shibayu36/.cheat-private:$CHEATPATH"

# GCP
export GOOGLE_APPLICATION_CREDENTIALS="/Users/shibayu36/.config/gcloud/application_default_credentials.json"

# AWS CLI v1
# export PATH="/usr/local/opt/awscli@1/bin:$PATH"

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/shibayu36/.sdkman"
[[ -s "/Users/shibayu36/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/shibayu36/.sdkman/bin/sdkman-init.sh"

# imagemagick
export PATH="/usr/local/opt/imagemagick@6/bin:$PATH"
export PKG_CONFIG_PATH="/usr/local/opt/imagemagick@6/lib/pkgconfig"

# mysql
export PATH="/usr/local/opt/mysql@5.7/bin:$PATH"
