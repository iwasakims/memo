.. contents::


Tez
===

- java.util.ServiceLoaderが
  o.a.h.mapreduce.protocol.ClientProtocolProviderの実装である
  o.a.tez.mapreduce.client.YarnTezClientProtocolProviderを
  classpath上から見つけてロードする。
  mapred-site.xmlのmapreduce.jobtracker.addressの値が"yarn-tez"であれば、
  o.a.h.mapreduce.Cluster#getClientがTeZ用の
  o.a.h.mapreduce.protocol.ClientProtocl実装を返してくれる。

- 既存のMapReduceジョブをTezで動かす場合、
  ジョブをsubmitするクライアントノードで、
  hadoopのclasspathにTezのjarを追加する必要がある。

- Tezのcontainerのコマンドラインを組み立てるのは
  o.a.t.dag.util.TezRuntimeChildJVM#getVMCommand。
  メインクラスはo.a.t.runtime.task.TezChild。
  
- データの受け渡しはmapreduce_shuffleの仕組みをそのまま使うようだ。

- 並列度はVertex#createの引数で指定できる。


JVM
===

CMS
---

- gcログの "[ParNew: ... ,  %3.7f secs]" という部分は、
  GCTraceTimeというクラスのコンストラクタとデストラクタが出力する。
  コンストラクタが "[ParNew: "の部分を、デストラクタが ", %3.7f secs]"の部分を出力。
  GCTraceTimeが作られてから、
  そのスコープを抜ける(ことによってデストラクタが呼ばれる)までの、
  所要時間を表している。
  所要時間はgettimeofdayで取得したwall-clock timeに基づくもの。
  (ParNewGeneration::collectのソースを参照。)

- [CMS-concurrent-abortable-preclean: 1.910/54.082 secs]
  の1.910の部分はイベントカウンタを元に算出されるCPU時間的な値、
  54.082の部分はwall-clock time。

- CMSの場合、gc causeとしての"Full GC"は出力されない。
  Old領域を使い切って(concurrent mode failure)と出力された場合、
  内部的にアルゴリズムが切り替わっている。::
  
    // Concurrent mode failures are currently handled by
    // means of a sliding mark-compact.

- Old領域不足でFull Collectionが発生した場合にコンパクションを実行するかどうかは、
  UseCMSCompactAtFullCollectionの値(デフォルトでtrue)と、
  これまでに実効されたCMSのサイクル数が
  CMSFullGCsBeforeCompaction(デフォルト0)を超えているかどうかで判断される。

- CMSScavengeBeforeRemarkは、
  remarkの直前にminor GCを実行することで、remarkの仕事を減らす意図のもの
  デフォルトでfalse。

- promotion failedが発生したときに必要なのは、
  collectionかもしれないし、compactionかもしれない。

- ``-XX:NativeMemoryTracking=detail -XX:+UnlockDiagnosticVMOptions -XX:+PrintNMTStatistics``

- 参考

  - PLABってなに?
    http://blog.ragozin.info/2011/11/java-gc-hotspots-cms-promotion-buffers.html

  - CMSの細かいオプションの話
    https://blogs.oracle.com/jonthecollector/entry/did_you_know

- "-Xmx"で指定されるMaxHeapのサイズは、Permanent領域の分を含まない。


Swift
=====

curlでSwift APIを叩く
---------------------

::

  curl https://identity.api.rackspacecloud.com/v2.0/tokens \
   -X POST \
   -d '{"auth":{"RAX-KSKEY:apiKeyCredentials":{"username":"foobar","apiKey":"ffffffffffffffffffffffffffffffff"}}}' \
   -H "Content-type: application/json" | jq -r .access.token.id > ~/token.swift
  
  curl https://storage101.iad3.clouddrive.com/v1/MossoCloudFS_1035245/testfs/test \
   -i \
   -X HEAD \
   -H "Host: storage.clouddrive.com" \
   -H "X-Newest: true" \
   -H "X-Auth-Token: `cat ~/token.swift`"


example configuration for contract test
---------------------------------------

