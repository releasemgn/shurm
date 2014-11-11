#!/bin/bash

P_ENV=$1
P_DB=$2
P_DBCONN_REMOTE=$3
P_SINGLE_SCHEMA=$4

echo "execute run-export.sh: P_ENV=$P_ENV, P_DB=$P_DB, P_DBCONN_REMOTE=$P_DBCONN_REMOTE, P_SINGLE_SCHEMA=$P_SINGLE_SCHEMA ..."

# load common and env params
. ./common.sh

S_SCHEMALIST=
S_CONNECTION=
S_REMOTE_HOSTLOGIN=
S_REMOTE_ROOT=
S_EXPORTDATA_STATUS=

S_CMDRES=
function f_execute_datadir() {
	P_CMD="$1"

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo "execute $P_CMD ..."
		exit 1
	fi

	if [ "$C_ENV_CONFIG_DATADIR_HOSTLOGIN" != "" ]; then
		S_CMDRES=`ssh $C_ENV_CONFIG_DATADIR_HOSTLOGIN "$P_CMD"`
		if [ "$?" != "0" ]; then
			echo "f_execute_datadir: error executing remote command $P_CMD. Exiting"
			exit 1
		fi
	else
		S_CMDRES=`$P_CMD`
		if [ "$?" != "0" ]; then
			echo "f_execute_datadir: error executing local command $P_CMD. Exiting"
			exit 1
		fi
	fi
	echo $S_CMDRES
}

function f_execute_scp2data() {
	P_SRC=$1
	P_DSTPATH=$2

	if [ "$C_ENV_CONFIG_DATADIR_HOSTLOGIN" != "" ]; then
		rm -rf local.file
		scp $P_SRC local.file
		scp local.file $P_DSTPATH
		rm -rf local.file
	else
		rm -rf $P_DSTPATH
		scp $P_SRC $P_DSTPATH
	fi
}

