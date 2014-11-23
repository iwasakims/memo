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
  echo "Usage: $S [--config <conf-dir>] [start|stop] offset(s)"
  echo ""
  echo "    e.g. $S start 1"
  exit
fi

. "$bin"/../libexec/yarn-config.sh

run_nodemanager () {
  COMMAND=$1
  shift
  DN=$1
  shift
  OFFSET=`expr ${DN} \* 100`
  export YARN_IDENT_STRING="$USER-$DN"
  ADDRESS="0.0.0.0"
  NODEMANAGER_CONFIG=" \
    -Dyarn.nodemanager.localizer.address=${ADDRESS}:`expr 8040 + ${OFFSET}` \
    -Dyarn.nodemanager.address=${ADDRESS}:`expr 8041 + ${OFFSET}` \
    -Dyarn.nodemanager.webapp.address=${ADDRESS}:`expr 8042 + ${OFFSET}` \
    -Dmapreduce.shuffle.port=`expr 13562 + ${OFFSET}` \
    -Dyarn.nodemanager.aux-services=mapreduce_shuffle \
    -Dyarn.nodemanager.aux-services.mapreduce_shuffle.class=org.apache.hadoop.mapred.ShuffleHandler "
  "$bin"/yarn-daemon.sh --config "${YARN_CONF_DIR}" \
    "${COMMAND}" nodemanager ${NODEMANAGER_CONFIG}
}



CMD=$1
shift
NMS=$*

for i in $NMS
do
  run_nodemanager $CMD $i
done
