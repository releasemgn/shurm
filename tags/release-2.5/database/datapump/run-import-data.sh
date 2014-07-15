#!/bin/bash

P_ENV=$1
P_DB=$2
P_DBCONN="$3"
P_LOGDIR=$4
P_SINGLE_SCHEMA=$5
P_TABLEDATA_ONLY=$6

if [ "$P_LOGDIR" = "" ]; then
	echo "run-import-data.sh: invalid call. Exiting."
	exit 1
fi

echo "execute run-import-data.sh: P_ENV=$P_ENV, P_DB=$P_DB, P_DBCONN=$P_DBCONN, P_LOGDIR=$P_LOGDIR, P_SINGLE_SCHEMA=$P_SINGLE_SCHEMA, P_TABLEDATA_ONLY=$P_TABLEDATA_ONLY ..."

# load common and env params
. ./common.sh

S_SCHEMALIST=
S_REMOTE_HOSTLOGIN=
S_REMOTE_ROOT=
S_DATADIR=
S_LOGDIR=
S_SINGLE_SCHEMA=

function f_execute_copycorefiles() {
	# copy all required files, except dumps
	echo copy files to remote DB...
	scp datapump-config.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp common.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp import_helper.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT

	if [ "$C_ENV_CONFIG_TABLESET" != "" ]; then
		scp $C_CONFIG_PREPAREDATA_SQLFILE $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
		scp $C_CONFIG_TRUNCATEDATA_SQLFILE $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
		scp $C_CONFIG_FINISHDATA_SQLFILE $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	fi

	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "chmod 777 *.sh"
}

function f_wait_finishimportdata() {
	echo waiting for finish load process ...
	sleep 5
	while [ "1" = "1" ]; do
		F_STATUS=`ssh $S_REMOTE_HOSTLOGIN "cat $S_REMOTE_ROOT/import.status.log | grep FINISHED"`
		if [ "$F_STATUS" != "" ]; then
			echo load process successfully finished
			return 0
		fi

		sleep 10
	done
}

function f_execute_preparedata() {
	# prepare data for import
	echo prepare data...
	local F_SCHEMAONE
	if [ "$S_SINGLE_SCHEMA" = "" ]; then
		F_SCHEMAONE=
	else
		F_SCHEMAONE=$S_SINGLE_SCHEMA
	fi

	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "./import_helper.sh $P_ENV $P_DB $P_DBCONN preparedata $F_SCHEMAONE"
	scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_CONFIG_CREATEDATA_SQLFILE.out $S_LOGDIR
	scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_CONFIG_PREPAREDATA_SQLFILE.out $S_LOGDIR
	scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_CONFIG_TRUNCATEDATA_SQLFILE.out $S_LOGDIR
}

function f_execute_finishdata() {
	# prepare data for import
	local F_SCHEMAONE
	echo finish data...
	if [ "$S_SINGLE_SCHEMA" = "" ]; then
		F_SCHEMAONE=
	else
		F_SCHEMAONE=$S_SINGLE_SCHEMA
	fi

	# finish data
	echo restore indexes and constraints in database ...
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "./import_helper.sh $P_ENV $P_DB $P_DBCONN finishdata $F_SCHEMAONE"
	scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_CONFIG_FINISHDATA_SQLFILE.out $S_LOGDIR/$C_CONFIG_FINISHDATA_SQLFILE.out
}

function f_execute_importdata_schema() {
	local P_LOADMODE=$1
	local P_SCHEMA=$2

	echo execute import mode=$P_LOADMODE
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "/usr/bin/nohup ./import_helper.sh $P_ENV $P_DB $P_DBCONN $P_LOADMODE $P_SCHEMA > import.log 2>&1&"

	# wait import to finish
	f_wait_finishimportdata

	# get logs
	scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$S_LOAD_ORACLEDIR/$P_SCHEMA.log $S_LOGDIR/$P_SCHEMA.impdp.log
	if [ "$?" = "0" ]; then
		echo "schema $P_SCHEMA - import finished."
	else
		echo "schema $P_SCHEMA - cannot get import log"
	fi

	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "rm -rf $S_LOAD_ORACLEDIR/$P_SCHEMA.log"
}

