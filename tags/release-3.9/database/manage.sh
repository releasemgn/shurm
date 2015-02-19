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

function f_local_execute_db() {
	local P_DB=$1

	echo manage.sh: execute in DB=$P_DB ...
	f_env_getxmlserverinfo $DC $P_DB
	local F_DBMSTYPE=$C_ENV_SERVER_DBMSTYPE
	local F_TNSNAME="$C_ENV_SERVER_DBTNSNAME"
	local F_SCHEMALIST="$C_ENV_SERVER_DBSCHEMALIST"

	./dbmanage.sh $F_DBMSTYPE "$EXECUTEMODE" $RELEASE $F_TNSNAME $S_ALIGNED_ID "$EXECUTE_LIST"
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
