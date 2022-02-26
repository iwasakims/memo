Setting up quick exp env for NN-HA and RM-HA
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

wget https://dlcdn.apache.org/zookeeper/zookeeper-3.5.9/apache-zookeeper-3.5.9-bin.tar.gz
tar zxf apache-zookeeper-3.5.9-bin.tar.gz
mv apache-zookeeper-3.5.9-bin zookeeper-3.5.9
mv zookeeper-3.5.9 ~/dist/
cp ~/srcs/memo/docker/etc/zookeeper/zoo.cfg ~/dist/zookeeper-3.5.9/conf/
````

### setting up docker env

```
cd mydockerbuild
# docker build -t centos7-openjdk8 -f Dockerfile.centos7 .
# docker build -t centos8-openjdk8 -f Dockerfile.centos8 .
docker build -t rockylinux8-openjdk8 -f Dockerfile.rockylinux8 .

docker network create --subnet=172.18.0.0/16 hadoop

cd ~/dist/
mkdir -p logs
docker run -d -i -t --name hadoop01 --net hadoop --ip 172.18.0.11 -v ~/dist/hadoop-3.3.0-SNAPSHOT:/hadoop -v ~/dist/zookeeper-3.5.9:/zookeeper -v ~/dist/logs:/logs rockylinux8-openjdk8 /bin/bash
docker run -d -i -t --name hadoop02 --net hadoop --ip 172.18.0.12 -v ~/dist/hadoop-3.3.0-SNAPSHOT:/hadoop -v ~/dist/zookeeper-3.5.9:/zookeeper -v ~/dist/logs:/logs rockylinux8-openjdk8 /bin/bash
docker run -d -i -t --name hadoop03 --net hadoop --ip 172.18.0.13 -v ~/dist/hadoop-3.3.0-SNAPSHOT:/hadoop -v ~/dist/zookeeper-3.5.9:/zookeeper -v ~/dist/logs:/logs rockylinux8-openjdk8 /bin/bash
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

### removing containers

```
docker kill hadoop01 hadoop02 hadoop03
docker rm hadoop01 hadoop02 hadoop03
```


for hadoop-2
------------

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


Network settings on Docker host
===============================

firewalld rules on CentOS 8
---------------------------

On CentOS 8, nftables rules activated by firewalld drops inter-container packets.

`nft` command shows the rules.::

    $ sudo nft -a list ruleset | less

We can not use `trusted` zone here because masquerade are enabled.::

    $ sudo firewall-cmd --info-zone=trusted
    trusted
      target: ACCEPT
      icmp-block-inversion: no
      interfaces: 
      sources: 
      services: 
      ports: 
      protocols: 
      masquerade: yes
      forward-ports: 
      source-ports: 
      icmp-blocks: 
      rich rules: 
    
    $ sudo nft -a list chain nat_POST_trusted_allow
    
            chain nat_POST_trusted_allow { # handle 39
                    oifname != "lo" masquerade # handle 46
            }
  
Adding new zone targeted to ACCEPT and assign docker interfaces to it should work.::

    $ sudo firewall-cmd --permanent --new-zone=docker
    $ sudo firewall-cmd --permanent --zone=docker --set-target=ACCEPT
    $ sudo firewall-cmd --permanent --zone=docker --add-interface=docker0
    $ sudo firewall-cmd --permanent --zone=docker --add-interface=br-ab1b9c795ab1
    $ sudo firewall-cmd --reload
    $ sudo firewall-cmd --info-zone=docker
    docker (active)
      target: ACCEPT
      icmp-block-inversion: no
      interfaces: br-ab1b9c795ab1 docker0
      sources: 
      services: 
      ports: 
      protocols: 
      masquerade: no
      forward-ports: 
      source-ports: 
      icmp-blocks: 
