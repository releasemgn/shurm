#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

P_EXECUTE_CMD=$1
P_EXECUTE_HOSTLOGIN=$2
P_EXECUTE_HOSTNAME=$3
P_EXECUTE_HOSTADDR=$4

. ./common.sh

function f_local_execute() {
	if [ "$P_EXECUTE_CMD" = "set" ] || [ "$P_EXECUTE_CMD" = "delete" ]; then
		if [ "$P_EXECUTE_CMD" != "yes" ]; then
			echo "$P_EXECUTE_HOSTLOGIN: $P_RUNCMD_CMD $P_EXECUTE_HOSTNAME $P_EXECUTE_HOSTADDR (showonly)"
			return 0
		fi

		echo "$P_EXECUTE_HOSTLOGIN: $P_RUNCMD_CMD $P_EXECUTE_HOSTNAME $P_EXECUTE_HOSTADDR ..."

		local F_LOGCMD="echo `date` \"(SSH_CLIENT=$SSH_CLIENT): $P_RUNCMD_CMD $P_EXECUTE_HOSTNAME $P_EXECUTE_HOSTADDR\" >> ~/execute.log"
		f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "$F_LOGCMD"
	fi

	if [ "$P_EXECUTE_CMD" = "set" ]; then
		f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "cat /etc/hosts | grep -v $P_EXECUTE_HOSTNAME | grep -v $P_EXECUTE_HOSTADDR > /etc/hosts.new; echo \"$P_EXECUTE_HOSTADDR $P_EXECUTE_HOSTNAME\" >> /etc/hosts.new; mv /etc/hosts.new /etc/hosts"

	elif [ "$P_EXECUTE_CMD" = "delete" ]; then
		f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "cat /etc/hosts | grep -v $P_EXECUTE_HOSTNAME | grep -v $P_EXECUTE_HOSTADDR > /etc/hosts.new; mv /etc/hosts.new /etc/hosts"

	elif [ "$P_EXECUTE_CMD" = "check" ] && [ "$P_EXECUTE_HOSTADDR" = "" ]; then
		f_run_cmd $P_EXECUTE_HOSTLOGIN "cat /etc/hosts | grep $P_EXECUTE_HOSTNAME"
		if [ "$RUN_CMD_RES" = "" ]; then
			echo "$P_EXECUTE_HOSTLOGIN: missing $P_EXECUTE_HOSTNAME"
			return 0
		fi

		if [ `echo "$RUN_CMD_RES" | wc -l` != "1" ]; then
			echo "$P_EXECUTE_HOSTLOGIN: duplicate $P_EXECUTE_HOSTNAME ($RUN_CMD_RES)"
			return 1
		fi
		
		echo "$P_EXECUTE_HOSTLOGIN: $RUN_CMD_RES"
		return 0

	elif [ "$P_EXECUTE_CMD" = "check" ] && [ "$P_EXECUTE_HOSTADDR" != "" ]; then
		f_run_cmd $P_EXECUTE_HOSTLOGIN "cat /etc/hosts | egrep \"$P_EXECUTE_HOSTNAME|$P_EXECUTE_HOSTADDR\""
		if [ "$RUN_CMD_RES" = "" ]; then
			echo "$P_EXECUTE_HOSTLOGIN: missing $P_EXECUTE_HOSTNAME"
			return 0
		fi

		if [ `echo "$RUN_CMD_RES" | wc -l` != "1" ]; then
			echo "$P_EXECUTE_HOSTLOGIN: duplicate $P_EXECUTE_HOSTNAME ($RUN_CMD_RES)"
			return 1
		fi

		local F_HOSTADDR=${RUN_CMD_RES%% *}
		local F_HOSTNAME=${RUN_CMD_RES##* }

		if [ "$F_HOSTNAME" != "$P_EXECUTE_HOSTNAME" ] || [ "$F_HOSTADDR" != "$P_EXECUTE_HOSTADDR" ]; then
			echo "$P_EXECUTE_HOSTLOGIN: $RUN_CMD_RES - not matched ($P_EXECUTE_HOSTNAME $P_EXECUTE_HOSTADDR)"
			return 1
		fi

		echo "$P_EXECUTE_HOSTLOGIN: $RUN_CMD_RES - ok"
		return 0
	fi
}

f_local_execute
