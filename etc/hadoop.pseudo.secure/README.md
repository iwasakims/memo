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

```
sudo kdb5_util create -s
sudo kadmin.local -q "addprinc ${USER}/admin"
sudo systemctl start krb5kdc.service
sudo systemctl start kadmin.service

mkdir ${HOME}/keytab
kadmin addprinc -randkey hdfs/localhost@EXAMPLE.COM
kadmin addprinc -randkey yarn/localhost@EXAMPLE.COM
kadmin addprinc -randkey http/localhost@EXAMPLE.COM
kadmin ktadd -k ${HOME}/keytab/hdfs.keytab hdfs/localhost@EXAMPLE.COM
kadmin ktadd -k ${HOME}/keytab/hdfs.keytab http/localhost@EXAMPLE.COM
kadmin ktadd -k ${HOME}/keytab/yarn.keytab yarn/localhost@EXAMPLE.COM
kadmin ktadd -k ${HOME}/keytab/yarn.keytab http/localhost@EXAMPLE.COM
```

```
keytool -keystore ${HOME}/http.keystore -genkey -alias http -keyalg RSA
```

```
cd ${HADOOP_HOME}

sudo ln ${PWD}/bin/container-executor /usr/local/bin/
sudo ln ${PWD}/bin/container-executor.cfg /usr/local/etc/hadoop/
sudo chown root:${USER} /usr/local/bin/container-executor
sudo chmod 6050 /usr/local/bin/container-executor

sudo mkdir -p /usr/local/etc/hadoop
sudo ln ${PWD}/etc/hadoop/container-executor.cfg /usr/local/etc/hadoop/
sudo chmod 644 /usr/local/etc/hadoop/container-executor.cfg 
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
echo hogemoge > etc/hadoop/kms.keystore.password
bin/hadoop --daemon start kms
bin/hadoop key create hoge
```


misc
----

```
curl -L -b "oraclelicense=a" -O http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip 
```

```
bin/yarn --daemon stop nodemanager
bin/yarn --daemon stop resourcemanager
bin/hdfs --daemon stop datanode
bin/hdfs --daemon stop namenode

bin/hdfs --daemon start namenode
bin/hdfs --daemon start datanode
bin/yarn --daemon start resourcemanager
bin/yarn --daemon start nodemanager
```
