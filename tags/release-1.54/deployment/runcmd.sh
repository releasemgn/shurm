#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo runcmd.sh: DC not set
	exit 1
fi

P_RUNCMD_CMD="$1"
if [ "$P_RUNCMD_CMD" = "" ]; then
	echo runcmd.sh: P_RUNCMD_CMD not set
	exit 1
fi
shift 1

SRVNAME_LIST=$1

# load common functions
. ./common.sh
. ./commonexecute.sh

# execute

function f_local_executeall() {
	echo execute datacenter=$DC...

	export C_EXECUTE_CMD="$P_RUNCMD_CMD"
	f_common_execute_set "runcmd" $DC $SRVNAME_LIST
}

# execute in environment (except for windows-based)
f_local_executeall

echo runcmd.sh: SUCCESSFULLY DONE.
