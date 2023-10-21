# oh-my-zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="ys"
DISABLE_AUTO_UPDATE="true"
#DISABLE_UPDATE_PROMPT="true"
#export UPDATE_ZSH_DAYS=13
DISABLE_MAGIC_FUNCTIONS="true"
DISABLE_AUTO_TITLE="false"
# ENABLE_CORRECTION="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"

plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# User configuration
export ARCHFLAGS="-arch x86_64"
export CC="clang"
export EDITOR="nvim"
export LANG=en_US.UTF-8
export PATH="$HOME/bin:$PATH"

# Aliases
alias cd..="cd .."
alias cdd="cd /mnt/d/anthony/Desktop"
alias cls="clear"
alias exp.="xdg-open ."
alias exp="xdg-open"
alias gnano="NVIM_INIT_SRC=nano nvim-qt"
alias gvim="nvim-qt"
alias nano="NVIM_INIT_SRC=nano nvim"
alias onesync="onedrive --synchronize"
# alias optrun="__NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia"
alias vim="nvim"

# Proxy
if [[ $(grep -i Microsoft /proc/version) ]]; then
  export _HOST_IP_=$(ip route | grep default | awk '{print $3}')
else
  export _HOST_IP_="127.0.0.1"
fi
export _HOST_PORT_=7890
export _PROXY_URL=http://$_HOST_IP_:$_HOST_PORT_

function _edit_conf_ {
  if ! [[ -f $1 ]]; then
    return 0
  fi

  if [[ `grep $2 $1 | wc -l` -eq 0 ]]; then
    case $# in
      2)
        sed -i $2 $1
        ;;
      3)
        echo $3 >> $1
        ;;
      *)
        ;;
    esac
  else
    sed -i "s~$2~$3~" $1
  fi
}

function proxy {
  export HTTPS_PROXY="${_PROXY_URL}"
  export HTTP_PROXY="${_PROXY_URL}"
  export ALL_PROXY="${_PROXY_URL}"
  git config --global http.proxy ${_PROXY_URL}
  git config --global https.proxy ${_PROXY_URL}
  _edit_conf_ "$HOME/.curlrc" "^proxy=.*" "proxy=${_PROXY_URL}"
  _edit_conf_ "$HOME/.proxychains/proxychains.conf" "^http.*" "http ${_HOST_IP_} ${_HOST_PORT_}"
  echo "Set proxy to ${_PROXY_URL}"
}

function unproxy {
  unset HTTPS_PROXY
  unset HTTP_PROXY
  unset ALL_PROXY
  git config --global --unset http.proxy
  git config --global --unset https.proxy
  _edit_conf_ $HOME/.curlrc "/^proxy=.*/d"
  echo "Unset proxy"
}
