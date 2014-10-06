#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo deployredist.sh: DC not set
	exit 1
fi

SRCVERSIONDIR=$1
if [ "$SRCVERSIONDIR" = "" ]; then
	echo deployredist.sh: SRCVERSIONDIR not set
	exit 1
fi

shift 1
SRVNAME_LIST=$*

if [ "$SRVNAME_LIST" = "pguwar" ]; then
	SRVNAME_LIST="pguapp pguweb"
fi

# execute

. ./common.sh
. ./commonredistbase.sh
. ./commonredistconf.sh
. ./commonredistmain.sh
. ./commonprocess.sh
. ./commondeploy.sh
. ./commoncluster.sh

S_HOTDEPLOY_SERVER_LIST=
S_COLDDEPLOY_SERVER_LIST=
S_NODE_HOTDEPLOY=
S_NODE_COLDDEPLOY=

function f_local_check_node() {
	local P_SRVNAME=$1
	local P_HOSTLOGIN=$2
	local P_NODE=$3
	local P_SRCVERSIONDIR=$4

	local location

	local F_NODE_COLDDEPLOY=no
	if [ "$GETOPT_DEPLOYHOT" != "yes" ]; then
		if [ "$GETOPT_DEPLOYCONF" = "yes" ]; then
			f_redist_getlocations $P_SRVNAME $P_HOSTLOGIN $P_SRCVERSIONDIR "config"
			local F_HAS=no
			for location in $C_REDIST_LOCATIONLIST; do
				f_redist_getitems $P_SRVNAME $P_HOSTLOGIN $P_SRCVERSIONDIR $location "config"
				if [ "$C_REDIST_DIRITEMS_ISEMPTY" = "false" ]; then
					F_NODE_COLDDEPLOY="yes"
					F_HAS=yes
				fi
			done
			if [ "$F_HAS" = "yes" ]; then
				echo "redist $P_HOSTLOGIN: configuration found."
			fi
		fi

		if [ "$GETOPT_DEPLOYBINARY" != "no" ] && [ "$GETOPT_DEPLOYHOT" != "yes" ]; then
			f_redist_getlocations $P_SRVNAME $P_HOSTLOGIN $P_SRCVERSIONDIR "deploy"
			local F_HAS=no
			for location in $C_REDIST_LOCATIONLIST; do
				f_redist_getitems $P_SRVNAME $P_HOSTLOGIN $P_SRCVERSIONDIR $location "deploy"
				if [ "$C_REDIST_DIRITEMS_ISEMPTY" = "false" ]; then
					F_NODE_COLDDEPLOY="yes"
					F_HAS=yes
				fi
			done
			if [ "$F_HAS" = "yes" ]; then
				echo "redist $P_HOSTLOGIN: binaries found."
			fi
		fi
	fi

	local F_NODE_HOTDEPLOY=no
	if [ "$GETOPT_DEPLOYHOT" != "no" ]; then
		f_redist_getlocations $P_SRVNAME $P_HOSTLOGIN $P_SRCVERSIONDIR "hotdeploy"
		local F_HAS=no
		for location in $C_REDIST_LOCATIONLIST; do
			f_redist_getitems $P_SRVNAME $P_HOSTLOGIN $P_SRCVERSIONDIR $location "hotdeploy"
			if [ "$C_REDIST_DIRITEMS_ISEMPTY" = "false" ]; then
				F_NODE_HOTDEPLOY="yes"
				F_HAS=yes
			fi
		done
		if [ "$F_HAS" = "yes" ]; then
			echo "redist $P_HOSTLOGIN: hotdeploy found."
		fi
	fi

	local F_RET=1
	if [ "$F_NODE_HOTDEPLOY" = "yes" ]; then
		S_NODE_HOTDEPLOY="yes"
		F_RET=0
	fi
	if [ "$F_NODE_COLDDEPLOY" = "yes" ]; then
		S_NODE_COLDDEPLOY="yes"
		F_RET=0
	fi

	if [ "$F_RET" != "0" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo $P_HOSTLOGIN: no deployment found for $P_SRVNAME release $P_SRCVERSIONDIR. Skipped.
		fi
	fi

	return $F_RET
}

# get server list based on redist
function f_local_check_server() {
	local P_SRVNAME=$1
	local P_SRCVERSIONDIR=$2

	f_env_getxmlserverinfo $DC $P_SRVNAME $GETOPT_DEPLOYGROUP
	if [ "$C_ENV_SERVER_DEPLOYTYPE" = "none" ] || [ "$C_ENV_SERVER_DEPLOYTYPE" = "manual" ]; then
		return 1
	fi

	local F_SERVER_HOTDEPLOY=no
	local F_SERVER_COLDDEPLOY=no
	local NODE

	# check on admin server if any
	if [ "$C_ENV_SERVER_HOTDEPLOYSERVER" != "" ]; then
		NODE=admin
		f_local_check_node $P_SRVNAME "$C_ENV_SERVER_HOTDEPLOYSERVER" $NODE $P_SRCVERSIONDIR
		F_SERVER_HOTDEPLOY=$S_NODE_HOTDEPLOY
	fi

	# check on each node
	NODE=1
	local hostlogin
	for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
		echo execute server=$P_SRVNAME node=$NODE...
		S_NODE_HOTDEPLOY=no
		S_NODE_COLDDEPLOY=no

		f_local_check_node $P_SRVNAME "$hostlogin" $NODE $P_SRCVERSIONDIR
		if [ "$S_NODE_HOTDEPLOY" = "yes" ]; then
			F_SERVER_HOTDEPLOY=yes
		fi
		if [ "$S_NODE_COLDDEPLOY" = "yes" ]; then
			F_SERVER_COLDDEPLOY=yes
		fi
		NODE=$(expr $NODE + 1)
	done

	local F_RET=1
	if [ "$F_SERVER_HOTDEPLOY" = "yes" ]; then
		S_HOTDEPLOY_SERVER_LIST="$S_HOTDEPLOY_SERVER_LIST $P_SRVNAME"
		F_RET=0
	fi
	if [ "$F_SERVER_COLDDEPLOY" = "yes" ]; then
		S_COLDDEPLOY_SERVER_LIST="$S_COLDDEPLOY_SERVER_LIST $P_SRVNAME"
		F_RET=0
	fi
		
	return $F_RET
}

function f_local_executesrvlist() {
	local P_TYPE=$1
	local P_SRCVERSIONDIR=$2
	local P_SRVNAME_LIST="$3"
	local P_DEPLOYGROUP=$4

	echo deploy group=$P_DEPLOYGROUP type=$P_TYPE ...

	if [ "$P_TYPE" = "cold" ]; then
		./stopenv.sh -noforce -nomsg -deploygroup $P_DEPLOYGROUP -dc $DC $P_SRVNAME_LIST
		if [ $? -ne 0 ]; then
			echo "deployredist.sh: stopenv.sh failed. Exiting"
			exit 1
		fi
	fi

	local F_ROLLOUT_OPTION="-$P_TYPE"
	./rollout.sh $F_ROLLOUT_OPTION -nomsg -deploygroup $P_DEPLOYGROUP -dc $DC $P_SRCVERSIONDIR $P_SRVNAME_LIST
	if [ $? -ne 0 ]; then
		echo "deployredist.sh: rollout.sh failed. Exiting"
		exit 1
	fi

	if [ "$P_TYPE" = "cold" ]; then
		./startenv.sh -noforce -nomsg -deploygroup $P_DEPLOYGROUP -dc $DC $P_SRVNAME_LIST
		if [ $? -ne 0 ]; then
			echo "deployredist.sh: startenv.sh failed. Exiting"
			exit 1
		fi
	fi
}

function f_local_setrunconf() {
	local P_CONFMODE=$1

	local F_SWITCH_RUNLINKFILE
	if [ "$P_CONFMODE" = "first" ]; then
		F_SWITCH_RUNLINKFILE=$S_SWITCH_RUNFIRST
	elif [ "$P_CONFMODE" = "second" ]; then
		F_SWITCH_RUNLINKFILE=$S_SWITCH_RUNSECOND
	elif [ "$P_CONFMODE" = "all" ]; then
		F_SWITCH_RUNLINKFILE=$S_SWITCH_RUNALL
	else
		echo f_local_setrunconf: invalid call. Exiting
		exit 1
	fi

	echo set configuration=$P_CONFMODE...
	f_deploy_execute $DC "configurator" $S_SWITCH_HOSTLOGIN "rm -rf $S_SWITCH_CONFPATH/$S_SWITCH_RUNFILE; ln -s $S_SWITCH_CONFPATH/$F_SWITCH_RUNLINKFILE $S_SWITCH_CONFPATH/$S_SWITCH_RUNFILE; $S_SWITCH_COMMAND > /dev/null"
}

function f_local_executelive() {
	local P_SRCVERSIONDIR=$1
	local P_SRVNAME_LIST="$2"

	# get datacenter deployment information
	f_env_getzerodowntimeinfo $DC
	S_SWITCH_HOSTLOGIN=$C_ENV_DEPLOYMENT_SWITCH_HOSTLOGIN
	S_SWITCH_COMMAND=$C_ENV_DEPLOYMENT_SWITCH_COMMAND
	S_SWITCH_CONFPATH=$C_ENV_DEPLOYMENT_SWITCH_CONFPATH
	S_SWITCH_RUNFILE=$C_ENV_DEPLOYMENT_SWITCH_RUNFILE
	S_SWITCH_RUNFIRST=$C_ENV_DEPLOYMENT_SWITCH_RUNFIRST
	S_SWITCH_RUNSECOND=$C_ENV_DEPLOYMENT_SWITCH_RUNSECOND
	S_SWITCH_RUNALL=$C_ENV_DEPLOYMENT_SWITCH_RUNALL

	# deploy nodes - second group, nogroup, first group
	f_local_setrunconf "second"
	f_local_executesrvlist cold $SRCVERSIONDIR "$P_SRVNAME_LIST" "first"
	f_local_executesrvlist cold $SRCVERSIONDIR "$P_SRVNAME_LIST" "default"
	f_local_setrunconf "first"
	f_local_executesrvlist cold $SRCVERSIONDIR "$P_SRVNAME_LIST" "second"
	f_local_setrunconf "all"
}

# get server list
function f_local_executedc() {
	echo execute datacenter=$DC...
	f_env_getxmlserverlist $DC
	local F_SERVER_LIST=$C_ENV_XMLVALUE

	# check correct names
	f_checkvalidlist "$F_SERVER_LIST" "$SRVNAME_LIST"
	f_getsubset "$F_SERVER_LIST" "$SRVNAME_LIST"
	local F_SERVER_LIST=$C_COMMON_SUBSET

	# iterate servers - get deploy list
	S_COLDDEPLOY_SERVER_LIST=
	S_HOTDEPLOY_SERVER_LIST=
	local server
	local F_DEPLOY_SERVER_LIST=
	for server in $F_SERVER_LIST; do
		echo check server=$server...
		f_local_check_server $server $SRCVERSIONDIR
		if [ $? -eq 0 ]; then
			F_DEPLOY_SERVER_LIST="$F_DEPLOY_SERVER_LIST $server"
		fi
	done

	if [ "$F_DEPLOY_SERVER_LIST" = "" ]; then
		echo deployredist.sh: nothing to deploy.
		return 1
	fi

	if [ "$GETOPT_DEPLOYGROUP" = "" ]; then
		GETOPT_DEPLOYGROUP=normal
	fi

	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" != "true" ]; then
		if [ "$GETOPT_NOCHATMSG" != "yes" ]; then
			./sendchatmsg.sh -dc $DC "[deployredist.sh] deploy $SRCVERSIONDIR to server list: $F_DEPLOY_SERVER_LIST..."
		fi
	fi

	if [ "$S_COLDDEPLOY_SERVER_LIST" != "" ]; then
		echo "============================================ cold deploy to server list: $S_COLDDEPLOY_SERVER_LIST ..."

		if [ "$GETOPT_ZERODOWNTIME" = "yes" ]; then
			f_local_executelive $SRCVERSIONDIR "$S_COLDDEPLOY_SERVER_LIST"
		else
			f_local_executesrvlist cold $SRCVERSIONDIR "$S_COLDDEPLOY_SERVER_LIST" $GETOPT_DEPLOYGROUP
		fi
	fi

	if [ "$S_HOTDEPLOY_SERVER_LIST" != "" ]; then
		echo "============================================ hot deploy to server list: $S_HOTDEPLOY_SERVER_LIST ..."

		f_local_executesrvlist hot $SRCVERSIONDIR "$S_HOTDEPLOY_SERVER_LIST" $GETOPT_DEPLOYGROUP
	fi

	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" != "true" ]; then
		if [ "$GETOPT_NOCHATMSG" != "yes" ]; then
			./sendchatmsg.sh -dc $DC "[deployredist.sh] deploy done."
		fi
	fi
}

# execute
function f_local_execute_all() {
	# check specific version
	f_release_resolverelease "$SRCVERSIONDIR"
	SRCVERSIONDIR=$C_RELEASE_DISTRID

	C_DEPLOY_EXECUTE_ECHO_ONLY=true
	C_REDIST_EXECUTE_ECHO_ONLY=true
	if [ "$GETOPT_EXECUTE" = "yes" ]; then
		C_DEPLOY_EXECUTE_ECHO_ONLY=false
		C_REDIST_EXECUTE_ECHO_ONLY=false
	fi

	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" = "true" ]; then
		echo "deployredist.sh: deploy environment version=$SRCVERSIONDIR (show only)..."
	else
		echo "deployredist.sh: deploy environment version=$SRCVERSIONDIR (execute)..."
	fi

	# execute datacenter
	f_local_executedc
}

f_local_execute_all

echo deployredist.sh: SUCCESSFULLY DONE.
