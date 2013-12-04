#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo getredistinfo.sh: DC not set
	exit 1
fi

SRCVERSIONDIR=$1
if [ "$SRCVERSIONDIR" = "" ]; then
	echo getredistinfo.sh: SRCVERSIONDIR not set
	exit 1
fi

shift 1
SRVNAME_LIST=$*

# load common functions
. ./common.sh
. ./commonredistbase.sh
. ./commonredistconf.sh
. ./commonredistmain.sh

function f_local_executenode_redisttype() {
	local P_SERVER=$1
	local P_HOSTLOGIN="$2"
	local P_REDISTTYPE_DEPLOY=$3
	local P_REDISTTYPE_BACKUP=$4

	local location

	# get redist locations
	f_redist_getlocations $P_SERVER $P_HOSTLOGIN $SRCVERSIONDIR $P_REDISTTYPE_DEPLOY
	for location in $C_REDIST_LOCATIONLIST; do
		f_redist_getitems $P_SERVER $P_HOSTLOGIN $SRCVERSIONDIR $location $P_REDISTTYPE_DEPLOY

		# list items
		if [ "$C_REDIST_DIRITEMS_ISEMPTY" != "true" ]; then
			echo "$P_REDISTTYPE_DEPLOY $SRCVERSIONDIR/$location: $C_REDIST_DIRITEMS"
		fi
	done

	f_redist_getlocations $P_SERVER $P_HOSTLOGIN $SRCVERSIONDIR $P_REDISTTYPE_BACKUP
	for location in $C_REDIST_LOCATIONLIST; do
		f_redist_getitems $P_SERVER $P_HOSTLOGIN $SRCVERSIONDIR $location $P_REDISTTYPE_BACKUP

		# list items
		if [ "$C_REDIST_DIRITEMS_ISEMPTY" != "true" ]; then
			echo "$P_REDISTTYPE_BACKUP $SRCVERSIONDIR/$location: $C_REDIST_DIRITEMS"
		fi
	done
}

function f_local_executenode() {
	local P_SERVER=$1
	local P_HOSTLOGIN="$2"
	local P_NODE=$3

	echo redist info app=$P_SERVER node=$P_NODE, host=$P_HOSTLOGIN...
	echo $P_HOSTLOGIN: ============================================ redist info

	f_local_executenode_redisttype $P_SERVER $P_HOSTLOGIN "deploy" "deploy.backup"
	f_local_executenode_redisttype $P_SERVER $P_HOSTLOGIN "config" "config.backup"
	f_local_executenode_redisttype $P_SERVER $P_HOSTLOGIN "hotdeploy" "hotdeploy.backup"
}

function f_local_execute_server() {
	local P_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_SRVNAME $GETOPT_DEPLOYGROUP

	echo execute server=$P_SRVNAME...

	# iterate by nodes
	if [ "$C_ENV_SERVER_DEPLOYPATH" != "" ]; then
		local NODE=1
		local hostlogin
		for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
			echo execute server=$P_SRVNAME node=$NODE...
			f_local_executenode $P_SRVNAME "$hostlogin" $NODE
			NODE=$(expr $NODE + 1)
		done
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

function f_local_execute_all() {
	# check specific version
	if [ "$SRCVERSIONDIR" = "prod" ]; then
		f_release_getfullproddistr
		SRCVERSIONDIR=$C_RELEASE_DISTRID
		echo getredistinfo.sh: use prod version=$SRCVERSIONDIR
	fi

	# resdist all std binaries (except for windows-based)
	echo getredistinfo.sh: check distribution package in staging area...

	# execute datacenter
	f_local_executedc
}

f_local_execute_all

echo getredistinfo.sh: finished.
