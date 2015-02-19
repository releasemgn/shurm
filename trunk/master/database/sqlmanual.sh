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
DB=$3
SYSPWD=$4

if [ "$RELEASEDIR" = "" ]; then
	echo sqlmanual.sh: invalid RELEASEDIR parameter
	exit 1
fi
if [ "$RELEASEFILE" = "" ]; then
	echo sqlmanual.sh: invalid RELEASEFILE parameter
	exit 1
fi
if [ "$DB" = "" ]; then
	echo sqlmanual.sh: invalid DB parameter
	exit 1
fi

# execute

. ./common.sh

function f_execute_all() {
	f_release_resolverelease "$RELEASEDIR"
	RELEASEDIR=$C_RELEASE_DISTRID

	# release dir
	local F_RELEASEDIR=$C_CONFIG_DISTR_PATH/$RELEASEDIR
	if [ ! -d "$F_RELEASEDIR" ]; then
		echo sqlmanual.sh: unknown release directory - $F_RELEASEDIR. Exiting
		exit 1
	fi

	f_env_getxmlserverinfo $DC $DB
	local F_DBMSTYPE=$C_ENV_SERVER_DBMSTYPE
	local F_TNSNAME=$C_ENV_SERVER_DBTNSNAME

	f_getdbms_relfolderbytype $F_DBMSTYPE
	local F_SRCFOLDER=$S_DBMS_VALUE

	local OUTDIR_POSTFIX=`date "+%Y.%m.%d-%0k.%0M.%0S"`
	local F_RUNDIR
	local F_SRCDIR=$F_RELEASEDIR/$F_SRCFOLDER
	local F_SRCFILE
	if [ "$GETOPT_ALIGNED" != "" ]; then
		F_SRCFILE="$F_SRCDIR/aligned/$GETOPT_ALIGNED/manual/$RELEASEFILE"
		F_RUNDIR=$C_CONFIG_SOURCE_SQL_LOGDIR/$RELEASEDIR-aligned-$GETOPT_ALIGNED-$C_ENV_ID-$DC-$OUTDIR_POSTFIX
	else
		F_SRCFILE="$F_SRCDIR/manual/$RELEASEFILE"
		F_RUNDIR=$C_CONFIG_SOURCE_SQL_LOGDIR/$RELEASEDIR-$C_ENV_ID-$DC-$OUTDIR_POSTFIX
	fi

	if [ ! -f "$F_SRCFILE" ]; then
		echo unknown file $F_SRCFILE. Exiting
		exit 1
	fi

	rm -rf $F_RUNDIR
	mkdir -p $F_RUNDIR
	local F_DSTFILE=$F_RUNDIR/$RELEASEFILE
	cp $F_SRCFILE $F_DSTFILE

	./tnssys.sh $F_DBMSTYPE $F_TNSNAME $P_FILE $SYSPWD
	F_STATUS=$?
	if [ "$GETOPT_SKIPERRORS" != "yes" ] && [ "$F_STATUS" != "0" ]; then
		echo error executing tnssys.sh db=$DB file=$P_FILE. Exiting
		exit 1
	fi
}

f_execute_all

echo sqlmanual.sh: finished
