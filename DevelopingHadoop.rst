リンク
======

- Mailing listの過去ログなどを横断的に検索できる便利サイト。
  http://www.search-hadoop.com/

- JIRAが落ちている?というときにみてみるとよい。
  http://monitoring.apache.org/status/

- Apacheプロジェクトでのvotingについて
  http://www.apache.org/foundation/voting.

- JIRAに添付されているpatchを表示するChrome extention
  https://chrome.google.com/webstore/detail/git-patch-viewer/hkoggakcdopbgnaeeidcmopfekipkleg

- Gitの設定について
  https://git-wip-us.apache.org/

- Shellスクリプトのルール(hadoop3)
  http://wiki.apache.org/hadoop/UnixShellScriptProgrammingGuide

- Apacheプロジェクトの開発者向けMSDNライセンス
  https://svn.apache.org/repos/private/committers/donated-licenses/msdn-license-grants.txt


ビルド
======

ビルド環境
----------

RedHat系の開発パッケージのインストール。::

  sudo yum install git gcc gcc-c++ java-1.7.0-openjdk-devel cmake zlib-devel openssl-devel

protobuf、maven、findbugsは別途手動でインストール。::

  export JAVA_HOME=/usr/lib/jvm/java-1.7.0-openjdk.x86_64
  export PATH=$JAVA_HOME/bin:$PATH
  
  export MVN_HOME=/opt/maven
  export PATH=$PATH:$MVN_HOME/bin
  
  export FINDBUGS_HOME=/opt/findbugs
  export PATH=$PATH:$FINDBUGS_HOME/bin


ビルドオプション
----------------

hadoop-distから実行できるようにpackage::
  
  mvn package -Pdist -Pnative -DskipTests -DskipITs

dist環境は ``mvn clean`` したら消えてしまうので、
とりあえず適当な場所に移動して利用するとよい。::

  mv ~/srcs/hadoop-common/hadoop-dist/target/hadoop-3.0.0-SNAPSHOT ~/dist/

hadoopのsiteドキュメントのビルド。各サブプロジェクトのディレクトリ内でも同様。::

  mvn site site:stage -DstagingDirectory=/var/www/html/hadoop-site

HBaseビルド時のHadoopのバージョン指定方法。::

  mvn package -Phadoop-2.0 -Dhadoop-two.version=2.5.0-SNAPSHOT -DskipTests

HBase Reference Manualのビルド。事前に一度siteをビルドして、Javadocを生成する必要がある。::

  mvn site
  mvn docbkx:generate-html


checkstyleの実行
----------------

``target/test/checkstyle-errors.xml`` に結果が出力されるが、
``-Dcheckstyle.consoleOutput=true`` を付けるとコンソールにもテキストで出力される。
XMLと比較して見やすいかというとそれほどでもない。::

  mvn compile checkstyle:checkstyle -Dcheckstyle.consoleOutput=true


findbugsの実行
--------------

target/findbugsXml.xmlに結果が出力される。
普通の人間に読むことは難しいため、convertXmlToTextコマンドを利用するとよい。::

  $ mvn compile findbugs:findbugs
  $ /opt/findbugs-3.0.0/bin/convertXmlToText target/findbugsXml.xml


test
----

libhdfsなどのnativeモジュールのテストだけ実行したい場合には、 
``-Dtest`` の値にJavaのテストクラス名にマッチしない文字列を指定する。
もっとちゃんとしたやり方があるかもしれない。::

  $ mvn test -Pnative -Dtest=hoge


サブツリーでビルド
------------------

サブプロジェクトには
hadoop-main -> hadoop-project -> hadoop-common
のような親子関係があるため、サブツリーにcdしてビルドを実行するには、
一度ソースツリーのトップでhadoop-mainやhadoop-projectをinstallしておく必要がある。::

  mvn install -pl :hadoop-main -pl :hadoop-project -DskipTests


リリース関連
============


signatureをチェック::

  $ gpg --verify foo.tar.gz.asc

リリースマネージャのpublic keyを取得する必要がある場合は、以下の要領。::
  
  $ gpg --keyserver pgpkeys.mit.edu --recv-key C36C5F0F

hashcodeをチェック::

  $ gpg --print-mds foo.tar.gz | diff - foo.tar.gz.mds && echo "ok."


たまに使う
==========

