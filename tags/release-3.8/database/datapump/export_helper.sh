#!/bin/bash

P_ENV=$1
P_DB=$2
P_DBCONN="$3"
P_CMD=$4

if [ "$P_CMD" = "" ]; then
	echo P_CMD is not set. Exiting
	exit 1
fi
shift 4

P_SCHEMA_SET=$*

# load common and env params
. ./common.sh

. $C_ENV_CONFIG_REMOTE_SETORAENV $P_ENV $P_DB

S_LOADCONNECTION=
S_LOAD_ORACLEDIR=
S_LOAD_STAGINGDIR=

function f_execute_exportdata_one() {
	local P_TSCHEMA=$1

	# remove in dump space and in store
	rm -rf $S_LOAD_ORACLEDIR/$P_TSCHEMA.*
	rm -rf $S_LOAD_STAGINGDIR/$P_TSCHEMA.*

	local F_TSCHEMA_LOWER=`echo $P_TSCHEMA | tr '[A-Z]' '[a-z]'`
	local F_TSCHEMA_UPPER=`echo $F_TSCHEMA_LOWER | tr '[a-z]' '[A-Z]'`

	local F_EXPORT_ALL=yes
	if [ "$C_CONFIG_TABLE_FILE" != "" ]; then
		local F_CHECK=`grep -c "^$F_TSCHEMA_UPPER/TABLE/\\*" $C_CONFIG_TABLE_FILE`
		if [ "$F_CHECK" = "0" ]; then
			F_EXPORT_ALL=no
		fi
	fi

	if [ "$F_EXPORT_ALL" = "yes" ]; then
		# simple export
		if [[ "$S_LOADCONNECTION" =~ "sys/" ]] || [ "$S_LOADCONNECTION" = "/" ]; then
			echo "execute expdp \"$S_LOADCONNECTION as sysdba\" DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_TSCHEMA_LOWER.dmp LOGFILE=$F_TSCHEMA_LOWER.log schemas=$F_TSCHEMA_UPPER CONTENT=DATA_ONLY ..."
			expdp \"$S_LOADCONNECTION as sysdba\" DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_TSCHEMA_LOWER.dmp LOGFILE=$F_TSCHEMA_LOWER.log schemas=$F_TSCHEMA_UPPER CONTENT=DATA_ONLY
		else
			echo "execute expdp $S_LOADCONNECTION DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_TSCHEMA_LOWER.dmp LOGFILE=$F_TSCHEMA_LOWER.log schemas=$F_TSCHEMA_UPPER CONTENT=DATA_ONLY ..."
			expdp $S_LOADCONNECTION DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_TSCHEMA_LOWER.dmp LOGFILE=$F_TSCHEMA_LOWER.log schemas=$F_TSCHEMA_UPPER CONTENT=DATA_ONLY
		fi
	else
		# export using table set
		# impossible to adopt to oracle quotes and shell !
		if [[ "$S_LOADCONNECTION" =~ "sys/" ]] || [ "$S_LOADCONNECTION" = "/" ]; then
			echo "execute expdp \"$S_LOADCONNECTION as sysdba\" DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_TSCHEMA_LOWER.dmp LOGFILE=$F_TSCHEMA_LOWER.log schemas=$F_TSCHEMA_UPPER CONTENT=DATA_ONLY include=TABLE:\"IN \(select tname from $C_ENV_CONFIG_TABLESET where status = \'S\' and tschema = \'$F_TSCHEMA_UPPER\'\)\" ..."
			expdp \"$S_LOADCONNECTION as sysdba\" DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_TSCHEMA_LOWER.dmp LOGFILE=$F_TSCHEMA_LOWER.log schemas=$F_TSCHEMA_UPPER CONTENT=DATA_ONLY include=TABLE:\"IN \(select tname from $C_ENV_CONFIG_TABLESET where status = \'S\' and tschema = \'$F_TSCHEMA_UPPER\'\)\"
		else
			echo "execute expdp $S_LOADCONNECTION DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_TSCHEMA_LOWER.dmp LOGFILE=$F_TSCHEMA_LOWER.log schemas=$F_TSCHEMA_UPPER CONTENT=DATA_ONLY include=TABLE:\"IN \(select tname from $C_ENV_CONFIG_TABLESET where status = \'S\' and tschema = \'$F_TSCHEMA_UPPER\'\)\" ..."
			expdp $S_LOADCONNECTION DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_TSCHEMA_LOWER.dmp LOGFILE=$F_TSCHEMA_LOWER.log schemas=$F_TSCHEMA_UPPER CONTENT=DATA_ONLY include=TABLE:\"IN \(select tname from $C_ENV_CONFIG_TABLESET where status = \'S\' and tschema = \'$F_TSCHEMA_UPPER\'\)\"
		fi
	fi

	# move to store
	mv $S_LOAD_ORACLEDIR/$F_TSCHEMA_LOWER.* $S_LOAD_STAGINGDIR
}

