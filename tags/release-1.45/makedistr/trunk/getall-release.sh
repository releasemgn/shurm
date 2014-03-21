#!/bin/bash 

. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..
. ./getopts.sh

MODULE=$1
if [ "$MODULE" != "" ]; then
	shift 1
	MODULE_PROJECTLIST=$*
else
	MODULE_PROJECTLIST=
fi

. ./common.sh

VERSION=$C_CONFIG_NEXT_MAJORRELEASE

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
./getall-release.sh $VERSION $MODULE "$MODULE_PROJECTLIST"

cd $VERSION_MODE
