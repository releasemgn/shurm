#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

USAGE="Usage: `basename $0` <DC> <DB> <OUTDIR_POSTFIX> <RELEASE> <SQLDIRECTORY>"

SCRIPTDIR=`dirname $0`
cd $SCRIPTDIR
SCRIPTDIR=`pwd`

. ./getopts.sh

DC=$1
DB=$2
OUTDIR_POSTFIX=$3
RELEASE=$4
SQLDIRECTORY=$5

# check parameters
if [ "$DC" = "" ]; then
	echo sqlldrall.sh: invalid DC parameter
	exit 1
fi
if [ "$DB" = "" ]; then
	echo sqlldrall.sh: invalid DB parameter
	exit 1
fi
if [ "$OUTDIR_POSTFIX" = "" ]; then
	echo sqlldrall.sh: invalid OUTDIR_POSTFIX parameter
	echo $USAGE    
	exit 1
fi
if [ "$RELEASE" = "" ]; then
	echo sqlldrall.sh: RELEASE not set
	exit 1
fi
if [ "$SQLDIRECTORY" = "" ] || [ ! -d "$SQLDIRECTORY" ]; then
	echo sqlldrall.sh: invalid SQLDIRECTORY parameter
	exit 1
fi

. ./common.sh

# execute

S_DBMSTYPE=
S_TNSNAME=
S_TNSSCHEMALIST=

function f_local_tnsldr_sh {
	local P_SCRIPT=$1

	# check schema
	local F_SCHEMA=`basename $P_SCRIPT | cut -d "-" -f2`
	if [[ " $S_TNSSCHEMALIST " =~ " $F_SCHEMA " ]]; then
		# skip script
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo f_local_tnsldr_sh: unrelated schema with script=$P_SCRIPT. Skipped.
		fi
		return 1
	fi

	./tnsldr.sh $S_DBMSTYPE $S_TNSNAME $OUTDIR_POSTFIX $RELEASE $P_SCRIPT
	local RET=$?
	if [ "$GETOPT_SKIPERRORS" != "yes" ] && [ $RET -ne 0 ]; then
		echo $S_TNSNAME: script $P_SCRIPT was applied with errors. Exiting.
		exit 2
	fi

	return 0
}

function f_local_getenvinfo() {
	# check db and get used schema list
	f_env_getxmlserverinfo $DC $DB
	S_DBMSTYPE=$C_ENV_SERVER_DBMSTYPE
	S_TNSNAME=$C_ENV_SERVER_DBTNSNAME
	S_TNSSCHEMALIST=$C_ENV_SERVER_DBSCHEMALIST
}

function f_local_execute_all() {
	f_release_resolverelease "$RELEASE"
	RELEASE=$C_RELEASE_DISTRID

	f_local_getenvinfo
	for script in $( find $SQLDIRECTORY/dataload -name "*.ctl" | sort ); do
		f_local_tnsldr_sh $script
	done
	return 0
}

f_local_execute_all
echo sqlldrall.sh: SUCCESSFULLY DONE.
