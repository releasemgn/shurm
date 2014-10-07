#!/bin/bash 

cd `dirname $0`
. ../getopts.sh
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..

DOWNLOAD_PROJECT=$1
if [ "$DOWNLOAD_PROJECT" != "" ]; then
	shift 1
	DOWNLOAD_PRODUCTPROJECT_ITEMS=$*
else
	DOWNLOAD_PRODUCTPROJECT_ITEMS=
fi

# execute

export OUTDIR=branch

. ./common.sh
TAG_VERSION=$C_CONFIG_VERSION_NEXT_FULL
TAG_GETALL=prod-${TAG_VERSION}-candidate

./getall.sh $TAG_VERSION $TAG_GETALL $DOWNLOAD_PROJECT "$DOWNLOAD_PRODUCTPROJECT_ITEMS"

cd branch

echo getall.sh finished.
