#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo verifydeploy.sh: DC not set
	exit 1
fi

P_VERSIONMASK="$1"
if [ "$P_VERSIONMASK" = "" ]; then
	echo verifydeploy.sh: P_VERSIONMASK not set
	exit 1
fi

shift 2
SRVNAME_LIST=$*

echo verifydeploy.sh: execute dc=$DC, versionmask=$P_VERSIONMASK, servers=$SRVNAME_LIST...

# load common functions
. ./common.sh
. ./commonredistbase.sh
. ./commonredistconf.sh
. ./commonredistmain.sh

# execute

function f_local_getdeployitems() {
	local P_DIST_ITEMS="$1"

	S_VERIFY_DEPLOYITEMS=
	S_VERIFY_DEPLOYITEMSMASKED=
	local item
	for item in $P_DIST_ITEMS; do
		f_distr_readitem $item
		if [ "$C_DISTR_TYPE" = "binary" ] || [ "$C_DISTR_TYPE" = "war" ] || [ "$C_DISTR_TYPE" = "pguwar" ]; then
			local F_NAME=$P_VERSIONMASK-$C_DISTR_DEPLOYBASENAME$C_DISTR_EXT
			local F_NAMEMASKED=".*$C_DISTR_DEPLOYBASENAME.*$C_DISTR_EXT"

			S_VERIFY_DEPLOYITEMS="$S_VERIFY_DEPLOYITEMS $F_NAME"
			S_VERIFY_DEPLOYITEMSMASKED="$S_VERIFY_DEPLOYITEMSMASKED $F_NAMEMASKED"
		fi
	done
}

function f_local_check_fileset() {
	local P_SERVERTYPE=$1
	local P_HOSTLOGIN=$2
	local P_DIST_ACTIVE_ITEMS="$3"
	local P_DIST_OBSOLETE_ITEMS="$4"
	local P_DSTPATH=$5

	# get current set
	f_run_cmd $P_HOSTLOGIN "ls $P_DSTPATH | tr \" \" \"\n\" | grep \"[1-9]\.[1-9]\" | tr \"\n\" \" \""
	local F_CURRENT_FILESET=$RUN_CMD_RES

	# get difference
	if [ "$F_CURRENT_FILESET" = "" ]; then
		echo no files deployed currently.
		return 0
	fi

	local F_DIST_ITEMS
	if [ "$GETOPT_OBSOLETE" = "yes" ]; then
		F_DIST_ITEMS="$P_DIST_ACTIVE_ITEMS $P_DIST_OBSOLETE_ITEMS"
	else
		F_DIST_ITEMS="$P_DIST_ACTIVE_ITEMS"
	fi

	# get deploy items
	f_local_getdeployitems "$F_DIST_ITEMS"
		
	# check items
	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo ""
		echo $P_HOSTLOGIN: current items - $F_CURRENT_FILESET
		echo $P_HOSTLOGIN: expected items - $S_VERIFY_DEPLOYITEMS
	fi

	local F_UNMATCHED_ITEMS=
	local item
	local F_FOUND
	local maskitem
	for item in $F_CURRENT_FILESET; do
		F_FOUND="no"
		for maskitem in $S_VERIFY_DEPLOYITEMS; do
			if [[ "$item" =~ $maskitem ]]; then
				F_FOUND="yes"
			fi
		done
		if [ "$F_FOUND" = "no" ]; then
			F_UNMATCHED_ITEMS="$F_UNMATCHED_ITEMS $item"
		fi
	done

	local F_UNEXPECTED_ITEMS=
	for item in $F_CURRENT_FILESET; do
		F_FOUND="no"
		for maskitem in $S_VERIFY_DEPLOYITEMSMASKED; do
			if [[ "$item " =~ $maskitem ]]; then
				F_FOUND="yes"
			fi
		done
		if [ "$F_FOUND" = "no" ]; then
			F_UNEXPECTED_ITEMS="$F_UNEXPECTED_ITEMS $item"
		fi
	done

	echo ""
	if [ "$F_UNEXPECTED_ITEMS" = "" ] && [ "$F_UNMATCHED_ITEMS" = "" ]; then
		echo $P_HOSTLOGIN: deployment is completely expected and matched.
	else
		if [ "$F_UNMATCHED_ITEMS" != "" ]; then
			echo $P_HOSTLOGIN: unmatched items in $P_DSTPATH - $F_UNMATCHED_ITEMS
		fi
		if [ "$F_UNEXPECTED_ITEMS" != "" ]; then
			echo $P_HOSTLOGIN: unexpected items in $P_DSTPATH - $F_UNEXPECTED_ITEMS
		fi
	fi
	echo ""
}

