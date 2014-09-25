#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo stopenv.sh: DC not set
	exit 1
fi

# check call form: server node1 node2...
NODE_LIST=
if [[ "$2" =~ ^[1-9] ]]; then
	SRVNAME_LIST=$1
	shift 1
	NODE_LIST=$*
else
	SRVNAME_LIST=$*
fi

# load common functions
. ./common.sh
. ./commonprocess.sh
. ./commondeploy.sh
. ./commoncluster.sh

function f_local_execute_server_single() {
	local P_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_SRVNAME $GETOPT_DEPLOYGROUP
	if [ "$C_ENV_SERVER_HOSTLOGIN_LIST" = "" ]; then
		return 1
	fi

	if [ "$C_ENV_SERVER_TYPE" = "generic.server" ] || [ "$C_ENV_SERVER_TYPE" = "generic.web" ] ||
		( [ "$C_ENV_SERVER_TYPE" = "generic.command" ] && [ "$GETOPT_FORCE" = "yes" ] ); then
		f_cluster_stopall_generic $DC $P_SRVNAME "$C_ENV_SERVER_HOSTLOGIN_LIST" "$C_ENV_SERVER_ROOTPATH" "$C_ENV_SERVER_BINPATH" "$NODE_LIST"

	elif [ "$C_ENV_SERVER_TYPE" = "service" ]; then
		f_cluster_stopall_service $DC $P_SRVNAME "$C_ENV_SERVER_SERVICENAME" "$C_ENV_SERVER_HOSTLOGIN_LIST" "$NODE_LIST"

	else
		echo server type=$C_ENV_SERVER_TYPE is not supported. Skipped.
	fi
}

function f_local_execute_server() {
	local P_EXECUTE_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_EXECUTE_SRVNAME $GETOPT_DEPLOYGROUP
	local F_LOCAL_SUBORDINATE="$C_ENV_SERVER_SUBORDINATE_SERVERS"
	local F_LOCAL_PROXYSERVER=$C_ENV_SERVER_PROXYSERVER

	# check affected
	if [ "$GETOPT_ALL" != "yes" ]; then
		# do not stop normally not deployed server if not requested specifically
		if [ "$C_ENV_SERVER_COMPONENT_LIST" = "" ] && [ "$SRVNAME_LIST" = "" ]; then
			return 1
		fi
	fi

	echo ============================================ execute server=$P_EXECUTE_SRVNAME, type=$C_ENV_SERVER_TYPE...

	# stop proxy if any
	if [ "$F_LOCAL_PROXYSERVER" != "" ]; then
		echo stop proxy server=$F_LOCAL_PROXYSERVER...
		f_local_execute_server_single $F_LOCAL_PROXYSERVER
	fi

	# stop main
	if [ "$C_ENV_SERVER_HOSTLOGIN_LIST" != "" ]; then
		echo stop main server...
		f_local_execute_server_single $P_EXECUTE_SRVNAME
	fi

	# then stop childs
	if [ "$F_LOCAL_SUBORDINATE" != "" ]; then
		echo "ensure subordinate servers ($F_LOCAL_SUBORDINATE) are stopped..."
		local server
		for server in $F_LOCAL_SUBORDINATE; do
			f_local_execute_server_single $server
		done
	fi
}

function f_local_executedc_servergroup() {
	local P_GROUP=$1
	local P_SERVERS="$2"
	
	# execute servers in parallel within subprocess
	echo "execute stop group=$P_GROUP servers=($P_SERVERS)..."

	local server
	local process
	local F_PROCESSLIST
	for server in $P_SERVERS; do
		(f_local_execute_server $server) &
		process=$!
		F_PROCESSLIST="$F_PROCESSLIST $server=$process"
	done
	F_PROCESSLIST=${F_PROCESSLIST# }

	# wait all
	echo "wait process group=($F_PROCESSLIST)..."

	local pair
	local F_RETSTATUS=0
	for pair in $F_PROCESSLIST; do
		server=${pair%%=*}
		process=${pair##*=}

		wait $process
		if [ "$?" = "2" ]; then
			echo f_local_executedc_servergroup: error stopping server=$server
			F_RETSTATUS=2
		fi
	done

	if [ "$F_RETSTATUS" != "2" ]; then
		echo group=$P_GROUP successfully stopped.
	else
		echo f_local_executedc_servergroup: group=$P_GROUP failed to stop.
	fi
}

function f_local_executedc_servers() {
	local P_SERVERS="$1"

	# get sequence
	f_env_getstartsequence $DC
	f_env_revertsequence "$C_ENV_SEQUENCE"
	f_env_getfilteredsequence $DC "$C_ENV_SEQUENCE" "$P_SERVERS"

	# execute by sequence group
	f_env_getsequencegroups "$C_ENV_SEQUENCE"
	local F_GROUPS="$C_ENV_SEQUENCEITEMS"

	local group
	for group in $F_GROUPS; do
		f_env_getsequencegroupservers "$C_ENV_SEQUENCE" $group
		f_local_executedc_servergroup $group "$C_ENV_SEQUENCEITEMS"
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

	if [ "$GETOPT_NOCHATMSG" != "yes" ]; then
		if [ "$GETOPT_EXECUTE" = "yes" ]; then
			./sendchatmsg.sh -dc $DC "[stopenv.sh] stopping $F_SERVER_LIST..."
		fi
	fi

	# execute server list
	f_local_executedc_servers "$F_SERVER_LIST"

	if [ "$GETOPT_NOCHATMSG" != "yes" ]; then
		if [ "$GETOPT_EXECUTE" = "yes" ]; then
			./sendchatmsg.sh -dc $DC "[stopenv.sh] done."
		fi
	fi
}

# stop all processes (except for windows-based)
C_DEPLOY_EXECUTE_ECHO_ONLY=true
if [ "$GETOPT_EXECUTE" = "yes" ]; then
	C_DEPLOY_EXECUTE_ECHO_ONLY=false
fi

if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" = "true" ]; then
	echo "stopenv.sh: stop environment dc=$DC (show only)..."
else
	echo "stopenv.sh: stop environment dc=$DC (execute)..."
fi

# execute datacenter
f_local_executedc

echo stopenv.sh: SUCCESSFULLY DONE.
