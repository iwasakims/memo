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
(add-hook 'shell-script-mode-hook '(lambda () (gtags-mode 1)))


;; C & Java
(setq-default c-basic-offset 2)
(setq c-default-style '((java-mode . "java")
                        (other . "gnu")))
(add-hook 'c-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'c++-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'java-mode-hook '(lambda () (gtags-mode 1)))
(setq auto-mode-alist
      (append '(("\\.groovy$" . java-mode)) auto-mode-alist))


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


;; Scala
;(setq load-path (cons "/usr/local/src/scala-tool-support-2.10.0/scala-emacs-mode" load-path))
;(require 'scala-mode-auto)
;(add-hook 'scala-mode-hook '(lambda () (gtags-mode 1)))


;; Erlang
(setq load-path (cons "/usr/lib/erlang/lib/tools-2.6.7/emacs " load-path))
(setq erlang-root-dir "/usr/lib/erlang")
(require 'erlang-start)
(add-hook 'erlang-mode-hook '(lambda () (gtags-mode 1)))

;; reStructuredText
;(require rst)
(setq frame-background-mode 'dark)
(setq auto-mode-alist
      (append '(("\\.txt$" . rst-mode)
                ("\\.rst$" . rst-mode))
              auto-mode-alist))


;;
(cond 
 ((eq window-system 'ns) ; macosx
  (create-fontset-from-ascii-font "Menlo-14:weight=normal:slant=normal"
                                  nil
                                  "menlokakugo")
  (set-fontset-font "fontset-menlokakugo"
                    'unicode
                    (font-spec :family "Hiragino Kaku Gothic ProN" :size 16)
                    nil
                    'append)
  (add-to-list 'default-frame-alist '(font . "fontset-menlokakugo"))
  (add-to-list 'default-frame-alist '(width . 100))
  (add-to-list 'default-frame-alist '(hight . 35))
  (setq default-input-method "MacOSX")
  ))
