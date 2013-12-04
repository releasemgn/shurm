#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

SCRIPTDIR=`dirname $0`
cd $SCRIPTDIR
SCRIPTDIR=`pwd`

. ./getopts.sh

# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo sqlmanual.sh: DC not set
	exit 1
fi

# check parameters
RELEASEDIR=$1
RELEASEFILE=$2
SYSPWD=$3

if [ "$RELEASEDIR" = "" ]; then
	echo sqlmanual.sh: invalid RELEASEDIR parameter
	exit 1
fi
if [ "$RELEASEFILE" = "" ]; then
	echo sqlmanual.sh: invalid RELEASEFILE parameter
	exit 1
fi

# execute

. ./common.sh

function f_execute_db() {
	P_DB=$1
	P_FILE=$2

	f_env_getxmlserverinfo $DC $P_DB
	./tnssys.sh $C_ENV_SERVER_DBTNSNAME $P_FILE $SYSPWD
	F_STATUS=$?
	if [ "$GETOPT_SKIPERRORS" != "yes" ] && [ "$F_STATUS" != "0" ]; then
		echo error executing tnssys.sh db=$P_DB file=$P_FILE. Exiting
		exit 1
	fi
}

function f_execute_all() {
	# release dir
	local F_RELEASEDIR=$C_CONFIG_DISTR_PATH/$RELEASEDIR
	if [ ! -d "$F_RELEASEDIR" ]; then
		echo sqlmanual.sh: unknown release directory - $F_RELEASEDIR. Exiting
		exit 1
	fi

	local OUTDIR_POSTFIX=`date "+%Y.%m.%d-%0k.%0M.%0S"`
	local F_RUNDIR
	local F_SRCDIR=$F_RELEASEDIR/SQL
	local F_SRCFILE
	if [ "$GETOPT_ALIGNED" != "" ]; then
		F_SRCFILE="$F_SRCDIR/aligned/$GETOPT_ALIGNED/manual/$RELEASEFILE"
		F_RUNDIR=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/database/patches.log/$RELEASEDIR-aligned-$GETOPT_ALIGNED-$C_ENV_ID-$DC-$OUTDIR_POSTFIX
	else
		F_SRCFILE="$F_SRCDIR/manual/$RELEASEFILE"
		F_RUNDIR=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/database/patches.log/$RELEASEDIR-$C_ENV_ID-$DC-$OUTDIR_POSTFIX
	fi

	if [ ! -f "$F_SRCFILE" ]; then
		echo unknown file $F_SRCFILE. Exiting
		exit 1
	fi

	rm -rf $F_RUNDIR
	mkdir -p $F_RUNDIR
	local F_DSTFILE=$F_RUNDIR/$RELEASEFILE
	cp $F_SRCFILE $F_DSTFILE

	# execute in database list
	f_env_getxmlserverlist_bytype $DC "database"
	local F_DBLIST="$C_ENV_XMLVALUE"

	for db in $F_DBLIST; do
		if [ "$GETOPT_DB" = "" ] || [ "$GETOPT_DB" = "$db" ]; then
			f_execute_db $db $F_DSTFILE
		fi
	done
}

f_execute_all

echo sqlmanual.sh: finished
