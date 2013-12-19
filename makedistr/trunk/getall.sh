#!/bin/bash 

cd ..
. ./getopts.sh

DOWNLOAD_PROJECT=$1
if [ "$DOWNLOAD_PROJECT" != "" ]; then
	shift 1
	DOWNLOAD_PROJECT_ITEMS=$*
else
	DOWNLOAD_PROJECT_ITEMS=
fi

# execute

export VERSION_MODE=trunk
export OUTDIR=trunk

. ./common.sh

TAG_VERSION=$C_CONFIG_NEXT_MAJORRELEASE
TAG_GETALL=$C_CONFIG_PRODMAJOR_TAG

./getall.sh $TAG_VERSION $TAG_GETALL $DOWNLOAD_PROJECT "$DOWNLOAD_PROJECT_ITEMS"

cd $VERSION_MODE

echo getall.sh finished.
