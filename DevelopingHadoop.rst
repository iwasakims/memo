.. contents::


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


installing protobuf 2.5.0 on aarm64
-----------------------------------

::

  $ git clone https://github.com/protocolbuffers/protobuf
  $ cd protobuf
  $ git checkout v2.5.0
  $ git cherry-pick -x f0b6a5cfeb5f6347c34975446bda08e0c20c9902
  $ git cherry-pick -x 2ca19bd8066821a56f193e7fca47139b25c617ad
  $ autoreconf -i
  $ ./configure --prefix=/usr/local
  $ make
  $ sudo make install
  $ sudo ldconfig


ビルドオプション
----------------

hadoop-distから実行できるようにpackage::
  
  mvn package -Pdist -Pnative -DskipTests -DskipITs

dist環境は ``mvn clean`` したら消えてしまうので、
とりあえず適当な場所に移動して利用するとよい。::

  mv ~/srcs/hadoop-common/hadoop-dist/target/hadoop-3.0.0-SNAPSHOT ~/dist/

hadoopのsiteドキュメントのビルド。各サブプロジェクトのディレクトリ内でも同様。::

  mvn site site:stage -DstagingDirectory=/var/www/html/hadoop-site

branch-2のdistビルドにはJDK 7を使う必要があるが、
Maven Centralが?TLS 1.0, 1.1をサポートしなくなったことに起因して、
システムプロパティでTLS 1.2を明示的に指定する。
compileはJDK 8でも通るが、Javadoc warningsに起因してdistビルドは失敗する。::

  mvn clean package -Dhttps.protocols=TLSv1.2 -DskipTests -DskipShade -Pdist -Pnative

HBaseビルド時のHadoopのバージョン指定方法。::

  mvn package -Phadoop-2.0 -Dhadoop-two.version=2.5.0-SNAPSHOT -DskipTests

HBase Reference Manualのビルド。事前に一度siteをビルドして、Javadocを生成する必要がある。::

  mvn site
  mvn docbkx:generate-html

Maven CentralがTLS 1.0, 1.1を許容しなくなったため、Java 7でのビルド実行時には、https.protocolsの指定が必要になった。::

  mvn -Dhttps.protocols=TLSv1.2 install


サブツリーでビルド
------------------

サブプロジェクトには
hadoop-main -> hadoop-project -> hadoop-common
のような親子関係があるため、サブツリーにcdしてビルドを実行するには、
一度ソースツリーのトップでhadoop-mainやhadoop-projectをinstallしておく必要がある。::

  mvn install -pl :hadoop-main -pl :hadoop-project -DskipTests


checkstyle
----------

``target/test/checkstyle-errors.xml`` に結果が出力されるが、
``-Dcheckstyle.consoleOutput=true`` を付けるとコンソールにもテキストで出力される。
XMLと比較して見やすいかというとそれほどでもない。::

  mvn compile checkstyle:checkstyle -Dcheckstyle.consoleOutput=true


findbugs
--------

target/findbugsXml.xmlに結果が出力される。
普通の人間に読むことは難しいため、convertXmlToTextコマンドを利用するとよい。::

  $ mvn compile findbugs:findbugs
  $ /opt/findbugs-3.0.0/bin/convertXmlToText -longBugCodes target/findbugsXml.xml


deprecation warnings
--------------------

::

  $ mvn clean compile -Dmaven.compiler.showDeprecation=true


test
----

特定のテストクラスを実行したい場合は、testプロパティの値としてクラス名を指定する。
テストクラスが含まれているプロジェクトのディレクトリに移動した方が、時間節約になる。::

  $ cd hadoop-common-project/hadoop-common/
  $ mvn test -Dtest=TestConfiguration

`-Dtest=クラス名#メソッド名` という指定で、特定のテストケースだけを実行することもできる。::
  
  $ mvn test -Dtest=TestConfiguration#testVariableSubstitution

`Parameterized tests <https://github.com/junit-team/junit4/wiki/parameterized-tests>`_ の場合、
メソッド名ずばりではマッチしないが、後ろにアスタリスクをつけるとマッチする。
コマンドラインからパラメータを指定することができるのかは不明。::

  $ mvn test '-Dtest=TestWebHdfsTimeouts#testConnectTimeout*'


テストコード中で出力されるログは、
target/surefire-reportsディレクトリ下のファイルに出力される。::

  $ less target/surefire-reports/org.apache.hadoop.conf.TestConfiguration-output.txt


テストを複数プロセスで並列実行。これでポートやファイルについてのraceによる問題を再現できる場合がある。::

  $ mvn test -Pparallel-tests

失敗するテストがあっても、全部流す。::

  $ mvn test -Dmaven.test.failure.ignore=true

flaky testでエラーを再現するためにテストを繰り返し実行する場合の例。::

  $ for i in `seq 100` ; do echo $i && mvn test -Dtest=TestGangliaMetrics || break  ; done


cmakeでnativeモジュールのテストを実行したい場合には、 
``-Dtest`` の値に ``allNative`` を指定する。::

  $ mvn test -Pnative -Dtest=allNative


