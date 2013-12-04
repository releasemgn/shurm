#!/bin/bash 

cd ..
. ./getopts.sh

DOWNLOAD_PROJECT=$1
if [ "$DOWNLOAD_PROJECT" != "" ]; then
	shift 1
	DOWNLOAD_PRODUCTPROJECT_ITEMS=$*
else
	DOWNLOAD_PRODUCTPROJECT_ITEMS=
fi

# execute

export VERSION_MODE=branch
export OUTDIR=branch

. ./common.sh
TAG_VERSION=$C_CONFIG_VERSIONBRANCH.$C_CONFIG_NEXT_VERSION_BUILD
TAG_GETALL=prod-${TAG_VERSION}-candidate

./getall.sh $TAG_VERSION $TAG_GETALL $DOWNLOAD_PROJECT "$DOWNLOAD_PRODUCTPROJECT_ITEMS"

cd branch

echo getall.sh finished.
