#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

USAGE="Usage: `basename $0` -afxr(apply, force apply, execute anyway, rollback) [-s (skip errors)] [-l (load data using sqlldr)] <DC> <DB> <OUTDIR_POSTFIX> <RELEASE> <SQLDIRECTORY> [<INDEXLIST>]"

SCRIPTDIR=`dirname $0`
cd $SCRIPTDIR
SCRIPTDIR=`pwd`

. ./getopts.sh

if [ "$GETOPT_EXECUTEMODE" = "" ]; then
	echo $USAGE
	exit 1
fi

DC=$1
DB=$2
OUTDIR_POSTFIX=$3
RELEASE=$4
SQLDIRECTORY=$5
ALIGNEDID=$6

# check parameters
if [ "$DC" = "" ]; then
	echo sqlexecall.sh: invalid DC parameter
	exit 1
fi
if [ "$DB" = "" ]; then
	echo sqlexecall.sh: invalid DB parameter
	exit 1
fi
if [ "$OUTDIR_POSTFIX" = "" ]; then
	echo sqlexecall.sh: invalid OUTDIR_POSTFIX parameter
	exit 1
fi
if [ "$RELEASE" = "" ]; then
	echo sqlexecall.sh: invalid RELEASE parameter
	exit 1
fi
if [ "$SQLDIRECTORY" = "" ] || [ ! -d "$SQLDIRECTORY" ]; then
	echo sqlexecall.sh: invalid SQLDIRECTORY parameter
	exit 1
fi
if [ "$ALIGNEDID" = "" ]; then
	echo sqlexecall.sh: invalid ALIGNEDID parameter
	exit 1
fi

shift 6
EXECUTE_LIST=$*
if [ "$EXECUTE_LIST" = "" ]; then
	echo "sqlexecall.sh: execute all release scripts ..."
else
	echo "sqlexecall.sh: execute list=$EXECUTE_LIST ..."
fi

# execute

. ./common.sh
. ./commonadmindb.sh

S_FOLDERLIST=
S_RELSCHEMALIST=
S_USESCHEMALIST=
S_TNSNAME=
S_TNSSCHEMALIST=
S_SQLEXECLISTMASK=
S_STATUSFILE=

function f_local_tnsexec_sh {
	local P_SCRIPT=$1

	# check index
	if [ "$EXECUTE_LIST" != "" ]; then
		local SCRIPT_INDEX_MATCH=`basename $P_SCRIPT | egrep -c "$S_SQLEXECLISTMASK"`
		if [ "$SCRIPT_INDEX_MATCH" != "1" ]; then
			return 1
		fi
	fi

	./tnsexec.sh -statusfile $S_STATUSFILE $S_TNSNAME $OUTDIR_POSTFIX $RELEASE $P_SCRIPT
	RET=$?

	if [ "$GETOPT_SKIPERRORS" != "yes" ] && [ "${RET}" != "0" ]; then
		echo sqlexecall.sh: failed execution of script $P_SCRIPT. Exiting.
		exit 2
	fi
}

function f_local_tnsldr_sh {
	local P_FILE=$1

	# check index
	if [ "$EXECUTE_LIST" != "" ]; then
		local SCRIPT_INDEX_MATCH=`basename $P_FILE | egrep -c "$S_SQLEXECLISTMASK"`
		if [ "$SCRIPT_INDEX_MATCH" != "1" ]; then
			return 1
		fi
	fi

	./tnsldr.sh -statusfile $S_STATUSFILE $S_TNSNAME $OUTDIR_POSTFIX $RELEASE $P_FILE
	local RET=$?

	if [ "$GETOPT_SKIPERRORS" != "yes" ] && [ "${RET}" != "0" ]; then
		echo sqlexecall.sh: failed execution of dataload file $P_FILE. Exiting.
		exit 2
	fi
}