filesystem contract test
------------------------

https://hadoop.apache.org/docs/r3.1.0/hadoop-project-dist/hadoop-common/filesystem/testing.html

Filesystem contract testが実行されるかどうかは、
confでfs.contract.test.fs.%sが設定されているかどうかによる。
contract test用の設定は
src/test/resources/contract-test-options.xml に書けばロードされるが、
このファイルの存在自体は必須ではない。

逆に、認証が必要なhadoop-awsやhadoop-openstackのtestは、
src/test/resources/auth-keys.xmlというファイルが存在しないと実行されない。
この制御はpom.xmlで定義でされている。::

  <profiles>
    <profile>
      <id>tests-off</id>
      <activation>
        <file>
          <missing>src/test/resources/auth-keys.xml</missing>
        </file>
      </activation>
      <properties>
        <maven.test.skip>true</maven.test.skip>
      </properties>
    </profile>
　　...

auth-keys.xmlはsrc/test/recources/core-site.xmlの中でincludeされている。
これをロードするコードがソース中にあるわけではない。

また、hadoop-azureモジュールはauth-keys.xmlではなくazure-auth-keys.xmlというファイル名を想定している。
pom.xmlでの制御もしていない。このあたりの一貫性はいまいち。


リリース関連
============

RCのチェック
------------

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


RCをつくる
----------

https://cwiki.apache.org/confluence/display/HADOOP2/HowToRelease
の手順の補足

Nexusが使っているkeyserverにpublic keyを送る。::

  gpg --keyserver pool.sks-keyservers.net --send-key E206BB0D
  gpg --keyserver keyserver.ubuntu.com --send-key E206BB0D

https://infra.apache.org/release-signing.html#openpgp-ascii-detach-sig
の手順でOpenPGP compatible ASCII armored detached signatureを作る。
それに加えて、
https://infra.apache.org/release-signing.html#sha-checksum
の手順でsha512のチェックサムファイルを作る。::

  cd target/artifacts
  for f in `find . -type f` ; do gpg --armor --output $f.asc --detach-sig $f && gpg --print-md SHA512 $f > $f.sha512 ; done



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

.goのタグを作りたい場合は、 ``~/.ctags`` に以下の内容を追加する。::

  --langdef=Go
  --langmap=Go:.go
  --regex-Go=/func([ \t]+\([^)]+\))?[ \t]+([a-zA-Z0-9_]+)/\2/d,func/
  --regex-Go=/var[ \t]+([a-zA-Z_][a-zA-Z0-9_]+)/\1/d,var/
  --regex-Go=/type[ \t]+([a-zA-Z_][a-zA-Z0-9_]+)/\1/d,type/

.scalaのタグ作りには、 ``~/.ctags`` に以下の内容を追加する。::

  --langdef=scala
  --langmap=scala:.scala
  --regex-scala=/^[ \t]*((abstract|final|sealed|implicit|lazy)[ \t]*)*(private|protected)?[ \t]*class[ \t]+([a-zA-Z0-9_]+)/\4/c,classes/
  --regex-scala=/^[ \t]*((abstract|final|sealed|implicit|lazy)[ \t]*)*(private|protected)?[ \t]*object[ \t]+([a-zA-Z0-9_]+)/\4/c,objects/
  --regex-scala=/^[ \t]*((abstract|final|sealed|implicit|lazy)[ \t]*)*(private|protected)?[ \t]*case class[ \t]+([a-zA-Z0-9_]+)/\4/c,case classes/
  --regex-scala=/^[ \t]*((abstract|final|sealed|implicit|lazy)[ \t]*)*(private|protected)?[ \t]*case object[ \t]+([a-zA-Z0-9_]+)/\4/c,case objects/
  --regex-scala=/^[ \t]*((abstract|final|sealed|implicit|lazy)[ \t]*)*(private|protected)?[ \t]*trait[ \t]+([a-zA-Z0-9_]+)/\4/t,traits/
  --regex-scala=/^[ \t]*type[ \t]+([a-zA-Z0-9_]+)/\1/T,types/
  --regex-scala=/^[ \t]*((abstract|final|sealed|implicit|lazy)[ \t]*)*def[ \t]+([a-zA-Z0-9_]+)/\3/m,methods/
  --regex-scala=/^[ \t]*((abstract|final|sealed|implicit|lazy)[ \t]*)*val[ \t]+([a-zA-Z0-9_]+)/\3/l,constants/
  --regex-scala=/^[ \t]*((abstract|final|sealed|implicit|lazy)[ \t]*)*var[ \t]+([a-zA-Z0-9_]+)/\3/l,variables/
  --regex-scala=/^[ \t]*package[ \t]+([a-zA-Z0-9_.]+)/\1/p,packages/


diff
----

side by sideで差分を表示。--no-promptだとファイルの境目が分かりにくいので、yesで。::

  $ yes | git difftool -x "diff -y -W 240" | less

