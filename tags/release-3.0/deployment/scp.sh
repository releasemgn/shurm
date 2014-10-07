#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo scp.sh: DC not set
	exit 1
fi

P_SRC="$1"
P_DST="$2"

if [ "$P_SRC" = "" ]; then
	echo scp.sh: P_SRC not set
	exit 1
fi

if [ "$P_DST" = "" ]; then
	echo scp.sh: P_DST not set
	exit 1
fi

shift 2


SRVNAME_LIST=$*

# load common functions
. ./common.sh
. ./commonexecute.sh

# execute

function f_local_executeall() {
	local F_CMD="scp"

	if [ ! -f "$P_SRC" ]; then
		F_CMD="$F_CMD -r"
	fi

	F_CMD="$F_CMD $P_SRC @hostlogin@:$P_DST"

	export C_EXECUTE_CMD="$F_CMD"
	f_common_execute_unique "RUNLOCAL" $DC "$SRVNAME_LIST"
}

# execute in environment (except for windows-based)
f_local_executeall

echo runcmd.sh: SUCCESSFULLY DONE.
