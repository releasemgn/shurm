#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo hosts.sh: DC not set
	exit 1
fi

P_RUNCMD_CMD="$1"
P_RUNCMD_VALUE="$2"

if [ "$P_RUNCMD_CMD" = "" ]; then
	echo hosts.sh: P_RUNCMD_CMD not set
	exit 1
fi
if [ "$P_RUNCMD_VALUE" = "" ]; then
	echo hosts.sh: P_RUNCMD_VALUE not set
	exit 1
fi
shift 2

SRVNAME_LIST=$*

# load common functions
. ./common.sh
. ./commonexecute.sh

# execute

function f_local_executeall() {
	# check host pair
	local F_HOST_NAME=${P_RUNCMD_VALUE%=*}
	local F_HOST_IP=${P_RUNCMD_VALUE#*=}

	if [ "$P_RUNCMD_CMD" = "set" ]; then
		if [ "$F_HOST_NAME" = "" ] || [[ ! "$F_HOST_IP" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
			echo hosts.sh: invalid value=$P_RUNCMD_VALUE. Exiting
			exit 1
		fi
	elif [ "$P_RUNCMD_CMD" = "delete" ] || [ "$P_RUNCMD_CMD" = "check" ]; then
		if [ "$F_HOST_NAME" = "" ]; then
			echo hosts.sh: invalid value=$P_RUNCMD_VALUE. Exiting
			exit 1
		fi
	else
		echo hosts.sh: invalid command=$P_RUNCMD_CMD. Exiting
		exit 1
	fi

	export GETOPT_ROOTUSER=yes
	export C_EXECUTE_CMD=$P_RUNCMD_CMD
	export C_EXECUTE_HOSTNAME=$F_HOST_NAME
	export C_EXECUTE_HOSTADDR=$F_HOST_IP

	f_common_execute_unique "HOSTS" $DC "$SRVNAME_LIST"
}

# execute in environment (except for windows-based)
f_local_executeall

echo hosts.sh: SUCCESSFULLY DONE.
