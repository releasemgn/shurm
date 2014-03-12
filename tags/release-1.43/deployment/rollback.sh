#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo rollback.sh: DC not set
	exit 1
fi

P_SRCVERSIONDIR=$1
if [ "$P_SRCVERSIONDIR" = "" ]; then
	echo rollback.sh: P_SRCVERSIONDIR not set
	exit 1
fi

shift 1
SRVNAME_LIST=$*

# load common functions
. ./common.sh
. ./commonredistbase.sh
. ./commonredistconf.sh
. ./commonredistmain.sh
. ./commonprocess.sh
. ./commondeploy.sh

S_DEPLOY_STATUS=
S_DEPLOY_TMPPATH="/tmp/$HOSTNAME.$USER.rollback.p$$"
S_DEPLOY_TMPPATH_TOTAL=$S_DEPLOY_TMPPATH/total.txt

function f_local_executelocation_binary() {
	local P_SERVER=$1
	local P_HOSTLOGIN="$2"
	local P_NODE=$3
	local P_ROOTDIR=$4
	local P_BINDIR="$5"
	local P_LOCATION=$6
	local P_LINKFROMPATH="$7"
	local P_HOTUPLOADPATH="$8"

	f_env_getlocationinfo $DC $P_SERVER $P_LOCATION
	local F_LOC_DEPLOYTYPE=$C_ENV_LOCATION_DEPLOYTYPE

	f_redist_rollback_generic $P_SERVER $P_HOSTLOGIN $P_NODE $P_ROOTDIR $P_SRCVERSIONDIR $P_LOCATION $F_LOC_DEPLOYTYPE "$P_HOTUPLOADPATH" "$P_LINKFROMPATH"
	local F_STATUS=$?
	if [ "$F_STATUS" = "0" ]; then
		S_DEPLOY_STATUS=yes
	fi
}

function f_local_executelocation_config() {
	local P_SERVER=$1
	local P_HOSTLOGIN=$2
	local P_NODE=$3
	local P_ROOTDIR=$4
	local P_LOCATION=$5

	echo execute locationdir=$P_LOCATION...
	f_redist_rollback_config $P_SERVER $P_HOSTLOGIN $P_NODE $P_ROOTDIR $P_SRCVERSIONDIR $P_LOCATION

	# save in svn if keep alive configuration
	if [ "$GETOPT_KEEPALIVE" = "yes" ]; then
		# get components affected
		f_redist_getitems $P_SERVER $P_HOSTLOGIN $P_SRCVERSIONDIR $P_LOCATION "config.backup"

		if [ "$C_REDIST_LOCATION_COMPONENTS" != "" ]; then
			# save components in svn
			echo "keep alive configuration components: $C_REDIST_DIRITEMS_CONFIG ..."

			if [ "$GETOPT_EXECUTE" = "yes" ]; then
				./svnsaveconfigs.sh -releasedir $P_SRCVERSIONDIR -dc $DC $P_SERVER $P_NODE $C_REDIST_DIRITEMS_CONFIG
			else
				echo keep alive skipped in showonly.
			fi
		fi
	fi
}

function f_local_executenode_binary() {
	local P_CLUSTERMODE=$1
	local P_SERVER=$2
	local P_HOSTLOGIN="$3"
	local P_NODE=$4
	local P_ROOTDIR=$5
	local P_BINDIR="$6"
	local P_LINKFROMPATH="$7"
	local P_HOTUPLOADPATH="$8"
	local P_HOTDEPLOYSCRIPT="$9"
	local P_HOTDEPLOYDATA="${10}"

	if [ "$GETOPT_DEPLOYBINARY" = "no" ]; then
		return 1
	fi

	local F_REDISTTYPE="deploy.backup"
	if [ "$GETOPT_DEPLOYHOT" = "yes" ]; then
		F_REDISTTYPE="hotdeploy.backup"
	fi

	f_redist_getlocations $P_SERVER $P_HOSTLOGIN $P_SRCVERSIONDIR $F_REDISTTYPE
	local F_LOCATIONS=$C_REDIST_LOCATIONLIST
	if [ "$F_LOCATIONS" = "" ]; then
		echo "$P_HOSTLOGIN: no binaries to roll back"
		return 1
	fi

	if [ "$GETOPT_DEPLOYHOT" = "yes" ]; then
		f_deploy_hotupload_clear $DC $P_SERVER $P_HOSTLOGIN $P_ROOTDIR "$P_HOTUPLOADPATH"
	fi

	# execute by location
	S_DEPLOY_STATUS=no
	local locationdir
	for locationdir in $F_LOCATIONS; do
		echo execute binary locationdir=$locationdir...
		f_local_executelocation_binary $P_SERVER $P_HOSTLOGIN $P_NODE $P_ROOTDIR "$P_BINDIR" $locationdir "$P_LINKFROMPATH" "$P_HOTUPLOADPATH"
	done

	if [ "$GETOPT_DEPLOYHOT" = "yes" ] && [ "$S_DEPLOY_STATUS" = "yes" ]; then
		f_deploy_upload_server $DC $P_SERVER $P_HOSTLOGIN $P_ROOTDIR $P_BINDIR "$P_HOTUPLOADPATH" "$P_SRCVERSIONDIR"
	fi

	return 0
}