EPELからcolordiffをインストールして使うと、より見やすい。::

  $ yes | git difftool -x "colordiff -y -W 240" | less -R

上記をより簡単に使うには、PATHの通った場所に、git-sidediffという名前のスクリプトを作っておく。
これを ``git sidediff`` というコマンドで呼び出すことができる。::
  
  $ cat > ~/bin/git-sidediff <<EOF
  yes | git difftool -x 'colordiff -y -W250' "\$@"| less -R
  EOF
  
  $ chmod +x ~/bin/git-sidediff
  $ git sidediff arg1 arg2 ...

``git show`` のように特定のcommitのdiffをside by sideで見るためのスクリプトは、以下のような感じ。::
  
  $ cat ~/bin/git-showtool
  yes | git difftool -x 'colordiff -y -W250' $1~1 $1 | less -R

  
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


debugging by spark-shell
========================

試行錯誤用の便利な対話環境として、bin-without-hadoopなSparkのtarballをダウンロードし、spark-shellを利用する。::

    $ SPARK_DIST_CLASSPATH=$(../hadoop-3.3.0-SNAPSHOT/bin/hadoop classpath) bin/spark-shell

デバッグ用のオプションや、libhadoop.soをロードするためのオプションを追加する例。::

    $ SPARK_SUBMIT_OPTS='-agentlib:jdwp=transport=dt_socket,address=0.0.0.0:8765,server=y,suspend=y -Djava.library.path=/home/iwasakims/dist/hadoop-2.10.1-SNAPSHOT/lib/native' \
        SPARK_DIST_CLASSPATH=$(../hadoop-2.10.1-SNAPSHOT/bin/hadoop classpath) \
        bin/spark-shell \
        --conf spark.executor.heartbeatInterval=600


debugging shell scripts
=======================

- 再帰的にset -xが有効になるようにして、hoge.shをデバッグする。::

    $ sudo /bin/sh -x -c 'export SHELLOPTS && hoge.sh'


confdir
=======

- 開発中にコマンドを実行するときは ``--config path/to/confdir`` オプションで、
  confディレクトリを指定すると便利。::

    bin/hdfs --config ~/etc/hadoop.rmha dfs -ls /

- ただしstart-dfs.shやstart-yarn.shは ``--config`` オプションを受け付けないので、
  環境変数で指定。::

    HADOOP_CONF_DIR=~/etc/hadoop.rmha sbin/start-dfs.sh 


testing httpfs
==============

http
----

::

  $ curl -i -c cookiejar -X PUT 'http://172.32.1.195:14000/webhdfs/v1/tmp/README.txt?user.name=iwasakims&op=CREATE&replication=1'
  $ curl -i -X PUT -b cookiejar \
      --header "Content-Type:application/octet-stream" \
      --data-binary @README.txt \
      'http://172.32.1.195:14000/webhdfs/v1/tmp/README.txt?op=CREATE&replication=1&user.name=iwasakims&data=true'
  $ curl -i -L -X GET 'http://172.32.1.195:14000/webhdfs/v1/tmp/README.txt?user.name=iwasakims&op=OPEN'
  

https
-----

::

  $ keytool -importkeystore -srckeystore ~/.keystore -destkeystore ~/.keystore.p12 -deststoretype pkcs12
  $ pk12util -i ~/.keystore.p12 -d ~/nss
  $ certutil -L -d ~/nss

  $ SSL_DIR=~/nss curl -k --cert tomcat:hogemoge -i -c cookiejar -X PUT 'https://172.32.1.195:14000/webhdfs/v1/tmp/README.txt?user.name=iwasakims&op=CREATE&replication=1'
  $ SSL_DIR=~/nss curl -k --cert tomcat:hogemoge -i -X PUT --header "Content-Type:application/octet-stream" --data-binary @README.txt -b cookiejar 'https://172.32.1.195:14000/webhdfs/v1/tmp/README.txt?op=CREATE&replication=1&user.name=iwasakims&data=true'
  $ SSL_DIR=~/nss curl -k --cert tomcat:hogemoge -i -L -X GET 'https://172.32.1.195:14000/webhdfs/v1/tmp/README.txt?user.name=iwasakims&op=OPEN'


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

The line setting renew_lifetime in /etc/krb5.conf should be commented out due to https://bugs.openjdk.java.net/browse/JDK-8131051.

  #  renew_lifetime = 7d

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
    <value>/usr/local/bin/container-executor</value>
  </property>

put container-executor binary and conf.::

  $ sudo cp container-executor /usr/local/bin/
  $ sudo chown root:centos /usr/local/bin/container-executor
  $ sudo chmod 6050 /usr/local/bin/container-executor
  $ sudo mkdir /usr/local/etc/hadoop
  $ sudo vim /usr/local/etc/hadoop/container-executor.cfg
  
  $ cat /usr/local/etc/hadoop/container-executor.cfg
  yarn.nodemanager.linux-container-executor.group=centos
  banned.users=hdfs,yarn,mapred
  allowed.system.users=foo,bar
  min.user.id=500
  
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
