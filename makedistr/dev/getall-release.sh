#!/bin/bash 

cd `dirname $0`
RUNDIR=`pwd`

. ../getopts.sh

MODULE=$1
if [ "$MODULE" != "" ]; then
	shift 1
	MODULE_PROJECTLIST=$*
else
	MODULE_PROJECTLIST=
fi

# execute
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..
. ./common.sh

VERSION=$C_CONFIG_VERSIONBRANCH # e.g. 1.0

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
./getall-release.sh $VERSION $MODULE "$MODULE_PROJECTLIST"

cd $VERSION_MODE