function f_local_executelocation() {
	local P_SERVER=$1
	local P_SERVERTYPE=$2
	local P_HOSTLOGIN=$3
	local P_NODE=$4
	local P_ROOTDIR=$5
	local P_LOCATION=$6

	# get components by location
	f_env_getlocationinfo $DC $P_SERVER $P_LOCATION
	local F_VERIFY_COMPONENT_LIST="$C_ENV_LOCATION_COMPONENT_LIST"

	# get runtime path
	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_FINALPATH=$C_COMMON_DIRPATH

	echo redist components=$F_VERIFY_COMPONENT_LIST ...

	# collect distribution items for all components
	local DIST_ITEMS=
	local DIST_OBSOLETE_ITEMS=
	local component
	for component in $F_VERIFY_COMPONENT_LIST; do
		f_distr_getcomponentitems $component
		if [ "$C_DISTR_ITEMS" != "" ]; then
			DIST_ITEMS="$DIST_ITEMS $C_DISTR_ITEMS"
		fi
		if [ "$C_DISTR_OBSOLETE_ITEMS" != "" ]; then
			DIST_OBSOLETE_ITEMS="$DIST_OBSOLETE_ITEMS $C_DISTR_OBSOLETE_ITEMS"
		fi
	done

	if [ "$DIST_ITEMS" != "" ] || [ "$DIST_OBSOLETE_ITEMS" != "" ]; then
		DIST_ITEMS=`echo "$DIST_ITEMS" | tr " " "\n" | sort -u | tr "\n" " "`
		DIST_OBSOLETE_ITEMS=`echo "$DIST_OBSOLETE_ITEMS" | tr " " "\n" | sort -u | tr "\n" " "`

		f_local_check_fileset $P_SERVERTYPE $P_HOSTLOGIN "$DIST_ITEMS" "$DIST_OBSOLETE_ITEMS" $F_FINALPATH
	fi
}

function f_local_executenode() {
	local P_SERVER=$1
	local P_SERVERTYPE=$2
	local P_HOSTLOGIN=$3
	local P_NODE=$4
	local P_ROOTDIR=$5

	if [ "$P_SERVERTYPE" != "generic" ]; then
		echo "verifydeploy.sh: P_SERVERTYPE=$P_SERVERTYPE is not supported currently"
		return 0
	fi

	echo "============================================ verify app=$P_SERVER node=$P_NODE, host=$P_HOSTLOGIN..."

	# get deployment locations
	f_env_getserverlocations $DC $P_SERVER
	local F_ENV_LOCATIONS=$C_ENV_SERVER_LOCATIONLIST

	# execute by location
	local location
	for location in $F_ENV_LOCATIONS; do
		echo execute location=$location...
		f_local_executelocation $P_SERVER $P_SERVERTYPE $P_HOSTLOGIN $P_NODE $P_ROOTDIR $location
	done
}

function f_local_execute_server() {
	local P_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_SRVNAME $GETOPT_DEPLOYGROUP
	local F_REDIST_ROOTDIR=$C_ENV_SERVER_ROOTPATH

	echo verify server=$P_SRVNAME...

	# iterate by nodes
	if [ "$C_ENV_SERVER_DEPLOYTYPE" != "manual" ]; then
		local NODE=1
		local hostlogin
		for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
			echo verify server=$P_SRVNAME node=$NODE...
			f_local_executenode $P_SRVNAME generic "$hostlogin" $NODE $F_REDIST_ROOTDIR
			NODE=$(expr $NODE + 1)
		done
	fi
}

# get server list
function f_local_executedc() {
	echo verify datacenter=$DC...
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

# resdist all std binaries (except for windows-based)
echo verifydeploy.sh: verify deployment done...

# execute datacenter
f_local_executedc

echo verifydeploy.sh: SUCCESSFULLY DONE.
