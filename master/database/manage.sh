#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

USAGE="Usage: `basename $0` -[r|c|p] [db option] <RELEASE> [index_list|folder_list]"

SCRIPTDIR=`dirname $0`
cd $SCRIPTDIR
SCRIPTDIR=`pwd`

. ./getopts.sh

# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo manage.sh: DC not set
	exit 1
fi

EXECUTEMODE=$GETOPT_EXECUTEMODE
if [ "$EXECUTEMODE" = "" ]; then
	echo manage.sh: EXECUTEMODE not set
	exit 1
fi

RELEASE=$1

# check parameters
if [ "$RELEASE" = "" ]; then
	echo manage.sh: RELEASE not set
	exit 1
fi

shift 1
EXECUTE_LIST="$*"

. ./common.sh
. ./commonadmindb.sh

# execute
S_ALIGNED_ID=

function f_local_execute_tns_rollback() {
	local P_TNSNAME=$1

	if [ "$EXECUTE_LIST" = "" ]; then
		echo $P_TNSNAME: drop release $RELEASE...
		f_admindb_droprelease $RELEASE $P_TNSNAME
	else
		echo $P_TNSNAME: drop release $RELEASE items ...
		f_admindb_dropreleaseitems $RELEASE $P_TNSNAME "$EXECUTE_LIST" $S_ALIGNED_ID
	fi

	# finish release
	f_admindb_checkandfinishrelease $RELEASE $P_TNSNAME
}

function f_local_execute_tns_correct() {
	local P_TNSNAME=$1

	if [ "$EXECUTE_LIST" = "" ]; then
		echo $P_TNSNAME: correct release $RELEASE...
		f_admindb_fixreleaseall $RELEASE $P_TNSNAME
	else
		echo $P_TNSNAME: correct release $RELEASE items...
		f_admindb_fixreleaseitems $RELEASE $P_TNSNAME "$EXECUTE_LIST" $S_ALIGNED_ID
	fi

	# finish release
	f_admindb_checkandfinishrelease $RELEASE $P_TNSNAME
}

function f_local_execute_tns_print() {
	local P_TNSNAME=$1

	echo $P_TNSNAME: get status of release $RELEASE...
	f_admindb_getreleasefailed $RELEASE $P_TNSNAME

	if [ "$C_ADMINDB_SQLRES" = "" ]; then
		echo $P_TNSNAME: release is successfully finalized.
	else
		echo "$P_TNSNAME: not finalized scripts - $C_ADMINDB_SQLRES""- executed with errors, see latest logs below - "

		for script in $C_ADMINDB_SQLRES; do
			LOGS=""
			for logdir in $C_CONFIG_SOURCE_SQL_LOGDIR/$RELEASE-$C_ENV_ID-$DC-*; do
				LOGS="$LOGS `find $logdir -name \"$script-*.sql.spool\"`"
			done

			LAST_LOG=`ls -t $LOGS | head -1`
			SCRIPT=`echo $LAST_LOG | sed -e 's/.spool//' | sed -e 's/.*\///'`
			SCRIPT=`echo $SCRIPT | sed -e 's/[0-9]*\([0-9][0-9][0-9]\)/\1/'`

			echo "less $LAST_LOG # *$SCRIPT"
		done
	fi
}

function f_local_execute_db() {
	local P_DB=$1

	echo manage.sh: execute in DB=$P_DB ...
	f_env_getxmlserverinfo $DC $P_DB
	local F_TNSNAME="$C_ENV_SERVER_DBTNSNAME"
	local F_SCHEMALIST="$C_ENV_SERVER_DBSCHEMALIST"

	f_admindb_getreleasestatus $RELEASE $F_TNSNAME
	if [ "$C_ADMINDB_RELEASESTATUS" = "" ]; then
		echo $F_TNSNAME: unknown release=$RELEASE. Exiting
		exit 1
	fi

	if [ "$EXECUTEMODE" = "rollback" ]; then
		f_local_execute_tns_rollback $F_TNSNAME

	elif [ "$EXECUTEMODE" = "correct" ]; then
		f_local_execute_tns_correct $F_TNSNAME

	elif [ "$EXECUTEMODE" = "print" ]; then
		f_local_execute_tns_print $F_TNSNAME
	fi
}

function f_local_execute_all() {
	f_release_resolverelease "$RELEASE"
	RELEASE=$C_RELEASE_DISTRID

	# execute in database list
	f_env_getxmlserverlist_bytype $DC "database"
	local F_DBLIST="$C_ENV_XMLVALUE"

	# check aligned
	if [ "$GETOPT_ALIGNED" = "" ]; then
		GETOPT_ALIGNED=common
	fi
	f_aligned_getidbyname $GETOPT_ALIGNED
	S_ALIGNED_ID=$S_COMMON_ALIGNEDID

	if [ "$GETOPT_DB" != "" ]; then
		f_checkvalidlist "$F_DBLIST" "$GETOPT_DB"
		F_DBLIST="$GETOPT_DB"
	fi

	# check release across all tns
	for db in $F_DBLIST; do
		f_local_execute_db $db
	done
}

f_local_execute_all

echo manage.sh: SUCCESSFULLY DONE.
