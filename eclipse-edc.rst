-----------
eclipse-edc
-----------

.. contents::


Connector
=========

Overview
--------

- EDCはIDSのリファレンスをそのまま踏襲するものではない。

  - https://github.com/eclipse-edc/docs/blob/cc53fe25ea9c89797d2d04ebb3f857c6edcf1152/docs/README.md#statement-edc-vs-dsc
  - https://github.com/eclipse-edc/Connector/discussions/1037
  - https://github.com/eclipse-edc/Connector/blob/9adb0e4a09f4b0518a903e61890f94229ebda69e/docs/developer/decision-records/2022-06-02-ids-serializer/README.md

- JettyとJerseyを使ってREST APIをserve

- idscp2は利用/対応しない

- IDSコネクタと連携するためのREST APIの口がある。

  - https://github.com/eclipse-dataspaceconnector/DataSpaceConnector/issues/1563

- ServeceLoaderと独自アノテーションを使ったフレームワークを独自実装

  - org.eclipse.edc.spi.system.ServiceExtensionの実装を、
    いろいろ組み合わせてコネクタとして機能するまとまりを形成する。

  - Extensionは、他のExtension(がregisterするService)に依存する形で作られがち。
    モジュール間の依存関係は、build.gradle.ktsに書くが、
    どのServiceがどのモジュールのどのExtensionにあるかは自明ではない。
    Extension間のdependency hellみたいになりそうな。

  - ServiceLoaderでロードするための
    META-INF/services/org.eclipse.edc.spi.system.ServiceExtension
    が用意されている。コード上のモジュール間のつながりは見えにくい。
    build.gradle.ktsを見ると、どこで使われているは分かる。::

      $ find . -name build.gradle.kts | xargs grep iam-mock
      ./extensions/control-plane/api/management-api/catalog-api/build.gradle.kts:    testImplementation(project(":extensions:common:iam:iam-mock"))
      ./system-tests/e2e-transfer-test/control-plane/build.gradle.kts:    implementation(project(":extensions:common:iam:iam-mock"))
      ./system-tests/runtimes/azure-storage-transfer-consumer/build.gradle.kts:    implementation(project(":extensions:common:iam:iam-mock"))
      ...

  - ソースツリーは最近リファクタリングされた。しかし、上記の課題が解決するわけではない。

    - https://github.com/eclipse-edc/Connector/blob/9adb0e4a09f4b0518a903e61890f94229ebda69e/docs/developer/decision-records/2022-08-09-project-structure-review/README.md

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


- BaseRuntimeクラスが、ServiceExtension実装をロードしていくようなmainクラスを提供している。

  - https://github.com/eclipse-edc/Connector/blob/73a6d9b49d164c927031de71c384f239e05f33d4/core/common/boot/src/main/java/org/eclipse/edc/boot/system/runtime/BaseRuntime.java
  - https://github.com/eclipse-edc/Connector/blob/73a6d9b49d164c927031de71c384f239e05f33d4/launchers/ids-connector/README.md
  - https://github.com/eclipse-edc/Connector/blob/73a6d9b49d164c927031de71c384f239e05f33d4/launchers/ids-connector/build.gradle.kts#L39-L41


SPI
---

- #1832 で多少整理された感がある。

  - https://github.com/eclipse-edc/Connector/pull/1832

- どのモジュールがどのSPIを実装してるのかは、モジュールの依存関係から見るのが早いのかな..?::

    $ find . -name build.gradle.kts | xargs grep 'api(project(":spi:'
    ./core/data-plane-selector/data-plane-selector-core/build.gradle.kts:    api(project(":spi:data-plane-selector:data-plane-selector-spi"))
    ./core/data-plane/data-plane-framework/build.gradle.kts:    api(project(":spi:common:core-spi"))
    ./core/data-plane/data-plane-framework/build.gradle.kts:    api(project(":spi:data-plane:data-plane-spi"))
    ./core/data-plane/data-plane-framework/build.gradle.kts:    api(project(":spi:control-plane:control-plane-api-client-spi"))
    ./core/data-plane/data-plane-util/build.gradle.kts:    api(project(":spi:data-plane:data-plane-spi"))
    ...


REST API
--------

- `web.http.{context}.path` and `web.http.{context}.port` のような設定プロパティの組で、ポートとpathの組を指定する。

  - https://github.com/eclipse-edc/Connector/blob/9adb0e4a09f4b0518a903e61890f94229ebda69e/extensions/common/http/jetty-core/src/main/java/org/eclipse/edc/web/jetty/JettyConfiguration.java

- 上記のcontext aliasとしてはcontrol、management、protocol、publicがある。

  - https://github.com/eclipse-edc/Connector/blob/9adb0e4a09f4b0518a903e61890f94229ebda69e/docs/developer/decision-records/2022-11-09-api-refactoring/renaming.md

  - controlはコネクタが内部的に使うもの。
    という理解だったが、コネクタ間のやりとりでDataspace Protocol以外のものだと、少ないように見える。
    transferのsample実行時に/controlというcontext pathにregisterされたcontrollerは以下。

    - TransferProcessControlApiController
    - ConsumerPullTransferTokenValidationApiController
    - DataPlaneControlApiController

  - managementはコネクタのクライアントが呼び出すもの。

  - protocolはDataspace Protocol用のもので、Dataspace Protocolへの移行前はidsだった。

  - publicはdata planeがデータを送るときに使うもの。

- どのAPIがどのport/contextに対応してるいるのか、コードを静的に眺めて判断するのが以外と難しい。
  `JerseyRestService#start <https://github.com/eclipse-edc/Connector/blob/6012c7ae99bda409b9780c0a2c17d803a19e0106/extensions/common/http/jersey-core/src/main/java/org/eclipse/edc/web/jersey/JerseyRestService.java#L74-L80>`_
  にブレークポイントを仕掛けて、contextとcontrolerとの対応付けをデバッガで見るとわかりやすいか。
  `Samples/transferのコネクタ <https://github.com/eclipse-edc/Samples/tree/66b108bd9e30efe430c62aaa1aebe445ba81c2fe/transfer/transfer-00-prerequisites>`_
  でやると、以下のような感じ。::

    $ java \
       -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=18888 \
       -Dedc.keystore=transfer/transfer-00-prerequisites/resources/certs/cert.pfx \
       -Dedc.keystore.password=123456 \
       -Dedc.vault=transfer/transfer-00-prerequisites/resources/configuration/provider-vault.properties \
       -Dedc.fs.config=transfer/transfer-00-prerequisites/resources/configuration/provider-configuration.properties \
       -jar \
       transfer/transfer-00-prerequisites/connector/build/libs/connector.jar