- dist環境のjarを手動で置き換え。::

    mvn package -DskipTests
    cp ~/srcs/hadoop-common/hadoop-common-project/hadoop-common/target/hadoop-common-3.0.0-SNAPSHOT.jar \
       ~/srcs/hadoop-common/hadoop-dist/target/hadoop-3.0.0-SNAPSHOT/share/hadoop/common/
    cp ~/srcs/hadoop-common/hadoop-hdfs-project/hadoop-hdfs/target/hadoop-hdfs-3.0.0-SNAPSHOT.jar \
       ~/srcs/hadoop-common/hadoop-dist/target/hadoop-3.0.0-SNAPSHOT/share/hadoop/hdfs/
    find ~/srcs/hadoop-common/hadoop-yarn-project -name '*SNAPSHOT.jar' \
      | xargs -I XARGS cp XARGS ~/srcs/hadoop-common/hadoop-dist/target/hadoop-3.0.0-SNAPSHOT/share/hadoop/yarn  


- ローカルリポジトリからモノを削除。::

    rm ~/.m2/repository/org/apache/hadoop/hadoop-{project,common,hdfs}/3.0.0-SNAPSHOT/*
    rm ~/.m2/repository/org/apache/hadoop/hadoop-*/3.0.0-SNAPSHOT/*

- sleepジョブの起動。::

    $ bin/mapred org.apache.hadoop.test.MapredTestDriver sleep ...


ライセンス
==========

参考
----

- ソースヘッダのライセンスの記載について:
  http://www.apache.org/legal/src-headers.html

- Apacheプロダクトとそれ以外のライセンスとの兼ね合いについて:
  http://www.apache.org/legal/3party.html


apache-rat-plugin
-----------------

多くのHadoop系プロダクトでは、
Mavenによるビルド時にapache-rat-pluginによるライセンスのチェックが入る。
.gitやprotobufで生成されるファイル、画像ファイルなど、
チェックから除外したファイルについては、
pom.xmlのpluginの設定で指定する必要がある。::

      <plugin>
        <groupId>org.apache.rat</groupId>
        <artifactId>apache-rat-plugin</artifactId>
        <configuration>
          <excludes>
            <exclude>.git/**</exclude>
            <exclude>.svn/**</exclude>
            <exclude>.idea/**</exclude>
            <exclude>**/.settings/**</exclude>
            <exclude>**/generated/**</exclude>
            <exclude>src/site/resources/images/*</exclude>
            <exclude>src/main/webapps/static/bootstrap-3.0.2/**</exclude>
          </excludes>
        </configuration>
      </plugin>


エディタ
========

pygments
--------

GNU GLOBAL 6.3.2以降とpygmetnsの組み合わせが便利。
EPELのYumリポジトリからpipをインストールし、pipでpygmentsをインストールする。::

  $ sudo yum ctags
  $ sudo yum --enablerepo=epel install python-pip
  $ sudo pip install pygments

タグファイルを作る場合は、 ``--gtagslabel`` オプションの値にpygmentsを指定。::

  $ gtags --gtagslabel=pygments

golangはpygmentsで処理されるはずなのだが、なぜかexuberant-ctagsにフォールバックしてうまくタグがつくれない。
``~/.ctags`` に以下の内容を追加すると、とりあえずctagsで.goのタグを抽出することはできた。::

  --langdef=Go
  --langmap=Go:.go
  --regex-Go=/func([ \t]+\([^)]+\))?[ \t]+([a-zA-Z0-9_]+)/\2/d,func/
  --regex-Go=/var[ \t]+([a-zA-Z_][a-zA-Z0-9_]+)/\1/d,var/
  --regex-Go=/type[ \t]+([a-zA-Z_][a-zA-Z0-9_]+)/\1/d,type/


jdbによるJavaプログラムのデバッグ
=================================

どうみてもEclipseやIntelliJと使った方が便利だが、CUIだけの環境で調べるために。
Emacsと組み合わせると意外といける。

- デバッギのJVMオプション。::

    -agentlib:jdwp=transport=dt_socket,address=localhost:8765,server=y,suspend=y

- jdbのコマンドラインを入力。
  ``-sourcepath`` オプションと値の間に空白を入れてはいけない。::

    jdb -attach localhost:8765 -sourcepath~/srcs/hadoop-common/hadoop-common-project/hadoop-common/src/main/java:~/srcs/hadoop-common/hadoop-hdfs-project/hadoop-hdfs/src/main/java

- Emacsを使う場合、 ``M-x jdb`` を押した後、上記のコマンドラインを入力。

- yarnも含めた場合。::

    jdb -attach localhost:8765 -sourcepath~/srcs/hadoop-common/hadoop-common-project/hadoop-common/src/main/java:~/srcs/hadoop-common/hadoop-hdfs-project/hadoop-hdfs/src/main/java:~/srcs/hadoop-common/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-api/src/main/java

- findコマンドでまとめて指定する試み::

    jdb -attach localhost:8765 -sourcepath .`find . -wholename '*/src/main/java' -type d -print0 | sed -e 's/\./\:\./g'`


Setup
=====

