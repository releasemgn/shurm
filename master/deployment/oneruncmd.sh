#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

P_EXECUTE_SRVNAME=$1
P_NODE=$2
P_EXECUTE_HOSTLOGIN=$3
P_RUNCMD_CMD="$4"

. ./common.sh

function f_local_execute() {
	if [ "$GETOPT_EXECUTE" = "yes" ]; then
		echo "$P_EXECUTE_HOSTLOGIN: $P_RUNCMD_CMD"

		local F_LOGCMD="echo `date` \"(SSH_CLIENT=$SSH_CLIENT): $P_RUNCMD_CMD\" >> ~/execute.log"
		f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "$F_LOGCMD"
		f_run_cmdout $P_EXECUTE_HOSTLOGIN "$P_RUNCMD_CMD"
		echo "$RUN_CMD_RES"
	else
		echo "$P_EXECUTE_HOSTLOGIN: $P_RUNCMD_CMD (showonly)"
	fi
}

f_local_execute
