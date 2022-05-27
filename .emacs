(setq load-path (cons "~" load-path))
(global-font-lock-mode t)
(transient-mark-mode t)
(setq ls-lisp-dirs-first t)
(setq-default indent-tabs-mode nil)
(setq-default column-number-mode t)
(setq use-dialog-box nil)
;(when (fboundp 'terminal-init-bobcat)
;  (terminal-init-bobcat))

;; GNU GLOBAL
(setq load-path (cons "/usr/local/share/gtags" load-path))
(setq gtags-suggested-key-mapping t)
(setq gtags-path-style 'relative)
(when (locate-library "gtags") (require 'gtags))
(add-hook 'dired-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'sh-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'sgml-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'nxml-mode-hook '(lambda () (gtags-mode 1)))

;; C & Java
(setq-default c-basic-offset 2)
(setq c-default-style '((java-mode . "java")
                        (other . "gnu")))
(add-hook 'c-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'c++-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'java-mode-hook '(lambda ()
                             (gtags-mode 1)
                             (c-toggle-electric-state -1)))
(setq auto-mode-alist
      (append '(("\\.groovy$" . java-mode)) auto-mode-alist))

;; Javascript
(setq js-indent-level 2)
(add-hook 'js-mode-hook '(lambda () (gtags-mode 1)))

;; Python
(add-hook 'python-mode-hook '(lambda () (gtags-mode 1)))

;; Ruby
;(setq load-path (cons "/usr/local/src/ruby-1.8.7-p352/misc" load-path))
;(autoload 'rubydb "rubydb3x" "" t)
(add-hook 'ruby-mode-hook '(lambda () (gtags-mode 1)))

;; Clojure
;(setq load-path (cons "/usr/local/src/clojure-mode" load-path))
;(require 'clojure-mode)
;(add-hook 'clojure-mode-hook '(lambda () (gtags-mode 1)))
;(add-hook 'clojure-mode-hook
;          '(lambda () (setq gtags-symbol-regexp "[A-Za-z_][A-Za-z_0-9\-\!\?]*")))
;;(require 'paredit)
;;(add-hook 'clojure-mode-hook '(lambda () (paredit-mode 1)))

; Scala
;(setq load-path (cons "~/srcs/scala-tool-support/tool-support/emacs" load-path))
;(require 'scala-mode-auto)
;(add-hook 'scala-mode-hook '(lambda () (gtags-mode 1)))

;; Erlang
;(setq load-path (cons "/usr/lib/erlang/lib/tools-2.6.7/emacs " load-path))
;(setq erlang-root-dir "/usr/lib/erlang")
;(require 'erlang-start)
;(add-hook 'erlang-mode-hook '(lambda () (gtags-mode 1)))

;; golang
;(setq load-path (cons "~/srcs/go-mode.el" load-path))
;(autoload 'go-mode "go-mode" nil t)
;(add-to-list 'auto-mode-alist '("\\.go\\'" . go-mode))
;(add-hook 'go-mode-hook '(lambda () (gtags-mode 1)))

;; reStructuredText
;(require rst)
(setq frame-background-mode 'dark)
(setq auto-mode-alist
      (append '(("\\.txt$" . rst-mode)
                ("\\.rst$" . rst-mode))
              auto-mode-alist))

;; Markdown
(autoload 'markdown-mode "markdown-mode" "Major mode for editing Markdown files" t)
(add-to-list 'auto-mode-alist '("\\.text\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.md.vm\\'" . markdown-mode))

;; C# - https://github.com/emacs-csharp/csharp-mode
;(setq load-path (cons "~/srcs/csharp-mode" load-path))
;(require 'csharp-mode)
;(add-hook 'csharp-mode-hook '(lambda () (gtags-mode 1)))


;;
(cond 
 ((eq window-system 'ns) ; macosx
  (create-fontset-from-ascii-font "Menlo-12:weight=normal:slant=normal"
                                  nil
                                  "menlokakugo")
  (set-fontset-font "fontset-menlokakugo"
                    'unicode
                    (font-spec :family "Hiragino Kaku Gothic ProN" :size 12)
                    nil
                    'append)
  (add-to-list 'default-frame-alist '(font . "fontset-menlokakugo"))
  (add-to-list 'initial-frame-alist '(font . "fontset-menlokakugo"))
  (add-to-list 'face-font-rescale-alist
               '(".*Hiragino Kaku Gothic ProN.*" . 1.2))
  (add-hook 'after-init-hook
            (lambda () (set-frame-font "fontset-menlokakugo")))
  (add-to-list 'default-frame-alist '(width . 100))
  (add-to-list 'default-frame-alist '(hight . 35))
  (add-to-list 'default-frame-alist '(alpha . 80))
  (setq default-input-method "MacOSX")
  ))


;; Windows
;(global-set-key "\C-\\" nil)
;
; for rgrep and find-dired on Windows
; assuming Git for Windows installed to C:/opt/Git
;
;(add-to-list 'exec-path "C:/opt/Git/mingw64/bin")
;(add-to-list 'exec-path "C:/opt/Git/usr/bin")
;(setenv "PATH"
;	(concat
;	 "C:\\opt\\Git\\mingw64\\bin;C:\\opt\\Git\\usr\\bin"
;	 (getenv "PATH")))
;(setq find-program "C:/opt/Git/usr/bin/find.exe")
;(setq grep-program "C:/opt/Git/usr/bin/grep.exe")
;(custom-set-variables
; '(find-ls-option '("-ls" . "-dilsb")))
