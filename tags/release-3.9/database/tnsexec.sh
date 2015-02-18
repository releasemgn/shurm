#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

#D=echo

USAGE="Usage: `basename $0` -afxr(apply, force apply, execute anyway, rollback) [-s (skip errors)] <TNSNAME> <OUTDIR_POSTFIX> <RELEASE> <FILE_NAME.sql>"

SCRIPTDIR=`dirname $0`
cd $SCRIPTDIR
SCRIPTDIR=`pwd`

. ./getopts.sh

if [ "$GETOPT_EXECUTEMODE" = "" ]; then
	echo $USAGE
	exit 1
fi

DBMSTYPE=$1
TNSNAME=$2
if [ "$DBMSTYPE" = "" ]; then
	echo tnsexec.sh: DBMSTYPE not set
	exit 1
fi
if [ "$TNSNAME" = "" ]; then
	echo tnsexec.sh: TNSNAME not set
	exit 1
fi

OUTDIR_POSTFIX=$3
RELEASE=$4
FNAME=$5

# check parameters
if [ "$OUTDIR_POSTFIX" = "" ]; then
	echo tnsexec.sh: OUTDIR_POSTFIX not set
	exit 1
fi
if [ "$RELEASE" = "" ]; then
	echo tnsexec.sh: RELEASE not set
	exit 1
fi
if [ "$FNAME" = "" ]; then
	echo tnsexec.sh: FNAME not set
	exit 1
fi

. ./specific/$DBMSTYPE.sh
. ./common.sh
. ./commonadmindb.sh

function f_local_check_beforeexecute() {
	SCRIPTNAME=`basename $FNAME`
	SCRIPTNUM=`echo $SCRIPTNAME | cut -d "-" -f1`
	SCHEMA=`echo $SCRIPTNAME | cut -d "-" -f2`

	OPTION_FINALIZEANY=no
	if [ "$GETOPT_SKIPERRORS" = "yes" ]; then
		OPTION_FINALIZEANY=yes
	fi

	OUTDIR=`dirname $FNAME`/run.$TNSNAME.$OUTDIR_POSTFIX
	mkdir -p $OUTDIR

	f_admindb_check_scriptstatus $RELEASE $TNSNAME $SCHEMA $SCRIPTNAME $SCRIPTNUM

	# check showonly status
	if [ "$GETOPT_EXECUTE" = "no" ]; then
		echo "$TNSNAME: showonly apply $SCRIPTNAME to $SCHEMA"
		exit 0
	fi
}

function f_local_execute() {
	# first time applied or skip error
	if [ "$C_ADMINDB_SCRIPT_STATUS" = "new" ] && ( [ $GETOPT_EXECUTEMODE = "apply" ] || [ $GETOPT_EXECUTEMODE = "anyway" ] ); then
		(
			f_add_sqlheader $SCRIPTNAME $OUTDIR
			f_admindb_add_beginscriptstatus $RELEASE $SCHEMA $SCRIPTNAME $SCRIPTNUM
			f_add_sqlfile $FNAME
		) > $OUTDIR/$SCRIPTNAME.run

		f_exec_sql $TNSNAME $SCHEMA $OUTDIR/$SCRIPTNAME.run $OUTDIR $OPTION_FINALIZEANY
		if [ $? -ne 0 ]; then
			F_STATUS=S
		else
			F_STATUS=A
		fi
		f_admindb_updatescriptstatus $RELEASE $TNSNAME $SCHEMA $SCRIPTNAME $SCRIPTNUM $F_STATUS

	# force or reapplied
	elif [ "$C_ADMINDB_SCRIPT_STATUS" = "applied" ] && ( [ $GETOPT_EXECUTEMODE = "force" ] || [ $GETOPT_EXECUTEMODE = "anyway" ] || [ $GETOPT_EXECUTEMODE = "correct" ] ); then
		if [ $GETOPT_EXECUTEMODE = "correct" ] && [ "$C_ADMINDB_SCRIPT_ERRORS" = "no" ]; then
			echo "$TNSNAME: $SCRIPTNAME is already applied without errors. Skipped"
		else
			(
				f_add_sqlheader $SCRIPTNAME $OUTDIR
				f_admindb_add_updatescripttime $RELEASE $SCHEMA $SCRIPTNUM
				f_add_sqlfile $FNAME
			) > $OUTDIR/$SCRIPTNAME.run 

			f_exec_sql $TNSNAME $SCHEMA $OUTDIR/$SCRIPTNAME.run $OUTDIR $OPTION_FINALIZEANY
			if [ $? -ne 0 ]; then
				F_STATUS=S
			else
				F_STATUS=A
			fi
			f_admindb_updatescriptstatus $RELEASE $TNSNAME $SCHEMA $SCRIPTNAME $SCRIPTNUM $F_STATUS
		fi

	# force but not applied yet - error
	elif [ "$C_ADMINDB_SCRIPT_STATUS" = "new" ] && [ $GETOPT_EXECUTEMODE = "force" ]; then
		echo "$TNSNAME: $SCRIPTNAME is being applied first time with WRONG option -f, shoud be used option -a. Skipped"

	# rollback
	elif [ "$C_ADMINDB_SCRIPT_STATUS" = "new" ] && [ $GETOPT_EXECUTEMODE = "rollback" ]; then
		(
			f_add_sqlheader $SCRIPTNAME $OUTDIR
			f_add_sqlfile $FNAME
		) > $OUTDIR/$SCRIPTNAME.run

		f_exec_sql $TNSNAME $SCHEMA $OUTDIR/$SCRIPTNAME.run $OUTDIR
		f_admindb_deletestatus $RELEASE $TNSNAME $SCRIPTNUM $SCHEMA

	elif [ "$C_ADMINDB_SCRIPT_STATUS" = "applied" ] && [ $GETOPT_EXECUTEMODE = "apply" ]; then
		echo "$TNSNAME: $SCRIPTNAME is already applied to $SCHEMA. Skipped."

	else
		echo "$TNSNAME: $SCRIPTNAME WRONG options combination or ERROR. Skipped."
		echo "$COUNT_OUTPUT"
	fi
}

f_local_check_beforeexecute
f_local_execute