- ユーザの作成::

    ansible all -i ./hosts -u root -m user -a 'name=iwasakims'

- authorized_keysの更新::

    ansible all -i ./hosts -u root -m authorized_key -a 'user=iwasakims key="{{ lookup("file", "/home/iwasakims/.ssh/id_rsa.pub") }}"'

- インストールと実行::

    $ ls ~/files/
    hadoop-2.6.2.tar.gz zookeeper-3.4.6.tar.gz
    
    $ ansible-playbook -i hosts setup.yml
    $ ansible-playbook -i hosts format.yml
    $ ansible-playbook -i hosts start-daemons.yml
    
    $ ansible master1 -i hosts -u iwasakims -a '/home/bench/hadoop-2.6.2/bin/yarn jar /home/bench/hadoop-2.6.2/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.6.2.jar pi 9 1000000'
    
    $ ansible-playbook -i hosts stop-daemons.yml


メモ
====

シェルスクリプト
----------------

- 開発中にコマンドを実行するときは ``--config path/to/confdir`` オプションで、
  confディレクトリを指定すると便利。::

    bin/hdfs --config ~/etc/hadoop.rmha dfs -ls /

- ただしstart-dfs.shやstart-yarn.shは ``--config`` オプションを受け付けないので、
  環境変数で指定。::

    HADOOP_CONF_DIR=~/etc/hadoop.rmha sbin/start-dfs.sh 

- yarn-site.xmlやmapred-site.xmlの内容は、NameNodeやDataNodeにもロードされてしまう。
  org.apache.hadoop.util.ReflectionUtils.setConfが呼ばれると、
  JobConfが無条件にロードされることが原因。
  HADOOP-1230によると、coreがmapredにconpile時に依存しないようにするため、
  こうなっているらしい。
  (JobConf初期化時に呼ばれるConfigUtil#loadResourcesメソッドが、
  ConfigurationにstaticにYARN/MapReduceの設定ファイルを読み込む。)::
    
      public static void loadResources() {
        addDeprecatedKeys();
        Configuration.addDefaultResource("mapred-default.xml");
        Configuration.addDefaultResource("mapred-site.xml");
        Configuration.addDefaultResource("yarn-default.xml");
        Configuration.addDefaultResource("yarn-site.xml");
      }

バージョン
----------

- zookeeper-3.4.6はCLIに互換性を壊す変更が入ったので、HBaseで問題がある。
  3.4.7で修正が入る。


バイト列の操作
--------------

- Writableからbyte[]を取り出すために
  org.apache.hadoop.hbase.util.Writablesというユーティリティが用意されている。
  そこで使われているorg.apache.hadoop.io.WritableUtilsの中身をみると、
  オブジェクトを複数まとめて一つのバイト列にする場合の
  ByteArrayOutputBuffeの使い方として参考になる。

- WritableUtilsはorg.apache.hadoop.io.DataOutputBufferという独自定義のDataOutputを利用している。
  DataOutputBuffが内部で利用しているBufferはByteArrayOutputStreamの拡張で、
  byte[]をコピーせずに返せるようgetDataメソッドが追加されている。
  ただし、getDataで返ってくるバイト列は後ろの方にゴミが入っているので、
  getLengthメソッドでどこまでが正しいデータなのかを判断しなければならない。::

    private static class Buffer extends ByteArrayOutputStream {
      public byte[] getData() { return buf; }
      public int getLength() { return count; }

- KeyValueはCellというインタフェースの実装になった。
  Cellが提供するメソッドが推奨され、古いKeyValueのメソッドはdeprecatedに。


htrace
------

htracedのREST APIをcurlコマンドでたたく。::

  curl http://localhost:9095/query -G -d 'query={"pred":[],"lim":11}:'

libhtraceとlibhdfsを使ったコードのコンパイル::

  gcc -I/home/iwasakims/srcs/htrace/htrace-c/target/install/include \
      -L/home/iwasakims/srcs/htrace/htrace-c/target/install/lib \
      -I$HADOOP_HOME/include -L$HADOOP_HOME/lib/native \
  -lhtrace -lhdfs -o test_libhdfs_write test_libhdfs_write.c

実行::

  export CLASSPATH=`$HADOOP_HOME/bin/hdfs classpath --glob`
  export LD_LIBRARY_PATH=$HADOOP_HOME/lib/native:/home/iwasakims/srcs/htrace/htrace-c/target/install/lib 
  ./test_libhdfs_write /tmp/test04.txt 2048 2048

htracedの特定のテストを実行::

  cd htrace-htraced/go
  export GOPATH=/home/iwasakims/srcs/htrace/htrace-htraced/go:/home/iwasakims/srcs/htrace/htrace-htraced/go/build
  go test ./src/org/apache/htrace/htraced -run Client -v
