gtagsでClojureのコードのタグ付け
--------------------------------

Clojureで実装されたプロダクトは、
ClojureだけではなくJavaのコードとセットになっていることが多いので、
両方同時に見れるよう、gtagsを使うのがよさそう。

まず、Exuberant Ctagsをインストールする。::

  $ tar zxf ctags-5.8.tar.gz 
  $ cd ctags-5.8
  $ ./configure --prefix=/usr/local
  $ make
  $ sudo make install

.. _`GNU GLOBAL`: http://www.gnu.org/software/global/

`GNU GLOBAL`_ をインストールする。::

  $ curl -l -o global-6.2.4.tar.gz http://tamacom.com/global/global-6.2.4.tar.gz 
  $ tar zxf global-6.2.4.tar.gz 
  $ cd global-6.2.4
  $ ./configure --prefix=/usr/local
  $ make
  $ sudo make install

ホームディレクトリに.globalrcを作成し、.cljを処理対象にするように修正する。::

  $ cp /usr/local/share/gtags/gtags.conf ~/.globalrc
  $ vim ~/.globalrc 
  $ diff /usr/local/share/gtags/gtags.conf ~/.globalrc
  77c77
  < 	:langmap=Lisp\:.cl.clisp.el.l.lisp.lsp:\
  ---
  > 	:langmap=Lisp\:.cl.clisp.el.l.lisp.lsp.clj:\

.emacsに、gtags-mode用の設定を追加する。::

  (setq exec-path (cons "/usr/local/bin" exec-path))
  (setq load-path (cons "/usr/local/share/gtags" load-path))
  (setq gtags-suggested-key-mapping t)
  (when (locate-library "gtags") (require 'gtags))
  (add-hook 'c-mode-hook '(lambda () (gtags-mode 1)))
  (add-hook 'java-mode-hook '(lambda () (gtags-mode 1)))
  (add-hook 'clojure-mode-hook '(lambda () (gtags-mode 1)))

タグテーブル作成は、ソースツリーの最上位に移動して、以下の要領で実行。::

  $ cd hoge/src
  $ gtags --gtagslabel=exuberant-ctags

これでgtags-modeのいつもの要領で、.cljと.javaの両方に対して操作ができるようになった。::

  TOPOLOGY         1396 jvm/backtype/storm/generated/Nimbus.java TOPOLOGY((short)4, "topology");
  topology          171 clj/backtype/storm/clojure.clj (defalias topology thrift/mk-topology)
  topology          531 jvm/backtype/storm/generated/Nimbus.java private StormTopology topology;
  topology         1389 jvm/backtype/storm/generated/Nimbus.java private StormTopology topology; // required
  topology           14 jvm/backtype/storm/scheduler/TopologyDetails.java StormTopology topology;

あと、現状の設定だと、gtags-modeでタグを探すときにカーソルを関数の上もっていっても、
Lisp系ではよくみられるらしいハイフンが入ったシンボル名を関数名と見なしてくれないのを直したいところ。
