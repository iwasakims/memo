 bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin" >/dev/null && pwd`

if [ $# -lt 2 ]; then
  S=`basename "${BASH_SOURCE-$0}"`
  echo "Usage: $S [--config <conf-dir>] [start|stop] offset(s)"
  echo ""
  echo "    e.g. $S start 1"
  exit
fi

. "$bin"/../libexec/yarn-config.sh

run_master () {
  COMMAND=$1
  shift
  DN=$1
  shift
  RMID="rm${DN}"
  OFFSET=`expr $DN \* 100`
  HOST=`hostname`
  export YARN_IDENT_STRING="$USER-$DN"
  YARN_RESOURCEMANAGER_ARGS="$@ \
    -Dyarn.resourcemanager.ha.enabled=true \
    -Dyarn.resourcemanager.ha.automatic-failover.enabled=false \
    -Dyarn.resourcemanager.cluster-id=cl1 \
    -Dyarn.resourcemanager.ha.id=${RMID} \
    -Dyarn.resourcemanager.webapp.address.${RMID}=$HOST:`expr 8088 + $OFFSET` \
    -Dyarn.resourcemanager.scheduler.address.${RMID}=$HOST:`expr 8030 + $OFFSET` \
    -Dyarn.resourcemanager.resource-tracker.address.${RMID}=$HOST:`expr 8031 + $OFFSET` \
    -Dyarn.resourcemanager.address.${RMID}=$HOST:`expr 8032 + $OFFSET` \
    -Dyarn.resourcemanager.admin.address.${RMID}=$HOST:`expr 8033 + $OFFSET` "
  "$bin"/yarn-daemon.sh --config "${YARN_CONF_DIR}" \
    "${COMMAND}" resourcemanager "${YARN_RESOURCEMANAGER_ARGS}"
}

cmd=$1
shift;

RM_IDS=""
RM_HOSTS=""
for i in $*
do
  RMID=rm${i}
  RM_IDS="${RM_IDS},${RMID}"
  RM_HOSTS="${RM_HOSTS} -Dyarn.resourcemanager.hostname.${RMID}=`hostname`"
done 
RM_IDS="-Dyarn.resourcemanager.ha.rm-ids=${RM_IDS:1}"

for i in $*
do
  run_master  $cmd $i $RM_IDS $RM_HOSTS
done 
