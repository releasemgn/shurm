#!/bin/bash

if [ -f ~/.bash_profile ]; then
	. ~/.bash_profile
fi

if [ -f ~/.profile ]; then
	. ~/.profile
fi

. ./datapump-config.sh

S_FINAL_SCHEMA=
S_FINAL_SCHEMALIST=
S_RUNCMDRES=

C_DUMP_NAME=
C_DUMP_LIST=
C_DUMP_SCHEMALIST=

function f_execute_cmd() {
	local P_REMOTE_HOSTLOGIN=$1
	local P_REMOTE_ROOT=$2
	local P_CMD="$3"

	echo "$P_REMOTE_HOSTLOGIN: execute $P_CMD in $P_REMOTE_ROOT ..."
	ssh $P_REMOTE_HOSTLOGIN "cd $P_REMOTE_ROOT; $P_CMD"
}

function f_execute_cmdres() {
	local P_REMOTE_HOSTLOGIN=$1
	local P_REMOTE_ROOT=$2
	local P_CMD="$3"

	S_RUNCMDRES=`ssh $P_REMOTE_HOSTLOGIN "cd $P_REMOTE_ROOT; $P_CMD"`
}

function f_get_finalschema() {
	local P_SCHEMA=$1

	if [ "$C_ENV_CONFIG_SCHMAPPING" = "" ]; then
		echo mapping C_ENV_CONFIG_SCHMAPPING is not found in configuration. Exiting
		exit 1
	fi

	S_FINAL_SCHEMA=`echo $C_ENV_CONFIG_SCHMAPPING | tr " " "\n" | grep "$P_SCHEMA=" | cut -d "=" -f2`
	if [ "$S_FINAL_SCHEMA" = "" ]; then
		echo schema $P_SCHEMA is not mapped. Exiting
		exit 1
	fi
}

function f_get_finalschemalist() {
	local P_SCHEMALIST=$1

	S_FINAL_SCHEMALIST=
	local schema
	for schema in $P_SCHEMALIST; do
		f_get_finalschema $schema
		S_FINAL_SCHEMALIST="$S_FINAL_SCHEMALIST $S_FINAL_SCHEMA"
	done
}

function f_expdp() {
	local P_LOADCONNECTION=$1
	local P_PARAMS="$2"

	local F_STATUS=
	if [[ "$P_LOADCONNECTION" =~ "sys/" ]] || [ "$P_LOADCONNECTION" = "/" ]; then
		echo execute expdp \"$P_LOADCONNECTION as sysdba\" $P_PARAMS ...
		expdp \"$P_LOADCONNECTION as sysdba\" $P_PARAMS
		F_STATUS="$?"
	else
		echo execute expdp $P_LOADCONNECTION $P_PARAMS ...
		expdp $P_LOADCONNECTION $P_PARAMS
		F_STATUS="$?"
	fi

	if [ "$F_STATUS" != "0" ]; then
		echo expdp failed. Exiting
		exit 1
	fi
}

function f_impdp() {
	local P_LOADCONNECTION=$1
	local P_PARAMS="$2"
	local P_IGNOREERRORS="$3"

	if [[ "$P_LOADCONNECTION" =~ "sys/" ]] || [ "$P_LOADCONNECTION" = "/" ]; then
		echo execute impdp \"$P_LOADCONNECTION as sysdba\" $P_PARAMS ...
		impdp \"$P_LOADCONNECTION as sysdba\" $P_PARAMS
		F_STATUS="$?"
	else
		echo execute impdp $P_LOADCONNECTION $P_PARAMS ...
		impdp $P_LOADCONNECTION $P_PARAMS
		F_STATUS="$?"
	fi

	if [ "$F_STATUS" != "0" ]; then
		if [ "$P_IGNOREERRORS" = "" ]; then
			echo impdp failed. Exiting
			exit 1
		else
			echo impdp failed. Ignored.
			return 0
		fi
	fi
}

function f_sqlexec() {
	local P_CONNECTION=$1
	local P_SCRIPT_RUN=$2
	local P_SCRIPT_OUT=$3

	if [[ "$P_CONNECTION" =~ "sys/" ]] || [ "$P_CONNECTION" = "/" ]; then
		sqlplus $P_CONNECTION "as sysdba" < $P_SCRIPT_RUN > $P_SCRIPT_OUT
	else
		sqlplus $P_CONNECTION < $P_SCRIPT_RUN > $P_SCRIPT_OUT
	fi
}

