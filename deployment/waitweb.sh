#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo waitweb.sh: DC not set
	exit 1
fi

# check call form server node
SRVNAME=$1
NODE=$2

if [ "$SRVNAME" = "" ]; then
	echo waitweb.sh: SRVNAME not set
	exit 1
fi

if [ "$NODE" = "" ]; then
	NODE=1
fi

# load common functions
. ./common.sh
. ./commonprocess.sh

# wait all processes (except for windows-based)
echo waitweb.sh: wait environment to start...

# wait process on given host
function f_local_wait_ctxload() {
	local P_SERVER=$1
	local P_HOSTLOGIN=$2
	local P_ROOTDIR=$3
	local P_DEPLOYPATH=$4
	local P_LOGPATH=$5

	# check already started
	f_process_pid $DC $P_SERVER $P_HOSTLOGIN
	if [ "$C_PROCESS_PID" = "" ]; then
		echo $P_HOSTLOGIN: not started. Exiting
		exit 1
	fi

	# get runtime path
	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_DEPLOYPATH
	local F_FINALDEPLOYPATH=$C_COMMON_DIRPATH
	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOGPATH
	local F_FINALLOGPATH=$C_COMMON_DIRPATH

	# get total binaries deployed
	f_run_cmd $P_HOSTLOGIN "ls $F_FINALDEPLOYPATH | grep -c .war"

	local MAX_BINARIES
	if [ "$C_ENV_SERVER_JBOSS_VERSION" = "5.1.0" ]; then
		MAX_BINARIES=$(expr $RUN_CMD_RES + 3)
	elif [ "$C_ENV_SERVER_JBOSS_VERSION" = "5.1.2" ]; then
		MAX_BINARIES=$(expr $RUN_CMD_RES + 0)
	else
		MAX_BINARIES=$(expr $RUN_CMD_RES + 4)
	fi

	echo $P_HOSTLOGIN: wait for $MAX_BINARIES binaries loaded...

	# wait for count of binaries started
	# wait no more than 10 mins
	local MAX_WAITS=60
	local CUR_WAIT=0
	while [ "$CUR_WAIT" -lt "$MAX_WAITS" ]; do
		f_run_cmd $P_HOSTLOGIN "cat $F_FINALLOGPATH* | grep -c ctxPath"
		local CHECK_RES=`echo $RUN_CMD_RES | grep -v "No such file"`
		local CURNUM
		if [ "$CHECK_RES" = "" ]; then
			CURNUM=0
		else
			CURNUM=$RUN_CMD_RES
		fi
		echo `date +%Y-%m-%d.%H-%M-%S` - loaded $CURNUM binaries
		
		if [ "$CURNUM" -ge "$MAX_BINARIES" ]; then
			echo $P_HOSTLOGIN: server successfully started - `date +%Y-%m-%d.%H-%M-%S`.
			return 0
		fi

		sleep 10
		CUR_WAIT=`expr $CUR_WAIT + 1`
	done

	echo $P_HOSTLOGIN: wait failed to start server.
}

function f_local_execute_server() {
	local P_SERVER=$1
	local P_NODE=$2

	f_env_getxmlserverinfo $DC $P_SERVER $GETOPT_DEPLOYGROUP

	f_getlistitem "$C_ENV_SERVER_HOSTLOGIN_LIST" $P_NODE
	local F_HOSTLOGIN=$C_LISTITEM

	if [ "$C_ENV_SERVER_TYPE" = "generic.web" ]; then
		f_local_wait_ctxload $P_SERVER $F_HOSTLOGIN $C_ENV_SERVER_ROOTPATH $C_ENV_SERVER_DEPLOYPATH $C_ENV_SERVER_LOGPATH
	else
		echo server type=$C_ENV_SERVER_TYPE is not supported. Exiting.
		exit 1
	fi
}

# wait all processes
echo "waitweb.sh: wait web server..."

# execute datacenter
f_local_execute_server $SRVNAME $NODE

echo waitweb.sh: SUCCESSFULLY DONE.
