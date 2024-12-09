======
Bigtop
======

.. contents::

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


Loop on hbase-shell
-------------------

::

  (0..9).each { |i| put 'test', 'r'+i.to_s, 'f:q'+i.to_s, 'v'+i.to_s }


Scan filter on hbase-shell
--------------------------

::

  scan 't1', {FILTER => "PrefixFilter ('r') AND ColumnRangeFilter ('q3', true, 'q6', false)"}


Java API on hbase-shell
-----------------------

::

  require 'java'
  java_import org.apache.hadoop.hbase.CellUtil
  java_import org.apache.hadoop.hbase.HBaseConfiguration
  java_import org.apache.hadoop.hbase.TableName
  java_import org.apache.hadoop.hbase.client.ConnectionFactory
  java_import org.apache.hadoop.hbase.client.Get
  java_import org.apache.hadoop.hbase.util.Bytes
  
  conf = HBaseConfiguration.create()
  conn = ConnectionFactory.createConnection(conf)
  table = conn.getTable(TableName.valueOf('test'))
  get = Get.new(Bytes.toBytes('r1'))
  result = table.get(get)
  
  result.rawCells().each { |c| print Bytes.toString(CellUtil.cloneValue(c)) }


HBase RDD on spark-shell
------------------------

::

  import scala.collection.JavaConversions._
  import org.apache.hadoop.hbase.CellUtil
  import org.apache.hadoop.hbase.HBaseConfiguration
  import org.apache.hadoop.hbase.TableName
  import org.apache.hadoop.hbase.client.Scan
  import org.apache.hadoop.hbase.spark.HBaseContext
  import org.apache.hadoop.hbase.util.Bytes
  
  val hbconf = HBaseConfiguration.create()
  val hc = new HBaseContext(sc, hbconf)
  val scan = new Scan()
  val rdd = hc.hbaseRDD(TableName.valueOf("test"), scan)
  rdd.foreach(r => r._2.listCells.foreach(c => println(c)))


setting long timeout for debugging on standalone cluster
---------------------------------------------------------

::

    <property>
      <name>hbase.zookeeper.property.tickTime</name>
      <value>60000</value>
    </property>
    <property>
      <name>hbase.zookeeper.property.minSessionTimeout</name>
      <value>120000</value>
    </property>
    <property>
      <name>hbase.zookeeper.property.maxSessionTimeout</name>
      <value>3600000</value>
    </property>
    <property>
      <name>zookeeper.session.timeout</name>
      <value>3600000</value>
    </property>
    <property>
      <name>zookeeper.session.timeout.localHBaseCluster</name>
      <value>3600000</value>
    </property>
    <property>
      <name>hbase.zookeeper.sync.timeout.millis</name>
      <value>3600000</value>
    </property>
    <property>
      <name>hbase.rpc.timeout</name>
      <value>3600000</value>
    </property>
      <property>
      <name>hbase.client.scanner.timeout.period</name>
      <value>3600000</value>
    </property>
    <property>
      <name>hbase.client.operation.timeout</name>
      <value>3600000</value>
    </property>
