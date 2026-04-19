# Dotfiles

## Emacs
- Unix-like
  ``` sh
  ln -s path/to/dotfiles/emacs ~/.emacs.d
  ```
- Windows
  ``` ps1
  New-Item -ItemType Junction -Path "$HOME\.emacs.d" -Target "path\to\dotfiles\emacs"
  ```
