#!/bin/sh
#/**
# * Copyright 2007 The Apache Software Foundation
# *
# * Licensed to the Apache Software Foundation (ASF) under one
# * or more contributor license agreements.  See the NOTICE file
# * distributed with this work for additional information
# * regarding copyright ownership.  The ASF licenses this file
# * to you under the Apache License, Version 2.0 (the
# * "License"); you may not use this file except in compliance
# * with the License.  You may obtain a copy of the License at
# *
# *     http://www.apache.org/licenses/LICENSE-2.0
# *
# * Unless required by applicable law or agreed to in writing, software
# * distributed under the License is distributed on an "AS IS" BASIS,
# * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# * See the License for the specific language governing permissions and
# * limitations under the License.
# */
# This is used for starting multiple masters on the same machine.
# run it from HADOOP_HOME just like 'bin/yarn'

bin=`dirname "${BASH_SOURCE-$0}"`
bin=`cd "$bin" >/dev/null && pwd`

if [ $# -lt 2 ]; then
  S=`basename "${BASH_SOURCE-$0}"`
  echo "Usage: $S [--config <conf-dir>] [start|stop|config] offset(s)"
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
  export YARN_IDENT_STRING="$USER-$DN"
  "$bin"/yarn-daemon.sh --config "${YARN_CONF_DIR}" \
    "${COMMAND}" resourcemanager "-Dyarn.resourcemanager.ha.id=${RMID}" $@
}

CMD=$1
shift
RMS=$*

RM_IDS=""
RM_HA_CONFIG=""
for i in $RMS
do
  RMID="rm${i}"
  OFFSET=`expr ${i} \* 100`
  HA_RM_IDS="${HA_RM_IDS},${RMID}"
  ADDRESS="0.0.0.0"
  RM_HA_CONFIG="${RM_HA_CONFIG} \
    -Dyarn.resourcemanager.scheduler.address.${RMID}=$ADDRESS:`expr 8030 + $OFFSET` \
    -Dyarn.resourcemanager.resource-tracker.address.${RMID}=$ADDRESS:`expr 8031 + $OFFSET` \
    -Dyarn.resourcemanager.address.${RMID}=$ADDRESS:`expr 8032 + $OFFSET` \
    -Dyarn.resourcemanager.admin.address.${RMID}=$ADDRESS:`expr 8033 + $OFFSET` \
    -Dyarn.resourcemanager.webapp.address.${RMID}=$ADDRESS:`expr 8088 + $OFFSET` "
done
RM_HA_CONFIG="${RM_HA_CONFIG} \
  -Dyarn.resourcemanager.ha.enabled=true \
  -Dyarn.resourcemanager.ha.automatic-failover.enabled=false \
  -Dyarn.resourcemanager.cluster-id=cl1 \
  -Dyarn.resourcemanager.ha.rm-ids=${HA_RM_IDS:1} "

if [ $CMD = "config" ]
then
  echo $RM_HA_CONFIG
else
  for i in $RMS
  do
    run_master  $CMD $i $RM_HA_CONFIG
  done 
fi
