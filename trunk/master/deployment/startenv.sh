#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo startenv.sh: DC not set
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

	echo execute server=$P_SRVNAME, type=$C_ENV_SERVER_TYPE...

	# do not start normally
	local F_START_RESULT=1
	local F_SERVER_TYPE=$C_ENV_SERVER_TYPE
	if [ "$F_SERVER_TYPE" = "generic.server" ] || [ "$F_SERVER_TYPE" = "generic.web" ] || [ "$F_SERVER_TYPE" = "generic.command" ]; then
		if [ "$GETOPT_FORCE" = "no" ] && [ "$F_SERVER_TYPE" = "generic.command" ]; then
			return 1
		fi

		f_cluster_startall_generic $DC $P_SRVNAME "$C_ENV_SERVER_HOSTLOGIN_LIST" "$C_ENV_SERVER_ROOTPATH" "$C_ENV_SERVER_BINPATH" "$NODE_LIST" $C_ENV_SERVER_STARTTIME
		F_START_RESULT=$?

	elif [ "$C_ENV_SERVER_TYPE" = "service" ]; then
		f_cluster_startall_service $DC $P_SRVNAME "$C_ENV_SERVER_SERVICENAME" "$C_ENV_SERVER_HOSTLOGIN_LIST" "$NODE_LIST" $C_ENV_SERVER_STARTTIME
		F_START_RESULT=$?

	else
		echo server type=$F_SERVER_TYPE is not supported. Skipped.
		return 1
	fi

	return $F_START_RESULT
}

function f_local_execute_server() {
	local P_EXECUTE_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_EXECUTE_SRVNAME $GETOPT_DEPLOYGROUP
	local F_LOCAL_HOSTLOGINLIST="$C_ENV_SERVER_HOSTLOGIN_LIST"
	local F_LOCAL_SUBORDINATE="$C_ENV_SERVER_SUBORDINATE_SERVERS"
	local F_LOCAL_PROXYSERVER=$C_ENV_SERVER_PROXYSERVER

	echo ============================================ execute server=$P_EXECUTE_SRVNAME, type=$C_ENV_SERVER_TYPE...

	# check affected
	if [ "$GETOPT_ALL" != "yes" ]; then
		# do not start normally not deployed server if not requested specifically
		if [ "$C_ENV_SERVER_COMPONENT_LIST" = "" ] && [ "$SRVNAME_LIST" = "" ]; then
			return 0
		fi
	fi

	# first start childs
	local F_EXECUTE_SERVER_RESULT=1
	if [ "$F_LOCAL_SUBORDINATE" != "" ]; then
		echo "ensure subordinate servers ($F_LOCAL_SUBORDINATE) are started..."
		local server
		for server in $F_LOCAL_SUBORDINATE; do
			f_local_execute_server_single $server
			if [ "$?" = "0" ]; then
				F_EXECUTE_SERVER_RESULT=0
			fi
		done
	fi

	# start main
	if [ "$F_LOCAL_HOSTLOGINLIST" != "" ]; then
		echo start main server...
		f_local_execute_server_single $P_EXECUTE_SRVNAME
		if [ "$?" = "0" ]; then
			F_EXECUTE_SERVER_RESULT=0
		fi
	fi

	# start proxy if any
	if [ "$F_LOCAL_PROXYSERVER" != "" ]; then
		echo start proxy server=$F_LOCAL_PROXYSERVER...
		f_local_execute_server_single $F_LOCAL_PROXYSERVER
		if [ "$?" = "0" ]; then
			F_EXECUTE_SERVER_RESULT=0
		fi
	fi

	# standard start
	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" = "true" ]; then
		return 0
	fi

	if [ "$F_EXECUTE_SERVER_RESULT" != "0" ]; then
		return 1
	fi

	./checkenv.sh -dc $DC $P_EXECUTE_SRVNAME
	if [ "$?" != "0" ]; then
		if [ "$GETOPT_NOCHATMSG" != "yes" ]; then
			./sendchatmsg.sh -dc $DC "[startenv.sh] $P_EXECUTE_SRVNAME started with errors"
		fi
		return 1
	fi
	return 0
}

function f_local_executedc_servergroup() {
	local P_GROUP=$1
	local P_SERVERS="$2"
	
	# execute servers in parallel within subprocess
	echo "execute start group=$P_GROUP servers=($P_SERVERS)..."

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
	local F_STATUS
	local F_RETSTATUS=0
	for pair in $F_PROCESSLIST; do
		server=${pair%%=*}
		process=${pair##*=}

		wait $process
		F_STATUS=$?
		if [ "$F_STATUS" != "0" ]; then
			echo f_local_executedc_servergroup: error starting server=$server
			F_RETSTATUS=2
		fi
	done

	if [ "$F_RETSTATUS" = "0" ]; then
		echo group=$P_GROUP successfully started.
	else
		if [ "$GETOPT_SKIPERRORS" = "yes" ]; then
			echo f_local_executedc_servergroup: group=$P_GROUP failed to start. Ignored.
		else
			echo f_local_executedc_servergroup: group=$P_GROUP failed to start. Exiting
			exit 1
		fi
	fi
}

function f_local_executedc_servers() {
	local P_SERVERS="$1"

	# get sequence
	f_env_getstartsequence $DC
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
			./sendchatmsg.sh -dc $DC "[startenv.sh] starting $F_SERVER_LIST..."
		fi
	fi

	# execute server list
	f_local_executedc_servers "$F_SERVER_LIST"

	if [ "$GETOPT_NOCHATMSG" != "yes" ]; then
		if [ "$GETOPT_EXECUTE" = "yes" ]; then
			./sendchatmsg.sh -dc $DC "[startenv.sh] done."
		fi
	fi
}

# start all processes (except for windows-based)
C_DEPLOY_EXECUTE_ECHO_ONLY=true
if [ "$GETOPT_EXECUTE" = "yes" ]; then
	C_DEPLOY_EXECUTE_ECHO_ONLY=false
fi

if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" = "true" ]; then
	echo "startenv.sh: start environment (show only)..."
else
	echo "startenv.sh: start environment (execute)..."
fi

# execute datacenter
f_local_executedc

echo startenv.sh: SUCCESSFULLY DONE.