function f_execute_cleanup() {
	# check env
	f_execute_datadir "mkdir -p $C_ENV_CONFIG_DATADIR $C_ENV_CONFIG_DATADIR_BACKUP; if [ -d $C_ENV_CONFIG_DATADIR_BACKUP ] && [ -d $C_ENV_CONFIG_DATADIR ]; then echo ok; done"
	if [ "$S_CMDRES" != "ok" ]; then
		echo "unable to locate data/backup directory. Exiting"
		exit 1
	fi

	# cleanup
	echo cleanup...
	F_LOGDIR="export-log"
	mkdir -p $F_LOGDIR

	if [ "$P_SINGLE_SCHEMA" = "" ]; then
		# backup
		f_execute_datadir "rm -rf $C_ENV_CONFIG_DATADIR_BACKUP; mkdir -p $C_ENV_CONFIG_DATADIR_BACKUP; mv $C_ENV_CONFIG_DATADIR/* $C_ENV_CONFIG_DATADIR_BACKUP/"

		# clear log and staging area
		rm -rf $F_LOGDIR/*
		f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "rm -rf $C_ENV_CONFIG_STAGINGDIR; mkdir $C_ENV_CONFIG_STAGINGDIR"

	elif [ "$P_SINGLE_SCHEMA" = "meta" ]; then
		f_execute_datadir "rm -rf $C_ENV_CONFIG_DATADIR/meta.* $C_ENV_CONFIG_DATADIR/role.*"
		rm -rf $F_LOGDIR/meta.* $F_LOGDIR/role.*

	else
		f_execute_datadir "rm -rf $C_ENV_CONFIG_DATADIR/$P_SINGLE_SCHEMA.*"
		rm -rf $F_LOGDIR/$P_SINGLE_SCHEMA.*
	fi
}

function f_execute_copycorefiles() {
	# copy files
	echo copy files to remote DB...
	scp datapump-config.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp common.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp export_helper.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT

	if [ "$C_ENV_CONFIG_TABLESET" != "" ]; then
		scp $C_CONFIG_TABLE_FILE $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	fi

	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "chmod 777 $S_REMOTE_ROOT/*.sh"
}

function f_execute_exportmeta() {
	# export meta
	if [ "$P_SINGLE_SCHEMA" = "" ] || [ "$P_SINGLE_SCHEMA" = "meta" ]; then
		echo "export metadata ($S_SCHEMALIST)..."
		f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "./export_helper.sh $P_ENV $P_DB $P_DBCONN_REMOTE exportmeta $S_SCHEMALIST" > $F_LOGDIR/meta.log 2>&1

		echo "copy exported metadata to $C_ENV_CONFIG_DATADIR ..."
		f_execute_scp2data $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_ENV_CONFIG_STAGINGDIR/meta.dmp "$C_ENV_CONFIG_DATADIR/meta.dmp"
		scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_ENV_CONFIG_STAGINGDIR/meta.log $F_LOGDIR/meta.expdp.log
		f_execute_scp2data $F_LOGDIR/meta.expdp.log "$C_ENV_CONFIG_DATADIR/meta.log"

		f_execute_scp2data $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_ENV_CONFIG_STAGINGDIR/role.dmp "$C_ENV_CONFIG_DATADIR/role.dmp"
		scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_ENV_CONFIG_STAGINGDIR/role.log $F_LOGDIR/role.expdp.log
		f_execute_scp2data $F_LOGDIR/role.expdp.log "$C_ENV_CONFIG_DATADIR/role.log"
	fi
}

function f_execute_getexportdatastatus() {
	f_execute_cmdres $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "./export_helper.sh $P_ENV $P_DB $P_DBCONN_REMOTE exportdata-status"
	S_RUNCMDRES=`echo $S_RUNCMDRES | tr -d "\n"`
	if [[ "$S_RUNCMDRES" =~ "STATUS=RUNNING" ]]; then
		S_EXPORTDATA_STATUS=RUNNING

	elif [[ "$S_RUNCMDRES" =~ "STATUS=STOPPED" ]]; then
		S_EXPORTDATA_STATUS=STOPPED

	elif [[ "$S_RUNCMDRES" =~ "STATUS=FINISHED" ]]; then
		S_EXPORTDATA_STATUS=FINISHED

	else
		echo "Unexpected error while checking export data status - S_RUNCMDRES=$S_RUNCMDRES. Exiting"
		exit 1
	fi
}

function f_execute_exportdata() {
	echo "export table data - $P_DBCONN_REMOTE exportdata $S_SCHEMALIST..."

	# check current status
	f_execute_getexportdatastatus
	if [ "$S_EXPORTDATA_STATUS" = "RUNNING" ]; then
		echo "export data process is in progress, unable to start new one. Exiting"
		exit 1
	fi

	# export dumps
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "/usr/bin/nohup ./export_helper.sh $P_ENV $P_DB $P_DBCONN_REMOTE exportdata $S_SCHEMALIST > exportdata.log 2>&1 &"

	# wait to start
	sleep 5
	f_execute_getexportdatastatus
	if [ "$S_EXPORTDATA_STATUS" != "RUNNING" ] && [ "$S_EXPORTDATA_STATUS" != "FINISHED" ]; then
		echo "export data process is unable to start. Exiting"
		exit 1
	fi

	# wait export to finish
	echo export data process started, wait to finish ...
	while [ "$S_EXPORTDATA_STATUS" = "RUNNING" ]; do
		f_execute_getexportdatastatus
		sleep 10
	done

	echo "copy exported data to $C_ENV_CONFIG_DATADIR ..."
	for schema in $S_SCHEMALIST; do
		f_execute_scp2data $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_ENV_CONFIG_STAGINGDIR/$schema.dmp $C_ENV_CONFIG_DATADIR/$schema.dmp
		scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_ENV_CONFIG_STAGINGDIR/$schema.log $F_LOGDIR/$schema.expdp.log
		f_execute_scp2data $F_LOGDIR/$schema.expdp.log "$C_ENV_CONFIG_DATADIR/$schema.log"
	done
}

function f_execute_all() {
	if [ "$P_SINGLE_SCHEMA" = "" ]; then
		S_SCHEMALIST=$C_ENV_CONFIG_FULLSCHEMALIST
	else
		if [ "$P_SINGLE_SCHEMA" = "meta" ]; then
			S_SCHEMALIST=$C_ENV_CONFIG_FULLSCHEMALIST
		else
			S_SCHEMALIST=$P_SINGLE_SCHEMA
		fi
	fi

	S_CONNECTION=`echo $C_ENV_CONFIG_CONNECTION | tr " " "\n" | grep "$P_DBCONN_REMOTE=" | cut -d "=" -f2`
	S_REMOTE_HOSTLOGIN=$C_ENV_CONFIG_REMOTE_HOSTLOGIN
	S_REMOTE_ROOT=$C_ENV_CONFIG_REMOTE_ROOT

	f_execute_cleanup
	f_execute_copycorefiles
	f_execute_createinitial $P_DBCONN_REMOTE $S_CONNECTION

	f_execute_exportmeta
	
	if [ "$P_SINGLE_SCHEMA" != "meta" ]; then
		f_execute_exportdata
	fi
}

f_execute_all

echo run-export.sh: successfully finished.
