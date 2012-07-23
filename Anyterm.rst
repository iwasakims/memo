========================================================
anytermを利用してWebブラウザからターミナルにアクセスする
========================================================

Amazon Linux AMI 2012.03から起動したEC2インスタンスで試した。

必要なパッケージのインストール。
開発環境、boost、httpdとmod_sslが必要。::

  $ sudo yum groupinstall development
  $ sudo yum install zlib-devel boost-devel
  $ sudo yum install httpd mod_ssl

anytermのソースコードをダウンロードしてコンパイルする。
GCC 4.4だと?、コンパイルでエラーになる部分があったため、
libpbe/src/SmtpClient.ccを1行書き換えた。::

  $ wget http://anyterm.org/download/anyterm-1.1.29.tbz2
  $ tar jxvf anyterm-1.1.29.tbz2
  $ cd anyterm-1.1.29
  $ cp libpbe/src/SmtpClient.cc /tmp/
  $ vim libpbe/src/SmtpClient.cc
  $ diff /tmp/SmtpClient.cc libpbe/src/SmtpClient.cc
  24a25
  > #include <cstdio>
  $ make

次にhttpdの設定を行う。Digest認証のためのファイルを作る。::

  $ sudo htdigest -c /etc/httpd/conf.d/.htdigest example.com ec2-user

opensslコマンドで、自己署名証明書を作る。::


  $ sudo mv cert.pem key.pem /etc/httpd/conf.d/
  $ cd /etc/httpd/conf.d/
  $ sudo openssl req -new -days 365 -x509 -keyout key.pem -out cert.pem
  $ sudo chown apache:apache cert.pem key.pem
  $ sudo chmod 600 cert.pem key.pem

mod_proxyとmod_sslでanytermにアクセスするための設定ファイルを作る。::

  $ vim /etc/httpd/conf.d/anyterm.conf
  $ cat /etc/httpd/conf.d/anyterm.conf
  <VirtualHost *:443>  # HTTPS port
      ServerName example.com
  
      <Location /anyterm>
          ProxyPass http://localhost:7676 ttl=60
          ProxyPassReverse http://localhost:7676
          AuthType Digest
          AuthName "example.com"
          AuthDigestDomain /anyterm/
          AuthDigestProvider file
          AuthUserFile /etc/httpd/conf.d/.htdigest
          Require valid-user
      </Location>
  
      SSLEngine on
      SSLCertificateFile /etc/httpd/conf.d/cert.pem
      SSLCertificateKeyFile /etc/httpd/conf.d/key.pem
  </VirtualHost>

anytermdとhttpdを起動する。::  
  
  $ ~/anyterm-1.1.29/anytermd -p 7676 --local-only
  $ sudo /etc/init.d/httpd start

最後に、EC2のSecurity Groupの設定で、TCP443番にアクセスできるようにする。

あとは、Webブラウザで、
https://ec2-xxx-xx-xxx-xxx.ap-northeast-1.compute.amazonaws.com/anyterm
のようなURLにアクセスするとダイアログが表示されるので、
ユーザ名とパスワードを入力すると、ターミナルが開く。

microインスタンスで試したこともあって、mod_ssl経由になるとターミナルがややもっさりする感じがした。
corkscrewが使える環境であれば、そちらを使った方が便利だと思われる。
