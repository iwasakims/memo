(setq load-path (cons "~" load-path))
(global-font-lock-mode t)
(transient-mark-mode t)
(setq ls-lisp-dirs-first t)
(setq-default indent-tabs-mode nil)
(setq c-default-style '((java-mode . "gnu")))
;(when (fboundp 'terminal-init-bobcat)
;  (terminal-init-bobcat))


(setq load-path (cons "/usr/local/src/ruby-1.8.7-p352/misc" load-path))
(autoload 'rubydb "rubydb3x" "" t)


(setq load-path (cons "/usr/local/src/clojure-mode" load-path))
(require 'clojure-mode)
;(require 'paredit)
;(add-hook 'clojure-mode-hook '(lambda () (paredit-mode 1)))
(add-hook 'clojure-mode-hook
          '(lambda () (setq gtags-symbol-regexp "[A-Za-z_][A-Za-z_0-9\-\!\?]*")))


(setq load-path (cons "/usr/local/src/scala-tool-support-2.10.0/scala-emacs-mode" load-path))
(require 'scala-mode-auto)


(setq load-path (cons "/usr/local/lib/erlang/lib/tools-2.6.8/emacs" load-path))
(setq erlang-root-dir "/usr/local/lib/erlang")
(require 'erlang-start)


;(require rst)


(setq load-path (cons "/usr/local/share/gtags" load-path))
(setq gtags-suggested-key-mapping t)
(setq gtags-path-style 'relative)
(when (locate-library "gtags") (require 'gtags))
(add-hook 'c-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'c++-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'java-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'python-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'ruby-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'clojure-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'erlang-mode-hook '(lambda () (gtags-mode 1)))


(setq auto-mode-alist
      (append '(
                ("\\.groovy$" . java-mode)
                ;("\\.txt$" . rst-mode)
                ;("\\.rst$" . rst-mode)
                ) auto-mode-alist))