function f_remote_sqlexec() {
	local P_CONNECTION=$1
	local P_SCRIPT_RUN=$2
	local P_SCRIPT_OUT=$3

	scp $P_SCRIPT_RUN $C_ENV_CONFIG_REMOTE_HOSTLOGIN:$C_ENV_CONFIG_REMOTE_ROOT

	if [[ "$P_CONNECTION" =~ "sys/" ]] || [ "$P_CONNECTION" = "/" ]; then
		ssh $C_ENV_CONFIG_REMOTE_HOSTLOGIN "cd $C_ENV_CONFIG_REMOTE_ROOT; rm -rf $P_SCRIPT_OUT; . $C_ENV_CONFIG_REMOTE_SETORAENV $C_ENV_CONFIG_ENV $C_ENV_CONFIG_DB; sqlplus $P_CONNECTION "as sysdba" < $P_SCRIPT_RUN > $P_SCRIPT_OUT 2>&1"
	else
		ssh $C_ENV_CONFIG_REMOTE_HOSTLOGIN "cd $C_ENV_CONFIG_REMOTE_ROOT; rm -rf $P_SCRIPT_OUT; . $C_ENV_CONFIG_REMOTE_SETORAENV $C_ENV_CONFIG_ENV $C_ENV_CONFIG_DB; sqlplus $P_CONNECTION < $P_SCRIPT_RUN > $P_SCRIPT_OUT 2>&1"
	fi

	scp $C_ENV_CONFIG_REMOTE_HOSTLOGIN:$C_ENV_CONFIG_REMOTE_ROOT/$P_SCRIPT_OUT $P_SCRIPT_OUT
}

function f_execute_fillinitial() {
	local P_DBC=$1

	# execute data - initial setup
	echo create initial setup...

	echo "-- prepare" > $C_CONFIG_CREATEDATA_SQLFILE

	# dynamic oracle dir
	if [ "$C_ENV_CONFIG_DATAPUMP_DIR" = "ORACLE_DYNAMICDATADIR" ]; then
		local F_LOADDIR=`echo $C_ENV_CONFIG_LOADDIR | tr " " "\n" | grep "$P_DBC=" | cut -d "=" -f2`
		echo "-- create export dir" >> $C_CONFIG_CREATEDATA_SQLFILE
		echo "create or replace directory ORACLE_DYNAMICDATADIR as '$C_ENV_CONFIG_REMOTE_ROOT/$F_LOADDIR';" >> $C_CONFIG_CREATEDATA_SQLFILE
	fi

	if [ "$C_ENV_CONFIG_TABLESET" = "" ]; then
		return 0
	fi

	echo "-- setup table with uat table data" >> $C_CONFIG_CREATEDATA_SQLFILE
	echo "drop table $C_ENV_CONFIG_TABLESET;" >> $C_CONFIG_CREATEDATA_SQLFILE
	echo "create table $C_ENV_CONFIG_TABLESET ( tschema varchar2(128) , rschema varchar2(128), tname varchar2(128) , status char(1) );" >> $C_CONFIG_CREATEDATA_SQLFILE

	local line
	local pschema
	local status
	local table
	local tschema_upper
	local rschema_upper
	local table_upper

	cat $C_CONFIG_TABLE_FILE | while read line; do
		line=`echo $line | sed "s/\r//;s/\n//"`
		pschema=${line%%/*}
		if [[ "$pschema" =~ "#" ]]; then
			schema=${pschema#\#}
			status="M"
		else
			schema=$pschema
			status="S"
		fi

		# only if schema in full schema list
		tschema_lower=`echo $schema | tr '[A-Z]' '[a-z]'`
		tschema_upper=`echo $tschema_lower | tr '[a-z]' '[A-Z]'`
		if [[ " $C_ENV_CONFIG_FULLSCHEMALIST " =~  " $tschema_lower " ]]; then
			table="${line#*/TABLE/}"

			# make insertion
			table_upper=`echo "$table" | tr '[a-z]' '[A-Z]'`
			f_get_finalschema $tschema_lower
			rschema_lower=$S_FINAL_SCHEMA
			rschema_upper=`echo $rschema_lower | tr '[a-z]' '[A-Z]'`

			echo "insert into $C_ENV_CONFIG_TABLESET ( tschema , rschema , tname , status ) values ( '$tschema_upper' , '$rschema_upper' , '$table_upper' , '$status' );" >> $C_CONFIG_CREATEDATA_SQLFILE
		fi
	done

	echo "commit; " >> $C_CONFIG_CREATEDATA_SQLFILE
	echo "exit" >> $C_CONFIG_CREATEDATA_SQLFILE
}

