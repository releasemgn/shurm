#!/bin/bash 

. ../getopts.sh

TAG=$1

# check params
if [ "$TAG" = "" ]; then
	echo TAG not set
	exit 1
fi

# execute
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..

export OUTDIR=$VERSION_MODE/tag-$TAG
mkdir -p $OUTDIR

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
./buildall-tags.sh $TAG $OUTDIR > $OUTDIR/buildall-tags-$TSVALUE.out 2>&1

cd branch
