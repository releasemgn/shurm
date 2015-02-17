#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

P_UPGRADE_ID=$1
P_EXECUTE_HOSTLOGIN=$2

. ./common.sh

S_DATAFILE="upgrade.data"
S_LOGFILE="upgrade.log"

function f_local_before() {
	local F_ACTION="initial"

	# check upgrade status
	f_run_cmd $P_EXECUTE_HOSTLOGIN "touch ~/$S_DATAFILE; grep \"id=$P_UPGRADE_ID:\" ~/$S_DATAFILE"
	local F_STATUS=$RUN_CMD_RES

	if [ "$F_STATUS" != "" ]; then
		if [[ "$F_STATUS" =~ "$P_UPGRADE_ID:ok" ]]; then
			if [ "$GETOPT_FORCE" != "yes" ]; then
				echo "$P_EXECUTE_HOSTLOGIN: upgrade P_UPGRADE_ID=$P_UPGRADE_ID already done. Skipped"
				exit 0
			fi

			F_ACTION="reinstall"
		else
			F_ACTION="repair"
		fi

	fi	

	if [ "$GETOPT_EXECUTE" != "yes" ]; then
		echo "$P_EXECUTE_HOSTLOGIN: $F_ACTION P_UPGRADE_ID=$P_UPGRADE_ID (showonly)"
		exit 0
	fi

	# add before record to log
	local F_CMD="echo `date` \"(SSH_CLIENT=$SSH_CLIENT): start $F_ACTION upgrade P_UPGRADE_ID=$P_UPGRADE_ID\" >> ~/$S_LOGFILE"
	f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "$F_CMD"

	# add before record to data
	local F_CMD="cat ~/$S_DATAFILE | grep -v \"id=$P_UPGRADE_ID:\" > ~/$S_DATAFILE.copy; mv ~/$S_DATAFILE.copy ~/$S_DATAFILE; echo \"id=$P_UPGRADE_ID:incomlete\" >> ~/$S_DATAFILE"
	f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "$F_CMD"

	echo "$P_EXECUTE_HOSTLOGIN: $F_ACTION upgrade P_UPGRADE_ID=$P_UPGRADE_ID (execute) ..."
}

function f_local_after() {
	local P_STATUS=$1

	# add after record to log
	local F_CMD="echo `date` \"(SSH_CLIENT=$SSH_CLIENT): upgrade done P_UPGRADE_ID=$P_UPGRADE_ID\" >> ~/$S_LOGFILE"
	f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "$F_CMD"

	# replace record in data
	local F_CMD="cat ~/$S_DATAFILE | grep -v \"id=$P_UPGRADE_ID:\" > $S_DATAFILE.copy; mv ~/$S_DATAFILE.copy ~/$S_DATAFILE; echo \"id=$P_UPGRADE_ID:$P_STATUS\" >> ~/$S_DATAFILE"
	f_run_cmdcheck $P_EXECUTE_HOSTLOGIN "$F_CMD"
}

function f_local_execute() {
	# check before upgrade
	f_local_before

	# execute upgrade script
	local F_STATUS=ok
	$C_CONFIG_UPGRADEPATH/upgrade-$P_UPGRADE_ID.sh $P_EXECUTE_HOSTLOGIN
	local F_STATUS=$?

	if [ "$F_STATUS" != 0 ]; then
		# check fatal
		if [ "$F_STATUS" = "2" ]; then
			echo fatal error. Exiting
			exit 2
		fi

		F_STATUS=errors
	else
		F_STATUS=ok
	fi

	# finish status
	f_local_after $F_STATUS
}

f_local_execute

exit 0
