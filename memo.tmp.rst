.. contents::


build & test
============

assembly
--------

- hadoop-hdfsは個別のassembly descriptorを用意していない。
  hadoop-project-dist/pom.xmlの設定によって、hadoop-dist.xmlが利用される。
  maven-assembly-pluginの設定を上書きしないサブプロジェクトも同様のはず。

- hadoop-commonもhadoop-hdfsもtest-jarをshare/${hadoop.component}に配置している。::

    <fileSet>
      <directory>${project.build.directory}</directory>
      <outputDirectory>/share/hadoop/${hadoop.component}</outputDirectory>
      <includes>
        <include>${project.artifactId}-${project.version}.jar</include>
        <include>${project.artifactId}-${project.version}-tests.jar</include>
      </includes>
      <excludes>
        <exclude>hadoop-tools-dist-*.jar</exclude>
      </excludes>
    </fileSet>

- hadoop-yarn-server-testsのtest-jarがshare/hadoop/yarn/test下にあるのは、
  hadoop-yarn-dist.xmlの以下の記述による。
  YARN-429によって、classpathが通らない場所に移動された。::

    <moduleSet>
      <includes>
        <include>org.apache.hadoop:hadoop-yarn-server-tests</include>
      </includes>
      <binaries>
        <attachmentClassifier>tests</attachmentClassifier>
        <outputDirectory>share/hadoop/${hadoop.component}/test</outputDirectory>
        <includeDependencies>false</includeDependencies>
        <unpack>false</unpack>
      </binaries>
    </moduleSet>


Mockito
-------

- CallsRealMethodsが、本来の値を返すAnswer実装。
  ``Mockito.CALLS_REAL_METHODS`` で取得できる。


configuration & scripts
=======================

- ``bin/hadoop classpath --glob`` でglob展開したあとのclasspathが取得できる。

- ``--daemon`` オプションをつけてもつけなくても pidファイルは作成される。

- ログファイルができるのは ``--daemon`` を付けたときのみ。
  ないと ``-Dhadoop.root.logger=`` の値が ``INFO,console`` になる。

- ``--daemon`` オプションを指定した場合、
  javaコマンドをバックグランドで起動してからdisownする。

- hbaseのようにローカルに複数デーモンを起動するスクリプトを足せないものか。

- zookeeperのログはlog4jの設定次第。
  デフォルト値のCONSOLEのままでdaemon起動すると、zookeeper.outに出力されることになる。

- ``-Ddfs.ha.namenodes.ns1=nn1,nn2 -Ddfs.namenode.rpc-address.ns1.nn1=nn1:8020 -Ddfs.namenode.rpc-address.ns1.nn2=nn2:8020``
  のように、NameNodeが2台分設定されていないと、
  HAUtil#isHAEnabledのチェックを通らない。

- パッケージ版の/usr/bin/zookeeper-serverなどは、
  bigtopのinstall-zookeeper.shの中で作られている。
  環境変数を設定してzkServer.shを呼び出す。

- {hadoop,mapred,yarn}-env.shは{hadoop,mapred,yarn}-config.shから読み込まれる。
  {mapred,yarn}-config.shは環境変数だけセットしてhadoop-config.shを呼び出す。

- HADOOP-7001でオンラインconfigアップデートが入った。
  DataNodeでdata.dirを更新するときにのみ利用されている(HDFS-1362)。
  dfsadmin -reconfigを実行すると、設定を再読み込みに行く。

- JobConf初期化時に呼ばれるConfigUtil#loadResourcesメソッドは、
  ConfigurationにstaticにYARN/MapReduceの設定ファイルを読み込んでしまう。
  つまりYARNだけに反映させたいと思ってyarn-site.xmlに設定を書いても、
  NameNodeやDataNodeにもロードされてしまう。::
  
    public static void loadResources() {
      addDeprecatedKeys();
      Configuration.addDefaultResource("mapred-default.xml");
      Configuration.addDefaultResource("mapred-site.xml");
      Configuration.addDefaultResource("yarn-default.xml");
      Configuration.addDefaultResource("yarn-site.xml");
    }

