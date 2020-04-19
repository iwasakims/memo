single node conf with secure mode
---------------------------------

```
sudo yum install krb5-server krb5-libs krb5-workstation
```

Edit realm settings and comment out the line `default_ccache_name = KEYRING:persistent:%{uid}`
wise hadoop client library can not find cached credential.
```
sudo vi /etc/krb5.conf
sudo vi /var/kerberos/krb5kdc/kdc.conf
```

First component of principal name for KerberosAuthenticationHandler (kms and httpfs) must be HTTP.
```
sudo kdb5_util create -s
sudo kadmin.local -q "addprinc ${USER}/admin"
sudo systemctl start krb5kdc.service
sudo systemctl start kadmin.service

mkdir ${HOME}/keytab
kadmin addprinc -randkey hdfs/localhost@EXAMPLE.COM
kadmin addprinc -randkey yarn/localhost@EXAMPLE.COM
kadmin addprinc -randkey HTTP/localhost@EXAMPLE.COM
kadmin ktadd -k ${HOME}/keytab/hdfs.keytab hdfs/localhost@EXAMPLE.COM
kadmin ktadd -k ${HOME}/keytab/hdfs.keytab HTTP/localhost@EXAMPLE.COM
kadmin ktadd -k ${HOME}/keytab/yarn.keytab yarn/localhost@EXAMPLE.COM
kadmin ktadd -k ${HOME}/keytab/http.keytab HTTP/localhost@EXAMPLE.COM
kadmin ktadd -k ${HOME}/keytab/http.keytab HTTP/localhost@EXAMPLE.COM
```

container-exucutor and container-exucutor.cfg can not be placed under /home
since permission of parents are checked recursively.
```
cd ${HADOOP_HOME}

sudo ln ${PWD}/bin/container-executor /usr/local/bin/
sudo chown root:${USER} /usr/local/bin/container-executor
sudo chmod 6050 /usr/local/bin/container-executor

sudo mkdir -p /usr/local/etc/hadoop
sudo ln ${PWD}/etc/hadoop/container-executor.cfg /usr/local/etc/hadoop/
sudo chown root:${USER} /usr/local/etc/hadoop/container-executor.cfg
sudo chmod 644 /usr/local/etc/hadoop/container-executor.cfg 
```

"first and last name" (CN) must be hostname of server.
```
keytool -keystore ${HOME}/http.keystore -genkey -alias http -keyalg RSA
vi etc/hadoop/ssl-server.xml
vi etc/hadoop/ssl-client.xml
```

using SSLEnabled connector of Tomcat for kms and https.
```
mv share/hadoop/kms/tomcat/conf/server.xml share/hadoop/kms/tomcat/conf/server.xml.org
cp share/hadoop/kms/tomcat/conf/ssl-server.xml share/hadoop/kms/tomcat/conf/server.xml
mv share/hadoop/httpfs/tomcat/conf/server.xml share/hadoop/httpfs/tomcat/conf/server.xml.org
cp share/hadoop/httpfs/tomcat/conf/ssl-server.xml share/hadoop/httpfs/tomcat/conf/server.xml
```

webapp of httpfs requires ssl-client.xml on the classpath for https access to kms.
```
cp ${PWD}/etc/hadoop/ssl-client.xml share/hadoop/httpfs/tomcat/webapps/webhdfs/WEB-INF/classes/
```


https via curl
--------------

```
kinit -t ~/keytab/hdfs.keytab hdfs/localhost@EXAMPLE.COM
curl --negotiate -u : -k https://localhost:9871/conf
```


KMS
---

```
cd ${HADOOP_HOME}
sbin/kms.sh start
```


stop and start
--------------

```
sbin/yarn-daemon.sh stop nodemanager
sbin/yarn-daemon.sh stop resourcemanager
sbin/hadoop-daemon.sh stop datanode
sbin/hadoop-daemon.sh stop namenode
sbin/kms.sh stop
sbin/httpfs.sh stop

sbin/httpfs.sh start
sbin/kms.sh start
sbin/hadoop-daemon.sh start namenode
sbin/hadoop-daemon.sh start datanode
sbin/yarn-daemon.sh start resourcemanager
sbin/yarn-daemon.sh start nodemanager
```

downloading JCE policy
----------------------

```
curl -L -b "oraclelicense=a" -O http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip
```

testing kms and httpfs
----------------------

```
bin/hadoop key create hoge
bin/hdfs dfs -mkdir /encrypted
bin/hdfs crypto -createZone -keyName hoge -path /encrypted
curl -i -k --negotiate -u : -c cookiejar -X PUT 'https://localhost:14000/webhdfs/v1/encrypted/README.txt?op=CREATE&replication=1'
curl -i -k --negotiate -u : -b cookiejar -X PUT --header "Content-Type:application/octet-stream" --data-binary @README.txt 'https://localhost:14000/webhdfs/v1/encrypted/README.txt?op=CREATE&replication=1&data=true'
curl -i -k --negotiate -u : 'https://localhost:14000/webhdfs/v1/encrypted/README.txt?op=OPEN'
```
