#!/bin/bash

cd `dirname $0`
RUNPATH=`pwd`

# set env/dc context
. ./_context.sh

cd ../..
. ./getopts.sh
. ./setenv.sh $C_CONTEXT_ENV

P_EXECUTE_CMD="$1"
shift 1

echo "`date`: execute ./key.sh -dc $C_CONTEXT_DC \"$P_EXECUTE_CMD\" $*" >> $RUNPATH/deploy.log
./key.sh -dc $C_CONTEXT_DC "$P_EXECUTE_CMD" $* | tee -a $RUNPATH/deploy.log; F_STATUS=${PIPESTATUS[0]}

exit $F_STATUS

