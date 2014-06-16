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
		if [ "$GETOPT_SKIPERRORS" = "yes" ]; then
			if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
				ssh -i $C_ENV_PROPERTY_KEYNAME -n $P_EXECUTE_HOSTLOGIN "$F_LOGCMD"
			else
				ssh -n $P_EXECUTE_HOSTLOGIN "$F_LOGCMD"
			fi
		else
			f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "$F_LOGCMD"
		fi

		if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
			ssh -i $C_ENV_PROPERTY_KEYNAME -n $P_EXECUTE_HOSTLOGIN "$P_RUNCMD_CMD"
		else
			ssh -n $P_EXECUTE_HOSTLOGIN "$P_RUNCMD_CMD"
		fi
	else
		echo "$P_EXECUTE_HOSTLOGIN: $P_RUNCMD_CMD (showonly)"
	fi
}

f_local_execute
