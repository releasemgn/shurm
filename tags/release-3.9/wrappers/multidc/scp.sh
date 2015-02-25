#!/bin/bash

cd `dirname $0`
RUNPATH=`pwd`

# set env/dc context
. ./_context.sh

cd ../..
. ./getopts.sh
. ./setenv.sh $C_CONTEXT_ENV

echo "`date`: execute ./scp.sh -dc $C_CONTEXT_DC $*" >> $RUNPATH/deploy.log
./scp.sh -dc $C_CONTEXT_DC $* | tee -a $RUNPATH/deploy.log; F_STATUS=${PIPESTATUS[0]}

exit $F_STATUS
