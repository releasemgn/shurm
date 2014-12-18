#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

# read-only process functions

C_PROCESS_PID=
C_PROCESS_STATUS=

S_PROCESS_DEFAULT_TIMEOUT=600
S_PROCESS_STARTPROCESS_TIMEOUT=10

function f_process_pid() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN=$3

	C_PROCESS_STATUS=
	C_PROCESS_PID=

	# find program process
	local F_USERNAME=`echo $P_HOSTLOGIN | cut -d "@" -f1`
	f_run_cmd $P_HOSTLOGIN "pgrep -f \"Dprogram.name=$P_PROGRAMNAME \""
	C_PROCESS_PID=$RUN_CMD_RES
	if [ "$C_PROCESS_PID" != "" ]; then
		C_PROCESS_PID=`echo $C_PROCESS_PID | tr "\n" " "`
	fi
}

# get process status
function f_process_service_status() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN=$3
	local P_SERVICENAME=$4

	C_PROCESS_PID=
	C_PROCESS_STATUS=

	f_run_cmd $P_HOSTLOGIN "/sbin/service $P_SERVICENAME status"
	if [[ "$RUN_CMD_RES" =~ "is stopped" ]] || [[ "$RUN_CMD_RES" =~ "is not running" ]]; then
		C_PROCESS_STATUS="STOPPED"
		return 0
	fi

	if [[ "$RUN_CMD_RES" =~ "is running" ]] || [[ "$RUN_CMD_RES" =~ "is already running" ]]; then
		C_PROCESS_STATUS="STARTED"
		return 0
	fi

	C_PROCESS_STATUS="ERRORS"
	return 1
}

function f_process_generic_started_status() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN=$3
	local P_FULLBINPATH=$4

	# find process
	f_process_pid $P_DC $P_PROGRAMNAME $P_HOSTLOGIN
	if [ "$C_PROCESS_PID" = "" ]; then
		C_PROCESS_STATUS="STOPPED"
		return 0
	fi

	# check process status
	f_run_cmd $P_HOSTLOGIN "cd $P_FULLBINPATH; ./server.status.sh $P_PROGRAMNAME $GETOPT_ARGS"
	if [[ "$RUN_CMD_RES" =~ "Started=true" ]] || [[ "$RUN_CMD_RES" =~ "RUNNING" ]] || [[ "$RUN_CMD_RES" =~ "is running" ]]; then
		C_PROCESS_STATUS="STARTED"
		return 0
	fi
	if [ "$RUN_CMD_RES" = "" ]; then
		C_PROCESS_STATUS="STARTING"
		return 0
	fi
	C_PROCESS_STATUS="ERRORS"
	return 0
}

function f_process_check_service() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_SERVICENAME=$3
	local P_HOSTLOGIN=$4

	f_process_service_status $P_DC $P_PROGRAMNAME $P_HOSTLOGIN $P_SERVICENAME
	echo $P_HOSTLOGIN: $P_SERVICENAME service status=$C_PROCESS_STATUS
}

function f_process_check_generic() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN=$3
	local P_FULLBINPATH=$4

	f_process_generic_started_status $P_DC $P_PROGRAMNAME $P_HOSTLOGIN $P_FULLBINPATH
	echo $P_HOSTLOGIN: generic status=$C_PROCESS_STATUS, pid=$C_PROCESS_PID
}

# one-node wait to start
function f_process_waitone_service_started() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_SERVICENAME=$3
	local P_HOSTLOGIN=$4
	local P_PROCESS_TIMEOUT=$5

	# wait for start
	local KWAIT=0
	local F_WAIT_DATE1=`date '+%s'`
	local F_WAIT_DATE2
	while [ "$KWAIT" -lt $P_PROCESS_TIMEOUT ]; do
		# check already started
		f_process_service_status $P_DC $P_PROGRAMNAME $P_HOSTLOGIN $P_SERVICENAME
		if [ "$C_PROCESS_STATUS" = "STARTED" ]; then
			echo "`date` $P_HOSTLOGIN: service $P_SERVICENAME successfully started"
			return 0

		elif [ "$C_PROCESS_STATUS" = "STOPPED" ]; then
			if [ "$KWAIT" -gt $S_PROCESS_STARTPROCESS_TIMEOUT ]; then
				echo "`date` $P_HOSTLOGIN: service $P_SERVICENAME is not started (reason: process launch timeout=$S_PROCESS_STARTPROCESS_TIMEOUT). Exiting"
				exit 1
			fi

		elif [ "$C_PROCESS_STATUS" != "STARTING" ]; then
			echo "`date` $P_HOSTLOGIN: errors starting server $P_PROGRAMNAME, servicename=$P_SERVICENAME, status=$C_PROCESS_STATUS (reason: unexpected cmdres=$RUN_CMD_RES). Exiting"
			exit 1
		fi

        	sleep 1
		F_WAIT_DATE2=`date '+%s'`
        	KWAIT=$(expr $F_WAIT_DATE2 - $F_WAIT_DATE1)
	done

	echo "`date` $P_HOSTLOGIN: service $P_SERVICENAME is not started within $P_PROCESS_TIMEOUT seconds. Exiting"
	exit 1
}

