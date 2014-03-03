#!/bin/bash 

# Usage example: ./buildall-release.sh -showall core

. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..
. ./getopts.sh
MODULE=$1
if [ "$MODULE" != "" ]; then
	shift 1
	MODULE_PROJECTLIST=$*
else
	MODULE_PROJECTLIST=
fi

. ./common.sh

VERSION=$C_CONFIG_VERSIONBRANCH.$C_CONFIG_NEXT_VERSION_BUILD

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`

# override params by options
if [ "$GETOPT_RELEASE" != "" ]; then
	VERSION=$GETOPT_RELEASE
fi

OUTDIR=$VERSION_MODE/$VERSION
mkdir -p $OUTDIR

if [ "$GETOPT_SHOWALL" = "yes" ]; then
	./buildall-release.sh $VERSION $OUTDIR $MODULE "$MODULE_PROJECTLIST" 2>&1 | tee $OUTDIR/buildall-$TSVALUE.out
else
	./buildall-release.sh $VERSION $OUTDIR $MODULE "$MODULE_PROJECTLIST" > $OUTDIR/buildall-$TSVALUE.out 2>&1
fi

cd branch
