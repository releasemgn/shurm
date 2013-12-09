#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

P_CUSTOM_SCRIPT=$1
P_CUSTOM_SET=$2

if [ "$P_CUSTOM_SET" != "" ]; then
	shift 2
	P_CUSTOM_PROJECTS=$*
else
	P_CUSTOM_PROJECTS=
fi

if [ "$P_CUSTOM_SCRIPT" = "" ]; then
	echo custom.sh: invalid P_CUSTOM_SCRIPT. Exiting
	exit 1
fi

. ./common.sh

# execute

export C_CUSTOM_SCRIPT=$P_CUSTOM_SCRIPT

if [ "$P_CUSTOM_SET" = "" ] || [ "$P_CUSTOM_SET" = "core" ]; then
	if [ "$P_CUSTOM_PROJECTS" = "" ]; then
		EXECUTE_FILTER="all"
	else	
		EXECUTE_FILTER="$P_CUSTOM_PROJECTS"
	fi
	f_execute_core "$EXECUTE_FILTER" CUSTOM
fi

if [ "$P_CUSTOM_SET" = "" ] || [ "$P_CUSTOM_SET" = "war" ]; then
	if [ "$P_CUSTOM_PROJECTS" = "" ]; then
		EXECUTE_FILTER="all"
	else	
		EXECUTE_FILTER="$P_CUSTOM_PROJECTS"
	fi
	f_execute_wars "$EXECUTE_FILTER" CUSTOM
fi

cd branch

echo custom.sh finished.
