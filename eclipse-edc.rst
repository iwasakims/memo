-----------
eclipse-edc
-----------

.. contents::


Rebranding
==========

- 元々はEclipse Dataspace Connectorだったが、Eclipse Dataspace Componentsにrebrandされた。

  - https://github.com/eclipse-edc/Connector/discussions/2244

  - URLも https://github.com/eclipse-dataspaceconnector/DataSpaceConnector から
    https://github.com/eclipse-edc/Connector に変わった。
    古いURLでもアクセス可能。


Connector
=========

Overview
--------

- EDCはIDSのリファレンスをそのまま踏襲するものではない。

  - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/blob/main/docs/README.md#statement-edc-vs-ds
  - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/discussions/1037
  - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/tree/main/docs/developer/decision-records/2022-06-02-ids-serializer

- JettyとJerseyを使ってREST APIをserve

- idscp2は利用/対応しない

- IDSコネクタと連携するためのREST APIの口がある。

  - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/issues/1563

- ServeceLoaderと独自アノテーションを使ったフレームワークを独自実装

  - org.eclipse.dataspaceconnector.spi.system.ServiceExtensionの実装を、
    いろいろ組み合わせてコネクタとして機能するまとまりを形成する。

  - Extensionは、他のExtension(がregisterするService)に依存する形で作られがち。
    モジュール間の依存関係は、build.gradle.ktsに書くが、
    どのServiceがどのモジュールのどのExtensionにあるかは自明ではない。
    Extension間のdependency hellみたいになりそうな。

  - ServiceLoaderでロードするための
    META-INF/services/org.eclipse.dataspaceconnector.spi.system.ServiceExtension
    が用意されている。コード上のモジュール間のつながりは見えにくい。
    build.gradle.ktsを見ると、どこで使われているは分かる。::

      $ find . -name build.gradle.kts | xargs grep iam-mock
      ./extensions/common/iam/iam-mock/build.gradle.kts:        create<MavenPublication>("iam-mock") {
      ./extensions/common/iam/iam-mock/build.gradle.kts:            artifactId = "iam-mock"
      ./extensions/control-plane/api/data-management-api/catalog-api/build.gradle.kts:    testImplementation(project(":extensions:common:iam:iam-mock"))
      ./system-tests/e2e-transfer-test/control-plane/build.gradle.kts:    implementation(project(":extensions:common:iam:iam-mock"))
      ...

  - ソースツリーは最近リファクタリングされた。しかし、上記の課題が解決するわけではない。
    https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/blob/main/docs/developer/decision-records/2022-08-09-project-structure-review/README.md

  - extensionの依存関係が循環していると、ロード時にエラーになる。see `ExtensionLoader#loadServiceExtensions`.

  - gradleのdependenciesタスクを使うと、依存関係をツリー表示できる。::

      $ ./gradlew -p system-tests/e2e-transfer-test/control-plane-postgresql -q dependencies --configuration compileClasspath | grep project
      +--- project :system-tests:e2e-transfer-test:control-plane
      +--- project :extensions:control-plane:store:sql:control-plane-sql
      +--- project :extensions:common:sql:pool:apache-commons-pool-sql
      |    +--- project :spi:common:transaction-datasource-spi
      |    |    \--- project :spi:common:core-spi
      |    |         \--- project :core:common:policy-evaluator
      |    \--- project :extensions:common:sql:common-sql
      |         \--- project :spi:common:core-spi (*)
      +--- project :extensions:common:transaction:transaction-local
      |    +--- project :spi:common:core-spi (*)
      |    \--- project :spi:common:transaction-spi
      

SPI
---

- #1832 で多少整理された感がある。
  https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/pull/1832

- どのモジュールがどのSPIを実装してるのかは、モジュールの依存関係から見るのが早いのかな..?::

    $ find . -name build.gradle.kts | xargs grep 'project.*:spi:'
    ./core/data-plane-selector/data-plane-selector-core/build.gradle.kts:    api(project(":spi:data-plane-selector:data-plane-selector-spi"))
    ./core/data-plane/data-plane-framework/build.gradle.kts:    api(project(":spi:common:core-spi"))
    ./core/data-plane/data-plane-framework/build.gradle.kts:    api(project(":spi:data-plane:data-plane-spi"))
    ./core/data-plane/data-plane-util/build.gradle.kts:    api(project(":spi:data-plane:data-plane-spi"))
    ./core/data-plane/data-plane-core/build.gradle.kts:    api(project(":spi:common:web-spi"))
    ...

- DataManagement APIはdata-planeではなくcontrol-planeのSPIの実装というのは、名前的に分かりにくい。
  https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/tree/main/extensions/control-plane/api/data-management
  ::

    $ find ./extensions/control-plane/api/data-management -name build.gradle.kts | xargs grep '\-spi'
    ./extensions/control-plane/api/data-management/contractnegotiation-api/build.gradle.kts:    api(project(":spi:control-plane:control-plane-spi"))
    ./extensions/control-plane/api/data-management/contractnegotiation-api/build.gradle.kts:    api(project(":spi:common:transaction-spi"))
    ./extensions/control-plane/api/data-management/contractdefinition-api/build.gradle.kts:    api(project(":spi:control-plane:control-plane-spi"))
    ./extensions/control-plane/api/data-management/contractdefinition-api/build.gradle.kts:    api(project(":spi:common:transaction-spi"))
    ./extensions/control-plane/api/data-management/catalog-api/build.gradle.kts:    implementation(project(":spi:common:catalog-spi"))
    ./extensions/control-plane/api/data-management/asset-api/build.gradle.kts:    api(project(":spi:control-plane:control-plane-spi"))
    ./extensions/control-plane/api/data-management/asset-api/build.gradle.kts:    api(project(":spi:common:transaction-spi"))
    ./extensions/control-plane/api/data-management/transferprocess-api/build.gradle.kts:    api(project(":spi:common:transaction-spi"))
    ./extensions/control-plane/api/data-management/transferprocess-api/build.gradle.kts:    api(project(":spi:control-plane:transfer-spi"))
    ./extensions/control-plane/api/data-management/contractagreement-api/build.gradle.kts:    api(project(":spi:control-plane:control-plane-spi"))
    ./extensions/control-plane/api/data-management/policydefinition-api/build.gradle.kts:    api(project(":spi:control-plane:contract-spi"))
    ./extensions/control-plane/api/data-management/policydefinition-api/build.gradle.kts:    api(project(":spi:control-plane:policy-spi"))
    ./extensions/control-plane/api/data-management/policydefinition-api/build.gradle.kts:    api(project(":spi:common:transaction-spi"))


REST API
--------

- `web.http.{context}.path` and `web.http.{context}.port` のような設定プロパティの組で、ポートとpathの組を指定する。

  - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/blob/main/extensions/http/jetty/src/main/java/org/eclipse/dataspaceconnector/extension/jetty/JettyConfiguration.java#L29-L64

  - 例: https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/blob/main/extensions/data-plane/data-plane-api/src/test/java/org/eclipse/dataspaceconnector/dataplane/api/controller/DataPlaneApiIntegrationTest.java#L96-L102

  - web.http.data.pathとweb.http.data.portで、data management API用の設定を指定する。
    DataManagementApiConfigurationを参照するコードが、data management API用のパーツということになる。
    
    - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/blob/main/extensions/control-plane/api/data-management/api-configuration/src/main/java/org/eclipse/dataspaceconnector/api/datamanagement/configuration/DataManagementApiConfigurationExtension.java

    - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/pull/714

- Swaggerのアノテーションを利用して、*.yamlなどを生成している。

  - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/tree/main/docs/developer/decision-records/2022-03-15-swagger-annotations

  - resolveタスク、mergeOpenApiFilesタスク、generateSwaggerUiタスクを順に実行すると、Webブラウザで閲覧可能なドキュメント(docs/swaggerui)が更新される。
    https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/blob/main/docs/developer/openapi.md

  - connector同士がやりとりするためのIDSのAPIは、Swaggerによるドキュメント生成の対象外になっている。
    https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/issues/1563


statemachine
------------

- StateMachineManagerが使われるのは3か所。

  - ContractServiceExtensionで初期化される
    ProviderContractNegotiationManagerと、ConsumerContractNegotiationManager。

  - CoreTransferExtensionで初期化されるTransferProcessManager。

  - どちらもテスト用にWaitStrategyを差し込み可能になっている。

    - see NegotiationWaitStrategy and TransferWaitStrategy


transferprocess
---------------

- /transferprocess は、consumer connectorが、データ転送のためのリクエストを受けるAPI。

  - sourceは、ContractAgreementに含まれるassetIdで指定される。

  - destinationは、dataDestinationで具体的にtypeとその他propertyで指定される。
    例えばAzure Blobだと、typeはAzureStorageで、
    accountでストレージアカウント名、containerはcontainer名を指す。

- リクエストが呼ばれると、TransferProcessインスタンスが作成され、
  状態(state)を含む情報がTransferProcessStoreに保存される。
  StateMachineManagerのスレッドがprocess*を順次呼び出すことで、
  TransferProcessの状態は遷移していく。

  - processInitialで、destinationのtypeに応じて必要なら、
    登録されたConsumerResourceManifestGeneratorにが、ResourceDefinitionを作成する。
    現状destinationがAzure Blog/Amazon S3/GCSのオブジェクトの場合に、この処理が入る。

  - processProvisioningで、上記のResourceDefinitionに応じて、
    ProvisionManagerが登録されたProvisioner実装を利用して、resourceを作成する。
    destinationがAzure Blog/Amazon S3/GCSのオブジェクトの場合に、
    container/bucketを(無ければ)作成し、provider connecterに書き込みを許可するための、
    tokenを作成する。

  - processRequestingで、provider connectorにDataRequestを送る。
    リクエストはRemoteMessageDispatcherを利用して送信されるが、
    現時点で実装はids-multipart用のものしかない様子。

    - DataRequestメッセージ送信を行うのは、MultipartArtifactRequestSender。
    
    - DataRequestメッセージを受信したprovider connector側では、
      ArtifactRequestHandlerがリクエストを処理する。
      ここでも、consumer側と同じようにTransferProcessManagerImplが使われ、
      TransferProcessが作られる。
      consumer側のTransferProcessとは独立だが、同じDataRequestのidに紐づくので、
      consumerとproducerでTransferProcessStoreは独立になっていないとダメ。
      
      - (provider側の)processProvisioningの段階で、initiateDataTransferが呼ばれ、
        DataFlowManagerを介して、data-planeの処理が呼ばれる。

        - DataFlowManagerは、ただHttpProxyなdestinationを追加するために追加された??

      - DataPlaneSelectorで、接続先を選択する。
        DataPlaneSelectorも、個別に建ててREST APIでアクセスする方式を取れる。

       - 接続先を示すDataplaneInstanceは、
         data-plane-selector-apiの提供するREST API(/instances)で、事前に追加(定義)する。

      - DataPlaneClientで、DataFlowRequestをdata-planeに送る。
        DataPlaneManagerが同居しているどうかで、クラスが違う。
        EmbeddedDataPlaneTransferClientとRemotDataPlaneTransferClientがある。

  - processInprogressで、StatusChecker実装が、transferが終わったか確認する。
    Azure Blobだと、container内に、名前のsuffixが".complete"なblobがあるかを見る。

  - provider側でsink.transfer(source)という形で、データコピーが実行される。
    sinkはconsumer側に属するリソースなので、書き込み権限をどうやって与えるかがポイントになる。
    例えば、sinkがAzure Blobなら、consumer側のコネクタが、自身のstorage accountで、
    コンテナと、書き込みのにを許すSASトークンを作成し、それをvault経由でprovider側が読めるようにする。


data-plane
----------

- https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/issues/463

- DataPlaneFrameWorkExtensionが本体。
  サンプル類はdata-plane-coreにdependencyを付けてロードしている。

- TransferServiceがリクエストをvalidate。
  現状の実装はPipelineServiceTransferServiceImplしかないような。

- PipelineServiceImpl#transferがデータコピー処理の本体。
  sink.transfer(source) する。

- (data-plane-apiモジュールの)DataPlaneApiExtensionが、REST APIを提供する。
  controlとpublicという2種類のcontextを使い分ける。
  そのため、web.http.control.*とweb.http.public.*の2種類の設定(port mapping)が必要。
  DataFlowRequestを受け取る/transferはcontrolの範疇。

- DataPlanePublicApiControllerは、transferされたデータをByteArrayOutputStreamで受け取って、
  クライアントにtoStringして渡すので、大きなデータを受け渡せるわけではない。


test
----

- `-PverboseTest` を指定すると、出力されるログが増える。::

    $ ./gradlew test -PverboseTest

- 特定のテストだけを実行したい場合は以下の要領。 ::

    $ ./gradlew extensions:api:data-management:transferprocess:test --tests '*TransferProcessEventDispatchTest'

- 特定のディレクトリ下のサブモジュールのテストすべてを実行したい場合は、 `-p` でディレクトリを指定する。::

    $ ./gradlew test -p extensions/api/data-management/transferprocess --tests '*TransferProcessEventDispatchTest'

- `@EndToEntTest` アノテーションがついたテストを実行するためには、以下の要領。::

    $ ./gradlew test -DincludeTags="EndToEndTest"

- `@PostgresqlDbIntegrationTest` アノテーションが付いたテストを実行する場合、下記の要領。::
  
    $ ./gradlew test -p system-tests/e2e-transfer-test/runner -DincludeTags="PostgresqlIntegrationTest"

  - アノテーションのクラス名とタグ名が一致していないので分かりにくい?
    https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/blob/main/common/util/src/testFixtures/java/org/eclipse/dataspaceconnector/common/util/junit/annotations/PostgresqlDbIntegrationTest.java#L31-L32

- JUnitのテストケース内でServiceExtension実装をテストするための枠組みが、
  core/common/junit下に定義されている。

  - EdcExtensionは、各テストメソッドの前後でbootしてshutdownするようなBaseRuntimeの拡張。
    テストクラスに `@ExtendWith(EdcExtension.class)` して利用する。

  - EdcExtensionはParameterResolverを実装しているので、
    テストメソッドの引数としてregister済みのサービス(mock)を指定できる。

  - `EdcExtension#registerServiceMock` はテスト用のserviceをregisterする。
    `ServiceExtensionContext#registerService` で既にregister済みのserviceでもオーバーライドできる。

  - `EdcExtension#registerSystemExtension` はテスト用にextensionをregisterする。
    `@Inject` なフィールドに `@Provider` なメソッドで生成したインスタンスをセットする処理は、
    `ExtensionLoader#bootServiceExtensions` で実行される。
    そのため、 `@BetoreEach` なメソッドの中など、bootされるタイミングより前で、
    呼び出しておかなければならない。


logging
-------

- ログの出力はMonitorというインターフェースで抽象化されている。
  明示的にMonitor実装がregisterされていない場合、
  ConsoleMonitorという単純な実装が使われる。
  ロギングライブラリは使用せずに、コンソールにログを出力する、


documentation
-------------

- ドキュメント自動生成用のモジュールやアノテーションの定義は、
  #2001で、DataSpaceConnectorとは別のソースツリーに移動された。
  https://github.com/eclipse-dataspaceconnector/GradlePlugins



versionining
============

- バージョンはずっと0.0.1-SNAPSHOTだったが、ソースコードを分割して、
  それぞれのリポジトリで非互換な修正が入るとビルドが通らなくなるので、
  ある瞬間を示すための0.0.1-20230301-SNAPSHOTのようなバージョン番号をつけて参照する形になった。

  - https://github.com/eclipse-edc/Connector/blob/e7a092bf81fc43b42c349d98e3e6ad3939f181a6/docs/developer/decision-records/2022-08-11-versioning_and_artifacts/README.md
  - https://github.com/eclipse-edc/MinimumViableDataspace/blob/8141afce75613f62ed236cb325a862b8af40b903/gradle.properties#L3-L7

- snapshotはNexusから取得できる。

  - https://oss.sonatype.org/#view-repositories;snapshots~browsestorage~org/eclipse/edc

- Maven Centralにpublishされるrelease artifactのバージョンは、0.0.1-milestone-8のような形式になった。

  - https://central.sonatype.com/search?q=org.eclipse.edc&smo=true&namespace=org.eclipse.edc

- 依存ライブラリのバージョン定義は、GradlePluginsリポジトリで定義された、
  edc-versionsというアーティファクトにまとめられた。

  - https://github.com/eclipse-edc/Connector/blob/cc5b34833574be9b5f20d7c128f4e1c6a840e129/docs/developer/version-catalogs.md
  - https://github.com/eclipse-edc/GradlePlugins/blob/96f9cc05047c111a547f6ac78168cb6ce9a84fd4/version-catalog/build.gradle.kts
  - https://github.com/eclipse-edc/GradlePlugins/blob/96f9cc05047c111a547f6ac78168cb6ce9a84fd4/gradle/libs.versions.toml

- ローカルで修正して試すには、ちょっと手順が必要。

  - まずGradlePlugins側のバージョン定義を修正したものをローカルリポジトリにインストールする。::

    $ ./gradlew publishToMavenLocal -Pskip.signing

  - Connector側のsettings.gradle.ktsのdependencyResolutionManagementのrepositoriesの部分を修正して、mavenLocal()を一番上に持ってくる。
    https://github.com/eclipse-edc/Connector/blob/2c4bf1529b538077c2dd2cccd12128c3202d7548/settings.gradle.kts#L31-L38

- その後、あまりうまくないことが分かり、各コンポーネントがバージョンカタログを持つやり方に変わった。

  - https://github.com/eclipse-edc/Connector/blob/e7a092bf81fc43b42c349d98e3e6ad3939f181a6/docs/developer/decision-records/2023-03-31-version-catalog-per-component/README.md

  -  GradlePlugins側にも、共通のパーツだけ少し残されてはいる。

    - https://github.com/eclipse-edc/GradlePlugins/blob/83ad790b6e521862db8f66b7985457176070da81/gradle/libs.versions.toml



docs
====

- 複数のサブモジュールのドキュメントをまとめて一つに見せる仕組みができてた。

  - https://github.com/eclipse-edc/docs
  - https://eclipse-edc.github.io/docs/#/README

- OpenAPIで生成したドキュメントはSwagger Hubでホストされることになったから、
  ソースツリー内のdocs/swaggeruiは削除された。

  - https://github.com/eclipse-edc/Connector/discussions/2329
  - https://github.com/eclipse-edc/Connector/pull/2328

  - バージョンが0.0.1-SNAPSHOTのまま、中身だけ変わっていくのだろうか??

    - https://app.swaggerhub.com/apis/eclipse-edc-bot/control-api
    - https://app.swaggerhub.com/apis/eclipse-edc-bot/management-api


Samples
=======

- samplesの内容は、個別のソースツリーに移動された。

  - https://github.com/eclipse-edc/Samples
  - https://github.com/eclipse-edc/Connector/pull/2362

- 4番が、雰囲気をつかむのによさそうな内容。
  https://github.com/eclipse-edc/Samples/tree/main/04.1-file-transfer-listener

  - consumer, providerはどちらも基本的なモジュールが同じ。
    providerには、リクエストされたファイル操作をするための、
    固有Extension(に附随するSourceとSink)が、追加でロードされる。

   - clientはconsumerにREST APIでリクエストを送る。consumerは受付情報的な内容をすぐにレスポンスとして返す。

   - consumerはclientリクエストを受けて、providerにリクエストを送る。

   - providerはそれを受けて、指定されたasset(ここではファイル)を、指定されたpathにコピーする。
     ここではproviderからconsumerに実データが送られたりするわけではない。
     データ転送の実処理はprovider(役のモジュール)側で完結している。

     - データの送り先としてS3のバケットとかを指定した場合も、同じイメージだろうか。

   - clientは受付情報から、依頼したデータ転送処理が終わったかどうかをpollingして確認する。

   - このサンプルでは、curlコマンドでリクエストを送る先が全部9192番ポートで、
     providerのdata management APIができることの範囲で完結している。

     - controlplaneやidsのAPIは叩かれない。

- consumerがHTTPレスポンスのbodyとしてデータを受け取るパターンは、e2e-transfer-testの方に例が追加された。

  - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/discussions/1361
  - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/blob/main/system-tests/e2e-transfer-test/runner/src/test/java/org/eclipse/dataspaceconnector/test/e2e/AbstractEndToEndTransfer.java#L38-L104
  - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/pull/639

  - 実行は以下の要領::

      $ ./gradlew system-tests:e2e-transfer-test:runner:test -DincludeTags="EndToEndTest" --tests '*EndToEndTransferInMemoryTest'

- providerは、assetのtypeを、canHandleなSourceから、
  dataDestinationのtypeを、canHandleなDestinationに、transferする。
  

MinimumViableDataspace
======================

- https://github.com/eclipse-dataspaceconnector/MinimumViableDataspace

- EDCを使ったDSのデモ

- ローカル実行のdocker-compose.ymlを見ると、なんとなく構成が分かる。
  https://github.com/eclipse-dataspaceconnector/MinimumViableDataspace/tree/main/system-tests

- AssetはAzureのBlob。ローカル環境ではAzuriteを利用。

- RegistrationServiceを利用。
  https://github.com/eclipse-dataspaceconnector/RegistrationService

  - CredentialVerifierに依存するが、それはIdentityHubが供給。
    https://github.com/eclipse-dataspaceconnector/IdentityHub
    
    - でも、IdentityHubのコードは、TrustFrameworkAdoptionの方に移動されることになるらしい。

      - https://github.com/eclipse-edc/Connector/discussions/2303
      - https://github.com/eclipse-edc/TrustFrameworkAdoption

- assetを定義する仕込みために、コネクタのdata management APIを呼び出す部分は、
  Postmanで作った.jsonをNewmanで実行する形で実装。

  - https://github.com/eclipse-dataspaceconnector/MinimumViableDataspace/blob/main/deployment/data/MVD.postman_collection.json
  - https://github.com/eclipse-dataspaceconnector/MinimumViableDataspace/blob/main/deployment/seed-data.sh

- policyとregistrationに関連して、extensionを2個独自に実装して利用。

  - https://github.com/eclipse-dataspaceconnector/MinimumViableDataspace/blob/main/extensions/policies/src/main/java/org/eclipse/dataspaceconnector/mvd/SeedPoliciesExtension.java
  - https://github.com/eclipse-dataspaceconnector/MinimumViableDataspace/blob/main/extensions/refresh-catalog/src/main/java/org/eclipse/dataspaceconnector/mvd/RegistrationServiceNodeDirectoryExtension.java
