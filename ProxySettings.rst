各種コマンド類でプロキシサーバを越えるための設定
================================================

yum
---

/etc/yum.confに以下のような内容を記述。::

  proxy=http://proxy.example.com:8080
  proxy_username=ユーザ名
  proxy_password=パスワード


wget
----

/etc/wgetrcに以下を記述。::

  http_proxy = http://proxy.example.com:8080
  proxy_user = ユーザ名
  proxy_passwd = パスワード


curl
----

環境変数http_proxyで指定する。::

  $ export http_proxy=http://ユーザ名:パスワード@proxy.example.com:8080
  $ export https_proxy=http://ユーザ名:パスワード@proxy.example.com:8080


Ant
---

build.xmlのsetproxyタスクで設定できる。::

  <setproxy proxyhost="proxy.example.com" proxyport="8080"
            proxyuser="ユーザ名" proxypassword="パスワード" />

RedHat系のRPMでantをインストールした場合、ant-commons-netパッケージも必要。::

  $ yum install ant-commons-net

プロキシサーバとポート番号は、
環境変数HTTP_PROXY_HOST、HTTP_PROXY_PORTで指定することもできる。
環境変数HTTP_PROXY_USERNAME、HTTP_PROXY_PASSWORDで、
認証情報も指定できるという記述もみかけるが、
そちらはgetタスクでは効かない様子。


Subversion
----------

~/.subversion/serversに以下の内容を記述する。::

  [global]
  http-proxy-host = proxy.example.com
  http-proxy-port = 8080
  http-proxy-username = ユーザ名
  http-proxy-password = パスワード


Git
---

curl_ と同じ。環境変数http_proxyで指定する。::

  $ export http_proxy=http://ユーザ名:パスワード@proxy.example.com:8080
  $ export https_proxy=http://ユーザ名:パスワード@proxy.example.com:8080
  $ git clone http://foo.bar/baz

プロキシとは関係ないが、
ちゃんとした証明書がないところにアクセスする場合、以下の指定が必要。::

 $ GIT_SSL_NO_VERIFY=1 git clone http://foo.bar/baz


Maven
-----

~/.m2/settings.xmlに以下のような内容を記述。::

  <?xml version="1.0" encoding="UTF-8"?>
  <settings>
    <proxies>
      <proxy>
        <id>My Proxy</id>
        <active />
        <protocol>http</protocol>
        <host>proxy.example.com</host>
        <port>8080</port>
        <username>username</username>
        <password>password</password>
        <nonProxyHosts>127.0.0.1|*.example.com</nonProxyHosts>
      </proxy>
    </proxies>
  </settings>


leiningen
---------

version 1はMaven依存で、たぶん~/.m2/settings.xmlで指定。::

  <?xml version="1.0" encoding="UTF-8"?>
  <settings>
    <proxies>
      <proxy>
        <id>My Proxy</id>
        <active />
        <protocol>http</protocol>
        <host>proxy.example.com</host>
        <port>8080</port>
        <username>username</username>
        <password>password</password>
        <nonProxyHosts>127.0.0.1|*.example.com</nonProxyHosts>
      </proxy>
    </proxies>
  </settings>

version 2系は環境変数方式::

  http_proxy=http://username:password@proxy:port


sbt
---

javaのシステムプロパティ経由で指定する。::

  $ SBT_OPTS="-Dhttp.proxyHost=proxy.example.com -Dhttp.proxyPort=8080 -Dhttp.proxyUser=username -Dhttp.proxyPassword=password" \
      sbt clean update package-dist


easy_install
------------

環境変数HTTP_PROXYを指定。
urllib2_ を参照。


urllib2
-------

環境変数HTTP_PROXYを指定。::

  export HTTP_PROXY=http://ユーザ名:パスワード@proxyhost:port/


pythonのコード内で指定したい場合、以下のような感じでいけるっぽい。::

  import urllib2
  
  auth_handler = urllib2.ProxyBasicAuthHandler(urllib2.HTTPPasswordMgrWithDefaultRealm())
  auth_handler.add_password(None, 'proxy.example.com:8080', 'ユーザ名', 'パスワード')
  opener = urllib2.build_opener(auth_handler)
  urllib2.install_opener(opener)
  res = urllib2.urlopen('http://www.google.co.jp/')
  for line in res:
    print line


gem
---

これまた環境変数http_proxyの設定でいける。::

 export http_proxy=http://ユーザ名:パスワード@proxy.example.com:8080/

~/.gem.rcに書いておく方法もあるようだ。::

  http_proxy: http://ユーザ名:パスワード@proxy.example.com:8080
