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
# run it from hbase-dir/ just like 'bin/hbase'
# Supports up to 10 masters (limitation = overlapping ports)
set -x

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
  ADDRESS="0.0.0.0"
  export YARN_IDENT_STRING="$USER-$DN"
  YARN_RESOURCEMANAGER_ARGS="$@ \
    -Dyarn.resourcemanager.ha.enabled=true \
    -Dyarn.resourcemanager.ha.automatic-failover.enabled=false \
    -Dyarn.resourcemanager.cluster-id=cl1 \
    -Dyarn.resourcemanager.ha.id=${RMID} \
    -Dyarn.resourcemanager.webapp.address.${RMID}=$ADDRESS:`expr 8088 + $OFFSET` \
    -Dyarn.resourcemanager.scheduler.address.${RMID}=$ADDRESS:`expr 8030 + $OFFSET` \
    -Dyarn.resourcemanager.resource-tracker.address.${RMID}=$ADDRESS:`expr 8031 + $OFFSET` \
    -Dyarn.resourcemanager.address.${RMID}=$ADDRESS:`expr 8032 + $OFFSET` \
    -Dyarn.resourcemanager.admin.address.${RMID}=$ADDRESS:`expr 8033 + $OFFSET` "
  "$bin"/yarn-daemon.sh --config "${YARN_CONF_DIR}" \
    "${COMMAND}" resourcemanager ${YARN_RESOURCEMANAGER_ARGS}
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