src/test/resources/auth-keys.xml::

  <?xml version="1.0"?>
  <?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
  <configuration>
    <property>
      <name>fs.contract.test.fs.swift</name>
      <value>swift://testfs.rackspace/</value>
    </property>
    <property>
      <name>fs.swift.service.rackspace.auth.url</name>
      <value>https://auth.api.rackspacecloud.com/v2.0/tokens</value>
    </property>
    <property>
      <name>fs.swift.service.rackspace.username</name>
      <value>foobar</value>
    </property>
    <property>
      <name>fs.swift.service.rackspace.region</name>
      <value>IAD</value>
    </property>
    <property>
      <name>fs.swift.service.rackspace.apikey</name>
      <value>ffffffffffffffffffffffffffffffff</value>
    </property>
    <property>
      <name>fs.swift.service.rackspace.public</name>
      <value>true</value>
    </property>
  </configuration>


fluentd
=======

テストの実行
------------

::

  $ bundle install
  $ bundle exec rake test

特定のテストファイルを実行する場合::

  $ bundle exec rake test TEST=test/plugin/test_output_as_buffered.rb

特定のテストケースを実行::

  $ bundle exec rake test TEST=test/plugin/test_output_as_buffered.rb TESTOPTS="-t'/buffered output feature with timekey and range/'"


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



Ambari
======

Setting up single Ambari cluster on CentOS 7.::

  sudo curl -L -o /etc/yum.repos.d/ambari.repo  http://public-repo-1.hortonworks.com/ambari/centos7/2.x/updates/2.6.0.0/ambari.repo
  sudo yum -y install java-1.8.0-openjdk-devel ambari-server ambari-agent
  sudo ambari-server setup -j /usr/lib/jvm/java-1.8.0-openjdk --silent
  sudo service ambari-server start
  sudo service ambari-agent start

OpenSSLのバージョンによっては、
/etc/ambari-agent/conf/ambari-agent.iniの[security]セクションに、
以下を記述しないとambari-agentがambari-serverに接続できない。::

  force_https_protocol=PROTOCOL_TLSv1_2

HDP 2.6.1だと、以下を実行しないと、HiveMetastoreやHiveServer2が起動できない。::

  $ sudo yum install mysql-connector-java*
  $ ls -al /usr/share/java/mysql-connector-java.jar
  $ cd /var/lib/ambari-server/resources/
  $ ln -s /usr/share/java/mysql-connector-java.jar mysql-connector-java.jar


Ranger
======

setup.sh on CentOS 8
--------------------

Python 3 is not supported. Python 2 must be on the path as `python`.::

  $ sudo alternatives --set python /usr/bin/python2

Since MariaDB is not supported, MySQL should be used.::

  $ sudo dnf install mysql-server
  $ sudo yum install https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-8.0.21-1.el8.noarch.rpm
  $ sudo systemctl start mysqld

`CREATE FUNCTION` is not allowed without setting `log_bin_trust_function_creators`.::

  $ mysql -u root
  > SET GLOBAL log_bin_trust_function_creators = 1;

passwords must be set in install.properties.::

  # DB UserId used for the Ranger schema
  #
  db_name=ranger
  db_user=rangeradmin
  db_password=###PASSWORD HERE###
  
  # change password. Password for below mentioned users can be changed only once using this property.
  #PLEASE NOTE :: Password should be minimum 8 characters with min one alphabet and one numeric.
  rangerAdmin_password=###PASSWORD HERE###
  rangerTagsync_password=###PASSWORD HERE###
  rangerUsersync_password=###PASSWORD HERE###
  keyadmin_password=###PASSWORD HERE###


cache
-----

Policies fetched from ranger-admin are cached in the directory specified by `ranger.plugin.hbase.policy.cache.dir`.::

  2020-08-07 15:01:16,435 INFO  [centos8:44025.activeMasterManager] provider.AuditProviderFactory: AUDIT PROPERTY: ranger.plugin.hbase.policy.cache.dir=/etc/ranger/hbase/policycache

Cached policies are loaded if ranger-admin is not available on the startup.


EC2
===

