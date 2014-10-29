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
	local F_HOSTLOGIN=$C_LISTITEM
	if [ "$F_HOSTLOGIN" = "" ]; then
		echo login.sh: unknown host login to $F_SRVNAME node $NODE.
		exit 1
	fi

	# handle user options
	if [ "$GETOPT_HOSTUSER" != "" ]; then
		F_HOSTLOGIN=${GETOPT_HOSTUSER}@${F_HOSTLOGIN#*@}
	elif [ "$GETOPT_ROOTUSER" = "yes" ]; then
		F_HOSTLOGIN=root@${F_HOSTLOGIN#*@}
	fi

	local F_KEY=$C_ENV_PROPERTY_KEYNAME
	if [ "$GETOPT_KEY" != "" ]; then
		F_KEY=$GETOPT_KEY
	fi

	echo login dc=$DC, server=$F_SRVNAME, node=$P_NODE, hostlogin=$F_HOSTLOGIN ...
	if [ "$F_KEY" != "" ]; then
		ssh -i $F_KEY $F_HOSTLOGIN
	else
		ssh $F_HOSTLOGIN
	fi
}

f_execute_all
