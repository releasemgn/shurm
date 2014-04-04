#!/bin/bash 

# Get (previously built) components from Nexus - using release.xml from distr/
# Usage examples (run from makedistr/branch) -
# cat last-prod-tag.txt
# less ~/distr/<product>/2.2.18/release.xml
# ./getall-release.sh -dist
# ./getall-release.sh -dist core atc-bem-framework

cd `dirname $0`
. ../getopts.sh
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..

MODULE=$1
if [ "$MODULE" != "" ]; then
	shift 1
	MODULE_PROJECTLIST=$*
else
	MODULE_PROJECTLIST=
fi

. ./common.sh

VERSION=$C_CONFIG_VERSION_NEXT_FULL

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
./getall-release.sh $VERSION $MODULE "$MODULE_PROJECTLIST"

cd branch
