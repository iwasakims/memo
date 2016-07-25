export JAVA_HOME={{ java_home }}

export HBASE_OPTS="-XX:+UseConcMarkSweepGC -XX:CMSInitiatingOccupancyFraction=70"

export HBASE_MASTER_OPTS="\
-XX:PermSize=128m \
-XX:MaxPermSize=128m\
-Dcom.sun.management.jmxremote=true \
-Dcom.sun.management.jmxremote.authenticate=false \
-Dcom.sun.management.jmxremote.ssl=false \
-Dcom.sun.management.jmxremote.port=10101 \
-Xmx2g"

export HBASE_REGIONSERVER_OPTS="\
-XX:PermSize=128m \
-XX:MaxPermSize=128m\
-Dcom.sun.management.jmxremote=true \
-Dcom.sun.management.jmxremote.authenticate=false \
-Dcom.sun.management.jmxremote.ssl=false \
-Dcom.sun.management.jmxremote.port=10102 \
-Xmx24g"

export SERVER_GC_OPTS="-verbose:gc -XX:+PrintGCDetails -XX:+PrintGCDateStamps"

# HBASE_ROOT_LOGGER=INFO,DRFA
# The reason for changing default to RFA is to avoid the boundary case of filling out disk space as 
# DRFA doesn't put any cap on the log size. Please refer to HBase-5655 for more context.

export HADOOP_HOME={{ hadoop_home }}
