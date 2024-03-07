Setting up quick exp env for NN-HA and RM-HA for hadoop-2.10
============================================================

### setting up hadoop and zookeeper dist

branch-2 does not support multi standby NN and --daemon option.

````
cd ~/srcs/hadoop-2.10.1
mvn package -Pdist -Pnative -DskipTests
mv hadoop-dist/target/hadoop-2.10.1 ~/dist/
cp ~/srcs/memo/docker/etc/hadoop.ha.branch-2/* ~/dist/hadoop-2.10.1/etc/hadoop/
...
````


````
...
docker run -d -i -t --name hadoop01 --net hadoop --ip 172.18.0.11 -v ~/dist/hadoop-2.10.1:/hadoop -v ~/dist/zookeeper-3.4.14:/zookeeper centos8-openjdk8 /bin/bash
docker run -d -i -t --name hadoop02 --net hadoop --ip 172.18.0.12 -v ~/dist/hadoop-2.10.1:/hadoop -v ~/dist/zookeeper-3.4.14:/zookeeper centos8-openjdk8 /bin/bash
docker run -d -i -t --name hadoop03 --net hadoop --ip 172.18.0.13 -v ~/dist/hadoop-2.10.1:/hadoop -v ~/dist/zookeeper-3.4.14:/zookeeper centos8-openjdk8 /bin/bash
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

docker exec hadoop03 /hadoop/bin/hdfs namenode -bootstrapStandby -force -nonInteractive
docker exec hadoop03 /hadoop/sbin/hadoop-daemon.sh start namenode
docker exec hadoop03 /hadoop/sbin/hadoop-daemon.sh start zkfc

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
