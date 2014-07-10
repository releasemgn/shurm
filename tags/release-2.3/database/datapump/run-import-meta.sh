#!/bin/bash

P_ENV=$1
P_DB=$2
P_DBCONN="$3"
P_LOGDIR=$4
P_SINGLE_SCHEMA=$5

if [ "$P_LOGDIR" = "" ]; then
	echo "run-import-meta.sh: invalid call. Exiting."
	exit 1
fi

echo "execute run-import-meta.sh: P_ENV=$P_ENV, P_DB=$P_DB, P_DBCONN=$P_DBCONN, P_LOGDIR=$P_LOGDIR, P_SINGLE_SCHEMA=$P_SINGLE_SCHEMA ..."

# load common and env params
. ./common.sh

S_SCHEMALIST=
S_LOAD_ORACLEDIR=
S_REMOTE_HOSTLOGIN=
S_REMOTE_ROOT=
S_DATADIR=
S_LOGDIR=
S_SINGLE_SCHEMA=

function f_execute_cleanup() {
	echo cleanup...
	if [ "$S_SINGLE_SCHEMA" = "" ]; then
		rm -rf $S_LOGDIR/*
		f_execute_cmd "rm -rf $S_LOAD_ORACLEDIR/*.dmp $S_LOAD_ORACLEDIR/*.log"
	else
		rm -rf $S_LOGDIR/$S_SINGLE_SCHEMA.* $S_LOGDIR/meta.* $S_LOGDIR/role.*
		f_execute_cmd "rm -rf $S_LOAD_ORACLEDIR/$S_SINGLE_SCHEMA.* $S_LOAD_ORACLEDIR/role.* $S_LOAD_ORACLEDIR/meta.*"
	fi
}

function f_execute_copycorefiles() {
	# copy all required files, except dumps
	echo copy files to remote DB...
	scp datapump-config.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp common.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp import_helper.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp $C_CONFIG_SCRIPT_DROPUSERS $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	f_execute_cmd "chmod 777 *.sh"
}

function f_execute_dropdb() {
	# database to exclusive mode, kill sessions, drop schemas
	echo prepare for import...
	f_execute_cmd "./import_helper.sh $P_ENV $P_DB $P_DBCONN dropold $S_SCHEMALIST"
	scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$C_CONFIG_SCRIPT_DROPUSERS.out $S_LOGDIR/dropusers.out
}

function f_execute_importmeta() {
	# import meta
	echo "import metadata ($S_SCHEMALIST)..."
	if [ "$S_SINGLE_SCHEMA" = "" ]; then
		F_SCHEMAONE=
	else
		F_SCHEMAONE=$S_SINGLE_SCHEMA
	fi

	scp $S_DATADIR/role.dmp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$S_LOAD_ORACLEDIR/role.dmp
	scp $S_DATADIR/meta.dmp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$S_LOAD_ORACLEDIR/meta.dmp
	f_execute_cmd "chmod 444 $S_LOAD_ORACLEDIR/role.dmp $S_LOAD_ORACLEDIR/meta.dmp"

	f_execute_cmd "./import_helper.sh $P_ENV $P_DB $P_DBCONN importmeta $F_SCHEMAONE"
	scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$S_LOAD_ORACLEDIR/role.log $S_LOGDIR/role.impdp.log
	scp $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$S_LOAD_ORACLEDIR/meta.log $S_LOGDIR/meta.impdp.log
}

function f_execute_all() {
	S_CONNECTION=`echo $C_ENV_CONFIG_CONNECTION | tr " " "\n" | grep "$P_DBCONN=" | cut -d "=" -f2`
	S_LOAD_ORACLEDIR=`echo $C_ENV_CONFIG_LOADDIR | tr " " "\n" | grep "$P_DBCONN=" | cut -d "=" -f2`
	S_REMOTE_HOSTLOGIN=$C_ENV_CONFIG_REMOTE_HOSTLOGIN
	S_REMOTE_ROOT=$C_ENV_CONFIG_REMOTE_ROOT
	S_DATADIR=`echo $C_ENV_CONFIG_LOCAL_DATADIR | tr " " "\n" | grep "$P_DBCONN=" | cut -d "=" -f2`
	S_LOGDIR=$P_LOGDIR
	S_SINGLE_SCHEMA=$P_SINGLE_SCHEMA

	mkdir -p $S_LOGDIR

	# import roles meta
	if [ ! -f "$S_DATADIR/role.dmp" ] || [ ! "$S_DATADIR/meta.dmp" ]; then
		echo role.dmp and meta.dmp are required in $S_DATADIR. Exiting.
		exit 1
	fi

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

	f_execute_cleanup
	f_execute_copycorefiles

	f_execute_createinitial $P_DBCONN $S_CONNECTION

	f_execute_dropdb
	f_execute_importmeta
}

f_execute_all

echo run-import-meta.sh: successfully finished.
