-----
Ozone
-----

.. contents::


cli
===

- CLIは、picocliを使っている。

- Ozoneシェルの場合、
  `サブコマンドはServiceLoaderを使ってロード <https://github.com/apache/ozone/blob/ozone-1.4.1/hadoop-hdds/common/src/main/java/org/apache/hadoop/hdds/cli/GenericCli.java#L68-L78>`_
  する。
  getParentTypeがOzoneSHell.classを返すSubcommandWithParentの実装が、OzoneShellのサブコマンド。

- さらに下位のサブコマンドでは、
  `静的に指定<https://github.com/apache/ozone/blob/ozone-1.4.1/hadoop-ozone/tools/src/main/java/org/apache/hadoop/ozone/shell/volume/VolumeCommands.java#L41-L53>`_
  されていたりもする。


rpc
===

misc
----

- `ozone sh key put` したときの処理の流れ

  - `CreateKeyRequest <https://github.com/apache/ozone/blob/ozone-1.4.0/hadoop-ozone/common/src/main/java/org/apache/hadoop/ozone/om/protocolPB/OzoneManagerProtocolClientSideTranslatorPB.java#L679>`_
    を送る。

  - `OMKeyCreateRequest <https://github.com/apache/ozone/blob/ozone-1.4.0/hadoop-ozone/ozone-manager/src/main/java/org/apache/hadoop/ozone/om/request/key/OMKeyCreateRequest.java>`_
    のロジックがmaster側で実行される。

    - `HA構成かどうかで分岐 <https://github.com/apache/ozone/blob/ozone-1.4.0/hadoop-ozone/ozone-manager/src/main/java/org/apache/hadoop/ozone/protocolPB/OzoneManagerProtocolServerSideTranslatorPB.java#L206-L242>`_
      がある。HAだと、Ratisでリクエストを送る。 `OMClientRequest#preExecute` の部分は、どちらにせよその前に、このmaster上で実行される。

    - `SCMのallocateBlockを呼び出して <https://github.com/apache/ozone/blob/ozone-1.4.0/hadoop-ozone/ozone-manager/src/main/java/org/apache/hadoop/ozone/om/request/key/OMKeyCreateRequest.java#L140-L154>`_
      ブロックを確保する。ブロックの格納先情報は、レスポンスとしてクライアントに戻る。

    - `キーのキャッシュ情報を更新 <https://github.com/apache/ozone/blob/ozone-1.4.0/hadoop-ozone/ozone-manager/src/main/java/org/apache/hadoop/ozone/om/request/key/OMKeyCreateRequest.java#L314-L326>`_
      する。RocksDBに書くのは、もっと後のcommitするとき。

- ProtocolBuffer2と3それぞれのためのコードを、
  `同じ.protoファイル <https://github.com/apache/ozone/tree/ozone-1.4.0/hadoop-ozone/interface-client/src/main/proto>`_
  から生成している。
  `その過程でパッケージ名を3用に動的に書き換え <https://github.com/apache/ozone/blob/ozone-1.4.0/hadoop-ozone/interface-client/pom.xml#L111-L156>`_
  している。


om
--


- `HDDS-7309 <https://issues.apache.org/jira/browse/HDDS-7309>`_
  によって、一度OMのRPCはgRPC実装がデフォルトになったが、性能上の問題が出たので、
  `HDDS-9446 <https://issues.apache.org/jira/browse/HDDS-9446>`_
  によってHadoop RPC実装がデフォルトに戻された。
  gRPCに関する問題がクリアされたら、また変わると考えられる。

- gRPC版実装は、S3 gatewayからOzoneManagerへのアクセスについて、
  `Hadoop RPCの仕様ベースで、リクエスト単位で認証するために、クライアントインスタンスを毎回作りなおす非効率を解消する目的 <https://github.com/apache/ozone/blob/ozone-1.4.1/hadoop-hdds/docs/content/design/s3-performance.md>`_
  で、
  `HDDS-4440 <https://issues.apache.org/jira/browse/HDDS-4440>`_
  によって作られた。
  OzoneManagerでは現状、
  `s3g用のgRPC版RPCServerが、基本のRpcServerとは別に起動 <https://github.com/apache/ozone/blob/ozone-1.4.1/hadoop-ozone/ozone-manager/src/main/java/org/apache/hadoop/ozone/om/OzoneManager.java#L708-L711>`_
  している。


