#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo upgradeenv.sh: DC not set
	exit 1
fi

P_UPGRADE_ID="$1"
if [ "$P_UPGRADE_ID" = "" ]; then
	echo upgradeenv.sh: P_UPGRADE_ID not set
	exit 1
fi
shift 1

SRVNAME_LIST=$*

# load common functions
. ./common.sh
. ./commonexecute.sh

# execute

function f_local_executeall() {
	local F_SCRIPT=$C_CONFIG_UPGRADEPATH/upgrade-$P_UPGRADE_ID.sh
	if [ ! -f $F_SCRIPT ]; then
		echo cannot find upgrade script $F_SCRIPT
		exit 1
	fi

	export C_EXECUTE_UPGRADE="$P_UPGRADE_ID"
	f_common_execute_unique "UPGRADE" $DC "$SRVNAME_LIST"
}

# execute in environment (except for windows-based)
f_local_executeall

echo upgradeenv.sh: SUCCESSFULLY DONE.
