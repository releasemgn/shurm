#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

TAG=$1
OUTDIR=$2
MODULE=$3
MODULEPROJECT=$4

# check params
if [ "$TAG" = "" ]; then
	echo TAG not set
	exit 1
fi
if [ "$OUTDIR" = "" ]; then
	echo OUTDIR not set
	exit 1
fi

# execute

. ./common.sh

echo buildall-tags.sh TAG=$TAG
echo BUILD ALL TARGETS processid=$$...

mkdir -p $OUTDIR
echo FINAL STATUS: > $OUTDIR/build.final.out
if [ "$MODULE" = "core" ] || [ "$MODULE" = "" ]; then
	./buildall-core-tags.sh $TAG $OUTDIR $MODULEPROJECT
	grep "[INFO|ERROR]] BUILD" $OUTDIR/core/*.log >> $OUTDIR/build.final.out
fi

if [ "$MODULE" = "war" ] || [ "$MODULE" = "" ]; then
	./buildall-war-tags.sh $TAG $OUTDIR $MODULEPROJECT
	grep "[INFO|ERROR]] BUILD" $OUTDIR/war/*.log >> $OUTDIR/build.final.out
fi

echo buildall-tags.sh: finished
