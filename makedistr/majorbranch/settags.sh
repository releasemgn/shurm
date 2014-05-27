#!/bin/bash 

cd `dirname $0`
. ../getopts.sh
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

P_TAG=$1
P_MODULE=$2
if [ "$P_MODULE" != "" ]; then
	shift 2
	P_PROJECTS=$*
else
	P_PROJECTS=
fi

# execute
cd ..
. ./common.sh

export C_TAG=$P_TAG

# core
if [ "$P_MODULE" = "" ] || [ "$P_MODULE" = "core" ]; then
	if [ "$P_PROJECTS" = "" ]; then
		EXECUTE_FILTER="all"
	else	
		EXECUTE_FILTER="$P_PROJECTS"
	fi
	f_execute_core "$EXECUTE_FILTER" VCSSETBRANCHTAG
fi

if [ "$P_MODULE" = "" ] || [ "$P_MODULE" = "war" ]; then
	if [ "$P_PROJECTS" = "" ]; then
		EXECUTE_FILTER="all"
	else	
		EXECUTE_FILTER="$P_PROJECTS"
	fi
	f_execute_wars "$EXECUTE_FILTER" VCSSETBRANCHTAG
fi

echo settags.sh finished.
