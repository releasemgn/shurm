#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh
. ./common.sh

# check params
if [ "$C_CONFIG_VERSIONBRANCH" = "" ]; then
	echo C_CONFIG_VERSIONBRANCH not set
	exit 1
fi
if [ "$C_CONFIG_APPVERSION_TAG" = "" ]; then
	echo C_CONFIG_APPVERSION_TAG not set
	exit 1
fi
if [ "$OUTDIR" = "" ]; then
	echo OUTDIR not set
	exit 1
fi

# execute

echo running buildall.sh processid=$$

rm -rf $OUTDIR/build.final*
rm -rf $OUTDIR/diff-*

./diffbranchsince.sh prod-$C_CONFIG_VERSIONBRANCH.$C_CONFIG_LAST_VERSION_BUILD $OUTDIR
./codebase-updatetags.sh

./buildall-tags.sh $C_CONFIG_APPVERSION_TAG $OUTDIR

echo buildall.sh: finished
