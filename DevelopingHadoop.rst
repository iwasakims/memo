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

- 私家版スタイルガイド by Steve Loughran
  https://github.com/steveloughran/formality/blob/master/styleguide/styleguide.md

- Apacheプロジェクトの開発者向けMSDNライセンス
  https://svn.apache.org/repos/private/committers/donated-licenses/msdn-license-grants.txt

- Apacheコミュニティについて
  https://community.apache.org/

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


deprecation warningsの確認
--------------------------

::

  $ mvn clean compile -Dmaven.compiler.showDeprecation=true


test
----

libhdfsなどのnativeモジュールのテストだけ実行したい場合には、 
``-Dtest`` の値にJavaのテストクラス名にマッチしない文字列を指定する。
もっとちゃんとしたやり方があるかもしれない。::

  $ mvn test -Pnative -Dtest=hoge

テスト連打::

   for i in `seq 100` ; do echo $i && mvn test -Dtest=TestGangliaMetrics || break  ; done

テストを複数プロセスで並列実行。これでポートやファイルについてのraceによる問題を再現できる場合がある。::

  $ mvn test -Pparallel-tests

失敗するテストがあっても、全部流す。::

  $ mvn test -Dmaven.test.failure.ignore=true

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

環境やバージョンの違いに起因して??? ``gpg --verify`` の出力の改行位置は一定しない雰囲気。
ワンライナーを利用して適当に合わせる。::

  $ cat hadoop-2.7.2-RC2-src.tar.gz.mds | perl -00pe 's/\n[ ]+/ /g' - > 1.mds
  $ gpg --print-mds hadoop-2.7.2-RC2-src.tar.gz | perl -00pe 's/\n[ ]+/ /g' - > 2.mds
  $ diff 1.mds 2.mds


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


開発環境
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


diff
----

side by sideで差分を表示::

  $ git difftool -y -x "diff -y -W 240" | less

EPELからcolordiffをインストールして使うと、より見やすい。::

  $ git difftool -y -x "colordiff -y -W 240" | less -R


jdb
---

どうみてもEclipseやIntelliJを使った方が便利だが、CUIだけの環境で調べるために。
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
    
    $ ansible master1 -i hosts -u iwasakims -a '/home/iwasakims/hadoop-2.6.2/bin/yarn jar /home/iwasakims/hadoop-2.6.2/share/hadoop/mapreduce/hadoop-mapreduce-examples-2.6.2.jar pi 9 1000000'
    
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

  - 直接JobConfを使っていないクラスでも、
    ReflectionUtils#setConf(から呼ばれるReflectionUtils#setJobConf)によって、
    上記のコードが呼ばれてしまうことになる。
    UserToGroupsMappingをロードする家庭でReflectionUtilsが使われるので、
    広範囲に影響する::

	at org.apache.hadoop.conf.Configuration.addDefaultResource(Configuration.java:752)
	at org.apache.hadoop.mapreduce.util.ConfigUtil.loadResources(ConfigUtil.java:43)
	at org.apache.hadoop.mapred.JobConf.<clinit>(JobConf.java:124)
	at java.lang.Class.forName0(Native Method)
	at java.lang.Class.forName(Class.java:278)
	at org.apache.hadoop.conf.Configuration.getClassByNameOrNull(Configuration.java:2200)
	at org.apache.hadoop.util.ReflectionUtils.setJobConf(ReflectionUtils.java:95)
	at org.apache.hadoop.util.ReflectionUtils.setConf(ReflectionUtils.java:78)
	at org.apache.hadoop.util.ReflectionUtils.newInstance(ReflectionUtils.java:136)
	at org.apache.hadoop.security.Groups.<init>(Groups.java:81)
	at org.apache.hadoop.security.Groups.<init>(Groups.java:76)
	at org.apache.hadoop.security.Groups.getUserToGroupsMappingService(Groups.java:318)
	at org.apache.hadoop.security.UserGroupInformation.initialize(UserGroupInformation.java:298)
	at org.apache.hadoop.security.UserGroupInformation.setConfiguration(UserGroupInformation.java:326)
	at org.apache.hadoop.hdfs.server.datanode.DataNode.instantiateDataNode(DataNode.java:2460)
	at org.apache.hadoop.hdfs.server.datanode.DataNode.createDataNode(DataNode.java:2510)
	at org.apache.hadoop.hdfs.server.datanode.DataNode.secureMain(DataNode.java:2690)
	at org.apache.hadoop.hdfs.server.datanode.DataNode.main(DataNode.java:2714)

- 再帰的にset -xが有効になるようにして、hoge.shをデバッグする。::

    $ sudo /bin/sh -x -c 'export SHELLOPTS && hoge.sh'



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
======

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

