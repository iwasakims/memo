(setq load-path (cons "~" load-path))
(global-font-lock-mode t)
(transient-mark-mode t)
(setq ls-lisp-dirs-first t)
(setq-default indent-tabs-mode nil)

(when (fboundp 'terminal-init-bobcat)
  (terminal-init-bobcat))

(setq c-default-style '((java-mode . "gnu")))

(setq load-path (cons "/usr/local/src/ruby-1.8.7-p352/misc" load-path))
(autoload 'rubydb "rubydb3x" "" t)

(setq load-path (cons "/usr/local/src/clojure-mode" load-path))
(require 'clojure-mode)
;(require 'paredit)
;(add-hook 'clojure-mode-hook '(lambda () (paredit-mode 1)))
;(add-hook 'clojure-mode-hook '(lambda () (gtags-mode 1)))

(setq load-path (cons "/usr/local/src/scala-tool-support-2.10.0/scala-emacs-mode" load-path))
(require 'scala-mode-auto)

(setq load-path (cons "/usr/local/lib/erlang/lib/tools-2.6.8/emacs" load-path))
(setq erlang-root-dir "/usr/local/lib/erlang")
(require 'erlang-start)


(setq load-path (cons "/usr/local/share/gtags" load-path))
(setq gtags-suggested-key-mapping t)
(setq gtags-path-style 'relative)
(when (locate-library "gtags") (require 'gtags))
(add-hook 'c-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'c++-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'java-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'ruby-mode-hook '(lambda () (gtags-mode 1)))
