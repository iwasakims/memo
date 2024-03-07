Setting up quick exp env for NN-HA and RM-HA for 3.0.0 and above
================================================================

```
$ cd ~/srcs
$ git clone https://github.com/iwasakims/memo
```

### setting up hadoop and zookeeper dist

```
cd ~/srcs/hadoop
mvn package -Pdist -Pnative -DskipTests
mv hadoop-dist/target/hadoop-3.2.4 ~/dist/
cp ~/srcs/memo/docker/etc/hadoop.ha/* ~/dist/hadoop-3.2.4/etc/hadoop/

wget https://dlcdn.apache.org/zookeeper/zookeeper-3.5.9/apache-zookeeper-3.5.9-bin.tar.gz
tar zxf apache-zookeeper-3.5.9-bin.tar.gz
mv apache-zookeeper-3.5.9-bin zookeeper-3.5.9
mv zookeeper-3.5.9 ~/dist/
cp ~/srcs/memo/docker/etc/zookeeper/zoo.cfg ~/dist/zookeeper-3.5.9/conf/
```

### setting up docker env

```
cd mydockerbuild
# docker build -t centos7-openjdk8 -f Dockerfile.centos7 .
# docker build -t centos8-openjdk8 -f Dockerfile.centos8 .
docker build -t rockylinux8-openjdk8 -f Dockerfile.rockylinux8 .

docker network create --subnet=172.18.0.0/16 hadoop

export HADOOP_VERSION=3.2.4
export ZOOKEEPER_VERSION=3.5.9
export DIST=~/dist
cd ${DIST}
mkdir -p logs

docker run -d -i -t --name h01 --net hadoop --hostname h01 --ip 172.18.0.11 -v ${DIST}/hadoop-${HADOOP_VERSION}:/hadoop -v ${DIST}/zookeeper-${ZOOKEEPER_VERSION}:/zookeeper -v ${DIST}/logs:/logs rockylinux8-openjdk8 /bin/bash
docker run -d -i -t --name h02 --net hadoop --hostname h02 --ip 172.18.0.12 -v ${DIST}/hadoop-${HADOOP_VERSION}:/hadoop -v ${DIST}/zookeeper-${ZOOKEEPER_VERSION}:/zookeeper -v ${DIST}/logs:/logs rockylinux8-openjdk8 /bin/bash
docker run -d -i -t --name h03 --net hadoop --hostname h03 --ip 172.18.0.13 -v ${DIST}/hadoop-${HADOOP_VERSION}:/hadoop -v ${DIST}/zookeeper-${ZOOKEEPER_VERSION}:/zookeeper -v ${DIST}/logs:/logs rockylinux8-openjdk8 /bin/bash

```

### starting daemons

```
docker exec h01 mkdir /zk
docker exec h01 bash -c 'echo 1 > /zk/myid'
docker exec h01 /zookeeper/bin/zkServer.sh start
docker exec h02 mkdir /zk
docker exec h02 bash -c 'echo 2 > /zk/myid'
docker exec h02 /zookeeper/bin/zkServer.sh start
docker exec h03 mkdir /zk
docker exec h03 bash -c 'echo 3 > /zk/myid'
docker exec h03 /zookeeper/bin/zkServer.sh start

sleep 5

docker exec h01 /hadoop/bin/hdfs --daemon start journalnode
docker exec h02 /hadoop/bin/hdfs --daemon start journalnode
docker exec h03 /hadoop/bin/hdfs --daemon start journalnode

sleep 5

docker exec h01 /hadoop/bin/hdfs namenode -format -force -nonInteractive
docker exec h01 /hadoop/bin/hdfs zkfc -formatZK -force -nonInteractive
docker exec h01 /hadoop/bin/hdfs --daemon start namenode
docker exec h01 /hadoop/bin/hdfs --daemon start zkfc

docker exec h02 /hadoop/bin/hdfs namenode -bootstrapStandby -force -nonInteractive
docker exec h02 /hadoop/bin/hdfs --daemon start namenode
docker exec h02 /hadoop/bin/hdfs --daemon start zkfc

docker exec h03 /hadoop/bin/hdfs namenode -bootstrapStandby -force -nonInteractive
docker exec h03 /hadoop/bin/hdfs --daemon start namenode
docker exec h03 /hadoop/bin/hdfs --daemon start zkfc

docker exec h01 /hadoop/bin/hdfs --daemon start datanode
docker exec h02 /hadoop/bin/hdfs --daemon start datanode
docker exec h03 /hadoop/bin/hdfs --daemon start datanode

docker exec h01 /hadoop/bin/yarn --daemon start resourcemanager
docker exec h02 /hadoop/bin/yarn --daemon start resourcemanager
docker exec h03 /hadoop/bin/yarn --daemon start resourcemanager

docker exec h01 /hadoop/bin/yarn --daemon start nodemanager
docker exec h02 /hadoop/bin/yarn --daemon start nodemanager
docker exec h03 /hadoop/bin/yarn --daemon start nodemanager
```

### removing containers

```
docker kill h01 h02 h03
docker rm h01 h02 h03
```