テスト用のspanをロード::

  htraceTool load '{"a":"b9f2a1e07b6e4f16b0c2b27303b20e79",
    "b":1424736225037,"e":1424736225901,
    "d":"ClientNamenodeProtocol#getFileInfo",
    "r":"FsShell",
    "p":["3afebdc0a13f4feb811cc5c0e42d30b1"]}'

htracd用設定::

  <property>
    <name>hadoop.htrace.span.receiver.classes</name>
    <value>org.apache.htrace.impl.HTracedSpanReceiver</value>
  </property>
  <property>
    <name>hadoop.htrace.htraced.receiver.address</name>
    <value>centos7:9075</value>
  </property>

FsShellからtracing::

  hdfs dfs -Dfs.shell.htrace.sampler.classes=AlwaysSampler -put test.dat /tmp/


htrace-hbase
------------

HBaseSpanReceiverを利用するためには、以下のjarも必要。
(htrace-core-3.1.0は、hbase-clientが使う。
hbase-clientとしてのtracing設定がoffだとしても、
htrace関連クラスのロードは実行されるので、
無いとjava.lang.NoClassDefFoundError。)

- hbase-annotation
- hbase-client
- hbase-common
- hbase-protocol
- htrace-core-3.1.0


Bigtop
======

tarballからhadoopのrpmをビルドしてsmoke-testを流してみる
--------------------------------------------------------

bigtopのソースツリーをダウンロードする。::

  $ git clone https://github.com/apache/bigtop
  $ cd bigtop 