- ReflectionUtils#setConfのコメントにはHADOOP-1230に起因してこうなっているとある。
  coreがmapredに依存していることが原因とすると、ずっとこのまま? (see. HADOOP-7056)::
  
    /**
     * This code is to support backward compatibility and break the compile
     * time dependency of core on mapred.
     * This should be made deprecated along with the mapred package HADOOP-1230.
     * Should be removed when mapred package is removed.
     */
    private static void setJobConf(Object theObject, Configuration conf) {
      //If JobConf and JobConfigurable are in classpath, AND
      //theObject is of type JobConfigurable AND
      //conf is of type JobConf then
      //invoke configure on theObject
      try {
        Class<?> jobConfClass =
  	conf.getClassByNameOrNull("org.apache.hadoop.mapred.JobConf");
        if (jobConfClass == null) {
  	return;
        }

- 本来HDFSのデーモンがsetJobConfする必要はないはずだが、
  ReflectionUtilsのメソッドを使う流れで呼ばれてしまう様子。以下はDataNodeの場合::

    [1] org.apache.hadoop.util.ReflectionUtils.setJobConf (ReflectionUtils.java:91)
    [2] org.apache.hadoop.util.ReflectionUtils.setConf (ReflectionUtils.java:75)
    [3] org.apache.hadoop.util.ReflectionUtils.newInstance (ReflectionUtils.java:133)
    [4] org.apache.hadoop.security.Groups.<init> (Groups.java:64)
    [5] org.apache.hadoop.security.Groups.getUserToGroupsMappingService (Groups.java:240)
    [6] org.apache.hadoop.security.UserGroupInformation.initialize (UserGroupInformation.java:266)
    [7] org.apache.hadoop.security.UserGroupInformation.setConfiguration (UserGroupInformation.java:294)
    [8] org.apache.hadoop.hdfs.server.datanode.DataNode.instantiateDataNode (DataNode.java:1,770)
    [9] org.apache.hadoop.hdfs.server.datanode.DataNode.createDataNode (DataNode.java:1,813)
    [10] org.apache.hadoop.hdfs.server.datanode.DataNode.secureMain (DataNode.java:1,990)
    [11] org.apache.hadoop.hdfs.server.datanode.DataNode.main (DataNode.java:2,014)


RPC
===
 
- Hadoop IPCでは
  java.lang.reflect.InvocationHandlerのinvokeメソッド中でRPC requestを組み立て、
  Client#callを呼び出してサーバにデータを送っている。

- BlockingInterfaceはProtocol Buffersが提供する同期メソッド呼び出し用のwrapper
  https://developers.google.com/protocol-buffers/docs/reference/java-generated

- テストコード意外でWritableRPCEngineを使う場所はない。
  サーバ側でProtobufRpcEngineを使うようにハードコードされているので、
  設定変数で切り替えることはできない。

- x.y.z.protocolPB.fooBarPBというクラスは、
  RPCのプロトコルに付加情報をつけるために存在する様子。
  protocで自動生成されるモノは加工できないため。
  このクラスはrpc.engine.*にセットされるプロトコル名として使われる。::

    @InterfaceAudience.Private
    @InterfaceStability.Stable
    @KerberosInfo(
        serverPrincipal = DFSConfigKeys.DFS_NAMENODE_KERBEROS_PRINCIPAL_KEY)
    @TokenInfo(DelegationTokenSelector.class)
    @ProtocolInfo(protocolName = HdfsConstants.CLIENT_NAMENODE_PROTOCOL_NAME,
        protocolVersion = 1)
    /**
     * Protocol that a clients use to communicate with the NameNode.
     *
     * Note: This extends the protocolbuffer service based interface to
     * add annotations required for security.
     */
    public interface ClientNamenodeProtocolPB extends
      ClientNamenodeProtocol.BlockingInterface {
    }


Server
------

- listenerは1つ。acceptしてconnectionを各readerのpendingConnectionsというキューに積む。

- readerは複数いる。listenerはreaderをラウンドロビンで使う。

- readerがsocketから読み込んで作成したCallオブジェクトは単一のcallQueueに積まれる。

- callQueueからCallを取り出して処理をするhandlerが複数いる。


NameNode
--------

- "dfs.namenode.servicerpc-address"を指定すると、
  ClientNamenodeProtocol以外をserveするためのserviceRpcServerが追加で作成される。
  クライアントからNameNodeに過大なアクセスがあっても、
  DataNodeからのリクエスト等を処理できるようにするため。
  おそらくは後方互換性のため、serviceRpcServerとclientRpcServerのどちらも、
  すべてのプロトコルを処理できるようになっている。



security
========

- ``kdb5util create`` が/dev/randomのエントロピー不足でハングする場合、
  ``-w`` オプションを付けると/dev/urandomに切り替わってうまくいく。
  もちろんproductionでは使うべきではない設定。

- HDFSデーモンをsecure modeで起動する場合、WebHDFSの設定もないとダメ。

- "simple"に対応するhandlerはPseudoAuthenticationHandler

- AuthenticationTokenはrequestをwrapしてAuthenticationTokenの情報を仕込む。::

          final AuthenticationToken authToken = token;
          httpRequest = new HttpServletRequestWrapper(httpRequest) {

            @Override
            public String getAuthType() {
              return authToken.getType();
            }

            @Override
            public String getRemoteUser() {
              return authToken.getUserName();
            }

            @Override
            public Principal getUserPrincipal() {
              return (authToken != AuthenticationToken.ANONYMOUS) ?
                  authToken : null;
            }
          };

- ProxyUsers#authenticateを呼ぶ条件は以下。(o.a.h.ipc.Serverの場合)::

        if (user != null && user.getRealUser() != null
            && (authMethod != AuthMethod.TOKEN)) {
          ProxyUsers.authorize(user, this.getHostAddress());
        }


ZKFC
====

- "ActiveBreadCrumb"はpersistentなznodeで、これが残っていれば、fencingを実行する。

- auto-failoverがONで、BreadCrumbを自分で消すのは、
  failoverコマンドによりgracefulFailoverが実行される場合のみ。

- nn1のNameNodeが停止すると、
  HealthMonitorの状態はSERVICE_NOT_RESPONDINGに遷移するので、
  elector.quitElection(true) で
  zkfcはBreadCrumbノードを消さずにelectionから降りる。

- zkfcにはshutdown hookやstopコマンドはない。
  killでDFSZKFailoverControllerを停止すると、当然上記のノードは残る。

- fencingでは、まず対向のNameNodeのtransitionToStandbyを呼んでみるので、
  NameNodeより先にZKFCを止めたほうが、
  ハードなfencingを防ぐことができるとは言えるはず。


HDFS
====

- defaultFsのデフォルト値は"file:///"

- FsDatasetImplへのcontentionが発生する例: HDFS-7489

- lease holderの識別子としても使われるclientNameは以下のように決められる。
  taskIdの部分はMRタスクでなければ"NONMAPREDUCE"。(MRの場合はtask attempt id。)
  スレッドIDが入っているが、DFSClientが複数のスレッドから使われることもあるような。::

    this.clientName = "DFSClient_" + dfsClientConf.taskId + "_" +
        DFSUtil.getRandom().nextInt()  + "_" + Thread.currentThread().getId();

- DFSOutputStreamはchecksumに関連するロジックを表現するFSOutputSummerを継承している。
  4バイトのcrc32チェックサムを書き、つづけて512バイトのchunkを書く。

- checksum typeのデフォルトはDataChecksum.Type.CRC32C

- HDFS-3689によって最後のブロック以外はサイズが一定という前提はなくなった。

- NameNodeメトリクスのPendingDeletionBlocksは、InvalidateBlocks#numBlocksの値。
  同じblodkでinvalidate対象のレプリカが複数あれば、その分はカウントされる。

- hflush/hsyncは書いたところまでのPacketのackが戻るのを待つ。
  hsyncの場合、syncの実行命令を出すための空Packetを追加で送る場合がある。

- GenerationStampは1000から始まって1ずつ増える。
  FSNamesystemのBlockIdManagerが管理する。

- 書き込みエラーでupdatePiplineするとgenstampが繰り上がる

- DataNodeのDataXceiverServerがpeerをacceptして、
  DataXceiver (extends Receiver)を作る。
  DataXceiver#writeBlockでは上流からブロックデータを受け取るために、
  BlockReciverがnewされる。BlockReceiverは内部にPacketResponderを持つ。

- DFSOutputStream#completeFileはサーバ側のcompleteが成功するまで何度かリトライする。
  replication.minに達していないと成功しないから。


BlockManager
------------

- completeBlockはBlockManager自身の中からしか呼ばれない

- BlockInfoにtripletsが必要な理由は、BlockIteratorを実現するため。

- updatePipelineやaddBlockの際にはexpectedTargetはちゃんと更新される

 - completeBlockの直前にcommitBlockが呼ばれるので、
   BlockInfo#setGenerationStampAndVerifyReplicasによって
   expected locationsが変更されていないかが心配なところ

   - BlockInfoContiguous#removeStorage はtripletsの最後の要素をnullにするので、
     BlockInfoContiguous#numNodesが変な値を返すことはない。
     ちゃんとcurBlockの持っている要素が1つ減る。

- commitorcompletelastblock以外の場所からcompleteBlockが呼ばれるケースへの対応が必要? -> 大丈夫そう

  - completeBlockが呼ばれるのはcommitOrCompleteLastBlock以外に3箇所。

    - initial block reportを処理するためのaddStoredBlockImmediate

    - standby nnがeditsをtailするときに使われるforceCompleteBlock。このときだけforceがtrue。
      Replication MonitorはNNがactiveなときしか仕事をしないので、
      この場合にpendingReplications.incrementしても問題はないはず。

    - addStoredBlockで
      ``storedBlock.getBlockUCState() == BlockUCState.COMMITTED && numLiveReplicas >= minReplication``
      なとき。

      - addStoredBlockはblock reportの処理で呼ばれ、上記はその中のたくさんある条件分岐のひとつ。

      - BlockInfo#commitBlockが呼ばれないとBlockUCState.COMMITTEDな状態にはならない。
        以前にもcommitBlockが呼ばれたが、
        そのときはまだnumLiveReplicas >= minReplicationではなく、
        completeにはなっていなかった場合が該当すると思われる。

- UCなファイルの最後のblockについての扱いを調整する必要がある?

    makes sure that blocks except for the last block in a file
    under-construction get replicated when under-replicated; This will
    allow a decommissioning datanode to finish decommissioning even it
    has replicas in files under construction.

- pendingReplicationsに入っていても、
  isNeededReplicationによるチェックではレプリケーションは必要という判断となる。
  scheduleReplicationの中で、hasEnoughEffectiveReplicasを使ったチェックの際に、
  「やっぱ必要ない」となる。::

    int pendingNum = pendingReplications.getNumReplicas(block);
    if (hasEnoughEffectiveReplicas(block, numReplicas, pendingNum,
        requiredReplication)) {
      neededReplications.remove(block, priority);


webhdfs/httpsfs
---------------

- httpfsとwebhdfsのパーツはあまり共通化されていない

- PrincipalはStringを返すgetName()だけ定義している


MapReduce
=========

- core-site.xmlなどに記載のあるpropは、
  child側でconfを初期化した際の初期値になってしまい、
  submitter側からmapperやreducerに値を伝えるには、別の機構が必要になる??
  タスク側でcontext.getNumReduceTasksを呼び出しているコードはなくて、
  Reduceタスクの数はoutputディレクトリのファイルの数から判断されてる?

- java.nio.channels.FileChannel#transferToを利用したzero copyは、
  o.a.h.mapred.ShuffleHandlerも利用している。
  org.jboss.netty.channel.DefaultFileRegion経由。
  fadviseでキャッシュにしないようにもしてる。

- o.a.h.mapred.MapReduceChildJVMがclildのコマンドラインを生成する。
  childプロセスのメインクラスはo.a.h.mapred.YarnChild。

- uber jobを実現するには、AM側でのコーディングが必要。
  LocalContainerLauncherはmapreduceプロジェクトのパーツ。
  MRAppMaster.serviceStart::

    protected void serviceStart() throws Exception {
      if (job.isUber()) {
        this.containerLauncher = new LocalContainerLauncher(context,
            (TaskUmbilicalProtocol) taskAttemptListener);
      } else {
        this.containerLauncher = new ContainerLauncherImpl(context);
      }
      ((Service)this.containerLauncher).init(getConfig());
      ((Service)this.containerLauncher).start();
      super.serviceStart();
    }

- 新しく起動したMRAppMasterは前回attemptのJobHistryを読み出す。
  自身は自分用の新しいJobHistoryファイルに書き出す。

- 前回のtask attemptのJobHistoryから読み出した情報に成功したタスクとして残っているものは、
  JobImpl#scheduleTasksでTaskImpl#recoverが呼ばれて、一瞬で完了したことにされるっぽい。

- ShuffleHandlerは身元確認のため、tokenを使って作ったURLのhashをリクエスト/リプライのヘッダにつける。
  
    
YARN
====

- AMからのstartContainersの呼び出しによって、NMは子プロセスを起動する。

- コンテナプロセス起動の流れ

  - ContainerImpl.LocalizedTransition.transitionの中でContainersLauncherEventを発行。
  - ContainersLauncher.handleがContainerLaunchをExecutorServiceにsubmit。(ContainerではなくContainers)
  - ContainerLaunch.callからContainersExecutorlaunchContainerを実行して子プロセスを起動。

- uber jobは、AM上(のスレッド)でタスクを実行する。
  jvm reuseを置き換えるものではない。

- ContainerManagerImplは自前のdispatcherを持っている。

- RMが使っている設定プロパティのzk-addressをgrepしても
  ソースコード中から定義はみつからない。難読化しているようにしかみえない。::

    /** Zookeeper interaction configs */
    public static final String RM_ZK_PREFIX = RM_PREFIX + "zk-";
    
    public static final String RM_ZK_ADDRESS = RM_ZK_PREFIX + "address";


EventHandlerとStateMachine
--------------------------

- Dispatcher#registerはeventType(実体はEnum)に対応するEventHandler実装を登録する。
  `Map<Class<? extends Enum>, EventHandler>` にエントリを追加するものだが、
  1つのeventTypeに対して複数のEventHandlerを登録することもできるようになっている。
  その場合、登録されたすべてのlistnerのhandleメソッドが呼び出される。

- Application、Container、Job、Taskといったクラスは、
  各インスタンス内にStateMachineを持っていて、
  それで状態とその遷移を表現する。
  StateMachineはstaticなStateMachineFactoryから生成される。

- StateMachine状態遷移は、pre状態、post状態、EventType、
  遷移時に実行される処理を記述したhookを引数にとる、
  addTransitionメソッドを呼び出すことで追加される。

- 状態遷移で実行されるhookは、
  StateMachineFactory単位で型が決められたとOperandとEventを
  引数として渡される。
  引数はStateMachineFactory#makeの引数として与えられると、
  それが各状態遷移で使いまわされる。

- ApplicationImpl、ContainerImpl、JobImpl、TaskImpl
  といったクラスはEventHandler実装ともなっていて、
  そのhandleメソッド内でStateMachine#doTransitionを呼び出すことで、
  自身の状態遷移を発生させる。

- Dispatcherは基本的にサービスにつき1つだけ、になっている。
  ApplicationImpl、ContainerImpl、JobImpl、TaskImpl
  などのeventHandlerフィールドにセットされているのは自分自身ではなく、
  コンストラクタの引数としてから渡された上記のグローバルなdispatcher。
  そこに登録されたTaskAttemptEventDispatcherのhandleメソッド内で、
  TaskAttemptImpl#handleが呼ばれるというような、多段構成になる。


ShuffleHandler
--------------

- ShuffleHandlerは
  tokenを使って作ったURLのhashをリクエスト/リプライのヘッダにつけることで、
  通信相手が正しいかをチェックする。

- ShuffleHandlerはJobTokenその他を格納するためにleveldbを利用する。

    
log aggregation
---------------

- http://hortonworks.com/blog/simplifying-user-logs-management-and-access-in-yarn/

- log.aggregationのON/OFFでLogAggregationServiceかNonAggregatingLogHandlerかに分かれる。

- デフォルトではHDFS上の/tmp/logs下にディレクトリが作られる。
  ファイルはコンテナ単位で格納。

- MapReduce固有ではなく、YARNの機能

- LogAggregationServiceがContainerManagerImplの中で動いていて、
  hdfs:///tmp/log/ユーザ名
  の下にタスクログを1ファイルにまとめた形で置く。

- 集めたログにアクセスするためのLogsCLIが用意されていて、
  ``yarn logs`` コマンドで実行することができる。


JobHistoryServer
----------------

- ``mapred historyserver`` コマンドで起動されるmapreduce固有モジュール。

- HSAdminRefreshProtocolService で定義されたRPCがあるが、
  それほど細かいことができるわけではない。

- HistoryServerFileSystemStateStoreServiceが(HDFS上の)ファイルとして、
  ジョブ情報を保存する。

- HistoryServerStateStoreServiceの実装によっては、
  historyがファイルで保存されるとも限らなくなるのか...
  と思っていたら、そもそもTimelineServerに移行される方向性になっている。
  まだまだ時間がかかりそうではあるけど。

- historyサーバがいると
  mapreduce.jobhistory.intermediate-done-dir
  から
  mapreduce.jobhistory.done-dir
  の下にhistoryファイルが移動される。

- historyserverは3分に1回ディレクトリをスキャンしている様子。::

   14/11/02 13:22:16 INFO hs.JobHistory: Starting scan to move intermediate done files
   14/11/02 13:25:16 INFO hs.JobHistory: Starting scan to move intermediate done files
   14/11/02 13:28:16 INFO hs.JobHistory: Starting scan to move intermediate done files

- historyserverは設定更新系のAPIしか提供していない。
  アプリケーションとは独立にディレクトリをスキャンしている。
  ファイルの移動はスキャンされるまで行われない。


ApplicationHistoryServer
------------------------

- bin/yarn timelineserverで実行される新しい方。
  
- メインクラスは、
  org.apache.hadoop.yarn.server.applicationhistoryservice.ApplicationHistoryServer。
  コード中ではTimelineという単語が多いので、そのうちリネームされるのだろうか?


cgroups
-------

- /proc/mountsの中身をparseして、
  typeがcgroupで、optionsの中にcpuを含むもののマウントポイントを探す。

  - さらにCgroupsLCEResourcesHandler.java#initializeControllerPathsで、
    その下のhadoop-yarn(デフォルト値)というFileが書き込み可能かどうかのチェックが入る。
    これは、LinuxContainerExecutor#initから呼ばれるので、
    ちゃんと設定できていないとNodeManagerは起動に失敗する。

- 基本はcpu.sharesで分配を制御する。
  yarn.nodemanager.linux-container-executor.cgroups.strict-resource-usageがtrueならば、
  cfs_period_usとcfs_quota_usの値もセットされる。


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

- HBaseのLogWriterはSequenceFileLogWriterではなくProtobufLogWriterがデフォルトに変わった。

- master自体が内部的にregionserverを開くようになったので、
  擬似分散環境では以下のようにポート番号をずらさないと、
  Addless already in useで起動に失敗する。::

    $ bin/local-regionservers.sh start 1

- Table#flushCommitsは廃止された。(HBASE-12802)
  Connection#getBufferedMutatorで取得できるBufferedMutator#flushを使う必要がある。(HBASE-12728)


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