function f_local_executenode_config() {
	local P_CLUSTERMODE=$1
	local P_SERVER=$2
	local P_HOSTLOGIN="$3"
	local P_NODE=$4
	local P_ROOTDIR=$5
	local P_BINDIR=$6
	local P_HOTUPLOADPATH="$7"
	local P_HOTDEPLOYSCRIPT="$8"
	local P_HOTDEPLOYDATA="$9"

	# execution configuration rollback
	f_redist_getlocations $P_SERVER $P_HOSTLOGIN $P_SRCVERSIONDIR "config.backup"
	local F_LOCATIONS=$C_REDIST_LOCATIONLIST

	if [ "$F_LOCATIONS" = "" ]; then
		echo "$P_HOSTLOGIN: no configuration locations to rollback"
	else
		# execute by location
		local locationdir
		for locationdir in $F_LOCATIONS; do
			f_local_executelocation_config $P_SERVER $P_HOSTLOGIN $P_NODE $P_ROOTDIR $locationdir
		done
	fi
}

function f_local_executenode() {
	local P_CLUSTERMODE=$1
	local P_SERVER=$2
	local P_HOSTLOGIN="$3"
	local P_NODE=$4
	local P_ROOTDIR=$5
	local P_BINDIR="$6"
	local P_LINKFROMPATH="$7"
	local P_HOTUPLOADPATH="$8"
	local P_HOTDEPLOYSCRIPT="$9"
	local P_HOTDEPLOYDATA="${10}"

	local F_SERVER_DEPLOYLOG=$S_DEPLOY_TMPPATH/$P_SERVER.node$P_NODE.txt
	echo "$P_HOSTLOGIN: start rollback, see log $F_SERVER_DEPLOYLOG ..."

	local F_PROCESS

	(	f_local_executenode_binary $P_CLUSTERMODE $P_SERVER $P_HOSTLOGIN $P_NODE $P_ROOTDIR "$P_BINDIR" "$P_LINKFROMPATH" "$P_HOTUPLOADPATH" "$P_HOTDEPLOYSCRIPT" "$P_HOTDEPLOYDATA"
		if [ "$GETOPT_DEPLOYHOT" != "yes" ] && [ "$GETOPT_DEPLOYCONF" = "yes" ]; then
			f_local_executenode_config $P_CLUSTERMODE $P_SERVER $P_HOSTLOGIN $P_NODE $P_ROOTDIR "$P_BINDIR" "$P_HOTUPLOADPATH" "$P_HOTDEPLOYSCRIPT" "$P_HOTDEPLOYDATA"
		fi

	) > $F_SERVER_DEPLOYLOG &

	F_PROCESS=$!
	echo "$F_PROCESS=$F_SERVER_DEPLOYLOG" >> $S_DEPLOY_TMPPATH_TOTAL
}

