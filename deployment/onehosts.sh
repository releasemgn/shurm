#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

P_EXECUTE_CMD=$1
P_EXECUTE_HOSTLOGIN=$2
P_EXECUTE_HOSTNAME=$3
P_EXECUTE_HOSTADDR=$4

if [ "$P_EXECUTE_CMD" = "" ]; then
	echo P_EXECUTE_CMD not set. Exiting
	exit 1
fi
if [ "$P_EXECUTE_HOSTLOGIN" = "" ]; then
	echo P_EXECUTE_HOSTLOGIN not set. Exiting
	exit 1
fi
if [ "$P_EXECUTE_HOSTNAME" = "" ]; then
	echo P_EXECUTE_HOSTNAME not set. Exiting
	exit 1
fi

. ./common.sh

function f_local_execute_log() {
	if [ "$GETOPT_EXECUTE" != "yes" ]; then
		echo "$P_EXECUTE_HOSTLOGIN: $P_EXECUTE_CMD $P_EXECUTE_HOSTNAME $P_EXECUTE_HOSTADDR (showonly)"
		return 0
	fi

	echo "$P_EXECUTE_HOSTLOGIN: $P_EXECUTE_CMD $P_EXECUTE_HOSTNAME $P_EXECUTE_HOSTADDR (execute) ..."

	local F_LOGCMD="echo `date` \"(SSH_CLIENT=$SSH_CLIENT): $P_EXECUTE_CMD $P_EXECUTE_HOSTNAME $P_EXECUTE_HOSTADDR\" >> ~/execute.log"
	f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "$F_LOGCMD"
}

function f_local_execute_set() {
	if [ "$P_EXECUTE_HOSTADDR" = "" ]; then
		echo P_EXECUTE_HOSTADDR not set. Exiting
		exit 1
	fi

	f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "cat /etc/hosts | grep -v $P_EXECUTE_HOSTNAME | grep -v $P_EXECUTE_HOSTADDR > /etc/hosts.new; echo \"$P_EXECUTE_HOSTADDR $P_EXECUTE_HOSTNAME\" >> /etc/hosts.new; mv /etc/hosts.new /etc/hosts"
}

function f_local_execute_delete() {
	if [ "$P_EXECUTE_HOSTADDR" != "" ]; then
		f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "cat /etc/hosts | grep -v $P_EXECUTE_HOSTNAME | grep -v $P_EXECUTE_HOSTADDR > /etc/hosts.new; mv /etc/hosts.new /etc/hosts"
	else
		f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "cat /etc/hosts | grep -v $P_EXECUTE_HOSTNAME > /etc/hosts.new; mv /etc/hosts.new /etc/hosts"
	fi
}

function f_local_execute_check() {
	if [ "$P_EXECUTE_HOSTADDR" = "" ]; then
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

	else
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
	fi
}

function f_local_execute() {
	if [ "$P_EXECUTE_CMD" = "set" ] || [ "$P_EXECUTE_CMD" = "delete" ]; then
		f_local_execute_log
	fi

	if [ "$P_EXECUTE_CMD" = "set" ]; then
		f_local_execute_set
	elif [ "$P_EXECUTE_CMD" = "delete" ]; then
		f_local_execute_delete
	elif [ "$P_EXECUTE_CMD" = "check" ]; then
		f_local_execute_check
	fi
}

f_local_execute
