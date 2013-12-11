#!/bin/bash 

MODULE=$1
if [ "$MODULE" != "" ]; then
	shift 1
	MODULE_PROJECTLIST=$*
else
	MODULE_PROJECTLIST=
fi

cd ..
. ./getopts.sh

export VERSION_MODE=trunk

. ./common.sh

VERSION=$C_CONFIG_NEXT_MAJORRELEASE
TSVALUE=`date +%Y-%m-%d.%H-%M-%S`

# override params by options
if [ "$GETOPT_RELEASE" != "" ]; then
	VERSION=$GETOPT_RELEASE
fi

OUTDIR=$VERSION_MODE/$VERSION
mkdir -p $OUTDIR

./buildall-release.sh $VERSION $OUTDIR $MODULE "$MODULE_PROJECTLIST" > $OUTDIR/buildall-$TSVALUE.out 2>&1

cd $VERSION_MODE
