=====================
Clojureのデバッグ環境
=====================

Clojureの入門書を読んでいて、
サンプルコードを理解のために動かして様子をみたかったので、試してみたときのメモ。

.. _leiningen: https://github.com/technomancy/leiningen

leiningen_ はインストールしてある想定。::

  $ wget -O ~/bin/lein http://github.com/technomancy/leiningen/raw/stable/bin/lein
  $ chmod a+x ~/bin/lein
  $ lein self-install

.. _swank-clojure: https://github.com/technomancy/swank-clojure
.. _CDT: http://georgejahad.com/clojure/cdt.html

swank-clojure_　というEmacsからClojure環境を使うためのツールがあって、
それのバージョン1.4.0以降には CDT_ というデバッグ用のツールキットが同梱されているらしい。
というわけで、swank-clojureを使うためのEmacsの設定から。
swank-clojureはEmacsのバージョンが23以降じゃないと動かないようなのだが、
手元のMac OSXで使っていたEmacsは22だったので、
http://ftp.gnu.org/pub/gnu/emacs/emacs-23.4.tar.gz
をダウンロードして
http://sakito.jp/emacs/emacs23.html#ime
を参考にビルドした。

.emacsには以下の内容を記述した。
clojure-mode.elとparedit.elをダウンロードしてロードしたのと、
Emacs.appで起動した場合シェルの設定などが引き継がないので、
leinコマンドが置かれた場所をPATHに追加しないとダメだった。::

  (setenv "PATH" (concat "/Users/someone/bin:" (getenv "PATH")))
  (require 'paredit)
  (require 'clojure-mode)
  (defun turn-on-paredit () (paredit-mode 1))
  (add-hook 'clojure-mode-hook 'turn-on-paredit)

leiningenのプロジェクトディレクトリを作り、project.cljに以下のような内容を記述した。::

  (defproject test "0.0.1"
    :description "test project"
    :dependencies [[org.clojure/clojure "1.3.0"]]
    :plugins [[lein-swank "1.4.4"]])

その上で、プロジェクト内のclojureのソースコードをEmacsで開いて、
``M-x clojure-jack-in`` を実行すると、
lein経由でClojure実行環境のプロセスが起動して、REPLのバッファが開く。

REPLのバッファはおいといて、ソースコードのバッファ内でも評価ができるようになっている。
例えば、範囲選択して ``C-c C-r`` でリージョン内の評価ができる。
さらに、コード中に
``(swank.core/break)``
という式を埋め込んでおくと、そこがブレークポイントになる。::

  (defn astar [start-yx step-est cell-costs]
    (let [size (count cell-costs)]
      (loop [steps 0
             routes (vec (replicate size (vec (replicate size nil))))
             work-todo (sorted-set [0 start-yx])]
        (if (empty? work-todo)
          [(peek (peek routes)) :steps steps]
          (let [[_ yx :as work-item] (first work-todo)
                rest-work-todo (disj work-todo work-item)
                nbr-yxs (neighbors size yx)
                cheapest-nbr (min-by :cost
                                     (keep #(get-in routes %)
                                           nbr-yxs))
                newcost (path-cost (get-in cell-costs yx)
                                   cheapest-nbr)
                oldcost (:cost (get-in routes yx))]
            (swank.core/break)
            (if (and oldcost (>= newcost oldcost))
                (recur (inc steps) routes rest-work-todo)
                (recur (inc steps)
                       (assoc-in routes yx
                                 {:cost newcost
                                  :yxs (conj (:yxs cheapest-nbr []) yx)})
                       (into rest-work-todo
                             (map
                              (fn [w]
                                (let [[y x] w]
                                  [(total-cost newcost step-est size y x) w]))
                              nbr-yxs)))))))))

この状態で評価すると、
ブレークポイントに達したところで、
sldbというバッファが開く。::

  BREAK:
    [Thrown class java.lang.Exception]
  
  Restarts:
   0: [QUIT] Quit to the SLIME top level
   1: [CONTINUE] Continue from breakpoint
  
  Backtrace:
    0:       NO_SOURCE_FILE:1 user/astar
    1:       NO_SOURCE_FILE:1 user/eval2199
    2:     Compiler.java:6465 clojure.lang.Compiler.eval
    3:     Compiler.java:6431 clojure.lang.Compiler.eval
    4:          core.clj:2795 clojure.core/eval
    5:           core.clj:532 swank.core/eval782[fn]
    6:       MultiFn.java:163 clojure.lang.MultiFn.invoke
    7:           basic.clj:54 swank.commands.basic/eval-region
    8:           basic.clj:44 swank.commands.basic/eval-region
    9:           basic.clj:69 swank.commands.basic/eval964[fn]
    ...(省略)

バッファ内のバックトレースのところでリターンキーを押すと、
そこで束縛されている変数の値をみることができる。::

  BREAK:
    [Thrown class java.lang.Exception]
  
  Restarts:
   0: [QUIT] Quit to the SLIME top level
   1: [CONTINUE] Continue from breakpoint
  
  Backtrace:
    0:       NO_SOURCE_FILE:1 user/astar
        Locals:
          _ = 0
          cell-costs = [[1 1 1 1 1] [999 999 999 999 1] [1 1 1 1 1] [1 999 999 999 999] [1 1 1 1 1]]
          cheapest-nbr = nil
          nbr-yxs = ([1 0] [0 1])
          newcost = 1
          oldcost = nil
          rest-work-todo = #{}
          routes = [[nil nil nil nil nil] [nil nil nil nil nil] [nil nil nil nil nil] [nil nil nil nil nil] [nil nil nil nil nil]]
          size = 5
          start-yx = [0 0]
          step-est = 900
          steps = 0
          vec__2173 = [0 [0 0]]
          work-item = [0 [0 0]]
          work-todo = #{[0 [0 0]]}
          yx = [0 0]
    1:       NO_SOURCE_FILE:1 user/eval2199
    ...(省略)

ブレークポイントで停止している状態で、sldbバッファ内でcを押すと、continueする。

また、バックトレースの各行でvを押すと、対応するソースファイルの該当行を開いてくれる。
clojure.coreのものでも、自動的にjarファイルから取り出して表示してくれて便利そう。
