#!/bin/bash 

cd `dirname $0`
RUNDIR=`pwd`

. ../getopts.sh

MODULE_NAME=$1

# check params
if [ "$MODULE_NAME" = "" ]; then
	echo MODULE_NAME not set
	exit 1
fi

# execute
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..
. ./common.sh

export OUTDIR=$VERSION_MODE/$C_CONFIG_NEXT_MAJORRELEASE
mkdir -p $OUTDIR

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
LOGFNAME=$OUTDIR/buildone-$MODULE_NAME-$TSVALUE.out
TAG=$C_CONFIG_APPVERSION_TAG

./buildall-war-tags.sh $TAG $OUTDIR $MODULE_NAME > $LOGFNAME 2>&1

cd $VERSION_MODE
