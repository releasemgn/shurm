#!/bin/bash 

MODULE_NAME=$1

# check params
if [ "$MODULE_NAME" = "" ]; then
	echo MODULE_NAME not set
	exit 1
fi

# execute

export VERSION_MODE=majorbranch

cd ..
. ./common.sh

OUTDIR=$VERSION_MODE/$C_CONFIG_NEXT_MAJORRELEASE
mkdir -p $OUTDIR

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
LOGFNAME=$OUTDIR/buildone-$MODULE_NAME-$TSVALUE.out

export C_TAG=$C_CONFIG_PRODMAJOR_TAG
export C_BUILD_OUTDIR=$OUTDIR
f_execute_core $MODULE_NAME BUILDCORE >> $LOGFNAME 2>&1

cd $VERSION_MODE

