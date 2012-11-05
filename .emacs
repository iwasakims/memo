(setq load-path (cons "~" load-path))
(global-font-lock-mode t)
(transient-mark-mode t)

(load "term/bobcat")
(when (fboundp 'terminal-init-bobcat)
  (terminal-init-bobcat))

(setq c-default-style '((java-mode . "gnu")))
(setq-default indent-tabs-mode nil)

;(setq load-path (cons "/usr/local/src/ruby-1.8.7-p352/misc" load-path))
;(autoload 'rubydb "rubydb3x" "" t)

;(require 'clojure-mode)
;(require 'paredit)
;(add-hook 'clojure-mode-hook '(lambda () (paredit-mode 1)))
;(add-hook 'clojure-mode-hook '(lambda () (gtags-mode 1)))

(setq load-path (cons "/usr/local/share/gtags" load-path))
(setq gtags-suggested-key-mapping t)
(when (locate-library "gtags") (require 'gtags))
(add-hook 'c-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'c++-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'java-mode-hook '(lambda () (gtags-mode 1)))
(add-hook 'ruby-mode-hook '(lambda () (gtags-mode 1)))
