#!/bin/bash 

cd `dirname $0`
RUNDIR=`pwd`

export LAST_PROD_TAG=`cat last-prod-tag.txt`

cd ..
. ./getopts.sh

MODULE_NAME=$1

# check params
if [ "$MODULE_NAME" = "" ]; then
	echo MODULE_NAME not set
	exit 1
fi

# execute

export VERSION_MODE=branch

. ./common.sh

export C_BUILD_OUTDIR=$RUNDIR/$C_CONFIG_VERSIONBRANCH.$C_CONFIG_NEXT_VERSION_BUILD
mkdir -p $C_BUILD_OUTDIR

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
LOGFNAME=$C_BUILD_OUTDIR/buildone-$MODULE_NAME-$TSVALUE.out

echo get diff sincetag=prod-$C_CONFIG_VERSIONBRANCH.$C_CONFIG_LAST_VERSION_BUILD... > $LOGFNAME
f_execute_core $MODULE_NAME DIFFBRANCHSINCEONE >> $LOGFNAME 2>&1

echo build core MODULE_NAME=$MODULE_NAME... >> $LOGFNAME 2>&1
./buildone-core.sh $MODULE_NAME >> $LOGFNAME 2>&1

cd branch
