::

  ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ec2-user@


ノード一覧の作成::

  ec2din --hide-tags --filter tag:role=master | grep INSTANCE | awk '{print $5}' > masters
  ec2din --hide-tags --filter tag:role=slave | grep INSTANCE | awk '{print $5}' > slaves
  cat masters slaves > ansible_hosts

インスタンス起動後の仕込み::

  pssh -h slaves -- sudo mount /dev/xvdf /ephemeral
  pssh -h slaves -- tar -z -x -f hadoop-3.0.0-SNAPSHOT.tar.gz -C /ephemeral
  pssh -h slaves -- ln -s /ephemeral/hadoop-3.0.0-SNAPSHOT /ephemeral/hadoop
  pssh -h slaves -- mv /ephemeral/hadoop/etc/hadoop /ephemeral/hadoop/etc/hadoop.org
  pssh -h slaves -- ln -s /etc/hadoop /ephemeral/hadoop/etc/
  $HADOOP_HOME/bin/hdfs namenode -format
  $HADOOP_HOME/sbin/start-dfs.sh

設定ファイルの同期::

  pssh -h slaves -- pssh -h slaves rsync -av master:/etc/hadoop /etc/


ちょっとコンパイルと実行。::

  HADOOP_CLASSPATH=$JAVA_HOME/lib/tools.jar $HADOOP_HOME/bin/hdfs com.sun.tools.javac.Main TracingFsShell.java
  HADOOP_CLASSPATH=. $HADOOP_HOME/bin/hdfs TracingFsShell
