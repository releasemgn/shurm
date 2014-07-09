#!/bin/bash

P_ENV=$1
P_DB=$2
P_LOGDIR=$3
P_DBCONN=$4
P_SCHEMA_SRC=$5
P_SCHEMA_DST=$6

if [ "$P_LOGDIR" = "" ]; then
	echo "run-import-data.sh: invalid call. Exiting."
	exit 1
fi

echo "execute run-copy-schema.sh: P_ENV=$P_ENV, P_DB=$P_DB, P_LOGDIR=$P_LOGDIR, P_SCHEMA_SRC=$P_SCHEMA_SRC, P_SCHEMA_DST=$P_SCHEMA_DST ..."

# load common and env params
. ./common.sh

S_REMOTE_HOSTLOGIN=
S_REMOTE_ROOT=
S_LOGDIR=

function f_execute_copycorefiles() {
	# copy all required files, except dumps
	echo copy files to remote DB...
	scp datapump-config.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp common.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp import_helper.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT

	f_execute_cmd "chmod 777 *.sh"
}

function f_execute_wait() {
	local P_CMDWAIT=$1

	echo waiting $P_CMDWAIT ...
	sleep 5
	while [ "1" = "1" ]; do
		f_execute_cmdres "pgrep -f $P_CMDWAIT | tr \" \" \"\n\" | grep -v \$\$"
		if [ "$S_RUNCMDRES" = "" ]; then
			return 0
		fi
		echo S_RUNCMDRES=@$S_RUNCMDRES@
		sleep 10
	done
}

function f_execute_copydata() {
	# export
	echo execute export source schema
	f_execute_cmd "/usr/bin/nohup ./import_helper.sh $P_ENV $P_DB $P_DBCONN exportdatasimple $P_SCHEMA_SRC > export.log 2>&1&"
	f_execute_wait exportdatasimple

	# import
	echo execute import target schema
	f_execute_cmd "/usr/bin/nohup ./import_helper.sh $P_ENV $P_DB $P_DBCONN importdatasimple $P_SCHEMA_DST $P_SCHEMA_SRC > import.log 2>&1&"
	f_execute_wait importdatasimple
}

function f_execute_all() {
	S_REMOTE_HOSTLOGIN=$C_ENV_CONFIG_REMOTE_HOSTLOGIN
	S_REMOTE_ROOT=$C_ENV_CONFIG_REMOTE_ROOT
	S_LOGDIR=$P_LOGDIR

	mkdir -p $S_LOGDIR

	f_execute_copycorefiles
	f_execute_copydata
}

f_execute_all

echo run-import-data.sh: successfully finished.