function f_execute_createinitial() {
	local P_DBCONN=$1
	local P_CONNECTION=$2

	# execute data - create UAT table with table list
	f_execute_fillinitial $P_DBCONN

	# execute generated file
	f_remote_sqlexec $P_CONNECTION $C_CONFIG_CREATEDATA_SQLFILE $C_CONFIG_CREATEDATA_SQLFILE.out
}

function f_common_getschemadump() {
	local P_SCHEMA=$1

	# check defined in dump map
	if [ "$C_ENV_CONFIG_IMPORT_DUMPGROUPS" != "" ]; then
		C_DUMP_NAME=`echo $C_ENV_CONFIG_IMPORT_DUMPGROUPS | tr ";," "\n " | sed "s/:/: /;s/$/ /" | grep " $P_SCHEMA " | cut -d ":" -f1 | tr -d " "`
		if [ "$C_DUMP_NAME" != "" ]; then
			return 0
		fi
	fi

	# default naming
	if [ "$P_SCHEMA" = "role" ]; then
		C_DUMP_NAME=role.dmp
	elif [ "$P_SCHEMA" = "meta" ]; then
		C_DUMP_NAME=meta.dmp
	else
		C_DUMP_NAME=$P_SCHEMA.dmp
	fi
}

function f_common_getdumplist() {
	local P_SCHEMASET="$1"

	if [ "$P_SCHEMASET" = "" ]; then
		C_DUMP_LIST=`echo $C_ENV_CONFIG_IMPORT_DUMPGROUPS | tr -d " " | tr ";" "\n" | cut -d ":" -f1 | tr "\n" " "`
		C_DUMP_LIST=${C_DUMP_LIST% }
		return 0
	fi

	C_DUMP_LIST=
	for schema in $P_SCHEMASET; do
		f_common_getschemadump $schema
		if [[ ! " $C_DUMP_LIST " =~ " $C_DUMP_NAME " ]]; then
			C_DUMP_LIST="$C_DUMP_LIST $C_DUMP_NAME"
		fi
	done

	C_DUMP_LIST=${C_DUMP_LIST# }
}

function f_common_getdumpschemas() {
	local P_DUMP=$1
	local P_SCHEMASET="$2"

	C_DUMP_SCHEMALIST=
	if [ "$P_SCHEMASET" = "" ]; then
		C_DUMP_SCHEMALIST=`echo $C_ENV_CONFIG_IMPORT_DUMPGROUPS | tr -d " " | tr ";," "\n " | grep "$P_DUMP:" | cut -d ":" -f2 | tr -d "\n"`
		return 0
	fi

	for schema in $P_SCHEMASET; do
		f_common_getschemadump $schema
		if [ "$P_DUMP" = "$C_DUMP_NAME" ]; then
			C_DUMP_SCHEMALIST="$C_DUMP_SCHEMALIST $schema"
		fi
	done

	C_DUMP_SCHEMALIST=${C_DUMP_SCHEMALIST# }
}

S_CMDRES=
function f_common_datadir() {
	P_CMD="$1"

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo "execute $P_CMD ..."
	fi

	if [ "$C_ENV_CONFIG_DATADIR_HOSTLOGIN" != "" ]; then
		S_CMDRES=`ssh $C_ENV_CONFIG_DATADIR_HOSTLOGIN "$P_CMD"`
		if [ "$?" != "0" ]; then
			echo "f_common_datadir: error executing remote command $P_CMD. Exiting"
			exit 1
		fi
	else
		S_CMDRES=`eval $P_CMD`
		if [ "$?" != "0" ]; then
			echo "f_common_datadir: error executing local command $P_CMD. Exiting"
			exit 1
		fi
	fi
	echo $S_CMDRES
}

function f_common_scp2data() {
	P_SRC=$1
	P_DSTPATH=$2

	if [ "$C_ENV_CONFIG_DATADIR_HOSTLOGIN" != "" ]; then
		rm -rf local.file
		scp $P_SRC local.file
		scp local.file $C_ENV_CONFIG_DATADIR_HOSTLOGIN:$P_DSTPATH
		rm -rf local.file
	else
		rm -rf $P_DSTPATH
		scp $P_SRC $P_DSTPATH
	fi
}

function f_common_scpXdata() {
	P_SRCPATH=$1
	P_DST=$2

	if [ "$C_ENV_CONFIG_DATADIR_HOSTLOGIN" != "" ]; then
		rm -rf local.file
		scp $C_ENV_CONFIG_DATADIR_HOSTLOGIN:$P_SRCPATH local.file
		scp local.file $P_DST
		rm -rf local.file
	else
		scp $P_SRCPATH $P_DST
	fi
}

