#!/bin/bash 

cd `dirname $0`
RUNDIR=`pwd`

. ../getopts.sh

DOWNLOAD_PROJECT=$1
if [ "$DOWNLOAD_PROJECT" != "" ]; then
	shift 1
	DOWNLOAD_PROJECT_ITEMS=$*
else
	DOWNLOAD_PROJECT_ITEMS=
fi

# execute
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..
. ./common.sh

export OUTDIR=$VERSION_MODE

. ./common.sh

TAG_VERSION=$C_CONFIG_NEXT_MAJORRELEASE
TAG_GETALL=$C_CONFIG_APPVERSION_TAG

./getall.sh $TAG_VERSION $TAG_GETALL $DOWNLOAD_PROJECT "$DOWNLOAD_PROJECT_ITEMS"

cd $VERSION_MODE

echo getall.sh finished.
