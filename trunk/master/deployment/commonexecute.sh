#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com
#
# P_SUB: getgroups, getservers, finishdc, startserver, finishserver, executenode

S_EXECUTE_GROUPS=
S_EXECUTE_SERVERS=
S_EXECUTE_ENABLED=
S_EXECUTE_PARAM_SERVERS=
S_EXECUTE_PARAM_NODES=

function f_common_execute_runcmd() {
	local P_SUB=$1
	local P_DC=$2
	local P_FUNCTION=$3
	local P_SERVER_LIST="$4"
	local P_NODE_LIST="$5"
	local P_GROUP=$6
	local P_SERVER=$7
	local P_NODE=$8
	local P_HOSTLOGIN=$9

	if [ "$C_EXECUTE_CMD" = "" ]; then
		echo C_EXECUTE_CMD is not set. Exiting
		exit 1
	fi

	if [ "$P_SUB" = "getgroups" ]; then
		S_EXECUTE_GROUPS=all

	elif [ "$P_SUB" = "getservers" ]; then
		S_EXECUTE_SERVERS=$P_SERVER_LIST

	elif [ "$P_SUB" = "startserver" ]; then
		if [ "$C_ENV_SERVER_TYPE" = "generic.windows" ]; then
			echo "ignore server=$P_EXECUTE_SRVNAME, type=$C_ENV_SERVER_TYPE (windows)"
			S_EXECUTE_ENABLED=no
			return 1
		fi

	elif [ "$P_SUB" = "executenode" ]; then
		./oneruncmd.sh $P_SERVER $P_NODE $P_HOSTLOGIN "$C_EXECUTE_CMD"
	fi
}

function f_common_execute_function() {
	local P_SUB=$1
	local P_DC=$2
	local P_FUNCTION=$3
	local P_SERVER_LIST="$4"
	local P_NODE_LIST="$5"
	local P_GROUP=$6
	local P_SERVER=$7
	local P_NODE=$8
	local P_HOSTLOGIN=$9

	case "$P_FUNCTION" in
# build operations
		RUNCMD)
			f_common_execute_runcmd $P_SUB $P_DC $P_FUNCTION "$P_SERVER_LIST" "$P_NODE_LIST" $P_GROUP $P_SERVER $P_NODE $P_HOSTLOGIN
			;;
	esac
}

function f_common_execute_node() {
	local P_DC=$1
	local P_FUNCTION=$2
	local P_SERVER_LIST="$3"
	local P_NODE_LIST="$4"
	local P_GROUP=$5
	local P_SERVER=$6
	local P_NODE=$7
	local P_HOSTLOGIN=$8

	f_common_execute_function "executenode" $P_DC $P_FUNCTION "$P_SERVER_LIST" "$P_NODE_LIST" $P_GROUP $P_SERVER $P_NODE $P_HOSTLOGIN
}

function f_common_execute_server() {
	local P_DC=$1
	local P_FUNCTION=$2
	local P_SERVER_LIST="$3"
	local P_NODE_LIST="$4"
	local P_GROUP=$5
	local P_SERVER=$6

	f_env_getxmlserverinfo $P_DC $P_SERVER $GETOPT_DEPLOYGROUP
	local F_LOCAL_HOSTLOGINLIST="$C_ENV_SERVER_HOSTLOGIN_LIST"

	# check affected
	if [ "$F_LOCAL_HOSTLOGINLIST" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo "ignore server=$P_SERVER, type=$C_ENV_SERVER_TYPE (no hosts)"
		fi
		return 1
	fi

	S_EXECUTE_ENABLED=yes
	f_execute_function "startserver" $P_DC $P_FUNCTION "$P_SERVER_LIST" "$P_NODE_LIST" $P_GROUP $P_SERVER
	if [ "$S_EXECUTE_ENABLED" != "yes" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo "ignore server=$P_SERVER, type=$C_ENV_SERVER_TYPE (filtered)"
		fi
		return 1
	fi

	echo ============================================ execute server=$P_SERVER, type=$C_ENV_SERVER_TYPE...

	local NODE=1
	local hostlogin
	for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
		if [ "$P_NODE_LIST" = "" ] || [[ " $P_NODE_LIST " =~ " $NODE " ]]; then
			f_common_execute_node $P_DC $P_FUNCTION "$P_SERVER_LIST" "$P_NODE_LIST" $P_GROUP $P_SERVER $NODE $hostlogin
		fi
		NODE=$(expr $NODE + 1)
	done

	f_execute_function "finishserver" $P_DC $P_FUNCTION "$P_SERVER_LIST" "$P_NODE_LIST" $P_GROUP $P_SERVER
}

function f_common_execute_group() {
	local P_DC=$1
	local P_FUNCTION=$2
	local P_SERVER_LIST="$3"
	local P_NODE_LIST="$4"
	local P_GROUP=$5

	# limit server and order
	S_EXECUTE_SERVERS=
	f_execute_function "getservers" $P_DC $P_FUNCTION "$P_SERVER_LIST" "$P_NODE_LIST" $P_GROUP

	# iterate servers	
	local server
	for server in $S_EXECUTE_SERVERS; do
		# execute server
		f_common_execute_server $P_DC $P_FUNCTION "$F_SERVER_LIST" "$P_NODE_LIST" $P_GROUP $server
	done

	f_execute_function "finishgroup" $P_DC $P_FUNCTION "$P_SERVER_LIST" "$P_NODE_LIST" $P_GROUP
}

function f_common_execute_splitservers() {
	# check if node syntax
	if [[ "$2" =~ ^[1-9] ]]; then
		S_EXECUTE_PARAM_SERVERS=$1
		shift 1
		S_EXECUTE_PARAM_NODES=$*
	else
		S_EXECUTE_PARAM_SERVERS=$*
		S_EXECUTE_PARAM_NODES=
	fi
}

function f_common_execute_set() {
	local P_FUNCTION=$1
	local P_DC=$2
	local P_EXECUTE_LIST="$3"

	# split into servers and nodes
	S_EXECUTE_PARAM_SERVERS=
	S_EXECUTE_PARAM_NODES=
	f_common_execute_splitservers $P_EXECUTE_LIST

	echo execute datacenter=$P_DC...
	f_env_getxmlserverlist $P_DC
	local F_SERVER_LIST=$C_ENV_XMLVALUE

	f_checkvalidlist "$F_SERVER_LIST" "$S_EXECUTE_PARAM_SERVERS"
	f_getsubset "$F_SERVER_LIST" "$S_EXECUTE_PARAM_SERVERS"
	F_SERVER_LIST=$C_COMMON_SUBSET

	S_EXECUTE_GROUPS=
	S_EXECUTE_SERVERS=
	S_EXECUTE_ENABLED=

	# split into groups
	f_execute_function "getgroups" $P_DC $P_FUNCTION "$F_SERVER_LIST" "$S_EXECUTE_PARAM_NODES"

	# iterate groups
	local group
	for group in $S_EXECUTE_GROUPS; do
		# execute group
		f_common_execute_group $P_DC $P_FUNCTION "$F_SERVER_LIST" "$S_EXECUTE_PARAM_NODES" $group 
	done

	f_execute_function "finishdc" $P_DC $P_FUNCTION "$P_SERVER_LIST" "$S_EXECUTE_PARAM_NODES"
}