インスタンス起動時にとりあえずでsshのlisten portに443を追加するためのuser data for CentOS 6 and CentOS 7。
再起動してSELinuxがenforcingで上がってくると、
sshdが443をlistenできなくて起動失敗し、ログインできなくなる::

  #!/bin/bash
  setenforce 0
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/sysconfig/selinux
  sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
  service iptables stop
  chkconfig iptables off
  echo "" >> /etc/ssh/sshd_config
  echo "Port 22" >> /etc/ssh/sshd_config
  echo "Port 443" >> /etc/ssh/sshd_config
  service sshd reload


firewalld
=========

opening ports for zone.::

  $ sudo firewall-cmd --permanent --zone=public --add-port=1024-65535/tcp
  $ sudo firewall-cmd --reload

showing all settings of nftables.::

  $ sudo nft -a list ruleset | less

 
Gradle
======

maven-publish
-------------

https://docs.gradle.org/current/userguide/publishing_maven.html

::

  $ ./gradlew publishToMavenLocal -Pskip.signing



Alluxio
=======

FileSystem
----------

- alluxio.hadoop.FileSystemがAlluxioのFileSystem実装。

- org.apache.hadoop.fs.FileSystem#openは、alluxio.client.file.FileSystem#openFileに対応付けられる感じ。

- ``return new FSDataInputStream(new HdfsFileInputStream(mFileSystem, uri, mStatistics));``
  みたいな形で、wrapされるalluxio.hadoop.HdfsFileInputStreamのさらに内側に、
  alluxio.client.file.FileInStreamのサブクラス(AlluxioFileInStream)が埋まってる。

- FileInStreamの中で、read箇所のブロックに対応するalluxio.client.block.stream.BlockInStreamを作る。

- BlockInStreamの内部では、DataReaderのインスタンスを作ってデータをreadする。
  リモートのAlluxio workerにリクエストを送ってデータを読む場合、GrpcDataReader。



Configuration
-------------

- クライアント側の設定は結構複雑

  - 以下などから取得した内容をマージして使う。

    - クラスパス上のalluxio-site.properties
    - alluxio-masterからRPCで取得
    - (org.apache.hadoop.conf.Configuration)

  - 優先順位は
    `alluxio.conf.Source <https://github.com/Alluxio/alluxio/blob/v2.9.3/core/common/src/main/java/alluxio/conf/Source.java>`_
    の値で決まる。ローカル優先。

  - 同じRUNTIMEでも、alluxio-site.propertiesよりも、
    `HadoopのConfiguration経由が優先 <https://github.com/Alluxio/alluxio/blob/v2.9.3/core/client/hdfs/src/main/java/alluxio/hadoop/AbstractFileSystem.java#L503-L504>`_
    される。


ASYCN_THROUGH
-------------

- ASYCN_THROUGHで書き込むと、
  typeが
  `ALLUXIO_BLOCK <https://github.com/Alluxio/alluxio/blob/v2.9.4/core/transport/src/main/proto/grpc/block_worker.proto#L49>`_
  なWriteRequestでデータを送った後、
  `completeFile <https://github.com/Alluxio/alluxio/blob/v2.9.4/core/server/master/src/main/java/alluxio/master/file/FileSystemMaster.java#L220-L237>`_
  するときに
  `asyncPersistOptions <https://github.com/Alluxio/alluxio/blob/v2.9.4/core/transport/src/main/proto/grpc/file_system_master.proto#L83>`_
  をセットしてリクエストを送る。その後、
  `PersistenceScheduler <https://github.com/Alluxio/alluxio/blob/v2.9.4/core/server/master/src/main/java/alluxio/master/file/DefaultFileSystemMaster.java#L4611-L4615>`_
  が非同期に、このファイルをUFSに書き込むためのジョブを起動する。


extensions
----------