function f_local_getrelschemalist() {
	P_FOLDERLIST="$1"

	# find schemas actually used in scripts
	local F_USESCHEMALIST=
	local fdir
	local F_ONEFLIST
	for fdir in $P_FOLDERLIST; do
		F_ONEFLIST=`find $fdir -maxdepth 1 -name "*.sql" -exec basename {} \; | cut -d "-" -f2 | tr " " "\n" | sort -u | tr "\n" " "`
		F_USESCHEMALIST="$F_USESCHEMALIST $F_ONEFLIST"
	done

	if [ "$GETOPT_DATALOADOPT" = "yes" ] && [ -d $SQLDIRECTORY/dataload ]; then
		F_ONEFLIST=`find $SQLDIRECTORY/dataload -maxdepth 1 -name "*.ctl" -exec basename {} \; | cut -d "-" -f2 | tr " " "\n" | sort -u | tr "\n" " "`
		F_USESCHEMALIST="$F_USESCHEMALIST $F_ONEFLIST"
		F_ONEFLIST=`find $SQLDIRECTORY/dataload -maxdepth 1 -name "*.sql" -exec basename {} \; | cut -d "-" -f2 | tr " " "\n" | sort -u | tr "\n" " "`
		F_USESCHEMALIST="$F_USESCHEMALIST $F_ONEFLIST"
	fi

	S_RELSCHEMALIST=`echo $F_USESCHEMALIST | tr " " "\n" | sort -u | tr "\n" " "`
}

function f_local_addenvfolder() {
	local P_SQLDIR=$1

	if [[ ! "$P_SQLDIR" =~ ^/ ]]; then
		echo "f_local_addenvfolder: script folder $P_SQLDIR should be absolute path. Exiting"
		exit 1
	fi

	local F_ENVFOLDER=

	# never configure prod
	if [ "$GETOPT_PROD" = "yes" ]; then
		F_ENVFOLDER=prodonly
		if [ -d $P_SQLDIR/$F_ENVFOLDER ]; then
			S_FOLDERLIST="$S_FOLDERLIST $P_SQLDIR/$F_ENVFOLDER"
		fi

		return 0
	fi

	# configure uat if any
	F_ENVFOLDER=uatonly
	if [ ! -d $P_SQLDIR/$F_ENVFOLDER ]; then
		return 0
	fi

	local F_LIVEDIR=$P_SQLDIR/$F_ENVFOLDER.run.$DC.$DB
	mkdir -p $F_LIVEDIR

	# go to environment
	local F_SAVEDIR=`pwd`
	cd $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/deployment

	# generate configuration files using environment parameters
	./configure.sh -raw -dc $DC templates $P_SQLDIR/$F_ENVFOLDER $F_LIVEDIR $DB
	if [ "$?" != "0" ]; then
		echo error executing configure.sh. Exiting
		exit 1
	fi

	cd $F_SAVEDIR

	S_FOLDERLIST="$S_FOLDERLIST $F_LIVEDIR/$DC/$DB"
}

function f_local_getenvinfo() {
	S_FOLDERLIST=
	S_RELSCHEMALIST=
	S_USESCHEMALIST=
	S_TNSNAME=
	S_TNSSCHEMALIST=

	local F_ENVFOLDER=
	if [ "$GETOPT_PROD" = "yes" ]; then
		F_ENVFOLDER=prodonly
	else
		F_ENVFOLDER=uatonly
	fi		

	# collect folder list
	if [ ! -d "$SQLDIRECTORY" ]; then
		echo sqlexecall.sh: invalid source directory - $SQLDIRECTORY. Exiting
		exit 1
	fi
	S_FOLDERLIST=$SQLDIRECTORY

	if [ -d $SQLDIRECTORY/$F_ENVFOLDER ]; then
		f_local_addenvfolder $SQLDIRECTORY
		S_FOLDERLIST="$S_FOLDERLIST $SQLDIRECTORY/$S_ENVFOLDER"
	fi
	if [ -d $SQLDIRECTORY/svcrun/$F_ENVFOLDER ]; then
		f_local_configurefolder $SQLDIRECTORY/$F_ENVFOLDER $SQLDIRECTORY/$F_ENVFOLDER.run
		S_FOLDERLIST="$S_FOLDERLIST $SQLDIRECTORY/svcrun/$F_ENVFOLDER"
	fi
	if [ -d $SQLDIRECTORY/svcrun ]; then
		S_FOLDERLIST="$S_FOLDERLIST $SQLDIRECTORY/svcrun"
	fi

	# check db and get used schema list
	f_env_getxmlserverinfo $DC $DB
	S_TNSNAME=$C_ENV_SERVER_DBTNSNAME
	S_TNSSCHEMALIST=$C_ENV_SERVER_DBSCHEMALIST

	# get release schemas
	f_local_getrelschemalist "$S_FOLDERLIST"

	# verify schema list
	f_getregionaldbschemalist "$S_TNSSCHEMALIST" "$C_ENV_SERVER_DBREGIONS"

	f_getsubset "$S_RELSCHEMALIST" "$S_DB_ALLSCHEMALIST"
	S_USESCHEMALIST="$C_COMMON_SUBSET"
}

