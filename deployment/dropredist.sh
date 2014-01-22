#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo dropredist.sh: DC not set
	exit 1
fi

SRVNAME_LIST=$*

# load common functions
. ./common.sh
. ./commonredistbase.sh
. ./commonredistconf.sh
. ./commonredistmain.sh

function f_local_executenode() {
	local P_SERVER=$1
	local P_HOSTLOGIN="$2"
	local P_NODE=$3

	f_redist_drop $P_SERVER $P_HOSTLOGIN
}

function f_local_execute_server() {
	local P_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_SRVNAME $GETOPT_DEPLOYGROUP

	# iterate by nodes
	if [ "$C_ENV_SERVER_COMPONENT_LIST" != "" ] || [ "$C_ENV_SERVER_CONFLIST" != "" ]; then
		echo execute server=$P_SRVNAME...

		local NODE=1
		local hostlogin
		for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
			echo execute server=$P_SRVNAME node=$NODE...
			f_local_executenode $P_SRVNAME "$hostlogin" $NODE
			NODE=$(expr $NODE + 1)
		done
	else
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo ignore non-deployable server=$P_SRVNAME.
		fi
	fi
}

# get server list
function f_local_executedc() {
	echo execute datacenter=$DC...
	f_env_getxmlserverlist $DC
	local F_SERVER_LIST=$C_ENV_XMLVALUE

	f_checkvalidlist "$F_SERVER_LIST" "$SRVNAME_LIST"
	f_getsubset "$F_SERVER_LIST" "$SRVNAME_LIST"
	local F_SERVER_LIST=$C_COMMON_SUBSET

	# iterate servers
	local server
	for server in $F_SERVER_LIST; do
		f_local_execute_server $server
	done
}

# drop redist
echo dropredist.sh: drop distribution packages from staging area...

# execute datacenter
f_local_executedc

echo dropredist.sh: finished.