- underfsのライブラリの.jarは、
  `java.nio.file.Files#newDirectoryStreamで順次読み込む <https://github.com/Alluxio/alluxio/blob/v2.9.4/core/common/src/main/java/alluxio/extensions/ExtensionFactoryRegistry.java#L216-L229>`_
  ため、同じunderfsの複数のバージョンのライブラリが存在する場合、どれが使われるかは事前に分からない。
  `mount時のalluxio.underfs.versionの値で制御 <https://docs.alluxio.io/os/user/2.9.4/en/ufs/HDFS.html#supported-hdfs-versions>`_
  できる。

- alluxio.underfs.versionのバージョン番号は、ある程度柔軟にマッチされる。
  例えば、libディレクトリにhdfs用のunderfsのjarとして、
  ``alluxio-underfs-hdfs-3.3.4-2.9.4.jar`` のみが存在する場合、
  3.3や3.3.3は許されるが、2.10や3.2はエラーになる。::
   
    alluxio fs mount --option alluxio.underfs.version=2.10 /mnt/hdfs hdfs://nn1:8020/alluxio
    alluxio fs mount --option alluxio.underfs.version=3.2 /mnt/hdfs hdfs://nn1:8020/alluxio
    alluxio fs mount --option alluxio.underfs.version=3.3 /mnt/hdfs hdfs://nn1:8020/alluxio
    alluxio fs mount --option alluxio.underfs.version=3.3.3 /mnt/hdfs hdfs://nn1:8020/alluxio


Testing with Bigtop provisioner
-------------------------------

launch pseudo distributed cluster by pre-built packages.::

  ./docker-hadoop.sh \
    --create 1 \
    --memory 16g \
    --image bigtop/puppet:trunk-rockylinux-8 \
    --repo http://repos.bigtop.apache.org/releases/3.3.0/rockylinux/8/x86_64 \
    --stack hdfs,yarn,mapreduce,alluxio

or with locally built packages.::

  ./docker-hadoop.sh \
    --create 1 \
    --memory 16g \
    --image bigtop/puppet:trunk-ubuntu-22.04 \
    --repo file:///bigtop-home/output/apt \
    --disable-gpg-check \
    --stack hdfs,yarn,mapreduce,alluxio
  
``vi /etc/alluxio/conf/alluxio-site.properties``::

  alluxio.user.short.circuit.enabled=false
  alluxio.user.file.writetype.default=CACHE_THROUGH
  alluxio.underfs.s3.streaming.upload.enabled=true
  s3a.accessKeyId=XXXXX
  s3a.secretKey=XXXXXXXXXX

``vi /etc/alluxio/conf/log4j.properties`` and ``vi /etc/hadoop/conf/log4j.properties``::

  log4j.logger.alluxio.client.file=DEBUG
  log4j.logger.alluxio.client.block.stream=DEBUG
  log4j.logger.alluxio.conf=DEBUG
  log4j.logger.alluxio.extensions=DEBUG
  log4j.logger.alluxio.underfs=DEBUG
  log4j.logger.alluxio.underfs.hdfs=DEBUG
  log4j.logger.alluxio.underfs.s3=DEBUG
  log4j.logger.alluxio.worker.grpc=DEBUG

``vi /etc/hadoop/conf/core-site.xml``::

    <property>
      <name>alluxio.user.file.writetype.default</name>
      <value>CACHE_THROUGH</value>
    </property>
  
    <property>
      <name>fs.alluxio.impl</name>
      <value>alluxio.hadoop.FileSystem</value>
    </property>

``vi /etc/hadoop/conf/hadoop-env.sh``::

  export HADOOP_CLASSPATH=/usr/lib/alluxio/client/build/alluxio-2.9.4-hadoop3-client.jar

preparing services::

  usermod -aG hadoop root
  systemctl restart alluxio-master alluxio-worker alluxio-job-master alluxio-job-worker
  
  hdfs dfs -mkdir /alluxio
  
  alluxio fs mkdir /mnt
  alluxio fs mount /mnt/hdfs hdfs://$(hostname --fqdn):8020/alluxio
  alluxio fs mount /mnt/s3 s3://my-test-backet/alluxio

