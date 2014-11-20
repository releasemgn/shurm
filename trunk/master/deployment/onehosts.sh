#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

P_EXECUTE_CMD=$1
P_EXECUTE_HOSTLOGIN=$2
P_EXECUTE_HOSTNAME=$3
P_EXECUTE_HOSTADDR=$4

. ./common.sh

function f_local_execute() {
	if [ "$P_EXECUTE_CMD" != "yes" ]; then
		echo "$P_EXECUTE_HOSTLOGIN: $P_RUNCMD_CMD $P_EXECUTE_HOSTNAME $P_EXECUTE_HOSTADDR (showonly)"
		return 0
	fi

	echo "$P_EXECUTE_HOSTLOGIN: $P_RUNCMD_CMD $P_EXECUTE_HOSTNAME $P_EXECUTE_HOSTADDR ..."

	local F_LOGCMD="echo `date` \"(SSH_CLIENT=$SSH_CLIENT): $P_RUNCMD_CMD $P_EXECUTE_HOSTNAME $P_EXECUTE_HOSTADDR\" >> ~/execute.log"
	f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "$F_LOGCMD"

	if [ "$P_EXECUTE_CMD" = "set" ]; then
		f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "cat /etc/hosts | grep -v $P_EXECUTE_HOSTNAME | grep -v $P_EXECUTE_HOSTADDR > /etc/hosts.new; echo \"$P_EXECUTE_HOSTADDR $P_EXECUTE_HOSTNAME\" >> /etc/hosts.new; mv /etc/hosts.new /etc/hosts"

	elif [ "$P_EXECUTE_CMD" = "delete" ]; then
		f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "cat /etc/hosts | grep -v $P_EXECUTE_HOSTNAME | grep -v $P_EXECUTE_HOSTADDR > /etc/hosts.new; mv /etc/hosts.new /etc/hosts"
	fi
}

f_local_execute