function f_local_check() {
	echo $S_TNSNAME: scripts will be applied to - $S_USESCHEMALIST
	echo check connect to $S_TNSNAME...

	echo check admin schema=$C_CONFIG_SCHEMAADMIN ...
	f_check_db_connect $S_TNSNAME $C_CONFIG_SCHEMAADMIN

	local schema
	for schema in $S_USESCHEMALIST; do
		echo check schema=$schema ...
		f_check_db_connect $S_TNSNAME $schema
	done
}

function f_local_loaddata() {
	echo load data from $SQLDIRECTORY/dataload...

	local F_SQLFILE
	local F_CTLFILE
	local F_SCHEMA

	local script
	for script in $(find $SQLDIRECTORY/dataload -maxdepth 1 -name "*.ctl" | sort); do
		F_SQLFILE=${script%.ctl}.sql

		F_SCHEMA=`basename $script | cut -d "-" -f2`
		if [[ " $S_USESCHEMALIST " =~ " $F_SCHEMA " ]]; then
			f_local_tnsldr_sh $script

			# execute post-load if any
			if [ -f "$F_SQLFILE" ]; then
				f_local_tnsldr_sh $F_SQLFILE
			fi
		fi
	done

	# single post-load scripts
	for script in $(find $SQLDIRECTORY/dataload -maxdepth 1 -name "*.sql" | sort); do
		F_CTLFILE=${script%.sql}.ctl

		if [ ! -f "$F_CTLFILE" ]; then
			F_SCHEMA=`basename $script | cut -d "-" -f2`
			if [[ " $S_USESCHEMALIST " =~ " $F_SCHEMA " ]]; then
				echo execute single post-load script $script ...
				f_local_tnsldr_sh $script
			fi
		fi
	done
}

function f_local_apply {
	local P_SQLDIR=$1

	# apply scripts
	local script
	for script in $(find $P_SQLDIR -maxdepth 1 -name "*.sql" | sort); do
		local F_SCHEMA=`basename $script | cut -d "-" -f2`
		if [[ " $S_USESCHEMALIST " =~ " $F_SCHEMA " ]]; then
			f_local_tnsexec_sh $script
		fi
	done
}

function f_local_applyall() {
	echo apply all scripts release=$RELEASE from $SQLDIRECTORY to $S_TNSNAME ...
	f_admindb_beginrelease $RELEASE $S_TNSNAME

	# apply scripts
	for fdir in $S_FOLDERLIST; do
		echo execute scripts - $fdir ...
		f_local_apply $fdir
	done

	# load scripts
	if [ "$GETOPT_DATALOADOPT" = "yes" ] && [ -d $SQLDIRECTORY/dataload ]; then
		f_local_loaddata
	fi
}

function f_local_executeall() {
	f_release_resolverelease "$RELEASE"
	RELEASE=$C_RELEASE_DISTRID

	if [ "$EXECUTE_LIST" != "" ]; then
		f_sqlidx_getegrepexecmask "$EXECUTE_LIST" $ALIGNEDID
		S_SQLEXECLISTMASK="$S_SQL_LISTMASK"
		echo sqlexecall.sh: using execute mask="$S_SQL_LISTMASK" ...
	fi

	f_local_getenvinfo

	if [ "$S_USESCHEMALIST" = "" ]; then
		echo sqlexecall.sh: nothing to apply to $S_TNSNAME. Skipped.
		exit 0
	fi

	f_local_check

	# create initial status file
	if [ "$GETOPT_STATUSFILE" != "" ]; then
		S_STATUSFILE=$GETOPT_STATUSFILE
	else
		S_STATUSFILE=$SQLDIRECTORY/status.before.$S_TNSNAME.$OUTDIR_POSTFIX.txt
		f_admindb_get_scriptstatusall $RELEASE $S_TNSNAME $S_STATUSFILE
	fi

	f_local_applyall

	# create final status file
	if [ "$GETOPT_STATUSFILE" = "" ]; then
		local F_STATUSFILE=$SQLDIRECTORY/status.after.$S_TNSNAME.$OUTDIR_POSTFIX.txt
		f_admindb_get_scriptstatusall $RELEASE $S_TNSNAME $F_STATUSFILE
		f_admindb_checkandfinishrelease $RELEASE $S_TNSNAME
	fi
}

f_local_executeall

echo sqlexecall.sh: finished
