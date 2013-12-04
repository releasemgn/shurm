#!/bin/bash 

. ../getopts.sh

TAG=$1
shift 1

MODULEPROJECTS=$*

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
./buildall-war-tags.sh $TAG $OUTDIR $MODULEPROJECTS > $OUTDIR/buildall-war-tags-$TSVALUE.out 2>&1

cd $VERSION_MODE
