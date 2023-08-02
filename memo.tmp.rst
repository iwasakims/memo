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


HBase
=====

misc
----

- HBaseのLogWriterはSequenceFileLogWriterではなくProtobufLogWriterがデフォルトに変わった。

- master自体が内部的にregionserverを開くようになったので、
  擬似分散環境では以下のようにポート番号をずらさないと、
  Addless already in useで起動に失敗する。::

    $ bin/local-regionservers.sh start 1

- Table#flushCommitsは廃止された。(HBASE-12802)
  Connection#getBufferedMutatorで取得できるBufferedMutator#flushを使う必要がある。(HBASE-12728)


HBase multi pseudo-distributed clusters on localhost
----------------------------------------------------

::

  $ cd $HBASE_HOME
  $ cp -Rp conf conf1
  $ cp -Rp conf conf2
  $ vi conf1/hbase-env.sh
  $ vi conf1/hbase-site.xml
  $ vi conf2/hbase-env.sh
  $ vi conf2/hbase-site.xml
    
  $ HBASE_CONF_DIR=./conf1 bin/hbase-daemon.sh start master
  $ HBASE_CONF_DIR=./conf1 bin/hbase-daemon.sh start regionserver
  $ HBASE_CONF_DIR=./conf2 bin/hbase-daemon.sh start master
  $ HBASE_CONF_DIR=./conf2 bin/hbase-daemon.sh start regionserver
  
  $ HBASE_CONF_DIR=./conf2 bin/hbase shell
  > create 'test', 'f'
  
  $ HBASE_CONF_DIR=./conf1 bin/hbase shell
  > create 'test', 'f'
  > add_peer 'hbase2', 'localhost:2181:/hbase2'
  > enable_table_replication 'test'
  > put 'test', 'r1', 'f:', 'v1'

conf1/hase-env.sh::

  export HBASE_IDENT_STRING=hbase1

conf2/hase-env.sh::

  export HBASE_IDENT_STRING=hbase2

conf1/hbase-site.xml::

  <configuration>
    <property>
      <name>hbase.cluster.distributed</name>
      <value>true</value>
    </property>
    <property>
      <name>hbase.rootdir</name>
      <value>hdfs://localhost:8020/hbase1</value>
    </property>
    <property>
      <name>hbase.zookeeper.quorum</name>
      <value>localhost</value>
    </property>
    <property>
      <name>zookeeper.znode.parent</name>
      <value>/hbase1</value>
    </property>
    <property>
      <name>hbase.master.port</name>
      <value>60001</value>
    </property>
    <property>
      <name>hbase.master.info.port</name>
      <value>60011</value>
    </property>
    <property>
      <name>hbase.regionserver.port</name>
      <value>60021</value>
    </property>
    <property>
      <name>hbase.regionserver.info.port</name>
      <value>60031</value>
    </property>
  </configuration>

conf2/hbase-site.xml::

  <configuration>
    <property>
      <name>hbase.cluster.distributed</name>
      <value>true</value>
    </property>
    <property>
      <name>hbase.rootdir</name>
      <value>hdfs://localhost:8020/hbase2</value>
    </property>
    <property>
      <name>hbase.zookeeper.quorum</name>
      <value>localhost</value>
    </property>
    <property>
      <name>zookeeper.znode.parent</name>
      <value>/hbase2</value>
    </property>
    <property>
      <name>hbase.master.port</name>
      <value>60002</value>
    </property>
    <property>
      <name>hbase.master.info.port</name>
      <value>60012</value>
    </property>
    <property>
      <name>hbase.regionserver.port</name>
      <value>60022</value>
    </property>
    <property>
      <name>hbase.regionserver.info.port</name>
      <value>60032</value>
    </property>
  </configuration>


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

 
PostgreSQL
==========

replication quickstart (PostgreSQL 9.2 on Ubuntu)
-------------------------------------------------

