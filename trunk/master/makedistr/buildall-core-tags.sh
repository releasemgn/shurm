#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

TAG=$1
OUTDIR=$2

# check params
if [ "$TAG" = "" ]; then
	echo TAG not set
	exit 1
fi
if [ "$OUTDIR" = "" ]; then
	echo OUTDIR not set
	exit 1
fi
shift 2

MODULEPROJECTS=$*

# execute

. common.sh

echo buildall-core-tags.sh TAG=$TAG

if [ -d $OUTDIR/core ]; then
	OLDLOGS=$OUTDIR/oldlogs/core
	rm -rf $OLDLOGS
	mkdir -p $OLDLOGS
	mv $OUTDIR/core $OLDLOGS
fi

C_BUILD_OUTDIR=$OUTDIR/core
mkdir -p $C_BUILD_OUTDIR
C_TAG=$TAG

# core
export C_BUILD_OUTDIR
export C_TAG

if [ "$MODULEPROJECTS" = "" ]; then
	EXECUTE_FILTER="all"
else	
	EXECUTE_FILTER="$MODULEPROJECTS"
fi

f_execute_core "$EXECUTE_FILTER" BUILDCORE

grep "[INFO|ERROR]] BUILD" $C_BUILD_OUTDIR/*.log > $OUTDIR/build.final.core.out

echo buildall-core-tags.sh: finished
