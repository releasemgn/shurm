#!/bin/bash

cd `dirname $0`
RUNPATH=`pwd`

cd ..
. ./getopts.sh
. ./setenv.sh `basename $RUNPATH`.xml
. ./common.sh

P_EXECUTE_MSG="$1"
shift 1

echo "`date`: execute ./sendchatmsg.sh -dc all "$P_EXECUTE_MSG" $*" >> $RUNPATH/deploy.log
./sendchatmsg.sh -dc all "$P_EXECUTE_MSG" $* | tee -a $RUNPATH/deploy.log
