#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

C_DEPLOY_EXECUTE_ECHO_ONLY=true
function f_deploy_execute() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_EXEC_ITEM=$3
	local P_EXEC_CMD="$4"

	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" = "true" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo $P_EXEC_ITEM: showonly "$P_EXEC_CMD"
		fi
		RUN_CMD_RES=
	else
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo $P_EXEC_ITEM: execute "$P_EXEC_CMD"
		fi
		f_run_cmdcheck $P_EXEC_ITEM "echo `date` \"(SSH_CLIENT=\$SSH_CLIENT): $P_EXEC_CMD\" >> ~/execute.log"
		f_run_cmdcheck $P_EXEC_ITEM "$P_EXEC_CMD"
	fi
}

# stop process
function f_deploy_stop_generic() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN=$3
	local P_FULLBINPATH=$4

	# check status
	f_process_pid $P_DC $P_PROGRAMNAME $P_HOSTLOGIN
	if [ "$C_PROCESS_PID" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo "$P_HOSTLOGIN: server already stopped"
		fi
		return 1
	fi

	# stop kindly
	f_deploy_execute $P_DC $P_PROGRAMNAME $P_HOSTLOGIN "cd $P_FULLBINPATH; ./server.stop.sh $C_PROCESS_PID > /dev/null"

	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" = "true" ]; then
		return 1
	fi

	# wait for stop for a while
	C_PROCESS_PID_SAVE=$C_PROCESS_PID
	local KWAIT=0
	local F_WAITTIME=60
	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo "`date` $P_HOSTLOGIN: wait for stop server..."
	fi

	local F_WAIT_DATE1=`date '+%s'`
	local F_WAIT_DATE2
	while [ "$KWAIT" -lt $F_WAITTIME ]; do
		# check stopped
		f_process_pid $P_DC $P_PROGRAMNAME $P_HOSTLOGIN
		if [ "$C_PROCESS_PID" = "" ]; then
			echo "`date` $P_HOSTLOGIN: server successfully stopped (pid=$C_PROCESS_PID_SAVE)"
			return 0
		fi

        	sleep 1
		F_WAIT_DATE2=`date '+%s'`
        	KWAIT=$(expr $F_WAIT_DATE2 - $F_WAIT_DATE1)
	done
	
	# enforced stop
	echo "`date` $P_HOSTLOGIN: failed to stop server within $F_WAITTIME seconds. killing..."
	f_deploy_execute $P_DC $P_PROGRAMNAME $P_HOSTLOGIN "kill -9 $C_PROCESS_PID"
	return 0
}

function f_deploy_stop_service() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_SERVICENAME=$3
	local P_HOSTLOGIN=$4

	# check status
	f_process_service_status $P_DC $P_PROGRAMNAME $P_HOSTLOGIN $P_SERVICENAME

	if [ "$C_PROCESS_STATUS" = "STOPPED" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo "$P_HOSTLOGIN: $P_SERVICENAME already stopped"
		fi
		return 1
	fi

	if [ "$C_PROCESS_STATUS" != "STARTED" ]; then
		echo "$P_HOSTLOGIN: $P_SERVICENAME is in unexpected state. Exiting"
		exit 1
	fi

	f_deploy_execute $P_DC $P_PROGRAMNAME $P_HOSTLOGIN "/sbin/service $P_SERVICENAME stop > /dev/null 2>&1"

	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" = "true" ]; then
		return 1
	fi

	# wait for stop for a while
	C_PROCESS_PID_SAVE=$C_PROCESS_PID
	local KWAIT=0
	local F_WAITTIME=60
	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo "`date` $P_HOSTLOGIN: wait for stop $P_SERVICENAME..."
	fi

	local F_WAIT_DATE1=`date '+%s'`
	local F_WAIT_DATE2
	while [ "$KWAIT" -lt $F_WAITTIME ]; do
		# check stopped
		f_process_service_status $P_DC $P_PROGRAMNAME $P_HOSTLOGIN $P_SERVICENAME
		if [ "$C_PROCESS_STATUS" = "STOPPED" ]; then
			echo "$P_HOSTLOGIN: $P_SERVICENAME successfully stopped"
			return 0
		fi

        	sleep 1
		F_WAIT_DATE2=`date '+%s'`
        	KWAIT=$(expr $F_WAIT_DATE2 - $F_WAIT_DATE1)
	done

	echo "$P_HOSTLOGIN: failed to stop service $P_SERVICENAME within $F_WAITTIME seconds. Exiting"
	exit 1
}

