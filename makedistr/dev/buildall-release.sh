#!/bin/bash 

cd `dirname $0`
RUNDIR=`pwd`

. ../getopts.sh

MODULE=$1
if [ "$MODULE" != "" ]; then
	shift 1
	MODULE_PROJECTLIST=$*
else
	MODULE_PROJECTLIST=
fi

# execute
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..
. ./common.sh

VERSION=`echo $C_CONFIG_APPVERSION | cut -d "-" -f1`
TSVALUE=`date +%Y-%m-%d.%H-%M-%S`

# override params by options
if [ "$GETOPT_RELEASE" != "" ]; then
	VERSION=$GETOPT_RELEASE
fi

OUTDIR=$VERSION_MODE/$VERSION
mkdir -p $OUTDIR

./buildall-release.sh $VERSION $OUTDIR $MODULE "$MODULE_PROJECTLIST" > $OUTDIR/buildall-$TSVALUE.out 2>&1

cd $VERSION_MODE
