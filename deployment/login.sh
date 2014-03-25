#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo DC not set
	exit 1
fi

P_SRVNAME=$1
P_NODE=$2

if [ "$P_SRVNAME" = "" ]; then
	echo P_SRVNAME not set
	exit 1
fi

# set default node
if [ "$P_NODE" = "" ]; then
	P_NODE="1"
fi

# execute

# load common functions
. ./common.sh

function f_execute_all() {
	# find hostlogin list by server name
	local F_SRVNAME=$P_SRVNAME
	f_env_getxmlserverinfo $DC $F_SRVNAME $GETOPT_DEPLOYGROUP
	local F_HOSTOGINLIST="$C_ENV_SERVER_HOSTLOGIN_LIST"

	# find hostlogin by node
	f_getlistitem "$F_HOSTOGINLIST" $P_NODE
	local F_ENV_HOST=$C_LISTITEM
	if [ "$F_ENV_HOST" = "" ]; then
		echo login.sh: unknown host login to $F_SRVNAME node $NODE.
		exit 1
	fi

	# use root login
	if [ "$GETOPT_ROOTUSER" = "yes" ]; then
		local F_HOST=${F_ENV_HOST#*@}
		F_ENV_HOST=root@$F_HOST
	fi

	echo login dc=$DC, server=$F_SRVNAME, node=$P_NODE, hostlogin=$F_ENV_HOST...
	if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
		ssh -i $C_ENV_PROPERTY_KEYNAME $F_ENV_HOST
	else
		ssh $F_ENV_HOST
	fi
}

f_execute_all
