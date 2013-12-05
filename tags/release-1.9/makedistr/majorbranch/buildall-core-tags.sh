#!/bin/bash 

. ../getopts.sh

TAG=$1

# check params
if [ "$TAG" = "" ]; then
	echo TAG not set
	exit 1
fi
shift 1

MODULEPROJECTS=$*

# execute
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..

export OUTDIR=$VERSION_MODE/tag-$TAG
mkdir -p $OUTDIR

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
./buildall-core-tags.sh $TAG $OUTDIR $MODULEPROJECTS > $OUTDIR/buildall-core-tags-$TSVALUE.out 2>&1

cd $VERSION_MODE

echo buildall-core-tags.sh: finished
