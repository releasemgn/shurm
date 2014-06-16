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
. ./commondeploy.sh

# execute
function f_local_execute_node() {
	local P_EXECUTE_SRVNAME=$1
	local P_NODE=$2
	local P_EXECUTE_HOSTLOGIN=$3

	if [ "$GETOPT_EXECUTE" = "yes" ]; then
		echo "$P_EXECUTE_HOSTLOGIN: $P_RUNCMD_CMD"

		local F_LOGCMD="echo `date` \"(SSH_CLIENT=$SSH_CLIENT): $P_RUNCMD_CMD\" >> ~/execute.log"
		if [ "$GETOPT_SKIPERRORS" = "yes" ]; then
			if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
				ssh -i $C_ENV_PROPERTY_KEYNAME -n $P_EXECUTE_HOSTLOGIN "$F_LOGCMD"
			else
				ssh -n $P_EXECUTE_HOSTLOGIN "$F_LOGCMD"
			fi
		else
			f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "$F_LOGCMD"
		fi

		if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
			ssh -i $C_ENV_PROPERTY_KEYNAME -n $P_EXECUTE_HOSTLOGIN "$P_RUNCMD_CMD"
		else
			ssh -n $P_EXECUTE_HOSTLOGIN "$P_RUNCMD_CMD"
		fi
	else
		echo "$P_EXECUTE_HOSTLOGIN: $P_RUNCMD_CMD (showonly)"
	fi
}

function f_local_execute_server() {
	local P_EXECUTE_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_EXECUTE_SRVNAME $GETOPT_DEPLOYGROUP
	local F_LOCAL_HOSTLOGINLIST="$C_ENV_SERVER_HOSTLOGIN_LIST"

	# check affected
	if [ "$F_LOCAL_HOSTLOGINLIST" = "" ]; then
		echo "ignore server=$P_EXECUTE_SRVNAME, type=$C_ENV_SERVER_TYPE (no hosts)"
		return 1
	fi
	if [ "$C_ENV_SERVER_TYPE" = "generic.windows" ]; then
		echo "ignore server=$P_EXECUTE_SRVNAME, type=$C_ENV_SERVER_TYPE (windows)"
		return 1
	fi

	echo ============================================ execute server=$P_EXECUTE_SRVNAME, type=$C_ENV_SERVER_TYPE...

	local NODE=1
	local hostlogin
	for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
		if [ "$EXECUTE_NODELIST" = "" ] || [[ " $EXECUTE_NODELIST " =~ " $NODE " ]]; then
			f_local_execute_node $P_EXECUTE_SRVNAME $NODE $hostlogin
		fi
		NODE=$(expr $NODE + 1)
	done
}

# get server list
function f_local_executedc() {
	echo execute datacenter=$DC...
	f_env_getxmlserverlist $DC
	local F_SERVER_LIST=$C_ENV_XMLVALUE

	f_checkvalidlist "$F_SERVER_LIST" "$SRVNAME_LIST"
	f_getsubset "$F_SERVER_LIST" "$SRVNAME_LIST"
	F_SERVER_LIST=$C_COMMON_SUBSET

	# iterate servers
	local server
	for server in $F_SERVER_LIST; do
		f_local_execute_server $server
	done
}

# execute in environment (except for windows-based)

# execute datacenter
f_local_executedc

echo runcmd.sh: SUCCESSFULLY DONE.
