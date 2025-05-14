```
cd ~/srcs
git clone https://github.com/iwasakims/memo
```

```
cd memo/docker/mydockerfile
docker build -t rockylinux8-openjdk8 -f Dockerfile.rockylinux8 .
docker network create --subnet=172.18.0.0/16 hadoop
```

```
export DIST=~/dist/storm-ha
mkdir -p ${DIST}
cd ${DIST}

wget https://dlcdn.apache.org/hadoop/common/hadoop-3.2.4/hadoop-3.2.4.tar.gz
tar zxf hadoop-3.2.4.tar.gz
cp ~/srcs/memo/docker/etc/hadoop.ha/* hadoop-3.2.4/etc/hadoop/

wget https://archive.apache.org/dist/zookeeper/zookeeper-3.5.9/apache-zookeeper-3.5.9-bin.tar.gz
tar zxf apache-zookeeper-3.5.9-bin.tar.gz
mv apache-zookeeper-3.5.9-bin zookeeper-3.5.9
cp ~/srcs/memo/docker/etc/zookeeper/zoo.cfg zookeeper-3.5.9/conf/

wget https://archive.apache.org/dist/storm/apache-storm-2.4.0/apache-storm-2.4.0.tar.gz
tar zxf apache-storm-2.4.0.tar.gz
mv apache-storm-2.4.0 storm-2.4.0
cp ~/srcs/memo/docker/etc/storm.ha/* storm-2.4.0/conf/
```

```
### For recent Maven rejecting HTTP.
###
# $ cat << EOF  > ~/.m2/settings.xml
# <settings xmlns="http://maven.apache.org/SETTINGS/1.2.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
#         xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.2.0 http://maven.apache.org/xsd/settings-1.2.0.xsd" >
#     <mirrors>
#        <mirror>
#            <id>maven-default-http-blocker</id>
#            <mirrorOf>dummy</mirrorOf>
#            <name>Dummy mirror to override default blocking mirror that blocks http</name>
#            <url>http://0.0.0.0/</url>
#        </mirror>
#     </mirrors>
# </settings>
# EOF

export DIST=~/dist/storm-ha
cd ~/srcs
git clone https://github.com/apache/storm
cd storm
git checkout v2.4.0
mvn clean install -DskipTests -Dhadoop.version=3.2.4
cp external/storm-hdfs-blobstore/target/storm-hdfs-blobstore-2.4.0.jar ${DIST}/storm-2.4.0/lib/
cp examples/storm-starter/target/storm-starter-2.4.0.jar ${DIST}/storm-2.4.0/lib-tools/

mv ${DIST}/storm-2.4.0/lib/hadoop-auth-2.8.5.jar ${DIST}/storm-2.4.0/lib/hadoop-auth-2.8.5.jar.org
```

```
export ZOOKEEPER_VERSION=3.5.9
export HADOOP_VERSION=3.2.4
export STORM_VERSION=2.4.0
export DIST=~/dist/storm-ha
cd ${DIST}
mkdir -p logs

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

docker exec h01 /hadoop/bin/hdfs --daemon start journalnode
docker exec h02 /hadoop/bin/hdfs --daemon start journalnode
docker exec h03 /hadoop/bin/hdfs --daemon start journalnode

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

docker exec -d h01 /bin/bash -c '/storm/bin/storm nimbus'
docker exec -d h01 /bin/bash -c '/storm/bin/storm supervisor'
docker exec -d h01 /bin/bash -c '/storm/bin/storm ui'
docker exec -d h02 /bin/bash -c '/storm/bin/storm nimbus'
docker exec -d h02 /bin/bash -c '/storm/bin/storm supervisor'
docker exec -d h03 /bin/bash -c '/storm/bin/storm nimbus'
docker exec -d h03 /bin/bash -c '/storm/bin/storm supervisor'

docker exec h01 /storm/bin/storm jar /storm/lib-tools/storm-starter-2.4.0.jar org.apache.storm.starter.WordCountTopology
```