function f_process_waitone_generic_started() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN=$3
	local P_FULLBINPATH=$4
	local P_PROCESS_TIMEOUT=$5

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo "`date` $P_HOSTLOGIN: wait for start generic server=$P_PROGRAMNAME..."
	fi

	local KWAIT=0
	local F_WAITTIME=$P_PROCESS_TIMEOUT
	local F_WAIT_DATE1=`date '+%s'`
	local F_WAIT_DATE2
	while [ "$KWAIT" -lt $F_WAITTIME ]; do
		# check already started
		f_process_generic_started_status $P_DC $P_PROGRAMNAME $P_HOSTLOGIN $P_FULLBINPATH
		if [ "$C_PROCESS_STATUS" = "STARTED" ]; then
			echo "`date` $P_HOSTLOGIN: generic server=$P_PROGRAMNAME successfully started (pid=$C_PROCESS_PID)"
			return 0

		elif [ "$C_PROCESS_STATUS" = "STOPPED" ]; then
			if [ "$KWAIT" -gt $S_PROCESS_STARTPROCESS_TIMEOUT ]; then
				echo "`date` $P_HOSTLOGIN: generic server=$P_PROGRAMNAME is not started (reason: process launch timeout=$S_PROCESS_STARTPROCESS_TIMEOUT). Exiting"
				exit 1
			fi

		elif [ "$C_PROCESS_STATUS" != "STARTING" ]; then
			echo "`date` $P_HOSTLOGIN: errors starting server=$P_PROGRAMNAME, status=$C_PROCESS_STATUS (reason: unexpected cmdres=$RUN_CMD_RES). Exiting"
			exit 1
		fi

        	sleep 1
		F_WAIT_DATE2=`date '+%s'`
        	KWAIT=$(expr $F_WAIT_DATE2 - $F_WAIT_DATE1)
	done

	echo "`date` $P_HOSTLOGIN: generic server=$P_PROGRAMNAME is not started within $F_WAITTIME seconds. Exiting"
	exit 1
}

function f_process_waitone_generic_stopped() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN=$3
	local P_FULLBINPATH=$4
	local P_PROCESS_TIMEOUT=$5

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo "`date` $P_HOSTLOGIN: wait for stop generic server=$P_PROGRAMNAME..."
	fi

	if [ "$P_PROCESS_TIMEOUT" = "" ]; then
		P_PROCESS_TIMEOUT=$S_PROCESS_DEFAULT_TIMEOUT
	fi

	local KWAIT=0
	local F_WAITTIME=$P_PROCESS_TIMEOUT
	local F_WAIT_DATE1=`date '+%s'`
	local F_WAIT_DATE2
	while [ "$KWAIT" -lt $F_WAITTIME ]; do
		# check stopped
		f_process_pid $P_DC $P_PROGRAMNAME $P_HOSTLOGIN
		if [ "$C_PROCESS_PID" = "" ]; then
			echo "`date` $P_HOSTLOGIN: server successfully stopped"
			return 0
		fi

        	sleep 1
		F_WAIT_DATE2=`date '+%s'`
        	KWAIT=$(expr $F_WAIT_DATE2 - $F_WAIT_DATE1)
	done

	# enforced stop
	echo "`date` $P_HOSTLOGIN: failed to stop server within $F_WAITTIME seconds. killing..."
	f_deploy_execute $P_DC $P_PROGRAMNAME $P_HOSTLOGIN "kill -9 $C_PROCESS_PID"

	f_process_pid $P_DC $P_PROGRAMNAME $P_HOSTLOGIN
	if [ "$C_PROCESS_PID" = "" ]; then
		echo "`date` $P_HOSTLOGIN: server successfully killed"
		return 0
	fi

	echo "`date` $P_HOSTLOGIN: generic server=$P_PROGRAMNAME - unable to kill. Exiting"
	exit 1
}

