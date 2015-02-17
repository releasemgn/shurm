#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com
# tns-level script

USAGE="Usage: `basename $0` <TNSNAME> <FILE_NAME.sql> [<SYS_PASSWD>]"

SCRIPTDIR=`dirname $0`
cd $SCRIPTDIR
SCRIPTDIR=`pwd`

DBMSTYPE=$1
TNSNAME=$2

if [ "$DBMSTYPE" = "" ]; then
	echo tnssys.sh: DBMSTYPE not set
	exit 1
fi
if [ "$TNSNAME" = "" ]; then
	echo tnssys.sh: TNSNAME not set
	exit 1
fi

FNAME=$3
SYS_PASSWD=$4

# execute

. ./common.sh

function f_execute_all() {
	# check file
	if [ ! -f "$FNAME" ]; then
		echo unknown file $FNAME. Exiting
		exit 1
	fi

	# set final password
	if [ "$SYS_PASSWD" = "" ]; then
		DBPWDFILE=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/.auth/db.$TNSNAME.sys.password
		if [ -f "$DBPWDFILE" ]; then
			SYS_PASSWD=`cat $DBPWDFILE`
		else
			SYS_PASSWD=oracle
		fi
	fi

	# execute
	if [ "$FNAME" != "" ]; then
		# public sys script
		OUTDIR=`dirname $FNAME`/run.$TNSNAME
		mkdir -p $OUTDIR
		SCRIPTNAME=`basename $FNAME`

		# create runtime script
		(       
			f_add_sqlheader $SCRIPTNAME $OUTDIR
			f_add_sqlfile $FNAME
		) > $OUTDIR/$SCRIPTNAME.run 

		# check showonly status
		if [ "$GETOPT_EXECUTE" = "no" ]; then
			echo "$TNSNAME: showonly apply $SCRIPTNAME to sys"
			exit 0
		fi

		f_exec_syssql $TNSNAME $OUTDIR/$SCRIPTNAME.run $OUTDIR "no" $SYS_PASSWD

	else
		# pivate sys script
		f_exec_syssql_private $TNSNAME $SYS_PASSWD $GETOPT_SKIPERRORS
	fi
}

f_execute_all
echo tnssys.sh: finished.