# start process
function f_deploy_start_generic() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN=$3
	local P_FULLBINPATH=$4

	# check already started
	f_process_generic_started_status $P_DC $P_PROGRAMNAME generic $P_HOSTLOGIN $P_FULLBINPATH
	if [ "$C_PROCESS_STATUS" = "STARTED" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo "$P_HOSTLOGIN: server already started (pid=$C_PROCESS_PID)"
		fi
		return 1
	fi

	if [ "$C_PROCESS_STATUS" != "STOPPED" ]; then
		echo "$P_HOSTLOGIN: unexpected - server in progress of startup (pid=$C_PROCESS_PID). Exiting"
		exit 1
	fi

	# proceed with startup
	f_deploy_execute $P_DC $P_PROGRAMNAME $P_HOSTLOGIN "cd $P_FULLBINPATH; ./server.start.sh $P_PROGRAMNAME"
	return 0
}

function f_deploy_start_service() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_SERVICENAME=$3
	local P_HOSTLOGIN=$4

	# check already started
	f_process_service_status $P_DC $P_PROGRAMNAME $P_HOSTLOGIN $P_SERVICENAME
	if [ "$C_PROCESS_STATUS" = "STARTED" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo "$P_HOSTLOGIN: server already started"
		fi
		return 1
	fi

	if [ "$C_PROCESS_STATUS" != "STOPPED" ]; then
		echo "$P_HOSTLOGIN: unexpected - server in progress of startup. Exiting"
		exit 1
	fi

	# proceed with startup
	f_deploy_execute $P_DC $P_PROGRAMNAME $P_HOSTLOGIN "/sbin/service $P_SERVICENAME start > /dev/null 2>&1"
	return 0
}

# hot upload
function f_deploy_upload_server() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN=$3
	local P_NODE=$4
	local P_ROOTDIR=$5
	local P_BINPATH=$6
	local P_SRCVERSIONDIR=$7
	local P_HOTUPLOADPATH="$8"
	local P_HOTDEPLOYSCRIPT="$9"
	local P_HOTDEPLOYDATA="${10}"

	if [ "$C_ENV_ID" = "" ] || [ "$P_DC" = "" ] || [ "$P_PROGRAMNAME" = "" ] || [ "$P_HOSTLOGIN" = "" ] || [ "$P_NODE" = "" ]; then
		echo "f_deploy_upload_server: invalid parameters. Exiting"
		exit 1
	fi
	if [ "$P_ROOTDIR" = "" ] || [ "$P_BINPATH" = "" ] || [ "$P_HOTUPLOADPATH" = "" ] || [ "$P_SRCVERSIONDIR" = "" ]; then
		echo "f_deploy_upload_server: invalid parameters. Exiting"
		exit 1
	fi

	local F_SCRIPTNAME="server.upload.sh"
	if [ "$P_HOTDEPLOYSCRIPT" != "" ]; then
		F_SCRIPTNAME=$P_HOTDEPLOYSCRIPT
	fi

	local F_RUNTIMEBINDIR
	if [ "$P_HOSTLOGIN" = "local" ]; then
		F_RUNTIMEBINDIR=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/custom
		if [ ! -f $F_RUNTIMEBINDIR/$F_SCRIPTNAME ]; then
			echo "f_deploy_upload_server: missing custom script $F_RUNTIMEBINDIR/$F_SCRIPTNAME. Exiting"
			exit 1
		fi
	else
		f_getpath_runtimelocation $P_PROGRAMNAME $P_ROOTDIR $P_BINPATH
		F_RUNTIMEBINDIR=$C_COMMON_DIRPATH
	fi

	f_getpath_runtimelocation $P_PROGRAMNAME $P_ROOTDIR $P_HOTUPLOADPATH
	local F_RUNTIMEUPLOADDIR=$C_COMMON_DIRPATH

	# proceed with upload
	f_deploy_execute $P_DC $P_PROGRAMNAME $P_HOSTLOGIN "cd $F_RUNTIMEBINDIR; ./$F_SCRIPTNAME $F_RUNTIMEUPLOADDIR $P_SRCVERSIONDIR $C_ENV_ID $P_DC $P_PROGRAMNAME $P_NODE $P_HOTDEPLOYDATA"
	return 0
}

function f_deploy_hotupload_clear() {
	local P_DC=$1
	local P_PROGRAMNAME=$2
	local P_HOSTLOGIN=$3
	local P_ROOTDIR=$4
	local P_HOTUPLOADPATH=$5

	if [ "$P_DC" = "" ] || [ "$P_PROGRAMNAME" = "" ] || [ "$P_HOSTLOGIN" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_HOTUPLOADPATH" = "" ]; then
		echo f_redist_hotupload_clear: invalid call. Exiting
		exit 1
	fi

	f_getpath_runtimelocation $P_PROGRAMNAME $P_ROOTDIR $P_HOTUPLOADPATH
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	f_deploy_execute $P_DC $P_PROGRAMNAME $P_HOSTLOGIN "mkdir -p $F_RUNTIMEDIR; rm -rf $F_RUNTIMEDIR/*"
}
