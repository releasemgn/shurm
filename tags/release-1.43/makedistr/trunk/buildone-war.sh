#!/bin/bash 

MODULE_NAME=$1

# check params
if [ "$MODULE_NAME" = "" ]; then
	echo MODULE_NAME not set
	exit 1
fi

# execute

export VERSION_MODE=trunk

cd ..
. ./common.sh

export OUTDIR=trunk/$C_CONFIG_NEXT_MAJORRELEASE
mkdir -p $OUTDIR

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
LOGFNAME=$OUTDIR/buildone-$MODULE_NAME-$TSVALUE.out
TAG=$C_CONFIG_PRODMAJOR_TAG

./buildall-war-tags.sh $TAG $OUTDIR $MODULE_NAME > $LOGFNAME 2>&1

cd $VERSION_MODE
