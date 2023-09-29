```
export DIST=~/dist/storm-ha
cd ${DIST}

wget https://dlcdn.apache.org/hadoop/common/hadoop-3.2.4/hadoop-3.2.4.tar.gz
tar zxf hadoop-3.2.4.tar.gz
cp ~/srcs/memo/docker/etc/hadoop.ha/* hadoop-3.2.4/etc/hadoop/

wget https://dlcdn.apache.org/zookeeper/zookeeper-3.5.9/apache-zookeeper-3.5.9-bin.tar.gz
tar zxf apache-zookeeper-3.5.9-bin.tar.gz
mv apache-zookeeper-3.5.9-bin zookeeper-3.5.9
mv zookeeper-3.5.9 ${DIST}/
cp ~/srcs/memo/docker/etc/zookeeper/zoo.cfg zookeeper-3.5.9/conf/

wget https://archive.apache.org/dist/storm/apache-storm-2.4.0/apache-storm-2.4.0.tar.gz
tar zxf apache-storm-2.4.0.tar.gz
mv apache-storm-2.4.0 storm-2.4.0
cp ~/srcs/memo/docker/etc/storm.ha/* storm-2.4.0/conf/

cd ~/srcs/storm
mvn clean install -DskipTests -Dhadoop.version=3.2.4
cp external/storm-hdfs-blobstore/target/storm-hdfs-blobstore-2.4.0.jar ${DIST}/storm-2.4.0/lib/
```

```
export ZOOKEEPER_VERSION=3.5.9
export HADOOP_VERSION=3.2.4
export STORM_VERSION=2.4.0
export DIST=~/dist
cd ${DIST}
mkdir logs
```

```
docker kill h01 h02 h03
docker rm h01 h02 h03

sudo rm -rf ./logs/*

docker run -d -i -t --name h01 --net hadoop --hostname h01 --ip 172.18.0.11 -v ${DIST}/zookeeper-${ZOOKEEPER_VERSION}:/zookeeper -v ${DIST}/hadoop-${HADOOP_VERSION}:/hadoop -v ${DIST}/storm-${STORM_VERSION}:/storm -v ${DIST}/logs/h01:/logs rockylinux8-openjdk8 /bin/bash
docker run -d -i -t --name h02 --net hadoop --hostname h02 --ip 172.18.0.12 -v ${DIST}/zookeeper-${ZOOKEEPER_VERSION}:/zookeeper -v ${DIST}/hadoop-${HADOOP_VERSION}:/hadoop -v ${DIST}/storm-${STORM_VERSION}:/storm -v ${DIST}/logs/h02:/logs rockylinux8-openjdk8 /bin/bash
docker run -d -i -t --name h03 --net hadoop --hostname h03 --ip 172.18.0.13 -v ${DIST}/zookeeper-${ZOOKEEPER_VERSION}:/zookeeper -v ${DIST}/hadoop-${HADOOP_VERSION}:/hadoop -v ${DIST}/storm-${STORM_VERSION}:/storm -v ${DIST}/logs/h03:/logs rockylinux8-openjdk8 /bin/bash

docker exec h01 mkdir /zk
docker exec h01 bash -c 'echo 1 > /zk/myid'
docker exec h01 /zookeeper/bin/zkServer.sh start
docker exec h02 mkdir /zk
docker exec h02 bash -c 'echo 2 > /zk/myid'
docker exec h02 /zookeeper/bin/zkServer.sh start
docker exec h03 mkdir /zk
docker exec h03 bash -c 'echo 3 > /zk/myid'
docker exec h03 /zookeeper/bin/zkServer.sh start

sleep 3

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

sleep 3

docker exec h01 /bin/bash -c 'nohup /storm/bin/storm nimbus &'
sleep 3
docker exec h02 /bin/bash -c 'nohup /storm/bin/storm nimbus &'
sleep 3
docker exec h03 /bin/bash -c 'nohup /storm/bin/storm nimbus &'
sleep 3
docker exec h01 /bin/bash -c 'nohup /storm/bin/storm supervisor &'
sleep 3
docker exec h02 /bin/bash -c 'nohup /storm/bin/storm supervisor &'
sleep 3
docker exec h03 /bin/bash -c 'nohup /storm/bin/storm supervisor &'
sleep 3

docker exec h01 /storm/bin/storm jar /storm/storm-starter-2.4.0.jar org.apache.storm.starter.WordCountTopology
```