scm
---

- scmは
  `複数のプロトコル <https://github.com/apache/ozone/tree/ozone-1.4.1/hadoop-hdds/interface-server/src/main/proto>`_
  を、複数のserverインスタンスを使ってserveしている。
  .protoのファイル名とプロトコル名称が微妙にマッチしていないのは、歴史的経緯だろうか。

  - `omがblockの操作に使うScmBlockLocationProtocol <https://github.com/apache/ozone/blob/ozone-1.4.1/hadoop-hdds/interface-server/src/main/proto/ScmServerProtocol.proto#L34-L42>`_

  - `StorageContainerLocationProtocol <https://github.com/apache/ozone/blob/ozone-1.4.1/hadoop-hdds/interface-admin/src/main/proto/ScmAdminProtocol.proto#L145-L187>`_

  - `datanodeがscmとのやりとりに使うStorageContainerDatanodeProtocol <https://github.com/apache/ozone/blob/ozone-1.4.1/hadoop-hdds/interface-server/src/main/proto/ScmServerDatanodeHeartbeatProtocol.proto>`_

  - 認証のための `あれこれ <https://github.com/apache/ozone/blob/ozone-1.4.1/hadoop-hdds/server-scm/src/main/java/org/apache/hadoop/hdds/scm/server/SCMSecurityProtocolServer.java>`_ 。

    - `ScmSecurityProtocol <https://github.com/apache/ozone/blob/ozone-1.4.1/hadoop-hdds/interface-server/src/main/proto/ScmServerSecurityProtocol.proto>`_

    - `ScmSecretKeyProtocol <https://github.com/apache/ozone/blob/ozone-1.4.1/hadoop-hdds/interface-server/src/main/proto/ScmSecretKeyProtocol.proto>`_



compose
=======

とりあえず手元で動かして実験するには、
`docker-compose用の資材 <https://github.com/apache/ozone/blob/ozone-1.4.0/hadoop-ozone/dist/src/main/compose/ozone/README.md>`_
が利用できる。

コンテナにはldbコマンドが用意されているので、RocksDBの中身を覗いてみることができる。

::

  $ docker exec -i -t ozone-om-1 /bin/bash
  
    $ ldb --db=/data/metadata/om.db list_column_families
    Column families in /data/metadata/om.db:
    {default, fileTable, principalToAccessIdsTable, deletedTable, userTable, s3SecretTable, transactionInfoTable, openKeyTable, snapshotInfoTable, directoryTable, prefixTable, compactionLogTable, multipartInfoTable, volumeTable, tenantStateTable, deletedDirectoryTable, tenantAccessIdTable, openFileTable, snapshotRenamedTable, dTokenTable, metaTable, keyTable, bucketTable}
    
    $ ldb --db=/data/metadata/om.db --column_family=fileTable --max_keys=1 scan | strings
    
    /-9223372036854775552/-9223372036854775040/-9223372036854775040/README.md :
    vol1
    bucket1
            README.md

::

  $ docker exec -i -t ozone-datanode-1 /bin/bash
  
    $ ldb \
        --db=/data/hdds/hdds/CID-35c6416b-9ea8-473b-aa2a-5fcf7bd487ea/DS-7c62ebf2-58e3-436c-8435-80d4a6d3dfa6/container.db/ \\
        --column_family=block_data \\
        --max_keys=1 \\
        --hex \\
        scan
    0x00000000000000017C313133373530313533363235363030303031 : 0x0A0E080110818080E097E587CA0118021A0B0A045459504512034B4559222F0A1A3131333735303135333632353630303030315F6368756E6B5F31100018E41F2A0C0802108080011A043FE8A01C28E41F



rocksdb
=======

- Datanode上では、container毎にrocksdbのインスタンスが作られていたが、
  `HDDS-3630 <https://issues.apache.org/jira/browse/HDDS-3630>`_
  でそれをやめて一つにした。


references
==========

- https://blog.cloudera.com/apache-ozone-metadata-explained/
