setting up quick exp env for NN-HA
==================================

````
$ cd ~/srcs
$ git clone https://github.com/iwasakims/memo
````

setting up hadoop and zookeeper dist
------------------------------------

````
$ cd ~/srcs/hadoop
$ mvn package -Pdist -Pnative -DskipTests
$ mv hadoop-dist/target/hadoop-3.0.0-alpha3-SNAPSHOT ~/dist/
$ cp ~/srcs/memo/docker/etc/hadoop.ha/* ~/dist/hadoop-3.0.0-alpha3-SNAPSHOT/etc/hadoop/

$ wget http://ftp.tsukuba.wide.ad.jp/software/apache/zookeeper/zookeeper-3.4.9/zookeeper-3.4.9.tar.gz
$ tar zxf zookeeper-3.4.9.tar.gz
$ mv zookeeper-3.4.9 ~/dist/
$ cp ~/srcs/memo/docker/etc/zookeeper/zoo.cfg ~/dist/zookeeper-3.4.9/conf/
````

setting up docker env
---------------------

```
$ cd mydockerbuild
$ docker build -t centos7-openjdk8 .

$ docker network create --subnet=172.18.0.0/16 hadoop

$ docker run -d -i -t --name hadoop01 --net hadoop --ip 172.18.0.11 -v ~/dist/hadoop-3.0.0-alpha3-SNAPSHOT:/hadoop -v ~/dist/zookeeper-3.4.9:/zookeeper centos7-openjdk8 /bin/bash
$ docker run -d -i -t --name hadoop02 --net hadoop --ip 172.18.0.12 -v ~/dist/hadoop-3.0.0-alpha3-SNAPSHOT:/hadoop -v ~/dist/zookeeper-3.4.9:/zookeeper centos7-openjdk8 /bin/bash
$ docker run -d -i -t --name hadoop03 --net hadoop --ip 172.18.0.13 -v ~/dist/hadoop-3.0.0-alpha3-SNAPSHOT:/hadoop -v ~/dist/zookeeper-3.4.9:/zookeeper centos7-openjdk8 /bin/bash
```

starting daemons
----------------

```
$ docker exec hadoop01 mkdir /zk
$ docker exec hadoop01 bash -c 'echo 1 > /zk/myid'
$ docker exec hadoop01 /zookeeper/bin/zkServer.sh start
$ docker exec hadoop02 mkdir /zk
$ docker exec hadoop02 bash -c 'echo 2 > /zk/myid'
$ docker exec hadoop02 /zookeeper/bin/zkServer.sh start
$ docker exec hadoop03 mkdir /zk
$ docker exec hadoop03 bash -c 'echo 3 > /zk/myid'
$ docker exec hadoop03 /zookeeper/bin/zkServer.sh start

$ sleep 5

$ docker exec hadoop01 /hadoop/bin/hdfs --daemon start journalnode
$ docker exec hadoop02 /hadoop/bin/hdfs --daemon start journalnode
$ docker exec hadoop03 /hadoop/bin/hdfs --daemon start journalnode

$ sleep 5

$ docker exec hadoop01 /hadoop/bin/hdfs namenode -format -force -nonInteractive
$ docker exec hadoop01 /hadoop/bin/hdfs zkfc -formatZK -force -nonInteractive
$ docker exec hadoop01 /hadoop/bin/hdfs --daemon start namenode
$ docker exec hadoop01 /hadoop/bin/hdfs --daemon start zkfc

$ docker exec hadoop02 /hadoop/bin/hdfs namenode -bootstrapStandby -force -nonInteractive
$ docker exec hadoop02 /hadoop/bin/hdfs --daemon start namenode
$ docker exec hadoop02 /hadoop/bin/hdfs --daemon start zkfc

$ docker exec hadoop03 /hadoop/bin/hdfs namenode -bootstrapStandby -force -nonInteractive
$ docker exec hadoop03 /hadoop/bin/hdfs --daemon start namenodefor NN-HA and RM-HA 

$ docker exec hadoop01 /hadoop/bin/hdfs --daemon start datanode
$ docker exec hadoop02 /hadoop/bin/hdfs --daemon start datanode
$ docker exec hadoop03 /hadoop/bin/hdfs --daemon start datanode
```
