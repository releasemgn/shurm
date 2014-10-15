#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo waitenv.sh: DC not set
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

# wait all processes (except for windows-based)
echo waitenv.sh: wait environment to start...

function f_local_execute_server() {
	local P_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_SRVNAME $GETOPT_DEPLOYGROUP
	local F_SERVER_TYPE=$C_ENV_SERVER_TYPE

	echo execute server=$P_SRVNAME...

	if [ "$F_SERVER_TYPE" = "service" ]; then
		f_process_waitall_service $DC $P_SRVNAME $C_ENV_SERVER_SERVICENAME "$C_ENV_SERVER_HOSTLOGIN_LIST" "$NODE_LIST"
		
	elif [ "$F_SERVER_TYPE" = "generic.server" ] || [ "$F_SERVER_TYPE" = "generic.web" ] || [ "$F_SERVER_TYPE" = "generic.command" ]; then
		if ( [ "$GETOPT_FORCE" = "no" ] || [ "$SRVNAME_LIST" = "" ] ) && [ "$F_SERVER_TYPE" = "generic.command" ]; then
			return 1
		fi

		f_process_waitall_generic $DC $P_SRVNAME "$C_ENV_SERVER_HOSTLOGIN_LIST" "$C_ENV_SERVER_ROOTPATH" "$C_ENV_SERVER_BINPATH" "$NODE_LIST"

	fi
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

# wait all processes
echo "waitenv.sh: wait environment..."

# execute datacenter
f_local_executedc

echo waitenv.sh: SUCCESSFULLY DONE.
