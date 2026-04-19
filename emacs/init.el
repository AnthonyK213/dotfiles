;;; -*- lexical-binding: t -*-

(defvar my/theme 'modus-vivendi "Default theme")
(defvar my/font-family "monospace" "Default font")
(defvar my/font-size 12 "Default font size")
(defvar my/cjk-font-family "monospace" "Default CJK font")

(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file))

(load-theme my/theme t)

(setq inhibit-startup-screen t)
(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(set-fringe-mode 10)
(setq-default fill-column 80)
(global-display-fill-column-indicator-mode 1)
(global-display-line-numbers-mode 1)

(setq ring-bell-function 'ignore)
(setq make-backup-files nil)
(setq auto-save-default nil)

(set-language-environment "UTF-8")
(prefer-coding-system 'utf-8)
(set-default-coding-systems 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(setq locale-coding-system 'utf-8)
(set-selection-coding-system (if (eq system-type 'windows-nt) 'utf-16-le 'utf-8))

(electric-pair-mode 1)

(when (display-graphic-p)
  (set-face-attribute 'default nil
                      :family my/font-family
                      :height (* my/font-size 10))
  (dolist (charset '(han kana hangul symbol cjk-misc bopomofo))
    (set-fontset-font (frame-parameter nil 'font)
                      charset
                      (font-spec :family my/cjk-font-family))))

(require 'package)
(setq package-archives '(("melpa"  . "https://melpa.org/packages/")
                         ("gnu"    . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
(package-initialize)

(require 'use-package)

(use-package evil
  :ensure t
  :init
  (setq evil-want-keybinding nil)
  (setq evil-undo-system 'undo-redo)
  :config
  (evil-mode 1))

(use-package evil-collection
  :ensure t
  :after evil
  :config
  (evil-collection-init))

(with-eval-after-load 'evil
  (evil-set-leader 'normal (kbd "SPC"))
  (evil-define-key 'normal 'global
    (kbd "K") 'eldoc
    (kbd "<leader>bn") 'evil-next-buffer
    (kbd "<leader>bp") 'evil-prev-buffer
    (kbd "<leader>bd") 'evil-delete-buffer
    (kbd "<leader>ff") 'find-file
    (kbd "<leader>fb") 'switch-to-buffer
    (kbd "<leader>gn") 'magit-status
    (kbd "<leader>op") 'dired-jump))

(use-package vertico
  :ensure t
  :init
  (vertico-mode))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package magit
  :ensure t
  :bind ("C-x g" . magit-status))

(use-package corfu
  :ensure t
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.1)
  (corfu-auto-prefix 1)
  (corfu-quit-at-boundary 'separator)
  :init
  (global-corfu-mode))

(use-package eglot
  :hook
  ((c++-mode . eglot-ensure)
   (c-mode . eglot-ensure)))

(with-eval-after-load 'eglot
  (evil-define-key 'normal eglot-mode-map
    (kbd "<leader>la") 'eglot-code-actions
    (kbd "<leader>li") 'eglot-find-implementation
    (kbd "<leader>ln") 'eglot-rename
    (kbd "<leader>lr") 'xref-find-references
    (kbd "<leader>lf") 'xref-find-definitions
    (kbd "<leader>lm") 'eglot-format
    (kbd "<leader>l[") 'flymake-goto-prev-error
    (kbd "<leader>l]") 'flymake-goto-next-error)
  (add-hook 'eglot-managed-mode-hook (lambda () (eglot-inlay-hints-mode -1))))
