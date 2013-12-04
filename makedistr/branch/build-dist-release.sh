#!/bin/bash
#
# Usage example: ./build-dist-release.sh war pgu-reg107

export VERSION_MODE=branch
export LAST_PROD_TAG=`cat last-prod-tag.txt`

cd ..
. ./getopts.sh
. ./common.sh
cd $VERSION_MODE

VERSION=$C_CONFIG_VERSIONBRANCH.$C_CONFIG_NEXT_VERSION_BUILD

echo -n "Starting build of release $VERSION (params: $*) ... "
sleep 3
echo "started ..."
date; time ./buildall-release.sh     $*

export OUTDIR=$VERSION
LOG=`ls -t $OUTDIR/buildall-*.out | head -1`

echo; grep BUILDSTATUS $LOG
echo; grep BUILDSTATUS $LOG | grep -v SUCCESSFUL

echo -n "Starting population of distributive ... "
sleep 3
echo "started ..."
date; time ./getall-release.sh -dist $*

echo; grep BUILDSTATUS $LOG
echo; grep BUILDSTATUS $LOG | grep -v SUCCESSFUL
