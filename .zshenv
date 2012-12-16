#PATH config
export JRUBY_HOME=/usr/local/jruby
export MANPATH=/opt/local/man:/usr/local/man:/usr/share/man:/usr/local/share/man:$MANPATH
export TERM=xterm-color
export LC_ALL=en_US.UTF-8
export LANG=ja_JP.UTF-8
export XDG_DATA_HOME=/opt/local/share
export PERLDOC_PAGER=lv
export RLWRAP_HOME=$HOME/.rlwrap
export XDG_DATA_HOME=/usr/local/share
export XDG_DATA_DIRS=/usr/local/share
export DYLD_FALLBACK_LIBRARY_PATH=/usr/local/lib:/usr/local/mysql/lib:$DYLD_FALLBACK_LIBRARY_PATH

# 最初の$PATH抜いてみたけどどうなるか
export PATH=/Users/shibayu36/development/Hatena/servers/bin:/usr/local/share/python:$HOME/bin:/usr/local/bin:/usr/local/sbin:/opt/local/bin:/usr/bin:/usr/sbin:/opt/local/sbin:/bin:/sbin:$JRUBY_HOME/bin
# export PATH=$PATH:/Users/shibayu36/development/Hatena/servers/bin:/usr/local/share/python:$HOME/bin:/usr/local/bin:/usr/local/sbin:/opt/local/bin:/usr/bin:/usr/sbin:/opt/local/sbin:/bin:/sbin:$JRUBY_HOME/bin
PATH=$PATH:$HOME/.rvm/bin # Add RVM to PATH for scripting
