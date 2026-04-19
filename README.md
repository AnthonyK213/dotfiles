# Dotfiles

## Emacs

### Installation

- Unix-like
  ``` sh
  ln -s path/to/dotfiles/emacs ~/.emacs.d
  ```

- Windows
  ``` ps1
  New-Item -ItemType Junction -Path "$HOME\.emacs.d" `
                              -Target "path\to\dotfiles\emacs"
  ```

## Neovim

### Requirements

- [Neovim](https://github.com/neovim/neovim) 0.12 or later
- [Git](https://github.com/git/git)
- [tree-sitter](https://github.com/tree-sitter/tree-sitter) CLI
- [ripgrep](https://github.com/BurntSushi/ripgrep) (optional)
- [fd](https://github.com/sharkdp/fd) (optional)

### Installation

- Unix-like
  ``` sh
  ln -s path/to/dotfiles/nvim ~/.config/nvim
  ```

- Windows
  ``` ps1
  New-Item -ItemType Junction -Path "$env:LOCALAPPDATA\nvim" `
                              -Target "path\to\dotfiles\nvim"
  ```

### Documentation

[documentation](./nvim/doc/nviq.txt)

## Powershell

### Installation

- Allow scripts (in admin mode)
  ``` ps1
  Set-ExecutionPolicy RemoteSigned
  # `Set-ExecutionPolicy Restricted` to reset
  ```
- Create junction
  ``` ps1
  $MyDocuments = [Environment]::GetFolderPath("MyDocuments")
  New-Item -ItemType Junction -Path "$MyDocuments\Powershell" `
                              -Target "path\to\dotfiles\pwsh"
  ```

### Configuration

.\config.ps1

| variable   | description |
|------------|-------------|
| USER_PROXY | Proxy URL   |