bigtop.bomを修正し、source tarballのdownload URLを差し替える。::

  $ git diff .
  diff --git a/bigtop.bom b/bigtop.bom
  index ff6d4e1..d4ce521 100644
  --- a/bigtop.bom
  +++ b/bigtop.bom
  @@ -144,12 +144,12 @@ bigtop {
       'hadoop' {
         name    = 'hadoop'
         relNotes = 'Apache Hadoop'
  -      version { base = '2.7.3'; pkg = base; release = 1 }
  +      version { base = '2.7.4'; pkg = base; release = 1 }
         tarball { destination = "${name}-${version.base}.tar.gz"
  -                source      = "${name}-${version.base}-src.tar.gz" }
  +                source      = "${name}-${version.base}-RC0-src.tar.gz" }
         url     { download_path = "/$name/common/$name-${version.base}"
  -                site = "${apache.APACHE_MIRROR}/${download_path}"
  -                archive = "${apache.APACHE_ARCHIVE}/${download_path}" }
  +                site = "http://home.apache.org/~shv/hadoop-2.7.4-RC0/"
  +                archive = "" }
       }
       'ignite-hadoop' {
         name    = 'ignite-hadoop'

必要なrpmをビルドする。::

  $ gradle bigtop-groovy-rpm
  $ gradle bigtop-groovy-rpm
  $ gradle bigtop-jsvc-rpm
  $ gradle bigtop-tomcat-rpm
  $ gradle bigtop-utils-rpm
  $ gradle hadoop-rpm

ビルドしたrpmでyum repositoryを作る。(./outputにそのままリポジトリが作成される。)::

  $ gradle yum

Dockerを使ってクラスタをデプロイする。
config.yamlを修正し、上記で作成したyumリポジトリを使ってパッケージインストールを行う設定に変更する。::

  $ cd provisioner/docker
  $ vi config.yaml
  $ git diff .
  diff --git a/provisioner/docker/config_centos-7.yaml b/provisioner/docker/config_centos-7.yaml
  index 6cdd7cf..342f860 100644
  --- a/provisioner/docker/config_centos-7.yaml
  +++ b/provisioner/docker/config_centos-7.yaml
  @@ -20,5 +20,5 @@ docker:
   repo: "http://bigtop-repos.s3.amazonaws.com/releases/1.2.0/centos/7/x86_64"
   distro: centos
   components: [hdfs, yarn, mapreduce]
  -enable_local_repo: false
  +enable_local_repo: true
   smoke_test_components: [hdfs, yarn, mapreduce]

以下の例では3ノードのクラスタがデプロイされる。::
  
  $ ./docker-hadoop.sh --create 3
  
  $ ./docker-hadoop.sh --exec 1 rpm -q hadoop
  WARNING: The DOCKER_IMAGE variable is not set. Defaulting to a blank string.
  WARNING: The MEM_LIMIT variable is not set. Defaulting to a blank string.
  hadoop-2.7.4-1.el7.centos.x86_64

smoke testを実行する。::

  ./docker-hadoop.sh --smoke-tests



testing security on single node (branch-2)
==========================================

minimal settings to make kms work
---------------------------------

create keystore file and password file.::

  $ mkdir /home/centos/keystores
  $ keytool -keystore /home/centos/keystores/kms.keystore -genkey -alias kms -keyalg RSA
  $ echo password >> $HADOOP_HOME/share/hadoop/kms/tomcat/lib/kms.keystore.password
  $ chmod 600 $HADOOP_HOME/share/hadoop/kms/tomcat/lib/kms.keystore.password

edit kms-site.xml.::

  <property>
    <name>hadoop.kms.key.provider.uri</name>
    <value>jceks://file@/home/centos/keystores/kms.keystore</value>
    <description>
      URI of the backing KeyProvider for the KMS.
    </description>
  </property>

  <property>
    <name>hadoop.security.keystore.java-keystore-provider.password-file</name>
    <value>kms.keystore.password</value>
    <description>
      If using the JavaKeyStoreProvider, the file name for the keystore password.
    </description>
  </property>


minimal settings to enable security auth on CentOS7
---------------------------------------------------

install and start krb5-server::

  sudo yum install krb5-server krb5-libs krb5-workstation
  sudo vi /etc/krb5.conf
  sudo vi /var/kerberos/krb5kdc/kdc.conf
  sudo kdb5_util create -s
  sudo kadmin.local -q "addprinc centos/admin"
  sudo systemctl start krb5kdc.service
  sudo systemctl start kadmin.service
  
The default_ccache_name in /etc/krb5.conf should the default value otherwise hadoop client library can not find cached credential.::

  # default_ccache_name = KEYRING:persistent:%{uid}

creating keytab file for services::

  $ mkdir /home/centos/keytab

adding principal and dump keytab file by kadmin::

  addprinc -randkey centos/localhost@EXAMPLE.COM
  ktadd -k /home/centos/keytab/centos.keytab centos/localhost@EXAMPLE.COM

edit core-site.xml::

  <property>
    <name>hadoop.security.authentication</name>
    <value>kerberos</value>
  </property>
  <property>
    <name>hadoop.security.auth_to_local</name>
    <value>
      RULE:[2:$1](centos)s/^.*$/centos/
      DEFAULT
    </value>
  </property>

edit hdfs-site.xml::

  <property>
    <name>dfs.block.access.token.enable</name>
    <value>true</value>
  </property>
  <property>
    <name>dfs.namenode.keytab.file</name>
    <value>/home/centos/keytab/centos.keytab</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.principal</name>
    <value>centos/localhost@EXAMPLE.COM</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.internal.spnego.principal</name>
    <value>centos/localhost@EXAMPLE.COM</value>
  </property>
  <property>
    <name>dfs.data.transfer.protection</name>
    <value>authentication</value>
  </property>
  <property>
    <name>dfs.datanode.keytab.file</name>
    <value>/home/centos/keytab/centos.keytab</value>
  </property>
  <property>
    <name>dfs.datanode.kerberos.principal</name>
    <value>centos/localhost@EXAMPLE.COM</value>
  </property>
  <property>
    <name>dfs.http.policy</name>
    <value>HTTPS_ONLY</value>
  </property>
  <property>
    <name>dfs.web.authentication.kerberos.keytab</name>
    <value>/home/centos/keytab/centos.keytab</value>
  </property>
  <property>
    <name>dfs.web.authentication.kerberos.principal</name>
    <value>centos/localdomain@EXAMPLE.COM</value>
  </property>

edit yarn-site.xml::

  <property>
    <name>yarn.resourcemanager.principal</name>
    <value>centos/localhost@EXAMPLE.COM</value>
  </property>
  <property>
    <name>yarn.resourcemanager.keytab</name>
    <value>/home/centos/keytab/centos.keytab</value>
  </property>
  <property>
    <name>yarn.nodemanager.principal</name>
    <value>centos/localhost@EXAMPLE.COM</value>
  </property>
  <property>
    <name>yarn.nodemanager.keytab</name>
    <value>/home/centos/keytab/centos.keytab</value>
  </property>
  <property>
    <name>yarn.nodemanager.container-executor.class</name>
    <value>org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor</value>
  </property>
  <property>
    <name>yarn.nodemanager.linux-container-executor.group</name>
    <value>centos</value>
  </property>
  <property>
    <name>yarn.nodemanager.linux-container-executor.path</name>
    <value>/path/to/container-executor</value>
  </property>

creating keystore for ssl::

  $ mkdir /home/centos/keystores
  $ keytool -keystore /home/centos/keystores/http.keystore -genkey -alias http -keyalg RSA

edit ssl-site.xml::

  <property>
    <name>ssl.server.keystore.location</name>
    <value>/home/centos/http.keystore</value>
  </property>
  <property>
    <name>ssl.server.keystore.password</name>
    <value>password</value>
  </property>
  <property>
    <name>ssl.server.keystore.keypassword</name>
    <value>password</value>
  </property>
