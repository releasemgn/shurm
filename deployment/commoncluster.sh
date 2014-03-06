#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

# stop
function f_cluster_stopall_generic() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN_LIST="$3"
	local P_ROOTDIR=$4
	local P_BINPATH=$5
	local P_NODE_LIST="$6"

	if [ "$P_DC" = "" ] || [ "$P_PROGRAMNAME" = "" ] || [ "$P_HOSTLOGIN_LIST" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_BINPATH" = "" ]; then
		echo f_cluster_stopall_generic: invalid call. Exiting
		exit 1
	fi

	local NODE=1
	local NODEN=`echo "$P_HOSTLOGIN_LIST" | tr " " "\n" | grep -c "@"`
	while [ ! "$NODE" -gt $NODEN ]; do
		if [ "$P_NODE_LIST" = "" ] || [[ "$P_NODE_LIST" =~ "$NODE" ]]; then
			f_getlistitem "$P_HOSTLOGIN_LIST" $NODE
			local F_ENV_HOSTLOGIN=$C_LISTITEM

			echo ============================================ stop generic app=$P_PROGRAMNAME node=$NODE, host=$F_ENV_HOSTLOGIN...
			f_deploy_stop_generic $P_DC $P_PROGRAMNAME $F_ENV_HOSTLOGIN $P_ROOTDIR/$P_BINPATH
		fi
		NODE=$(expr $NODE + 1)
	done	
}

function f_cluster_stopall_service() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_SERVICENAME=$3
	local P_HOSTLOGIN_LIST="$4"
	local P_NODE_LIST="$5"

	if [ "$P_DC" = "" ] || [ "$P_PROGRAMNAME" = "" ] || [ "$P_HOSTLOGIN_LIST" = "" ] || [ "$P_SERVICENAME" = "" ]; then
		echo f_cluster_stopall_service: invalid call. Exiting
		exit 1
	fi

	local NODE=1
	local NODEN=`echo "$P_HOSTLOGIN_LIST" | tr " " "\n" | grep -c "@"`
	while [ ! "$NODE" -gt $NODEN ]; do
		if [ "$P_NODE_LIST" = "" ] || [[ "$P_NODE_LIST" =~ "$NODE" ]]; then
			f_getlistitem "$P_HOSTLOGIN_LIST" $NODE
			F_ENV_HOSTLOGIN=$C_LISTITEM

			echo ============================================ stop service app=$P_PROGRAMNAME node=$NODE, host=$F_ENV_HOSTLOGIN...
			f_deploy_stop_service $P_DC $P_PROGRAMNAME $P_SERVICENAME $F_ENV_HOSTLOGIN
		fi
		NODE=$(expr $NODE + 1)
	done	
}

# start
function f_cluster_startall_generic() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN_LIST="$3"
	local P_ROOTDIR=$4
	local P_BINPATH=$5
	local P_NODE_LIST="$6"
	local P_STARTTIME=$7

	if [ "$P_DC" = "" ] || [ "$P_PROGRAMNAME" = "" ] || [ "$P_HOSTLOGIN_LIST" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_BINPATH" = "" ]; then
		echo f_cluster_startall_generic: invalid call. Exiting
		exit 1
	fi

	local NODE=1
	local NODEN=`echo "$P_HOSTLOGIN_LIST" | tr " " "\n" | grep -c "@"`
	local F_STARTALL_GENERIC_RESULT=1
	while [ ! "$NODE" -gt $NODEN ]; do
		if [ "$P_NODE_LIST" = "" ] || [[ "$P_NODE_LIST" =~ "$NODE" ]]; then
			f_getlistitem "$P_HOSTLOGIN_LIST" $NODE
			local F_ENV_HOSTLOGIN=$C_LISTITEM

			echo ============================================ start generic app=$P_PROGRAMNAME node=$NODE, host=$F_ENV_HOSTLOGIN...
			f_deploy_start_generic $P_DC $P_PROGRAMNAME $F_ENV_HOSTLOGIN $P_ROOTDIR/$P_BINPATH
			if [ "$?" = "0" ]; then
				F_STARTALL_GENERIC_RESULT=0
			fi
		fi
		NODE=$(expr $NODE + 1)
	done	

	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" = "true" ]; then
		return 1
	fi

	# ensure processes are started
	f_process_waitall_generic $P_DC $P_PROGRAMNAME "$P_HOSTLOGIN_LIST" $P_ROOTDIR $P_BINPATH "$P_NODE_LIST" $P_STARTTIME
	if [ "$?" = "0" ]; then
		F_STARTALL_GENERIC_RESULT=0
	fi

	return $F_STARTALL_GENERIC_RESULT
}

function f_cluster_startall_service() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_SERVICENAME=$3
	local P_HOSTLOGIN_LIST="$4"
	local P_NODE_LIST="$5"
	local P_STARTTIME=$6

	if [ "$P_DC" = "" ] || [ "$P_PROGRAMNAME" = "" ] || [ "$P_HOSTLOGIN_LIST" = "" ] || [ "$P_SERVICENAME" = "" ]; then
		echo f_cluster_startall_service: invalid call. Exiting
		exit 1
	fi

	local NODE=1
	local NODEN=`echo "$P_HOSTLOGIN_LIST" | tr " " "\n" | grep -c "@"`
	local F_STARTALL_SERVICE_RESULT=1
	while [ ! "$NODE" -gt $NODEN ]; do
		if [ "$P_NODE_LIST" = "" ] || [[ "$P_NODE_LIST" =~ "$NODE" ]]; then
			f_getlistitem "$P_HOSTLOGIN_LIST" $NODE
			local F_ENV_HOSTLOGIN=$C_LISTITEM

			echo ============================================ start service app=$P_PROGRAMNAME node=$NODE, host=$F_ENV_HOSTLOGIN...
			f_deploy_start_service $P_DC $P_PROGRAMNAME $P_SERVICENAME $F_ENV_HOSTLOGIN
			if [ "$?" = "0" ]; then
				F_STARTALL_SERVICE_RESULT=0
			fi
		fi
		NODE=$(expr $NODE + 1)
	done	

	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" = "true" ]; then
		return 1
	fi

	# ensure processes are started
	f_process_waitall_service $P_DC $P_PROGRAMNAME $P_SERVICENAME "$P_HOSTLOGIN_LIST" "$P_NODE_LIST" $P_STARTTIME
	if [ "$?" = "0" ]; then
		F_STARTALL_SERVICE_RESULT=0
	fi

	return $F_STARTALL_SERVICE_RESULT
}