- `web.http.path` and `web.http.port` は、defaultコンテキストに対応づけられる。
  controlとmanagementは固有の指定( `web.http.control.path` や `web.http.management.path` )がない場合、defaultを使う。
  ( `useDefaultContext(true)` されている。)

- Swaggerのアノテーションを利用して、*.yamlなどを生成している。

  - https://github.com/eclipse-edc/Connector/blob/9adb0e4a09f4b0518a903e61890f94229ebda69e/docs/developer/decision-records/2022-03-15-swagger-annotations/README.md

  - resolveタスクを実行すると、.yamlファイルが生成される。

    - https://github.com/eclipse-edc/Connector/blob/9adb0e4a09f4b0518a903e61890f94229ebda69e/docs/developer/openapi.md

  - connector同士がやりとりするためのIDSのAPIは、Swaggerによるドキュメント生成の対象外になっている。
    https://github.com/eclipse-edc/Connector/issues/1563

- OpenAPIで生成したドキュメントはSwagger Hubでホストされることになり、
  ソースツリー内のdocs/swaggeruiは削除された。
  generateSwaggerUiタスクによるローカルにドキュメント閲覧もできなくなった。

  - https://github.com/eclipse-edc/Connector/discussions/2329
  - https://github.com/eclipse-edc/Connector/pull/2328
  - https://github.com/eclipse-edc/Connector/pull/2209

  - バージョンが0.0.1-SNAPSHOTのまま、中身だけ変わっていくのだろうか??

    - https://app.swaggerhub.com/apis/eclipse-edc-bot/control-api
    - https://app.swaggerhub.com/apis/eclipse-edc-bot/management-api

  - と思ったが、0.1.0リリース後は0.1.1-SNAPSHOTに変わった

    - https://app.swaggerhub.com/apis/eclipse-edc-bot/control-api/0.1.1-SNAPSHOT
    - https://app.swaggerhub.com/apis/eclipse-edc-bot/management-api/0.1.1-SNAPSHOT

- Swagger UIのドキュメント上、management-apiとcontrol-apiの2つのくくりに分かれている。
  v0.1.0で見た時の分類は以下。
  context aliasとの対応で見ると、managementはmanagement-apiで、
  残りのcontrol、protocol、publicはcontrol-apiなのかしら。::
      
    $ find . -name build.gradle.kts | xargs grep management-api | grep apiGroup
    ./extensions/data-plane-selector/data-plane-selector-api/build.gradle.kts:        apiGroup.set("management-api")
    ./extensions/control-plane/provision/provision-http/build.gradle.kts:        apiGroup.set("management-api")
    ./extensions/control-plane/api/management-api/policy-definition-api/build.gradle.kts:        apiGroup.set("management-api")
    ./extensions/control-plane/api/management-api/contract-definition-api/build.gradle.kts:        apiGroup.set("management-api")
    ./extensions/control-plane/api/management-api/contract-negotiation-api/build.gradle.kts:        apiGroup.set("management-api")
    ./extensions/control-plane/api/management-api/transfer-process-api/build.gradle.kts:        apiGroup.set("management-api")
    ./extensions/control-plane/api/management-api/catalog-api/build.gradle.kts:        apiGroup.set("management-api")
    ./extensions/control-plane/api/management-api/asset-api/build.gradle.kts:        apiGroup.set("management-api")
    ./extensions/control-plane/api/management-api/contract-agreement-api/build.gradle.kts:        apiGroup.set("management-api")
    ./extensions/common/api/api-observability/build.gradle.kts:        apiGroup.set("management-api")
    ./extensions/common/api/management-api-configuration/build.gradle.kts:        apiGroup.set("management-api")
    
    $ find . -name build.gradle.kts | xargs grep control-api | grep apiGroup
    ./extensions/data-plane/data-plane-api/build.gradle.kts:        apiGroup.set("control-api")
    ./extensions/control-plane/transfer/transfer-data-plane/build.gradle.kts:        apiGroup.set("control-api")
    ./extensions/control-plane/api/control-plane-api/build.gradle.kts:        apiGroup.set("control-api")


test
----

- `-PverboseTest` を指定すると、出力されるログが増える。::

    $ ./gradlew test -PverboseTest

  - https://github.com/eclipse-edc/GradlePlugins/blob/af36bd7b0d79cd484736d45e59a3318e5f1b4e04/plugins/edc-build/src/main/java/org/eclipse/edc/plugins/edcbuild/conventions/TestConvention.java#L55-L65

- 特定のテストだけを実行したい場合は以下の要領。 ::

    $ ./gradlew extensions:api:data-management:transferprocess:test --tests '*TransferProcessEventDispatchTest'

- 特定のディレクトリ下のサブモジュールのテストすべてを実行したい場合は、 `-p` でディレクトリを指定する。::

    $ ./gradlew test -p extensions/api/data-management/transferprocess --tests '*TransferProcessEventDispatchTest'

- `@EndToEntTest` アノテーションがついたテストを実行するためには、以下の要領。::

    $ ./gradlew test -DincludeTags="EndToEndTest"

- 特定のテストメソッドだけ実行する例::

    $ ./gradlew clean test -p system-tests/e2e-transfer-test/runner -PverboseTest -DincludeTags="EndToEndTest" --tests "*EndToEndTransferInMemoryTest.httpPull_dataTransfer" 2>&1 | tee /tmp/test.log

- `@PostgresqlDbIntegrationTest` アノテーションが付いたテストを実行する場合、下記の要領。::
  
    $ ./gradlew test -p system-tests/e2e-transfer-test/runner -DincludeTags="PostgresqlIntegrationTest"

  - アノテーションのクラス名とタグ名が一致していないので分かりにくい?
    https://github.com/eclipse-edc/Connector/blob/main/common/util/src/testFixtures/java/org/eclipse/dataspaceconnector/common/util/junit/annotations/PostgresqlDbIntegrationTest.java#L31-L32

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


e2e-transfer-test
-----------------

- コネクタによるデータ転送の一連の流れを実行するテストコードが定義されている。

- AbstractEndToEndTransferがベースクラスで、データの永続化先によって3種類の派生がある。
  各派生には `@EndToEndTest` のようなアノテーションがついていて、それに応じて
  `-DincludeTags=EndToEndTest` のような指定をしないと、テストが実行されない。

- EndToEndTransferInMemoryTestはデータをメモリ上に持ち、永続化しないパターンで、それ単体で実行できる。::

    $ ./gradlew clean test -p system-tests/e2e-transfer-test/runner -DincludeTags=EndToEndTest --tests '*EndToEndTransferInMemoryTest' -PverboseTest

