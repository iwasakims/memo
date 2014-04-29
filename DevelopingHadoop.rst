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


jdbによるJavaプログラムのデバッグ
---------------------------------

どうみてもEclipseの方が便利だが、とりあえずCUIだけの環境用で調べる用に。
Emacsと組み合わせると意外といける。

- デバッギのJVMオプション。::

    -agentlib:jdwp=transport=dt_socket,address=localhost:8765,server=y,suspend=y

- jdbのコマンドラインを入力。
  ``-sourcepath`` オプションと値の間に空白を入れてはいけない。::

    $ jdb -attach localhost:8765 \
          -sourcepath~/srcs/hadoop-common/hadoop-common-project/hadoop-common/src/main/java:~/srcs/hadoop-common/hadoop-hdfs-project/hadoop-hdfs/src/main/java

- Emacsを使う場合、 ``M-x jdb`` を押した後、上記のコマンドラインを入力。


ビルドオプション
----------------

hadoop-distから実行できるようにpackage::

  mvn package -Pdist -Pnative -DskipTests -DskipITs

siteドキュメントのビルド。各サブプロジェクトのディレクトリ内でも同様。::

  mvn site site:stage -DstagingDirectory=/var/www/html/hadoop-site

HBaseビルド時のHadoopのバージョン指定方法。::

  mvn package -Phadoop-2.0 -Dhadoop-two.version=2.5.0-SNAPSHOT -DskipTests


たまに使う
----------

- dist環境のjarを主導で置き換え。::

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

