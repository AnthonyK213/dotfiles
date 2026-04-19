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

## Powershell
- Windows
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
- Config (.\config.ps1)
  | variable   | description |
  |------------|-------------|
  | USER_PROXY | Proxy URL   |
