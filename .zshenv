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
export PATH=~/.local/bin:/Users/shibayu36/development/apache-maven/bin:/Users/shibayu36/development/Hatena/servers/bin:/usr/local/share/python:$HOME/bin:/usr/local/bin:/usr/local/sbin:/opt/local/bin:/usr/bin:/usr/sbin:/opt/local/sbin:/bin:/sbin

# anyenv
export PATH="$HOME/.anyenv/bin:$PATH"
eval "$(anyenv init -)"

# mysqlenv
source ~/.mysqlenv/etc/bashrc

# Go PATH
export GOPATH=$HOME/development/go
export GOROOT=/usr/local/opt/go/libexec
export PATH=$PATH:$GOROOT/bin:$GOPATH/bin

# Scala
export JAVA_HOME=`/usr/libexec/java_home`
export SCALA_HOME=/usr/local/opt/scala
export PATH=$PATH:$SCALA_HOME/bin

# Python
# virtualenvでpromptを変更しない
export VIRTUAL_ENV_DISABLE_PROMPT=1

### Added by the Heroku Toolbelt
export PATH="/usr/local/heroku/bin:$PATH"

# openssl
OPENSSL_PATH=/usr/local/opt/openssl
if [ -d "$OPENSSL_PATH" ];then
  export PATH=$OPENSSL_PATH/bin:$PATH
  export LD_LIBRARY_PATH=$OPENSSL_PATH/lib:$LD_LIBRARY_PATH
  export CPATH=$OPENSSL_PATH/include:$LD_LIBRARY_PATH
fi

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="/Users/shibayu36/.sdkman"
[[ -s "/Users/shibayu36/.sdkman/bin/sdkman-init.sh" ]] && source "/Users/shibayu36/.sdkman/bin/sdkman-init.sh"