puttting file via alluxio.hadoop.FileSystem::

  dd if=/dev/zero of=256mb.dat bs=1M count=256
  hadoop fs -put -d 256mb.dat alluxio://localhost:19998/mnt/hdfs/
  hadoop fs -put -d 256mb.dat alluxio://localhost:19998/mnt/s3/



netty4
======

- pipeline中のChannelHandlerは、
  `<1本の双方向リスト https://github.com/netty/netty/blob/netty-4.1.100.Final/transport/src/main/java/io/netty/channel/DefaultChannelPipeline.java#L64-L65>`_
  につながれている。

  - inboundはheadからtailに向かって処理されていく。

  - outboundはtailからheadに向かって処理されていく。

  - handlerがinboundの方しか対応していなければ(ChannelInboundHandlerしか実装していなければ)、outboundの処理ではスキップされる。
    このスキップは、
    `マスク <https://github.com/netty/netty/blob/netty-4.1.100.Final/transport/src/main/java/io/netty/channel/ChannelHandlerMask.java>`_
    を利用して行われる。

  - この辺については、
    `ChannlePipelineのコメントの説明 <https://github.com/netty/netty/blob/netty-4.1.100.Final/transport/src/main/java/io/netty/channel/ChannelPipeline.java#L32-L221>`_
    が分かりやすい。


Camel
=====

- Consumerというのは、外からデータを受け取るin。

- Producerというのは、外にデータを送るout。

- Consumerが外からデータを受け取ってExchangeを作る。

  - 受け取ったデータは ``Exchange#setIn`` される。

- ExchangeはConsumerに紐づけられたProcessorで、processされる。

  - 戻りのレスポンスデータがあれば ``Exchange#setOut`` される。


camel-netty
-----------

- Exchangeを作るのは、
  `server channelのpipeline末尾に追加される <https://github.com/apache/camel/blob/camel-4.2.0/components/camel-netty/src/main/java/org/apache/camel/component/netty/DefaultServerInitializerFactory.java#L103-L111>`_
  `ServerChannelHandler <https://github.com/apache/camel/blob/camel-4.2.0/components/camel-netty/src/main/java/org/apache/camel/component/netty/handlers/ServerChannelHandler.java>`_
  。

- レスポンスを入れるのは、
  `client channelのpipeline末尾に追加される <https://github.com/apache/camel/blob/camel-4.2.0/components/camel-netty/src/main/java/org/apache/camel/component/netty/DefaultClientInitializerFactory.java#L95-L96>`_
  `ClientChannelHandler <https://github.com/apache/camel/blob/camel-4.2.0/components/camel-netty/src/main/java/org/apache/camel/component/netty/handlers/ClientChannelHandler.java>`_ 
  。


CentOS 7
========

using vault repo for installing packages::

  # cat >>/etc/yum.repos.d/CentOS-Vault.repo <<'EOF'
  
  [C7.9.2009-base]
  name=CentOS-7.9.2009 - Base
  baseurl=http://vault.centos.org/7.9.2009/os/$basearch/
  gpgcheck=1
  gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
  enabled=1
  
  [C7.9.2009-updates]
  name=CentOS-7.9.2009 - Updates
  updatesurl=http://vault.centos.org/7.9.2009/os/$basearch/
  gpgcheck=1
  gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
  enabled=1
  EOF
  
  
  # yum --disablerepo='*' --enablerepo=C7.9.2009-base install file


CentOS 8
========

using vault repo for installing packages::

  $ docker run -i -t centos:8 /bin/bash
  
  # cat >>/etc/yum.repos.d/CentOS-Vault.repo <<'EOF'
  [C8.2.2004-baseos]
  name=CentOS-8.2.2004 - BaseOS
  baseurl=https://vault.centos.org/8.2.2004/BaseOS/$basearch/os/
  gpgcheck=1
  enabled=1
  gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
  
  [C8.2.2004-appstream]
  name=CentOS-8.2.2004 - AppStream
  baseurl=https://vault.centos.org/8.2.2004/AppStream/$basearch/os/
  gpgcheck=1
  enabled=1
  gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
  EOF
  
  # yum --disablerepo='*' --enablerepo=C8.2.2004-appstream install crash
