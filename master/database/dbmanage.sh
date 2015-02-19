#!/bin/bash 
# Copyright 2011-2015 vsavchik@gmail.com

DBMSTYPE=$1
OP=$2
RELEASE=$3
TNSNAME=$4
ALIGNEDID=$5
if [ "$DBMSTYPE" = "" ]; then
	echo dbmanage.sh: DBMSTYPE not set
	exit 1
fi
if [ "$RELEASE" = "" ]; then
	echo dbmanage.sh: RELEASE not set
	exit 1
fi
if [ "$TNSNAME" = "" ]; then
	echo dbmanage.sh: TNSNAME not set
	exit 1
fi
if [ "$ALIGNEDID" = "" ]; then
	echo dbmanage.sh: ALIGNEDID not set
	exit 1
fi

EXECUTE_LIST="$6"

. ./specific/$DBMSTYPE.sh
. ./common.sh
. ./commonadmindb.sh

# execute
function f_local_execute_tns_rollback() {
	if [ "$EXECUTE_LIST" = "" ]; then
		echo $TNSNAME: drop release $RELEASE...
		f_admindb_droprelease $DBMSTYPE $RELEASE $TNSNAME
	else
		echo $TNSNAME: drop release $RELEASE items ...
		f_admindb_dropreleaseitems $DBMSTYPE $RELEASE $TNSNAME "$EXECUTE_LIST" $ALIGNEDID
	fi

	# finish release
	f_admindb_checkandfinishrelease $DBMSTYPE $RELEASE $TNSNAME
}

function f_local_execute_tns_correct() {
	if [ "$EXECUTE_LIST" = "" ]; then
		echo $TNSNAME: correct release $RELEASE...
		f_admindb_fixreleaseall $DBMSTYPE $RELEASE $TNSNAME
	else
		echo $TNSNAME: correct release $RELEASE items...
		f_admindb_fixreleaseitems $DBMSTYPE $RELEASE $TNSNAME "$EXECUTE_LIST" $ALIGNEDID
	fi

	# finish release
	f_admindb_checkandfinishrelease $DBMSTYPE $RELEASE $TNSNAME
}

function f_local_execute_tns_print() {
	echo $TNSNAME: get status of release $RELEASE...
	f_admindb_getreleasefailed $DBMSTYPE $RELEASE $TNSNAME

	if [ "$C_ADMINDB_SQLRES" = "" ]; then
		echo $TNSNAME: release is successfully finalized.
	else
		echo "$TNSNAME: not finalized scripts - $C_ADMINDB_SQLRES""- executed with errors, see latest logs below - "

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

function f_local_execute_all() {
	f_admindb_getreleasestatus $DBMSTYPE $RELEASE $TNSNAME
	if [ "$C_ADMINDB_RELEASESTATUS" = "" ]; then
		echo $F_TNSNAME: unknown release=$RELEASE. Exiting
		exit 1
	fi

	if [ "$OP" = "rollback" ]; then
		f_local_execute_tns_rollback

	elif [ "$OP" = "correct" ]; then
		f_local_execute_tns_correct

	elif [ "$OP" = "print" ]; then
		f_local_execute_tns_print

	fi	
}

f_local_execute_all
