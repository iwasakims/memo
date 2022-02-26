single node conf with secure mode
---------------------------------

```
sudo yum install krb5-server krb5-libs krb5-workstation
```

Edit krb5.conf.
* update realm settings.
* comment out the line `default_ccache_name = KEYRING:persistent:%{uid}` which breaks cached credential lookup of hadoop client library.
* comment out the line `renew_lifetime = 7d` in order to address [JDK-8131051](https://bugs.openjdk.java.net/browse/JDK-8131051).

```
sudo vi /etc/krb5.conf
```

Edit realm settings of kdc.conf.

```
sudo vi /var/kerberos/krb5kdc/kdc.conf
```

On CentOS 8, /etc/krb5.conf.d/kcm_default_ccache should be edited too
since it has default_ccache_name entry.

```
sudo vi /etc/krb5.conf.d/kcm_default_ccache
```

First component of principal name for HttpServer must be HTTP (in upper case).
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
kadmin ktadd -k ${HOME}/keytab/yarn.keytab yarn/localhost@EXAMPLE.COM
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
sudo vi /usr/local/etc/hadoop/container-executor.cfg
```

"first and last name" (CN) must be hostname of server.
```
keytool -keystore ${HOME}/http.keystore -genkey -alias http -keyalg RSA -dname "CN=localhost, OU=Unknown, O=Unknown, L=Unknown, ST=Unknown, C=Unknown"
vi etc/hadoop/ssl-server.xml
vi etc/hadoop/ssl-client.xml
```


https via curl
--------------

```
kinit -kt ~/keytab/hdfs.keytab hdfs/localhost@EXAMPLE.COM
curl --negotiate -u : -k https://localhost:9871/conf
```


KMS
---

```
cd ${HADOOP_HOME}
kinit
bin/hadoop --daemon start kms
bin/hadoop key create key1
bin/hdfs dfs -mkdir /zone1
bin/hdfs crypto -createZone -path /zone1 -keyName key1
bin/hdfs dfs -put README.txt /zone1/
curl --negotiate -u : -k "https://localhost:9871/webhdfs/v1/zone1?op=LISTSTATUS"
bin/hadoop fs -cat swebhdfs://localhost:9871/zone1/README.txt
```


stop and start
--------------

    bin/hadoop --daemon stop kms
    bin/yarn --daemon stop nodemanager
    bin/yarn --daemon stop resourcemanager
    bin/hdfs --daemon stop datanode
    bin/hdfs --daemon stop namenode
    
    bin/hdfs --daemon start namenode
    bin/hdfs --daemon start datanode
    bin/yarn --daemon start resourcemanager
    bin/yarn --daemon start nodemanager
    bin/hadoop --daemon start kms


downloading JCE policy
----------------------

    curl -L -b "oraclelicense=a" -O http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip


memo
----

Token files can be specifiled by `hadoop.token.files` which is system property or configuration property.
https://github.com/apache/hadoop/blob/rel/release-3.2.0/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/security/UserGroupInformation.java#L721-L739

    $ HADOOP_OPTS='-Dhadoop.token.files=./dt.dat' bin/hadoop org.apache.hadoop.security.UserGroupInformation
    Getting UGI for current user
    2019-06-28 17:24:25,987 DEBUG security.SecurityUtil: Setting hadoop.security.token.service.use_ip to true
    2019-06-28 17:24:26,120 DEBUG security.Groups:  Creating new Groups object
    2019-06-28 17:24:26,124 DEBUG security.JniBasedUnixGroupsMapping: Using JniBasedUnixGroupsMapping for Group resolution
    2019-06-28 17:24:26,124 DEBUG security.JniBasedUnixGroupsMappingWithFallback: Group mapping impl=org.apache.hadoop.security.JniBasedUnixGroupsMapping
    2019-06-28 17:24:26,267 DEBUG security.Groups: Group mapping impl=org.apache.hadoop.security.JniBasedUnixGroupsMappingWithFallback; cacheTimeout=300000; warningDeltaMs=5000
    2019-06-28 17:24:26,291 DEBUG security.UserGroupInformation: hadoop login
    2019-06-28 17:24:26,294 DEBUG security.UserGroupInformation: hadoop login commit
    2019-06-28 17:24:26,295 DEBUG security.UserGroupInformation: using kerberos user:iwasakims@EXAMPLE.COM
    2019-06-28 17:24:26,295 DEBUG security.UserGroupInformation: Using user: "iwasakims@EXAMPLE.COM" with name iwasakims@EXAMPLE.COM
    2019-06-28 17:24:26,296 DEBUG security.UserGroupInformation: User entry: "iwasakims@EXAMPLE.COM"
    2019-06-28 17:24:26,298 DEBUG security.UserGroupInformation: Reading credentials from location /home/iwasakims/dist/hadoop-3.3.0-SNAPSHOT/dt.dat
    2019-06-28 17:24:26,370 DEBUG security.UserGroupInformation: Loaded 1 tokens from /home/iwasakims/dist/hadoop-3.3.0-SNAPSHOT/dt.dat
    2019-06-28 17:24:26,370 DEBUG security.UserGroupInformation: UGI loginUser:iwasakims@EXAMPLE.COM (auth:KERBEROS)
    User: iwasakims@EXAMPLE.COM
    Group Ids:
    2019-06-28 17:24:26,378 DEBUG security.UserGroupInformation: Current time is 1561710266378
    2019-06-28 17:24:26,378 DEBUG security.UserGroupInformation: Next refresh is 1561769251000
    2019-06-28 17:24:26,387 DEBUG security.Groups: GroupCacheLoader - load.
    Groups: docker iwasakims
    UGI: iwasakims@EXAMPLE.COM (auth:KERBEROS)
    Auth method KERBEROS
    Keytab false
    ============================================================

Recent GenericOptionsParser provides generic option `-tokenCacheFile` .
https://github.com/apache/hadoop/blob/rel/release-3.2.0/hadoop-common-project/hadoop-common/src/main/java/org/apache/hadoop/util/GenericOptionsParser.java#L341-L356

    bin/hadoop dtutil get hdfs://localhost:8020/ ./dt.dat
    bin/hdfs dfs -tokenCacheFile ./dt.dat -ls /