# multinode ops - wait
function f_process_waitall_service_started() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_SERVICENAME=$3
	local P_HOSTLOGIN_LIST="$4"
	local P_NODE_LIST="$5"
	local P_PROCESS_TIMEOUT=$6

	if [ "$P_PROCESS_TIMEOUT" = "" ]; then
		P_PROCESS_TIMEOUT=$S_PROCESS_DEFAULT_TIMEOUT
	fi

	if [ "$P_DC" = "" ] || [ "$P_PROGRAMNAME" = "" ] || [ "$P_SERVICENAME" = "" ] || [ "$P_HOSTLOGIN_LIST" = "" ]; then
		echo f_process_waitall_service_started: invalid call. Exiting
		exit 1
	fi

	local NODE=1
	local NODEN=`echo "$P_HOSTLOGIN_LIST" | tr " " "\n" | grep -c "@"`
	while [ ! "$NODE" -gt $NODEN ]; do
		if [ "$P_NODE_LIST" = "" ] || [[ "$P_NODE_LIST" =~ "$NODE" ]]; then
			f_getlistitem "$P_HOSTLOGIN_LIST" $NODE
			F_ENV_HOSTLOGIN=$C_LISTITEM

			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo wait for service $P_SERVICENAME server=$P_PROGRAMNAME node=$NODE, host=$F_ENV_HOSTLOGIN...
			fi
			f_process_waitone_service_started $P_DC $P_PROGRAMNAME $P_SERVICENAME $F_ENV_HOSTLOGIN $P_PROCESS_TIMEOUT
		fi
		NODE=$(expr $NODE + 1)
	done	
}

function f_process_waitall_generic_started() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN_LIST="$3"
	local P_ROOTDIR=$4
	local P_BINPATH=$5
	local P_NODE_LIST="$6"
	local P_PROCESS_TIMEOUT=$7

	if [ "$P_DC" = "" ] || [ "$P_PROGRAMNAME" = "" ] || [ "$P_HOSTLOGIN_LIST" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_BINPATH" = "" ]; then
		echo f_process_waitall_generic_started: invalid call. Exiting
		exit 1
	fi

	if [ "$P_PROCESS_TIMEOUT" = "" ]; then
		P_PROCESS_TIMEOUT=$S_PROCESS_DEFAULT_TIMEOUT
	fi

	local NODE=1
	local NODEN=`echo "$P_HOSTLOGIN_LIST" | tr " " "\n" | grep -c "@"`
	while [ ! "$NODE" -gt $NODEN ]; do
		if [ "$P_NODE_LIST" = "" ] || [[ "$P_NODE_LIST" =~ "$NODE" ]]; then
			f_getlistitem "$P_HOSTLOGIN_LIST" $NODE
			F_ENV_HOSTLOGIN=$C_LISTITEM

			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo wait for start generic server=$P_PROGRAMNAME node=$NODE, host=$F_ENV_HOSTLOGIN...
			fi
			f_process_waitone_generic_started $P_DC $P_PROGRAMNAME $F_ENV_HOSTLOGIN $P_ROOTDIR/$P_BINPATH $P_PROCESS_TIMEOUT
		fi
		NODE=$(expr $NODE + 1)
	done	

	local F_WAITALL_GENERIC=$?
	return $F_WAITALL_GENERIC
}

function f_process_waitall_generic_stopped() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN_LIST="$3"
	local P_ROOTDIR=$4
	local P_BINPATH=$5
	local P_NODE_LIST="$6"
	local P_PROCESS_TIMEOUT=$7

	if [ "$P_DC" = "" ] || [ "$P_PROGRAMNAME" = "" ] || [ "$P_HOSTLOGIN_LIST" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_BINPATH" = "" ]; then
		echo f_process_waitall_generic_stopped: invalid call. Exiting
		exit 1
	fi

	local NODE=1
	local NODEN=`echo "$P_HOSTLOGIN_LIST" | tr " " "\n" | grep -c "@"`
	while [ ! "$NODE" -gt $NODEN ]; do
		if [ "$P_NODE_LIST" = "" ] || [[ "$P_NODE_LIST" =~ "$NODE" ]]; then
			f_getlistitem "$P_HOSTLOGIN_LIST" $NODE
			F_ENV_HOSTLOGIN=$C_LISTITEM

			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo wait for stop generic server=$P_PROGRAMNAME node=$NODE, host=$F_ENV_HOSTLOGIN...
			fi
			f_process_waitone_generic_stopped $P_DC $P_PROGRAMNAME $F_ENV_HOSTLOGIN $P_ROOTDIR/$P_BINPATH $P_PROCESS_TIMEOUT
		fi
		NODE=$(expr $NODE + 1)
	done	
	local F_WAITALL_GENERIC=$?
	return $F_WAITALL_GENERIC
}
