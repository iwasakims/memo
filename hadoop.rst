.. contents::


assembly
========

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
=======

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


バイト列の操作
==============

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
l
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
--------

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

- 認証方法がTOKENかKERBEROSかはSaslRpcClientとServerとのネゴシエーションの過程で決まる。
  ServerをnewするときにDelegationTokenSecretManagerが与えられていると、
  Server#getAuthMethodsはTOKENとKERBEROSの両方を含むListを返す。
  これは、RpcResponseHeaderProto.authsとして、ネゴシエーションの際にクライアントに送られる。
  クライアント側のUserGroupInformationsのCredentialsに対応するtokenがロード済みであれば、
  SaslClient#createSaslClientはこれを元に、SaslClientCallbackHandlerを仕込む。

- ジョブ実行のためのdelegation tokenは、
  AMを起動するためのAMのContainerLaunchContextの一部として、
  submitApplicationするときにResourceManagerに渡される。


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

- MD5MD5CRC32については、
  DFSClient#getFileChecksumを見るのが参考になる。
  DataNodeから各ブロックのmd5を取得し、全ブロック分のバイト列のdigestを取得する。

  - ブロックのmd5はDataXceiver#blockChecksumの中で都度計算される。
    .metaの中のcrc32すべてに対してdigestを取る。


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


short circuit local read
------------------------

