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

echo buildall-war-tags.sh TAG=$TAG, MODULEPROJECTS=$MODULEPROJECTS

OLDLOGS=$OUTDIR/oldlogs/war
rm -rf $OLDLOGS
mkdir -p $OLDLOGS
mv $OUTDIR/war $OLDLOGS

C_BUILD_OUTDIR=$OUTDIR/war
mkdir -p $C_BUILD_OUTDIR
C_TAG=$TAG

# wars
export C_BUILD_OUTDIR
export C_TAG
if [ "$MODULEPROJECTS" = "" ]; then
	EXECUTE_FILTER=all
else
	EXECUTE_FILTER="$MODULEPROJECTS"
fi

f_execute_wars "$EXECUTE_FILTER" BUILDWAR

# get build status
grep "[INFO|ERROR]] BUILD" $C_BUILD_OUTDIR/*.log > $OUTDIR/build.final.war.out

echo buildall-war-tags.sh: finished