- EndToEndTransferPostgresqlTestはPostgreSQLにデータを永続化する。
  これも、コンテナを利用してPostgreSQLのサーバを建てることで、簡単に実行できる。
  アノテーションが `@PostgresqlDbIntegrationTest` だが、定義されているTagがPostgresqlIntegrationTestで紛らわしい。::

    $ docker run --rm --name edc-postgres -e POSTGRES_PASSWORD=password -p 5432:5432 -d postgres
    $ ./gradlew clean test -p system-tests/e2e-transfer-test/runner -DincludeTags=PostgresqlIntegrationTest --tests '*EndToEndTransferPostgresqlTest' -PverboseTest

  - テスト実行後に、データベース内のデータを見てみるのも、理解を深めるのに役立つかもしれない。
    concsumerとproducerというデータベースができている。::

      $ psql -U postgres -W -h localhost -l
      psql: warning: extra command-line argument "postgres" ignored
      Password:
                                       List of databases
         Name    |  Owner   | Encoding |  Collate   |   Ctype    |   Access privileges
      -----------+----------+----------+------------+------------+-----------------------
       consumer  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
       postgres  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
       provider  | postgres | UTF8     | en_US.utf8 | en_US.utf8 |
       template0 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
                 |          |          |            |            | postgres=CTc/postgres
       template1 | postgres | UTF8     | en_US.utf8 | en_US.utf8 | =c/postgres          +
                 |          |          |            |            | postgres=CTc/postgres
      (5 rows)
      
      $ psql -U postgres -W -h localhost -c 'SELECT * FROM edc_policydefinitions LIMIT 1;' provider
                        policy_id               |  created_at   |                                                                                           permissions                                                                                           | prohibitions | duties | extensible_properties | inherits_from | assigner | assignee | target |      policy_type
      --------------------------------------+---------------+-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+--------------+--------+-----------------------+---------------+----------+----------+--------+-----------------------
       f5ed763c-7ec1-427d-a47d-3099236b61bd | 1682079999930 | [{"edctype":"dataspaceconnector:permission","uid":null,"target":null,"action":{"type":"USE","includedIn":null,"constraint":null},"assignee":null,"assigner":null,"constraints":[],"duties":[]}] | []           | []     | {}                    |               |          |          |        | {"@policytype":"set"}
      (1 row)


documentation
-------------

- ドキュメント自動生成用のモジュールやアノテーションの定義は、
  #2001で、DataSpaceConnectorとは別のソースツリーに移動された。
  https://github.com/eclipse-dataspaceconnector/GradlePlugins


configuration
-------------

- 設定プロパティは、ConfigurationExtensionがロードしたもの、環境変数からのもの、システムプロパティからのものがマージされる。競合があれば後のものほど強い。

  - https://github.com/eclipse-edc/Connector/blob/7e6089c9ac61310a05f08d6037bf877920095d9f/core/common/boot/src/main/java/org/eclipse/edc/boot/system/DefaultServiceExtensionContext.java#L121-L129

- `FsConfigurationExtension <https://github.com/eclipse-edc/Connector/blob/7e6089c9ac61310a05f08d6037bf877920095d9f/extensions/common/configuration/configuration-filesystem/src/main/java/org/eclipse/edc/configuration/filesystem/FsConfigurationExtension.java>`_
  は、edc.fs.configでpathを指定されたファイルから、設定内容を読み込む。


persistence
-----------

- データの永続化のための仕組み/抽象化は独自実装で、外部ライブラリの依存性が増えることを避ける方針に見える。

  - 永続化が必要なサブモジュールは、それぞれ ``org.eclipse.edc.spi.persistence.*.*Store`` のような名前の、インターフェースを定義する。
    この定義はサブモジュールごとに行っていて、意外と共通化されていない。

  - デフォルト実装として、データを永続化しない ``InMemory*Store`` があり、ユニットテストやサンプルの実行に利用される。
    こちらも、あまり共通化する余地なし。

  - RDBMSを利用してデータを永続化する実装として ``Sql*Store`` がある。
    これらの実装は、
    common/sql/sql-core下の ``org.eclipse.edc.sql.store.AbstractSqlStore`` を、
    ベースロジックとしてモジュール横断的に利用されているようだ。

    - ``Sql*Store`` では、 ``*Statements`` のような名前のクラスを使い、
      SQLステートメントを組み上げてJDBCドライバで実行する。

    - ``*Statements`` は ``*DialectStatements`` のようなクラスをベースにしている。
      このDialectを切り替えることで、複数RDBMSに対応できるようにする方針。
      デフォルトで用意されているのは ``PostgresDialectStatements`` でPostgreSQLが前提。


authentication
--------------

- management APIについては、AuthenticationService#isAuthenticatedを呼ぶようなfilterで認証している。

  - https://github.com/eclipse-edc/Connector/blob/v0.3.1/spi/common/auth-spi/src/main/java/org/eclipse/edc/api/auth/spi/AuthenticationRequestFilter.java

  - Connector配下にあるAuthenticationServiceの実装は2種類だけ。

    - 未指定デフォルトで利用される
      `AllPassAuthenticationService <https://github.com/eclipse-edc/Connector/blob/v0.3.1/spi/common/auth-spi/src/main/java/org/eclipse/edc/api/auth/spi/AllPassAuthenticationService.java>`_
      は文字通り素通し。

    - `BasicAuthenticationService <https://github.com/eclipse-edc/Connector/blob/v0.3.1/extensions/common/auth/auth-basic/src/main/java/org/eclipse/edc/api/auth/basic/BasicAuthenticationService.java>`_
      は、 ``edc.api.auth.key`` で指定されたキー文字列が、
      X-Api-Keyヘッダーにセットされているかをセットする、素朴なもの。

- コネクタの認証には、org.eclipse.edc.spi.iam.IdentityServiceが利用される。


identity
--------

- Connector配下にある実装はDIDとOAuth2の2択。

  - https://github.com/eclipse-edc/Connector/blob/72d8b8ef58de41db7111c9928f777ce60781f51c/extensions/common/iam/decentralized-identity/identity-did-service/src/main/java/org/eclipse/edc/iam/did/service/DecentralizedIdentityService.java
  - https://github.com/eclipse-edc/Connector/blob/72d8b8ef58de41db7111c9928f777ce60781f51c/extensions/common/iam/oauth2/oauth2-core/src/main/java/org/eclipse/edc/iam/oauth2/identity/Oauth2ServiceImpl.java


