nvdir=~/.config/nvim

if [ -d $nvdir ] && [ -d $nvdir_bak ]
then
  mv $nvdir ${nvdir}_tmp
  mv ${nvdir}_toggle $nvdir
  mv ${nvdir}_tmp ${nvdir}_toggle
  if [ -d $nvdir/lua ]
  then
    echo Configuration toggled to lua
  else
    echo Configuration toggled to viml
  fi
fi