DataTransferProtocol#requestShortCircuitShmが呼ばれると、
/dev/shm/HadoopShortCircuitShm_DFSClient_NONMAPREDUCE_893981988_1_1350490027
みたいな名前の共有メモリ領域(ShortCircuitShm)を(まだなければ)つくる。
ファイルサイズは8kiBで、64バイトのスロット128個分に相当する。
1つのスロットが1ブロックに関するやりとりに使る。
スロットには、このブロックが健在か、mlockされているか(i.e. mmap経由のzero-copy read可能か)、参照カウント、このスロットのメモリアドレス、ブロックID(ExtendedBlockId)が格納されている。
クライアント側は、この共有メモリセグメントのファイルディスクリプタを、
(DataTransferProtocol#requestShortCircuitShmの場合と同じ要領で)ドメインソケット経由で受け取る。

DataNode内で動くDomainSocketWatherはこの共有メモリ領域のFDをpollし、対向が落ちたらメモリ領域をクリアする。
DomainSocketWatherはDFSClient内にもいて、同じことをやっている。

mmap経由のzero-copy readはHasEnhancedByteBufferAccessというinterfaceで規定されている。
zero-copy readできるのは、DataNode側でmlockされているブロックを、チェックサムなしで読むときのみ。
クライアントはmlockされているかどうかを、上記のShortCircuitShmを使って判断する。
クライアントがzero-copy readを始める際に共有メモリセグメントを更新し、read中はDataNodeがそのブロックをmunlockしないようにする。
zero-copy可能な場合はMappedByteBufferを返すが、そうでないときはByteBufferPoolを利用してallocateしたByteBufferを返すモードにfall backする。
HBaseはこの機能は使っていない。ブロックキャッシュに載せるためにバイト列コピーするから? see also HBASE-21879.

short circuit read用のFielInputStreamとMappedByteBufferは、
DFSClient内で、複数のスレッドから共用できるようにするため、ShortCircuitCacheで管理される。


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


cgroup
------

- /proc/mountsの中身をparseして、

- `ResourceHandlerModule <https://github.com/apache/hadoop/blob/rel/release-3.2.2/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-nodemanager/src/main/java/org/apache/hadoop/yarn/server/nodemanager/containermanager/linux/resources/ResourceHandlerModule.java>`_
  というクラスが、新しい仕組み。

- CgroupsLCEResourcesHandlerは、
  `YARN-3542 <https://issues.apache.org/jira/browse/YARN-3542>`_
  でdeprecatedになり、内部的には使われなくなった。

  - CPUの制御を有効にする場合、以下が新しい設定方法。

      <property>
        <name>yarn.nodemanager.resource.cpu.enabled</name>
        <value>true</value>
      </property>

  - 以下の旧設定は、
    `上記と同じ効果 <https://github.com/apache/hadoop/blob/rel/release-3.2.2/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-nodemanager/src/main/java/org/apache/hadoop/yarn/server/nodemanager/containermanager/linux/resources/ResourceHandlerModule.java#L144-L151>`_
    を持つ。::

      <property>
        <name>yarn.nodemanager.linux-container-executor.resources-handler.class</name>
        <value>org.apache.hadoop.yarn.server.nodemanager.util.CgroupsLCEResourcesHandler</value>
      </property>

- デフォルトの設定では、 ``yarn.nodemanager.resource.memory.enforced`` がtrue、
  かつ ``yarn.nodemanager.elastic-memory-control.enabled`` がfalseなので、
  ``yarn.nodemanager.{pmem|vmem}-check-enabled`` によるcontainerのkillが
  `実行されない <https://github.com/apache/hadoop/blob/rel/release-3.2.2/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-server/hadoop-yarn-server-nodemanager/src/main/java/org/apache/hadoop/yarn/server/nodemanager/containermanager/monitor/ContainersMonitorImpl.java#L762-L765>`_
  ように見える。



KMS
===

ZKSignerSecretProviderとZKDelegationTokenSecretManagerは、
内部でcurator(zk client)のインスタンスを共用している。
前者のZK接続用の設定あれば、後者に要らないというか、設定が使われない。
現実的なケースではないが、ZKSignerSecretProviderを使わない
(hadoop.kms.authentication.signer.secret.provider=random or string)
にもかかわらず、ZKDelegationTokenSecretManagerを使う
(hadoop.kms.authentication.zk-dt-secret-manager.enable=true)
という場合には、
hadoop.kms.authentication.zk-dt-secret-manager.*にZK接続用設定を書かないと、
機能しない。
ちなみに、前者と後者のZK接続用設定のプロパティ名には統一感がない。::

  <property>
    <name>hadoop.kms.authentication.signer.secret.provider</name>
    <value>zookeeper</value>
  </property>
  <property>
    <name>hadoop.kms.authentication.signer.secret.provider.zookeeper.path</name>
    <value>/hadoop-kms/hadoop-auth-signature-secret</value>
  </property>
  <property>
    <name>hadoop.kms.authentication.signer.secret.provider.zookeeper.connection.string</name>
    <value>localhost:2181</value>
  </property>
  <property>
    <name>hadoop.kms.authentication.signer.secret.provider.zookeeper.auth.type</name>
    <value>none</value>
  </property>

  <property>
    <name>hadoop.kms.authentication.zk-dt-secret-manager.enable</name>
    <value>true</value>
  </property>
  <property>
    <name>hadoop.kms.authentication.zk-dt-secret-manager.zkConnectionString</name>
    <value>localhost:2181</value>
  </property>
  <property>
    <name>hadoop.kms.authentication.zk-dt-secret-manager.zkAuthType</name>
    <value>none</value>
  </property>


Kerberos authN on CentOS7 and HDP2.6.2
======================================

setting up and starting krb5-server
-----------------------------------

::

  sudo yum install krb5-server krb5-libs krb5-workstation
  sudo vi /etc/krb5.conf
  sudo vi /var/kerberos/krb5kdc/kdc.conf
  sudo kdb5_util create -s
  sudo kadmin.local -q "addprinc centos/admin"
  sudo systemctl start krb5kdc.service
  sudo systemctl start kadmin.service
  
  sudo mkdir /etc/security/keytab

The line below must be commented out in /etc/krb5.conf
otherwise hadoop client library can not find cached credential.::

  default_ccache_name = KEYRING:persistent:%{uid}

adding principals and writing keytab file by kadmin::

  addprinc -randkey nn/localhost@EXAMPLE.COM
  addprinc -randkey dn/localhost@EXAMPLE.COM
  addprinc -randkey rm/localhost@EXAMPLE.COM
  addprinc -randkey nm/localhost@EXAMPLE.COM
  addprinc -randkey http/localhost@EXAMPLE.COM
  ktadd -k /etc/security/keytab/nn.service.keytab nn/localhost@EXAMPLE.COM
  ktadd -k /etc/security/keytab/nn.service.keytab http/localhost@EXAMPLE.COM
  ktadd -k /etc/security/keytab/dn.service.keytab dn/localhost@EXAMPLE.COM
  ktadd -k /etc/security/keytab/dn.service.keytab http/localhost@EXAMPLE.COM
  ktadd -k /etc/security/keytab/rm.service.keytab rm/localhost@EXAMPLE.COM
  ktadd -k /etc/security/keytab/rm.service.keytab http/localhost@EXAMPLE.COM
  ktadd -k /etc/security/keytab/nm.service.keytab nm/localhost@EXAMPLE.COM
  ktadd -k /etc/security/keytab/nm.service.keytab http/localhost@EXAMPLE.COM


setting up Hadoop
-----------------

editing core-site.xml::

  <property>
    <name>hadoop.security.authentication</name>
    <value>kerberos</value>
  </property>
  <property>
    <name>hadoop.security.auth_to_local</name>
    <value>
      RULE:[2:$1](nn)s/^.*$/hdfs/
      RULE:[2:$1](jn)s/^.*$/hdfs/
      RULE:[2:$1](dn)s/^.*$/hdfs/
      RULE:[2:$1](nm)s/^.*$/yarn/
      RULE:[2:$1](rm)s/^.*$/yarn/
      RULE:[2:$1](jhs)s/^.*$/mapred/
      DEFAULT
    </value>
  </property>

editing hdfs-site.xml::

  <property>
    <name>dfs.block.access.token.enable</name>
    <value>true</value>
  </property>
  <property>
    <name>dfs.namenode.keytab.file</name>
    <value>/etc/security/keytab/nn.service.keytab</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.principal</name>
    <value>nn/localhost@EXAMPLE.COM</value>
  </property>
  <property>
    <name>dfs.namenode.kerberos.internal.spnego.principal</name>
    <value>http/localhost@EXAMPLE.COM</value>
  </property>
  
  <property>
    <name>dfs.data.transfer.protection</name>
    <value>authentication</value>
  </property>
  <property>
    <name>dfs.datanode.keytab.file</name>
    <value>/etc/security/keytab/dn.service.keytab</value>
  </property>
  <property>
    <name>dfs.datanode.kerberos.principal</name>
    <value>dn/localhost@EXAMPLE.COM</value>
  </property>
  
  <property>
    <name>dfs.http.policy</name>
    <value>HTTPS_ONLY</value>
  </property>
  <property>
    <name>dfs.web.authentication.kerberos.keytab</name>
    <value>/etc/security/keytab/nn.service.keytab</value>
  </property>
  <property>
    <name>dfs.web.authentication.kerberos.principal</name>
    <value>http/localdomain@EXAMPLE.COM</value>
  </property>

editing yarn-site.xml::

  <property>
    <name>yarn.resourcemanager.principal</name>
    <value>rm/localhost@EXAMPLE.COM</value>
  </property>
  <property>
    <name>yarn.resourcemanager.keytab</name>
    <value>/etc/security/keytab/rm.service.keytab</value>
  </property>
  <property>
    <name>yarn.nodemanager.principal</name>
    <value>nm/localhost@EXAMPLE.COM</value>
  </property>
  <property>
    <name>yarn.nodemanager.keytab</name>
    <value>/etc/security/keytab/nm.service.keytab</value>
  </property>
  <property>
    <name>yarn.nodemanager.container-executor.class</name>
    <value>org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor</value>
  </property>
  <property>
    <name>yarn.nodemanager.linux-container-executor.group</name>
    <value>hadoop</value>
  </property>
  <property>
    <name>yarn.nodemanager.linux-container-executor.path</name>
    <value>/usr/hdp/2.6.2.0-205/hadoop-yarn/bin/container-executor</value>
  </property>

editing mapred-site.xml::

  <property>
    <name>mapreduce.application.classpath</name>
    <value>/usr/hdp/current/hadoop-mapreduce-client/../hadoop-mapreduce/*,
      /usr/hdp/current/hadoop-mapreduce-client/../hadoop-mappreduce/lib/*,
      /usr/hdp/current/hadoop-mapreduce-client/../hadoop/*,
      /usr/hdp/current/hadoop-mapreduce-client/../hadoop/lib/*,
      /usr/hdp/current/hadoop-mapreduce-client/../hadoop-yarn/*,
      /usr/hdp/current/hadoop-mapreduce-client/../hadoop-yarn/lib/*,
      /usr/hdp/current/hadoop-mapreduce-client/../hadoop-hdfs/*,
      /usr/hdp/current/hadoop-mapreduce-client/../hadoop-hdfs/lib/*,
    </value>
  </property>
  
editing container-executor.cfg::

  yarn.nodemanager.linux-container-executor.group=hadoop
  banned.users=hdfs,yarn
  min.user.id=1000
  allowed.system.users=none

changing the owner of container-executor along with the config.::

  sudo chown root:hadoop /usr/hdp/current/hadoop-yarn-nodemanager/bin/container-executor
  sudo chmod 6050 /usr/hdp/current/hadoop-yarn-nodemanager/bin/container-executor

setting up keystore::

  sudo keytool -keystore /var/lib/keystores/.keystore -genkey -alias http -keyalg RSA

editing ssl-server.xml::

  <property>
    <name>ssl.server.keystore.location</name>
    <value>/var/lib/keystores/.keystore</value>
  </property>
  <property>
    <name>ssl.server.keystore.password</name>
    <value>serverfoo</value>
    <description>Must be specified.
    </description>
  </property>
  <property>
    <name>ssl.server.keystore.keypassword</name>
    <value>serverbar</value>
  </property>


Setup by Ansible
================

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