::

  $ sudo apt install bison flex libreadline-dev
  $ git clone https://github.com/postgres/postgres
  $ cd postgres
  $ git checkout REL9_2_24
  $ CFLAGS='-ggdb -O0' ./configure --prefix=/usr/local/pgsql9224
  $ make
  $ sudo make install
  $ cd contrib/pgstattuple
  $ make
  $ sudo make install
  $ export PATH=/usr/local/pgsql9224/bin:$PATH
  
  
  
  $ initdb -D $HOME/pgdata1
  $ mkdir $HOME/pgdata1/arc
  
  $ vi $HOME/pgdata1/postgresql.conf
  (wal_level = hot_standby, archive_mode = on, archive_command = 'test ! -f /home/iwasakims/pgdata1/arc/%f && cp %p /home/iwasakims/pgdata1/arc/%f', max_wal_senders = 3)
  
  $ vi $HOME/pgdata1/pg_hba.conf
  (host    replication     iwasakims        127.0.0.1/32            trust)
  
  $ pg_ctl -D $HOME/pgdata1 -l $HOME/pgdata1/postgresql.log start
  
  
  $ pg_basebackup -h localhost -D $HOME/pgdata2 -U iwasakims -v -P --xlog-method=stream
  
  $ vi $HOME/pgdata2/postgresql.conf
  (port = 5433, hot_standby = on)
  
  $ vi $HOME/pgdata2/recovery.conf
  $ cat $HOME/pgdata2/recovery.conf
  standby_mode = on
  primary_conninfo = 'host=localhost port=5432 user=iwasakims'
  
  $ pg_ctl -D $HOME/pgdata2 -l $HOME/pgdata2/postgresql.log start
  
  $ psql -p 5432 postgres
  $ psql -p 5433 postgres


replication quickstart (PostgreSQL 13 on Rocky Linux 8)
-------------------------------------------------------

::

  $ git clone https://github.com/postgres/postgres
  $ cd postgres
  $ git checkout REL13_5
  $ CFLAGS='-ggdb -O0' ./configure --prefix=/usr/local/pgsql135
  $ make
  $ sudo make install
  $ cd contrib/pgstattuple
  $ make
  $ sudo make install
  $ export PATH=/usr/local/pgsql135/bin:$PATH
  
  
  
  $ initdb -D $HOME/pgdata1
  $ mkdir $HOME/pgdata1/arc
  
  $ vi $HOME/pgdata1/postgresql.conf
  (wal_level = replica, archive_mode = on, archive_command = 'test ! -f /home/rocky/pgdata1/arc/%f && cp %p /home/rocky/pgdata1/arc/%f', max_wal_senders = 3, synchronous_standby_names = '*')
  
  $ vi $HOME/pgdata1/pg_hba.conf
  (host    replication     all        127.0.0.1/32            trust)
  
  $ pg_ctl -D $HOME/pgdata1 -l $HOME/pgdata1/postgresql.log start
  
  
  $ pg_basebackup -h localhost -D $HOME/pgdata2 -U $USER -v -P --wal-method=stream
  
  $ vi $HOME/pgdata2/postgresql.conf
  (port = 5433, hot_standby = on, archive_command = 'test ! -f /home/rocky/pgdata2/arc/%f && cp %p /home/rocky/pgdata2/arc/%f')
  
  $ touch $HOME/pgdata2/standby.signal
  $ echo -e "\nprimary_conninfo = 'host=localhost port=5432 user=rocky'\n" >> $HOME/pgdata2/postgresql.conf
  
  $ pg_ctl -D $HOME/pgdata2 -l $HOME/pgdata2/postgresql.log start
  
  $ psql -p 5432 postgres
  $ psql -p 5433 postgres


Gradle
======

maven-publish
-------------

https://docs.gradle.org/current/userguide/publishing_maven.html

::

  $ ./gradlew publishToMavenLocal -Pskip.signing
