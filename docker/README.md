setting up quick exp env for NN-HA and RM-HA
============================================

for hadoop-3
------------

````
$ cd ~/srcs
$ git clone https://github.com/iwasakims/memo
````

### setting up hadoop and zookeeper dist

````
cd ~/srcs/hadoop
mvn package -Pdist -Pnative -DskipTests
mv hadoop-dist/target/hadoop-3.3.0-SNAPSHOT ~/dist/
cp ~/srcs/memo/docker/etc/hadoop.ha/* ~/dist/hadoop-3.3.0-SNAPSHOT/etc/hadoop/

wget http://ftp.riken.jp/net/apache/zookeeper/zookeeper-3.4.14/zookeeper-3.4.14.tar.gz
tar zxf zookeeper-3.4.14.tar.gz
mv zookeeper-3.4.14 ~/dist/
cp ~/srcs/memo/docker/etc/zookeeper/zoo.cfg ~/dist/zookeeper-3.4.14/conf/
````

### setting up docker env

```
cd mydockerbuild
docker build -t centos7-openjdk8 .

docker network create --subnet=172.18.0.0/16 hadoop

cd ~/dist/
mkdir -p logs
docker run -d -i -t --name hadoop01 --net hadoop --ip 172.18.0.11 -v ~/dist/hadoop-3.3.0-SNAPSHOT:/hadoop -v ~/dist/zookeeper-3.4.14:/zookeeper -v ~/dist/logs:/logs centos7-openjdk8 /bin/bash
docker run -d -i -t --name hadoop02 --net hadoop --ip 172.18.0.12 -v ~/dist/hadoop-3.3.0-SNAPSHOT:/hadoop -v ~/dist/zookeeper-3.4.14:/zookeeper -v ~/dist/logs:/logs centos7-openjdk8 /bin/bash
docker run -d -i -t --name hadoop03 --net hadoop --ip 172.18.0.13 -v ~/dist/hadoop-3.3.0-SNAPSHOT:/hadoop -v ~/dist/zookeeper-3.4.14:/zookeeper -v ~/dist/logs:/logs centos7-openjdk8 /bin/bash
```

### starting daemons

```
docker exec hadoop01 mkdir /zk
docker exec hadoop01 bash -c 'echo 1 > /zk/myid'
docker exec hadoop01 /zookeeper/bin/zkServer.sh start
docker exec hadoop02 mkdir /zk
docker exec hadoop02 bash -c 'echo 2 > /zk/myid'
docker exec hadoop02 /zookeeper/bin/zkServer.sh start
docker exec hadoop03 mkdir /zk
docker exec hadoop03 bash -c 'echo 3 > /zk/myid'
docker exec hadoop03 /zookeeper/bin/zkServer.sh start

sleep 5

docker exec hadoop01 /hadoop/bin/hdfs --daemon start journalnode
docker exec hadoop02 /hadoop/bin/hdfs --daemon start journalnode
docker exec hadoop03 /hadoop/bin/hdfs --daemon start journalnode

sleep 5

docker exec hadoop01 /hadoop/bin/hdfs namenode -format -force -nonInteractive
docker exec hadoop01 /hadoop/bin/hdfs zkfc -formatZK -force -nonInteractive
docker exec hadoop01 /hadoop/bin/hdfs --daemon start namenode
docker exec hadoop01 /hadoop/bin/hdfs --daemon start zkfc

docker exec hadoop02 /hadoop/bin/hdfs namenode -bootstrapStandby -force -nonInteractive
docker exec hadoop02 /hadoop/bin/hdfs --daemon start namenode
docker exec hadoop02 /hadoop/bin/hdfs --daemon start zkfc

docker exec hadoop03 /hadoop/bin/hdfs namenode -bootstrapStandby -force -nonInteractive
docker exec hadoop03 /hadoop/bin/hdfs --daemon start namenode
docker exec hadoop03 /hadoop/bin/hdfs --daemon start zkfc

docker exec hadoop01 /hadoop/bin/hdfs --daemon start datanode
docker exec hadoop02 /hadoop/bin/hdfs --daemon start datanode
docker exec hadoop03 /hadoop/bin/hdfs --daemon start datanode

docker exec hadoop01 /hadoop/bin/yarn --daemon start resourcemanager
docker exec hadoop02 /hadoop/bin/yarn --daemon start resourcemanager
docker exec hadoop03 /hadoop/bin/yarn --daemon start resourcemanager

docker exec hadoop01 /hadoop/bin/yarn --daemon start nodemanager
docker exec hadoop02 /hadoop/bin/yarn --daemon start nodemanager
docker exec hadoop03 /hadoop/bin/yarn --daemon start nodemanager
```

for hadoop-2
------------

### setting up hadoop and zookeeper dist

branch-2 does not support multi standby NN and --daemon option.

````
cd ~/srcs/hadoop-2.8.0
mvn package -Pdist -Pnative -DskipTests
mv hadoop-dist/target/hadoop-2.8.0 ~/dist/
cp ~/srcs/memo/docker/etc/hadoop.ha.branch-2/* ~/dist/hadoop-2.8.0/etc/hadoop/
...
````


````
...
docker run -d -i -t --name hadoop01 --net hadoop --ip 172.18.0.11 -v ~/dist/hadoop-2.8.0:/hadoop -v ~/dist/zookeeper-3.4.9:/zookeeper centos7-openjdk8 /bin/bash
docker run -d -i -t --name hadoop02 --net hadoop --ip 172.18.0.12 -v ~/dist/hadoop-2.8.0:/hadoop -v ~/dist/zookeeper-3.4.9:/zookeeper centos7-openjdk8 /bin/bash
docker run -d -i -t --name hadoop03 --net hadoop --ip 172.18.0.13 -v ~/dist/hadoop-2.8.0:/hadoop -v ~/dist/zookeeper-3.4.9:/zookeeper centos7-openjdk8 /bin/bash
````

````
docker exec hadoop01 mkdir /zk
docker exec hadoop01 bash -c 'echo 1 > /zk/myid'
docker exec hadoop01 /zookeeper/bin/zkServer.sh start
docker exec hadoop02 mkdir /zk
docker exec hadoop02 bash -c 'echo 2 > /zk/myid'
docker exec hadoop02 /zookeeper/bin/zkServer.sh start
docker exec hadoop03 mkdir /zk
docker exec hadoop03 bash -c 'echo 3 > /zk/myid'
docker exec hadoop03 /zookeeper/bin/zkServer.sh start

sleep 5

docker exec hadoop01 /hadoop/sbin/hadoop-daemon.sh start journalnode
docker exec hadoop02 /hadoop/sbin/hadoop-daemon.sh start journalnode
docker exec hadoop03 /hadoop/sbin/hadoop-daemon.sh start journalnode

sleep 5

docker exec hadoop01 /hadoop/bin/hdfs namenode -format -force -nonInteractive
docker exec hadoop01 /hadoop/bin/hdfs zkfc -formatZK -force -nonInteractive
docker exec hadoop01 /hadoop/sbin/hadoop-daemon.sh start namenode
docker exec hadoop01 /hadoop/sbin/hadoop-daemon.sh start zkfc

docker exec hadoop02 /hadoop/bin/hdfs namenode -bootstrapStandby -force -nonInteractive
docker exec hadoop02 /hadoop/sbin/hadoop-daemon.sh start namenode
docker exec hadoop02 /hadoop/sbin/hadoop-daemon.sh start zkfc

docker exec hadoop01 /hadoop/sbin/hadoop-daemon.sh start datanode
docker exec hadoop02 /hadoop/sbin/hadoop-daemon.sh start datanode
docker exec hadoop03 /hadoop/sbin/hadoop-daemon.sh start datanode

docker exec hadoop01 /hadoop/sbin/yarn-daemon.sh start resourcemanager
docker exec hadoop02 /hadoop/sbin/yarn-daemon.sh start resourcemanager
docker exec hadoop03 /hadoop/sbin/yarn-daemon.sh start resourcemanager

docker exec hadoop01 /hadoop/sbin/yarn-daemon.sh start nodemanager
docker exec hadoop02 /hadoop/sbin/yarn-daemon.sh start nodemanager
docker exec hadoop03 /hadoop/sbin/yarn-daemon.sh start nodemanager
````