function f_execute_importdump() {
	local P_LOADMODE=$1
	local P_DUMP=$2

	# check dump
	if [ ! -f "$S_DATADIR/$P_DUMP" ]; then
		echo schema dump file $S_DATADIR/$P_DUMP not found. Skipped.
		return 1
	fi

	# copy dumps
	echo copy data...
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "rm -rf import.status.log"
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "rm -rf $S_LOAD_ORACLEDIR/$P_DUMP $S_LOAD_ORACLEDIR/$P_SCHEMA.log"

	scp $S_DATADIR/$P_DUMP $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$S_LOAD_ORACLEDIR

	f_common_getdumpschemas $P_DUMP "$S_SCHEMALIST"
	local F_SCHEMASET="$C_DUMP_SCHEMALIST"

	for schema in $F_SCHEMASET; do
		f_execute_importdata_schema $P_LOADMODE $schema
	done

	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "rm -rf $S_LOAD_ORACLEDIR/$P_DUMP"
}

function f_execute_importdata() {
	# execute import async
	local F_LOADMODE=importdatafull
	if [ "$P_TABLEDATA_ONLY" = "tabledata" ]; then
		F_LOADMODE=importdatatables
	fi

	# remove old dumps and logs
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "rm -rf $S_LOAD_ORACLEDIR/*.dmp $S_LOAD_ORACLEDIR/*.log"

	# get dumps
	f_common_getdumplist "$S_SCHEMALIST"
	local F_DUMPS="$C_DUMP_LIST"

	# execute by dump groups
	local F_SCHEMASET
	for dump in $F_DUMPS; do
		f_execute_importdump $F_LOADMODE $dump
	done
}

function f_execute_all() {
	S_CONNECTION=`echo $C_ENV_CONFIG_CONNECTION | tr " " "\n" | grep "$P_DBCONN=" | cut -d "=" -f2`
	S_LOAD_ORACLEDIR=`echo $C_ENV_CONFIG_LOADDIR | tr " " "\n" | grep "$P_DBCONN=" | cut -d "=" -f2`
	S_REMOTE_HOSTLOGIN=$C_ENV_CONFIG_REMOTE_HOSTLOGIN
	S_REMOTE_ROOT=$C_ENV_CONFIG_REMOTE_ROOT
	S_DATADIR=`echo $C_ENV_CONFIG_LOCAL_DATADIR | tr " " "\n" | grep "$P_DBCONN=" | cut -d "=" -f2`
	S_SINGLE_SCHEMA=$P_SINGLE_SCHEMA
	S_LOGDIR=$P_LOGDIR

	mkdir -p $S_LOGDIR

	f_execute_cmdres $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "if [ -d $S_REMOTE_ROOT ]; then date > laststartdate.txt; echo ok; fi"
	if [ "$S_RUNCMDRES" != "ok" ]; then
		echo unable to access remote root - $S_REMOTE_ROOT. Exiting
		exit 1
	fi

	# defines schemas
	if [ "$S_SINGLE_SCHEMA" != "" ]; then
		if [[ ! " $C_ENV_CONFIG_FULLSCHEMALIST " =~ " $S_SINGLE_SCHEMA " ]]; then
			echo invalid schema=$S_SINGLE_SCHEMA, expected one of $C_ENV_CONFIG_FULLSCHEMALIST. Exiting
			exit 1
		fi

		echo use single schema=$S_SINGLE_SCHEMA
		S_SCHEMALIST=$S_SINGLE_SCHEMA
	else
		S_SCHEMALIST=$C_ENV_CONFIG_FULLSCHEMALIST
	fi

	# execute
	f_execute_copycorefiles

	f_execute_createinitial $P_DBCONN $S_CONNECTION

	if [ "$C_ENV_CONFIG_TABLESET" != "" ]; then
		if [ "$P_TABLEDATA_ONLY" = "" ]; then
			f_execute_preparedata
		fi
	fi

	f_execute_importdata

	if [ "$C_ENV_CONFIG_TABLESET" != "" ]; then
		if [ "$P_TABLEDATA_ONLY" = "" ]; then
			f_execute_finishdata
		fi
	fi
}

f_execute_all

echo run-import-data.sh: successfully finished.