logging
-------

- ログの出力はMonitorというインターフェースで抽象化されている。
  明示的にMonitor実装がregisterされていない場合、
  ConsoleMonitorという単純な実装が使われる。
  ロギングライブラリは使用せずに、コンソールにDEBUGレベルを含むすべてのログを出力する。

- MonitorExtension実装をロードすることで、monitorの切りかえ/追加ができる。

- LoggerMonitorExtensionは、java.util.loggingでログ出力するLoggerMonitorを提供するもの。

- BaseRuntimeは `MonitorProvider <https://github.com/eclipse-edc/Connector/blob/v0.1.3/core/common/boot/src/main/java/org/eclipse/edc/boot/monitor/MonitorProvider.java>`_
  というSLF4JServiceProvider実装をロードし、SLF4J APIで出力されたログを、Monitor側に送る仕組みを用意している。
  結果として、ほかのSLF4J bindingを使うことができない。

  - removed: https://github.com/eclipse-edc/Connector/pull/3463


okhttp3 logging
---------------

コネクタ内のHTTPリクエストは、okhttp3で実行されている。
logging-interceptorを仕込むと、リクエストの内容をログ出力できる。::

  $ git diff
  diff --git a/core/common/connector-core/src/main/java/org/eclipse/edc/connector/core/base/OkHttpClientFactory.java b/core/common/connector-core/src/main/java/org/eclipse/edc/connector/core/base/OkHttpClientFactory.java
  index 10dc4d5d2..1c7bc3eab 100644
  --- a/core/common/connector-core/src/main/java/org/eclipse/edc/connector/core/base/OkHttpClientFactory.java
  +++ b/core/common/connector-core/src/main/java/org/eclipse/edc/connector/core/base/OkHttpClientFactory.java
  @@ -77,6 +77,9 @@ public class OkHttpClientFactory {
               context.getMonitor().info("HTTPS enforcement it not enabled, please enable it in a production environment");
           }
   
  +        var logging = new okhttp3.logging.HttpLoggingInterceptor();
  +        logging.setLevel(okhttp3.logging.HttpLoggingInterceptor.Level.BODY);
  +        builder.addInterceptor(logging);
           return builder.build();
       }
   
  diff --git a/gradle.properties b/gradle.properties
  index 9bd583ee1..e86600c1b 100644
  --- a/gradle.properties
  +++ b/gradle.properties
  @@ -1,9 +1,9 @@
   group=org.eclipse.edc
  -version=0.3.1-SNAPSHOT
  +version=0.3.1
   # for now, we're using the same version for the autodoc plugin, the processor and the runtime-metamodel lib, but that could
   # change in the future
  -annotationProcessorVersion=0.3.1-SNAPSHOT
  -edcGradlePluginsVersion=0.3.1-SNAPSHOT
  -metaModelVersion=0.3.1-SNAPSHOT
  +annotationProcessorVersion=0.3.1
  +edcGradlePluginsVersion=0.3.1
  +metaModelVersion=0.3.1
   edcScmUrl=https://github.com/eclipse-edc/Connector.git
   edcScmConnection=scm:git:git@github.com:eclipse-edc/Connector.git
  diff --git a/gradle/libs.versions.toml b/gradle/libs.versions.toml
  index 97672f052..12b80c690 100644
  --- a/gradle/libs.versions.toml
  +++ b/gradle/libs.versions.toml
  @@ -79,6 +79,7 @@ mockserver-client = { module = "org.mock-server:mockserver-client-java", version
   mockserver-netty = { module = "org.mock-server:mockserver-netty", version.ref = "httpMockServer" }
   nimbus-jwt = { module = "com.nimbusds:nimbus-jose-jwt", version.ref = "nimbus" }
   okhttp = { module = "com.squareup.okhttp3:okhttp", version.ref = "okhttp" }
  +okhttp-logging-interceptor = { module = "com.squareup.okhttp3:logging-interceptor", version.ref = "okhttp" }
   opentelemetry-api = { module = "io.opentelemetry:opentelemetry-api", version.ref = "opentelemetry" }
   opentelemetry-instrumentation-annotations = { module = "io.opentelemetry.instrumentation:opentelemetry-instrumentation-annotations", version.ref = "opentelemetry" }
   opentelemetry-proto = { module = "io.opentelemetry.proto:opentelemetry-proto", version.ref = "opentelemetry-proto" }
  diff --git a/spi/common/http-spi/build.gradle.kts b/spi/common/http-spi/build.gradle.kts
  index 9aaf288b5..d9fa0bfa7 100644
  --- a/spi/common/http-spi/build.gradle.kts
  +++ b/spi/common/http-spi/build.gradle.kts
  @@ -21,6 +21,7 @@ dependencies {
       api(project(":spi:common:core-spi"))
   
       api(libs.okhttp)
  +    api(libs.okhttp.logging.interceptor)
       api(libs.failsafe.okhttp)
   }

okhttp3のロギングはjava.util.loggingを使っているので、
``-Djava.util.logging.config.file=/tmp/logging.properties``
のようにシステムプロパティ経由で設定ファイルを指定できる。::

  $ cat >/tmp/logging.properties <<EOF
  handlers = java.util.logging.ConsoleHandler
  .level = INFO
  java.util.logging.ConsoleHandler.level = ALL
  java.util.logging.ConsoleHandler.formatter = java.util.logging.SimpleFormatter
  java.util.logging.SimpleFormatter.format = %1\$tF %1\$tT %4\$s : %5\$s %n
  EOF

指定したファイルのpathが誤っているなどすると、単にログが出なくなるため、原因を見つけにくい。


statemachine
------------

- StateMachineManagerが使われるのは3か所。

  - ContractServiceExtensionで初期化される
    ProviderContractNegotiationManagerと、ConsumerContractNegotiationManager。

  - CoreTransferExtensionで初期化されるTransferProcessManager。

  - どちらもテスト用にWaitStrategyを差し込み可能になっている。

    - see NegotiationWaitStrategy and TransferWaitStrategy


usage control
-------------

- https://github.com/eclipse-edc/Connector/blob/v0.3.1/docs/developer/architecture/usage-control/policies.md

- `PolicyEngine <https://github.com/eclipse-edc/Connector/blob/v0.3.1/spi/common/policy-engine-spi/src/main/java/org/eclipse/edc/policy/engine/spi/PolicyEngine.java>`_
  が
  `registerしておいた関数群 <https://github.com/eclipse-edc/Connector/blob/v0.3.1/core/common/policy-engine/src/main/java/org/eclipse/edc/policy/engine/PolicyEngineImpl.java#L51-L54>`_
  を実行することで、
  `Policy <https://github.com/eclipse-edc/Connector/blob/v0.3.1/spi/common/policy-model/src/main/java/org/eclipse/edc/policy/model/Policy.java>`_
  を満たすかどうか評価する。

- Catalog, ContractNegotiation, TransferProcess等のサービス内で、 ``PolicyEngine#evaluate`` が評価される。

- 関数によって評価される
  `Rule <https://github.com/eclipse-edc/Connector/blob/v0.3.1/spi/common/policy-model/src/main/java/org/eclipse/edc/policy/model/Rule.java>`_ には、
  `Duty <https://github.com/eclipse-edc/Connector/blob/v0.3.1/spi/common/policy-model/src/main/java/org/eclipse/edc/policy/model/Duty.java>`_ 、
  `Permission <https://github.com/eclipse-edc/Connector/blob/v0.3.1/spi/common/policy-model/src/main/java/org/eclipse/edc/policy/model/Permission.java>`_ 、
  `Prohibition <https://github.com/eclipse-edc/Connector/blob/v0.3.1/spi/common/policy-model/src/main/java/org/eclipse/edc/policy/model/Prohibition.java>`_
  の3種類がある。

- 上記のPolicyやRuleの概念は、 `ODRL <https://www.w3.org/TR/odrl-model/>`_ で定義されたもの。

- Policyは `policydefinitions <https://app.swaggerhub.com/apis/eclipse-edc-bot/management-api/0.3.1#/Policy%20Definition/>`_ のAPIで登録する。

- MVDの関連部分が参考になるかもしれない。

  - `Postman/NewmanでAPIを呼び出してポリシーを登録 <https://github.com/eclipse-edc/MinimumViableDataspace/blob/main/deployment/data/MVD.postman_collection.json#L92-L131>`_ してるところ。

  - `regionの値でアクセス制御するためのルール関数 <https://github.com/eclipse-edc/MinimumViableDataspace/blob/659505e2a3dee432341d3e91d6f22509dfcff6ec/extensions/policies/src/main/java/org/eclipse/edc/mvd/RegionConstraintFunction.java>`_

  - `関数を登録するためのextension <https://github.com/eclipse-edc/MinimumViableDataspace/blob/659505e2a3dee432341d3e91d6f22509dfcff6ec/extensions/policies/src/main/java/org/eclipse/edc/mvd/SeedPoliciesExtension.java>`_


catalog
-------

- CatalogはContractOfferの集まり。だったが、Dataspace Protocol対応で、DatasetやDataServiceという概念が登場した。

  - https://github.com/eclipse-edc/Connector/blob/0ac9755d7a058117fb8372181af7389760818e7e/spi/common/catalog-spi/src/main/java/org/eclipse/edc/catalog/spi/Catalog.java
  - https://github.com/eclipse-edc/Connector/pull/2656

 - CatalogServiceにはEDCのとIDSのと、2種類ある。
   e2e-transfer-test等の既存のテストやサンプルで使われているのは、後者のIDSのもののみに見える。
   Catalogのデータモデルは共通。

    - https://github.com/eclipse-edc/Connector/blob/0ac9755d7a058117fb8372181af7389760818e7e/spi/control-plane/control-plane-spi/src/main/java/org/eclipse/edc/connector/spi/catalog/CatalogService.java
    - https://github.com/eclipse-edc/Connector/blob/0ac9755d7a058117fb8372181af7389760818e7e/core/control-plane/control-plane-aggregate-services/src/main/java/org/eclipse/edc/connector/service/catalog/CatalogServiceImpl.java

    - https://github.com/eclipse-edc/Connector/blob/0ac9755d7a058117fb8372181af7389760818e7e/data-protocols/ids/ids-spi/src/main/java/org/eclipse/edc/protocol/ids/spi/service/CatalogService.java
    - https://github.com/eclipse-edc/Connector/blob/0ac9755d7a058117fb8372181af7389760818e7e/data-protocols/ids/ids-core/src/main/java/org/eclipse/edc/protocol/ids/service/CatalogServiceImpl.java


transferprocesses
-----------------

- /v2/transferprocesses は、consumer connectorが、データ転送のためのリクエストを受けるAPI。

  - sourceは、ContractAgreementに含まれるassetIdで指定される。

  - destinationは、dataDestinationで具体的にtypeとその他propertyで指定される。
    例えばAzure Blobだと、typeはAzureStorageで、
    accountでストレージアカウント名、containerはcontainer名を指す。

- データ転送の処理それ自体は、transfer-data-plane側にコードがある。
  https://github.com/eclipse-edc/Connector/blob/65479dc186ad0517565c77047672d1783a2188d7/extensions/control-plane/transfer/transfer-data-plane/README.md

- リクエストが呼ばれると、TransferProcessインスタンスが作成され、
  状態(state)を含む情報がTransferProcessStoreに保存される。
  StateMachineManagerのスレッドがprocess*を順次呼び出すことで、
  TransferProcessの状態は遷移していく。

  - processInitialで、destinationのtypeに応じて必要なら、
    登録されたConsumerResourceManifestGeneratorにが、ResourceDefinitionを作成する。
    現状destinationがAzure Blob/Amazon S3/GCSのオブジェクトの場合に、この処理が入る。

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

        - DataFlowManagerは、DataFlowControllerを切り替える。
          destinationがHttpProxyだとConsumerPullTransferDataFlowControllerが、
          それ以外だとProviderPushTransferDataFlwoControllerが使われる。

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

- https://github.com/eclipse-edc/Connector/issues/463

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

- consumerがHTTPレスポンスのbodyとしてデータを受け取るパターンは、e2e-transfer-testの方に例が追加された。

  - https://github.com/eclipse-edc/Connector/discussions/1361
  - https://github.com/eclipse-edc/Connector/blob/9adb0e4a09f4b0518a903e61890f94229ebda69e/system-tests/e2e-transfer-test/runner/src/test/java/org/eclipse/edc/test/e2e/AbstractEndToEndTransfer.java#L47-L113
  - https://github.com/eclipse-edc/Connector/pull/639

- providerは、
  asset typeをcanHandleなSourceから、
  dataDestination typeをcanHandleなSinkに、
  transferする。

- assetのtypeを増やす場合、DataSourceFactoryとDataSinkFactoryの実装をつくり、
  `PipelineService#registerFactory` する。

- 元々あったprovider pushは、provider connector側でデータ送信の処理( ``sink.transfer(source)`` )が呼ばれるのでわかりやすい。
  それに対して、後から追加されたデータ転送方式であるところのconsumer pullはちょっとわかりにくい。

  - 現状consumer pullになるのは、destinationのtypeがHttpProxyの場合のみ。

  - consumer pullの場合は、TransferStartMessageのペイロードとして、データの在処を示すEndpointDataReference(EDR)をconsumer connectorに渡す。
    consumer connectorは、受け取ったEDRをbackendにPOSTする。

  - consumer clientは(backendから取り出した)EDRに入っているendpointのURLに対して、authCodeに入っているトークンをAuthorizationヘッダに入れて、GETする。
    このendpointのURLはコネクタのdata-plane APIを指すもの。
    コネクタは、authCodeに含まれている真のデータの在処を示すURLからデータを取得し、clientに渡す。つまり、プロキシサーバとして振る舞う。
    authCodeに含まれる情報で認証を行うために、クライアントは直接データの在処にアクセスしない。

    - という仕組み上、sourceのtypeはHttpDataでなければ成立しないような。

    - consumerとproviderのどちらのコネクタのproxyとして振る舞えるが、
      ドキュメント上はprovider connectorがデータを中継する想定になっているように見える。
      この場合、データをpullするのはconsumer connectorではなく、そのクライアントということになる。

  - https://github.com/eclipse-edc/Connector/tree/5803513f0c4cc795c0d1d069f7039c8ca1bd8f7e/extensions/control-plane/transfer/transfer-data-plane



Dataspace Protocol
------------------

- https://github.com/eclipse-edc/Connector/issues/2429

- https://github.com/eclipse-edc/Connector/blob/73a6d9b49d164c927031de71c384f239e05f33d4/docs/developer/architecture/ids-dataspace-protocol/README.md


chunked transfer
----------------

`#1645 <https://github.com/eclipse-edc/Connector/pull/1645>`_ で、
chunked transferが問題となる場合の対策として、
HttpAddressのpropertyで、nonChunkedTransferをtrueにすることで、
chunked transferをオフにできるようになった。::

        "dataDestination": {
          "type": "HttpData",
          "baseUrl": "http://localhost:4000/api/consumer/store",
          "nonChunkedTransfer": "true"
        }


rebranding
==========

- 元々はEclipse Dataspace Connectorだったが、Eclipse Dataspace Componentsにrebrandされた。

  - https://github.com/eclipse-edc/Connector/discussions/2244

  - URLも https://github.com/eclipse-dataspaceconnector/DataSpaceConnector から
    https://github.com/eclipse-edc/Connector に変わった。
    古いURLでもアクセス可能。


versioning
==========

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

- その後、あまりうまくないことが分かり、各コンポーネントがバージョンカタログを持つやり方に変わった。

  - https://github.com/eclipse-edc/Connector/blob/e7a092bf81fc43b42c349d98e3e6ad3939f181a6/docs/developer/decision-records/2023-03-31-version-catalog-per-component/README.md

  -  GradlePlugins側にも、共通のパーツだけ少し残されてはいる。

    - https://github.com/eclipse-edc/GradlePlugins/blob/83ad790b6e521862db8f66b7985457176070da81/gradle/libs.versions.toml

- `version catalog自体はGradleが提供する機能 <https://docs.gradle.org/current/userguide/platforms.html>`_ 。

  - libs.versions.tomlという `TOML形式 <https://toml.io/>`_ のファイルによるバージョン定義を読んで解釈するのは、
    `GradleのVersionCatalobBuilder <https://docs.gradle.org/current/javadoc/org/gradle/api/initialization/dsl/VersionCatalogBuilder.html>`_ 。

  - `groovy-core` のようにハイフン区切りで定義されたaliasには、
    `libs.groovy.core` のようにドット区切りのアクセサでアクセスする `流儀 <https://docs.gradle.org/current/userguide/platforms.html#sub:mapping-aliases-to-accessors>`_ らしい。

  - Maven等にpublishして、外部から参照できるようにするためには、
    `version-catalogプラグイン <https://docs.gradle.org/current/userguide/platforms.html#sec:version-catalog-plugin>`_ を利用する。

- ローカルでEDCのコードを修正して、それをSamplesから使って試したりするには、ちょっと手順が必要。

  - まずGradlePlugins側のバージョン定義を修正したものをローカルリポジトリにインストールする。::

      $ ./gradlew publishToMavenLocal -Pskip.signing

  - `dependencyResolutionManagementのrepositoriesの設定 <https://github.com/eclipse-edc/Samples/blob/e837a2f9be9d8537f6b000103c580d0c7ef24f6e/settings.gradle.kts#L24-L29>`_
    の設定で、mavenLocalをmavenCentralの上に持ってこないと、
    ローカルのリポジトリ(~/.m2/repository)を見てくれないのかな? と思ったが、
    そうしなくても、ローカルからartifactsが取得されるように見える。

  - Gradleのキャッシュ(~/.gradle/caches)はキャッシュであって、リポジトリではない。
    キャッシュに対してartifactsをpublishするようなことはできない。
    mavenLocalから取得したartifactsはキャッシュされない。
    そのため、mavenLocalを使うとビルドが遅くなるので、使うべき場面以外では使わないほうがよいというトーンになっている。

  - Gradleのドキュメント的には、ローカルなartifactsを使ってビルドする場合、
    `composite build <https://docs.gradle.org/8.0/userguide/composite_builds.html#composite_builds>`_
    を使うことを推奨している。
    だがしかし、Samplesを `--include-build` を使ってビルドしようとしたところ、
    モジュール名の重複みたいな感じのエラーになった。::

      $ ./gradlew --include-build /path/to/Connector clean build
      ...
      > Could not resolve all task dependencies for configuration ':advanced:advanced-01-open-telemetry:open-telemetry-consumer:compileClasspath'.
        > Could not resolve org.eclipse.edc:management-api:0.3.1.
          Required by:
              project :advanced:advanced-01-open-telemetry:open-telemetry-consumer
           > Module version 'org.eclipse.edc:management-api:0.3.1' is not unique in composite: can be provided by [project :Connector:extensions:control-plane:api:management-api, project :Connector:system-tests:management-api].


docs
====

- Connectorからドキュメントを独立のリポジトリに移動し、
  複数のリポジトリのドキュメントをまとめて一つに見せる仕組みができてた。

  - https://github.com/eclipse-edc/docs
  - https://eclipse-edc.github.io/docs/#/README


Samples
=======

- samplesの内容は、個別のソースツリーに移動された。

  - https://github.com/eclipse-edc/Samples
  - https://github.com/eclipse-edc/Connector/pull/2362

- transferのサンプルが雰囲気をつかむのによい。

  - https://github.com/eclipse-edc/Samples/tree/66b108bd9e30efe430c62aaa1aebe445ba81c2fe/transfer

  - consumer, providerはどちら同じモジュールを利用し、設定で使い分ける。

   - client(curlコマンド)はconsumerにREST APIでmanagemnent APIのリクエストを送る。
     consumerは受付情報的な内容をすぐにレスポンスとして返す。

   - consumerはclientリクエストを受けて、providerにDataspace Protocolのリクエストを送る。

- 手でcurlコマンドを叩く代わりに、一連の処理をtestタスクで実行することもできる。::

    $ ./gradlew clean test -p system-tests -DincludeTags=EndToEndTest --tests Transfer03providerPushTest -PverboseTest

  - 最近は、testcontainersを使って、backendなどをDockerで起動するようになった様子。


MinimumViableDataspace
======================

- https://github.com/eclipse-edc/MinimumViableDataspace

- EDCを使ったDSのデモ

- AssetはAzureのBlob。ローカル環境ではAzuriteを利用。

- assetを定義する仕込みために、コネクタのdata management APIを呼び出す部分は、
  Postmanで作った.jsonをNewmanで実行する形で実装。

  - https://github.com/eclipse-edc/MinimumViableDataspace/blob/8141afce75613f62ed236cb325a862b8af40b903/deployment/data/MVD.postman_collection.json

  - https://github.com/eclipse-edc/MinimumViableDataspace/blob/8141afce75613f62ed236cb325a862b8af40b903/deployment/seed-data.sh

- policyとregistrationに関連して、extensionを2個独自に実装して利用。

  - https://github.com/eclipse-edc/MinimumViableDataspace/blob/8141afce75613f62ed236cb325a862b8af40b903/extensions/policies/src/main/java/org/eclipse/edc/mvd/SeedPoliciesExtension.java

  - https://github.com/eclipse-edc/MinimumViableDataspace/blob/8141afce75613f62ed236cb325a862b8af40b903/extensions/refresh-catalog/src/main/java/org/eclipse/edc/mvd/RegistrationServiceNodeDirectoryExtension.java

- DID/VCでParticipantを認証する仕組みとして
  `IdentityHub <https://github.com/eclipse-edc/IdentityHub>`_
  と
  `RegistrationService <https://github.com/eclipse-edc/RegistrationService>`_
  を利用。

  - https://github.com/eclipse-edc/MinimumViableDataspace/tree/8141afce75613f62ed236cb325a862b8af40b903/docs/developer/decision-records/2022-06-20-mvd-onboarding
  - https://github.com/eclipse-edc/MinimumViableDataspace/tree/8141afce75613f62ed236cb325a862b8af40b903/docs/developer/decision-records/2022-06-16-distributed-authorization
  - https://github.com/eclipse-edc/MinimumViableDataspace/tree/8141afce75613f62ed236cb325a862b8af40b903/docs/developer/decision-records/2022-06-15-registration-service

- FederatedCatalogを利用。


local testing
-------------

Docker Composeを利用して、ローカルノードで動作確認できる。

- https://github.com/eclipse-edc/MinimumViableDataspace/blob/659505e2a3dee432341d3e91d6f22509dfcff6ec/system-tests/README.md#test-execution-using-embedded-services

- `-DuseFsVault="true"` をつけてビルドしないと、(azuriteではなく)Azure前提のVaultが使われて、エラーになる。

- MVD_UI_PATHをexportして、DataDashboardのUIを動かす場合も、上記の仕込みは必要。

  - https://github.com/eclipse-edc/MinimumViableDataspace/tree/659505e2a3dee432341d3e91d6f22509dfcff6ec#local-development-setup

- MVDはAxure BlobのみをAssetのデータ置き場としてサポートしているため、azuriteのコンテナがいる。

- WebDidResolverがDIDを取得するために、nginxのコンテナがいる。

- 上記をまとめてると、以下の要領でコマンドを実行することになる。::

  $ cd /home/iwasakims/srcs
  $ git clone https://github.com/eclipse-edc/MinimumViableDataspace
  $ git clone https://github.com/eclipse-edc/DataDashBoard
  $ cd MinimumViableDataspace
  
  $ ./gradlew -DuseFsVault="true" :launchers:connector:shadowJar
  $ ./gradlew -DuseFsVault="true" :launchers:registrationservice:shadowJar
  $ export MVD_UI_PATH=/home/iwasakims/srcs/eclipse-edc/DataDashboard
  $ docker compose --profile ui -f system-tests/docker-compose.yml up --build

- cli-toolsというコンテナの、
  `entrypoint.sh <https://github.com/eclipse-edc/MinimumViableDataspace/blob/cc5cc02d8ca0ee69052ca765f611abe3ad82f5f8/system-tests/resources/cli-tools/entrypoint.sh>`_
  のなかで、participantのenrollmentを実行。

  - identity-hub-cliでverifiable credentialを登録

  - registry-service-cliでparticipantを登録

- did-serverというnginxのコンテナが、
  `DID document <https://github.com/eclipse-edc/MinimumViableDataspace/blob/main/system-tests/resources/webdid/company1/did.json>`_
  の置き場。


Azure CLI
---------

MVDはAxure BlobのみをAssetのデータ置き場としてサポートしているため、
試すには現物のAzureを使うか、Azuriteのコンテナをローカル実行する必要がある。

テスト用にAzure Blogのcontainerやblobを作る上では、
Azure CLIのazコマンドを使うのが楽。
Ubuntu環境であれば、
`LinuxにAzure CLIをインストールする <https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt>`_
手順にあるように、aptでインストールできる。::

  $ sudo apt-get update
  $ sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg
  $ curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
  $ sudo chmod go+r /etc/apt/keyrings/microsoft.gpg
  $ AZ_DIST=$(lsb_release -cs)
  $ echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_DIST main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
  $ sudo apt-get update
  $ sudo apt-get install azure-cli
  $ az version

azuriteを使う場合、ストレージアカウント名とキーは、
`docker-compose.ymlのAZURITE_ACCOUNTS <https://github.com/eclipse-edc/MinimumViableDataspace/blob/659505e2a3dee432341d3e91d6f22509dfcff6ec/system-tests/docker-compose.yml#L152-L159>`_
で設定されている。
それに合わせて、接続文字列を設定して使う。::

  $ az config set storage.connection_string="DefaultEndpointsProtocol=http;AccountName=company1assets;AccountKey=key1;BlobEndpoint=http://localhost:10000/company1assets"
  $ az storage container list
  $ az storage container create --name src-container
  $ az storage blob upload --container-name src-container --file ./deployment/azure/terraform/modules/participant/sample-data/text-document.txt

Azure CLIでblobを操作する方法は、
`Azure Blob Storage documentation <https://learn.microsoft.com/en-us/azure/storage/blobs/blob-cli>`_
等に説明がある。


IdentityHub
===========

- https://github.com/eclipse-edc/IdentityHub

- おもに以下の機能を提供

  - verifiable credentialの保存

    - Dataspace AuthorityのRegistration Serviceが、participantのenrollmentの過程で、
      署名したverifiable credential(JWS?)を書き込む。

    - キーバリュー的にVCを保存するが、キーは単にUUID#randomUUIDで決まるようだ。

  - verifiable presentationの取得

    - 検索条件などはなく、登録されているすべてのVCが返ってくるようだが?

- DIDに関する概念ででてくる
  `Decentralized Web Node <https://identity.foundation/decentralized-web-node/spec/#write>`_
  なるものに相当するらしい。
  だがしかし、そのコードの多くは
  `identity_dwn <https://github.com/eclipse-edc/IdentityHub/tree/identity_dwn>`_
  ブランチに残し、
  `PR#160 <https://github.com/eclipse-edc/IdentityHub/pull/160>`_
  で削除され、
  `2023-09-06のdecision records <https://github.com/eclipse-edc/docs/tree/e7730f432305775542503e4ecb61aa7e829bea30/developer/decision-records/2023-09-06-identity-trust>`_
  に書かれているように、EDCの仕組みを作る方向に向かうようだ。
  いまは
  `Tractus-X配下でされている枠組み <https://github.com/eclipse-tractusx/ssi-docu>`_
  が、標準化のために、
  `Eclipse Dataspace Working Group <https://www.eclipse.org/org/workinggroups/dataspace-charter.php>`_
  の方に移されるとも。

- Gaia-Xとの関係性てきな話題については、以下も参照。

  - https://github.com/eclipse-edc/Connector/discussions/2303
  - https://github.com/eclipse-edc/TrustFrameworkAdoption

- participantが各自IdentityHubを立てておき、DID documentの中にそのURLを入れる。

  - Connectorと同一プロセスにすることもできる。
    `RegistrationServiceのintegration test用コンテナ <https://github.com/eclipse-edc/RegistrationService/tree/v0.3.1/system-tests/launchers/participant>`_
    がその例。


RegistrationService
===================

- https://github.com/eclipse-edc/RegistrationService

- MVDのための簡易サービス。

  - https://github.com/eclipse-edc/MinimumViableDataspace/blob/main/docs/developer/decision-records/2022-06-15-registration-service/README.md

- DIDで識別されるParticipantを登録する。
  /registry/participant[s] で、単純な追加と取得ができるAPIだけ定義されている。

  - https://github.com/eclipse-edc/RegistrationService/blob/04df5c8f361d71520b48385872db63df68291537/extensions/registration-service-api/src/main/java/org/eclipse/edc/registration/api/RegistrationServiceApiController.java

  - Participant追加は、 `Authorization: Bearer DID-JWT` のようなヘッダー付きのリクエストをPOSTすることで行う。

  - Participantの情報は一旦storeに格納し、非同期的にstoreの情報を見ているParticipantManagerがDataspaceRegistrationPolicyに応じて参加を許可するか判断する。

    - https://github.com/eclipse-edc/RegistrationService/blob/v0.3.1/core/registration-service/src/main/java/org/eclipse/edc/registration/RegistrationServiceExtension.java#L93-L96

    - https://github.com/eclipse-edc/RegistrationService/blob/v0.3.1/core/registration-service-onboarding-policy-verifier/src/main/java/org/eclipse/edc/registration/verifier/OnboardingPolicyVerifierImpl.java#L53-L90

      - DidDocumentをDidResolverを使って取得する。
        WebDidResolverはWebサーバからGETする。アクセス先のURLは、DIDのURNを加工して作る。

- participantの参加登録は、
  `IdentityHubとやりとりして <https://github.com/eclipse-edc/MinimumViableDataspace/blob/8141afce75613f62ed236cb325a862b8af40b903/docs/developer/decision-records/2022-06-15-registration-service/README.md#1-dataspace-participant-enrollment>`_
  実行する。

  - まずparticipantのVCを取得する。

  - その後、
    `membership VC <https://github.com/eclipse-edc/RegistrationService/tree/v0.3.1/docs/developer/decision-records/2022-08-03-membership-credential>`_
    というJWSを格納する。


FederatedCatalog
================

- https://github.com/eclipse-edc/FederatedCatalog

- /federatedcatalogというpathに対応したAPIをserveする。
  指定された条件を満たすContractOfferを返す。

  - https://github.com/eclipse-edc/FederatedCatalog/blob/6e4fccb942bb352f098b23f4f1e31f1e3b5957be/extensions/api/federated-catalog-api/src/main/java/org/eclipse/edc/catalog/api/query/FederatedCatalogApiController.java

- (test用ではない)extensionとしては4つ。::

    40 FederatedCatalog/core/federated-catalog-core/src/main/java/org/eclipse/edc/catalog/cache/FederatedCatalogCacheExtension.java public class FederatedCatalogCacheExtension implements ServiceExtension {
    37 FederatedCatalog/core/federated-catalog-core/src/main/java/org/eclipse/edc/catalog/cache/FederatedCatalogDefaultServicesExtension.java public class FederatedCatalogDefaultServicesExtension implements ServiceExtension {
    28 FederatedCatalog/extensions/api/federated-catalog-api/src/main/java/org/eclipse/edc/catalog/api/query/FederatedCatalogCacheQueryApiExtension.java public class FederatedCatalogCacheQueryApiExtension implements ServiceExtension {
    35 FederatedCatalog/extensions/store/fcc-node-directory-cosmos/src/main/java/org/eclipse/edc/catalog/node/directory/azure/CosmosFederatedCacheNodeDirectoryExtension.java public class CosmosFederatedCacheNodeDirectoryExtension implements ServiceExtension {


DataDashboard
=============

- https://github.com/eclipse-edc/DataDashboard

- デモ用のWeb UI。TypeScriptで実装されている。

- Catalogの画面は、/federatedcatalogから取得したContractOfferをすべて並べて表示している感じ。

  - https://github.com/eclipse-edc/DataDashboard/blob/c3ec34f730ca4322121c67e54ea2ae980c96c2f0/src/modules/edc-demo/services/catalog-browser.service.ts
