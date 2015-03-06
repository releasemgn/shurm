#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com
# tns-level script

USAGE="Usage: `basename $0` <TNSNAME> <OUTDIR_POSTFIX> <RELEASE> <FILE_NAME.ctl>"

SCRIPTDIR=`dirname $0`
cd $SCRIPTDIR
SCRIPTDIR=`pwd`

. ./getopts.sh

DBMSTYPE=$1
TNSNAME=$2
if [ "$DBMSTYPE" = "" ]; then
	echo tnsldr.sh: DBMSTYPE not set
	exit 1
fi
if [ "$TNSNAME" = "" ]; then
	echo tnsldr.sh: TNSNAME not set
	exit 1
fi

OUTDIR_POSTFIX=$3
RELEASE=$4
FILE_NAME=$5

# check parameters
if [ "$OUTDIR_POSTFIX" = "" ]; then
	echo tnsldr.sh: OUTDIR_POSTFIX not set
	echo $USAGE    
	exit 1
fi
if [ "$RELEASE" = "" ]; then
	echo tnsldr.sh: RELEASE not set
	exit 1
fi
if [ "$FILE_NAME" = "" ]; then
	echo tnsldr.sh: FILE_NAME not set
	exit 1
fi

# execute

. ./specific/$DBMSTYPE.sh
. ./common.sh
. ./commonadmindb.sh

S_CTLPATH=
S_CTLNAME=
S_POSTCTLNAME=

S_FILENUM=
S_OUTDIR=
S_SCHEMA=

function f_local_prepare () {
	S_CTLPATH=`dirname $FILE_NAME`
	local F_BASENAME=`basename $FILE_NAME`
	local F_BASENAMENOEXT=${F_BASENAME%.*}

	S_POSTCTLNAME=$F_BASENAMENOEXT.sql
	S_CTLNAME=$F_BASENAMENOEXT.ctl

	S_FILENUM=`echo $F_BASENAMENOEXT | cut -d "-" -f1`
	S_SCHEMA=`echo $F_BASENAMENOEXT | cut -d "-" -f2`
	S_OUTDIR=$S_CTLPATH/run.sqlldr.$TNSNAME.$OUTDIR_POSTFIX

	if [ ! -f "$FILE_NAME" ] || [ "$S_FILENUM" = "" ] || [ "$S_SCHEMA" = "" ]; then
		echo tnsldr.sh: invalid name - $FILE_NAME. Exiting
		exit 1
	fi

	# execute
	mkdir -p $S_OUTDIR
	cd $S_OUTDIR
	S_OUTDIR=`pwd`
	cd $SCRIPTDIR

	cd $S_CTLPATH
	S_CTLPATH=`pwd`
	cd $SCRIPTDIR

	# check already executed
	f_admindb_check_scriptstatus $DBMSTYPE $RELEASE $TNSNAME $S_SCHEMA $F_BASENAME $S_FILENUM
	if [ "$C_ADMINDB_SCRIPT_STATUS" != "new" ] && [ "$GETOPT_EXECUTEMODE" != "force" ] && [ "$GETOPT_EXECUTEMODE" != "anyway" ]; then
		echo "$TNSNAME: $F_BASENAME is already loaded into $S_SCHEMA. Skipped."
		exit 0
	fi	

	if [ "$C_ADMINDB_SCRIPT_STATUS" = "new" ] && [ $GETOPT_EXECUTEMODE = "force" ]; then
		echo "$TNSNAME: $F_BASENAME is being applied first time with WRONG option -f, shoud be used option -a. Skipped"
		exit 0
	fi

	# check showonly status
	if [ "$GETOPT_EXECUTE" = "no" ]; then
		echo "$TNSNAME: showonly load $FILE_NAME to $SCHEMA"
		exit 0
	fi
}

function f_local_execute_loadctl() {
	echo $TNSNAME: release=$RELEASE, load data using $FILE_NAME OUTDIR=$S_OUTDIR ...

	if [ "$C_ADMINDB_SCRIPT_STATUS" = "new" ]; then
		f_admindb_beginscriptstatus $DBMSTYPE $RELEASE $TNSNAME $S_SCHEMA $S_CTLNAME $S_FILENUM
	fi

	local F_EXECNAME=$S_CTLPATH/$S_CTLNAME
	f_sqlload_ctlfile $DBMSTYPE $TNSNAME $S_SCHEMA $F_EXECNAME $S_OUTDIR
	if [ $? -ne 0 ]; then
		echo tnsldr.sh: errors while loading $F_EXECNAME. Exiting
		exit 1
	fi

	f_admindb_updatescriptstatus $DBMSTYPE $RELEASE $TNSNAME $S_SCHEMA $S_CTLNAME $S_FILENUM "A"
}

function f_local_execute_postsql() {
	local F_EXECNAME=$S_OUTDIR/$S_POSTCTLNAME.run
	echo $TNSNAME: executing post-load script $S_POSTCTLNAME ...
	(
		f_add_sqlheader $DBMSTYPE $S_POSTCTLNAME $S_OUTDIR

		if [ "$C_ADMINDB_SCRIPT_STATUS" = "new" ]; then
			f_admindb_add_beginscriptstatus $DBMSTYPE $RELEASE $S_SCHEMA $S_POSTCTLNAME $S_FILENUM
		else
			f_admindb_add_updatescripttime $DBMSTYPE $RELEASE $S_SCHEMA $S_FILENUM
		fi

		f_add_sqlfile $DBMSTYPE $S_CTLPATH/$S_POSTCTLNAME
	) > $F_EXECNAME
	
	f_exec_sql $DBMSTYPE $TNSNAME $S_SCHEMA $F_EXECNAME $S_OUTDIR
	if [ $? -ne 0 ]; then
		echo $TNSNAME: error executing post-load script $S_POSTCTLNAME in $S_SCHEMA. Exiting
		exit 1
	fi

	f_admindb_updatescriptstatus $DBMSTYPE $RELEASE $TNSNAME $S_SCHEMA $S_POSTCTLNAME $S_FILENUM "A"
}

function f_local_executeall() {
	f_local_prepare

	if [[ "$FILE_NAME" =~ ctl$ ]]; then
		f_local_execute_loadctl
	fi

	if [[ "$FILE_NAME" =~ sql$ ]]; then
		f_local_execute_postsql
	fi
}

f_local_executeall

exit 0