function f_local_execute_server() {
	local P_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_SRVNAME $GETOPT_DEPLOYGROUP
	local F_SERVER_DEPLOYTYPE=$C_ENV_SERVER_DEPLOYTYPE
	local F_SERVER_ROOTDIR=$C_ENV_SERVER_ROOTPATH
	local F_SERVER_BINDIR=$C_ENV_SERVER_BINPATH
	local F_SERVER_LINKFROM_DIR=$C_ENV_SERVER_LINKFROMPATH
	local F_HOTDEPLOYSERVER=$C_ENV_SERVER_HOTDEPLOYSERVER
	local F_HOTDEPLOYDIR=$C_ENV_SERVER_HOTDEPLOYPATH
	local F_HOTDEPLOYSCRIPT=$C_ENV_SERVER_HOTDEPLOYSCRIPT
	local F_HOTDEPLOYDATA=$C_ENV_SERVER_HOTDEPLOYDATA

	# ignore manually deployed and not deployed
	if [ "$F_SERVER_DEPLOYTYPE" = "manual" ] || [ "$F_SERVER_DEPLOYTYPE" = "none" ]; then
		echo server $P_SRVNAME DEPLOYTYPE=$F_SERVER_DEPLOYTYPE. Skipped.
		return 1
	fi

	local F_CLUSTER_MODE
	local NODE
	if [ "$GETOPT_DEPLOYHOT" = "yes" ] && [ "$F_HOTDEPLOYSERVER" != "" ]; then
		echo ============================================ execute cluster server=$P_SRVNAME, type=$C_ENV_SERVER_TYPE ...

		# cluster hot deploy - redist hotdeploy components to admin server only
		F_CLUSTER_MODE=yes
		NODE=admin
		f_local_executenode $F_CLUSTER_MODE $P_SRVNAME $F_HOTDEPLOYSERVER $NODE $F_SERVER_ROOTDIR $F_SERVER_BINDIR "$F_SERVER_LINKFROM_DIR" "$F_HOTDEPLOYDIR" "$F_HOTDEPLOYSCRIPT" "$F_HOTDEPLOYDATA"
	else
		if [ "$C_ENV_SERVER_HOSTLOGIN_LIST" = "" ]; then
			return 1
		fi

		echo ============================================ execute normal server=$P_SRVNAME, type=$C_ENV_SERVER_TYPE ...

		# iterate by nodes
		F_CLUSTER_MODE=no
		NODE=1
		local hostlogin
		for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
			echo execute generic server=$P_SRVNAME node=$NODE...

			# deploy both binaries and configs to each node
			f_local_executenode $F_CLUSTER_MODE $P_SRVNAME $hostlogin $NODE $F_SERVER_ROOTDIR $F_SERVER_BINDIR "$F_SERVER_LINKFROM_DIR" "$F_HOTDEPLOYDIR" "$F_HOTDEPLOYSCRIPT" "$F_HOTDEPLOYDATA"
			NODE=$(expr $NODE + 1)
		done
	fi
}

function f_local_wait_rollback() {
	local F_PROC
	local F_FILE

	echo "`date`: wait for rollback..."
	local F_STATUS
	local F_PROCS=`cat $S_DEPLOY_TMPPATH_TOTAL | cut -d "=" -f1 | tr "\n" " "`
	local F_PROCONE

	for F_PROCONE in $F_PROCS; do
		wait $F_PROCONE
		F_STATUS=$?
		if [ "$F_STATUS" != "0" ]; then
			F_FILE=`grep "$F_PROCONE=" $S_DEPLOY_TMPPATH_TOTAL | cut -d "=" -f2 | tr -d "\n"`
			echo "f_local_wait_rollout: error rolling back, see log file ($F_FILE). Exiting"
			exit 1
		fi
	done

	echo "`date`: wait for rollback successfully finished"
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

	# wait rollback using total.txt
	f_local_wait_rollback
}

function f_local_execute_all() {
	# check specific version
	f_release_resolverelease "$P_SRCVERSIONDIR"
	P_SRCVERSIONDIR=$C_RELEASE_DISTRID

	echo rollback release=$P_SRCVERSIONDIR SRVNAME_LIST=$SRVNAME_LIST...

	# rollback all std binaries (except for windows-based)
	C_DEPLOY_EXECUTE_ECHO_ONLY=true
	C_REDIST_EXECUTE_ECHO_ONLY=true
	if [ "$GETOPT_EXECUTE" = "yes" ]; then
		C_DEPLOY_EXECUTE_ECHO_ONLY=false
		C_REDIST_EXECUTE_ECHO_ONLY=false
	fi

	if [ "$C_REDIST_EXECUTE_ECHO_ONLY" = "false" ]; then
		echo "rollback.sh: rollback distribution on runtime (show only)..."
	else
		echo "rollback.sh: rollback distribution on runtime (execute)..."
	fi

	# tmp dir
	echo "create tmp dir: $S_DEPLOY_TMPPATH"
	rm -rf $S_DEPLOY_TMPPATH
	mkdir -p $S_DEPLOY_TMPPATH

	# execute datacenter
	f_local_executedc

	# clear tmp dir
	rm -rf $S_DEPLOY_TMPPATH
}

f_local_execute_all

echo rollback.sh: SUCCESSFULLY DONE.