function f_execute_all_exportdata() {
	echo STARTED > exportdata.status.txt
	# export data
	for schema in $P_SCHEMA_SET; do
		f_execute_exportdata_one $schema
	done
	echo FINISHED > exportdata.status.txt
}

function f_execute_all_exportdata_status() {
	local F_STATUS=STOPPED
	if [ -f exportdata.status.txt ]; then
		F_STATUS=`cat exportdata.status.txt | tr -d "\n"`
	fi

	if [ "$F_STATUS" = "STARTED" ]; then
		echo "STATUS=RUNNING"
	elif [ "$F_STATUS" = "FINISHED" ]; then
		echo "STATUS=FINISHED"
	else
		echo "STATUS=STOPPED"
	fi
}

function f_execute_all_exportmeta() {
	#----------------- remove old exports files
        rm -f $S_LOAD_ORACLEDIR/meta.*
        rm -f $S_LOAD_ORACLEDIR/role.*
        rm -f $S_LOAD_STAGINGDIR/meta.*
        rm -f $S_LOAD_STAGINGDIR/role.*

	#----------------- export ORACLE METADATA
	f_expdp $S_LOADCONNECTION "CONTENT=METADATA_ONLY schemas=$P_SCHEMA_SET exclude=STATISTICS DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=meta.dmp LOGFILE=meta.log"

	#----------------- export role data
	f_expdp $S_LOADCONNECTION "full=y INCLUDE=role DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=role.dmp LOGFILE=role.log"

	#----------------- copy to $S_LOAD_STAGINGDIR
	mkdir -p $S_LOAD_STAGINGDIR
	mv $S_LOAD_ORACLEDIR/meta.* $S_LOAD_STAGINGDIR
	mv $S_LOAD_ORACLEDIR/role.* $S_LOAD_STAGINGDIR
}

function f_execute_all() {
	S_LOADCONNECTION=`echo $C_ENV_CONFIG_CONNECTION | tr " " "\n" | grep "$P_DBCONN=" | cut -d "=" -f2`
	S_LOAD_ORACLEDIR=`echo $C_ENV_CONFIG_LOADDIR | tr " " "\n" | grep "$P_DBCONN=" | cut -d "=" -f2`
	S_LOAD_STAGINGDIR=$C_ENV_CONFIG_STAGINGDIR

	if [ "$S_LOADCONNECTION" = "" ]; then
		echo "export_helper.sh: invalid C_ENV_CONFIG_CONNECTION. Exiting..."
		exit 1
	fi
	if [ "$S_LOAD_ORACLEDIR" = "" ]; then
		echo "export_helper.sh: invalid C_ENV_CONFIG_LOADDIR. Exiting..."
		exit 1
	fi
	if [ "$S_LOAD_STAGINGDIR" = "" ]; then
		echo "export_helper.sh: invalid C_ENV_CONFIG_STAGINGDIR. Exiting..."
		exit 1
	fi

	echo "export_helper.sh: execute P_DBCONN=$P_DBCONN, P_CMD=$P_CMD, P_SCHEMA_SET=$P_SCHEMA_SET, S_LOADCONNECTION=$S_LOADCONNECTION, S_LOAD_ORACLEDIR=$S_LOAD_ORACLEDIR, S_LOAD_STAGINGDIR=$S_LOAD_STAGINGDIR ..."

	if [ "$P_CMD" = "exportmeta" ]; then
		f_execute_all_exportmeta
	elif [ "$P_CMD" = "exportdata" ]; then	
		f_execute_all_exportdata
	elif [ "$P_CMD" = "exportdata-status" ]; then	
		f_execute_all_exportdata_status
	fi
}
		
f_execute_all

echo export_helper.sh: successfully finished.
