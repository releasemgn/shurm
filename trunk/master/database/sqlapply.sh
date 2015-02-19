#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

SCRIPTDIR=`dirname $0`
cd $SCRIPTDIR
SCRIPTDIR=`pwd`

. ./getopts.sh

# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo sqlapply.sh: DC not set
	exit 1
fi

if [ "$GETOPT_EXECUTEMODE" = "" ]; then
	echo sqlapply.sh: GETOPT_EXECUTEMODE not set
	exit 1
fi

# check parameters
RELEASEDIR=$1

if [ "$RELEASEDIR" = "" ]; then
	echo sqlapply.sh: invalid RELEASEDIR parameter
	exit 1
fi

shift 1
EXECUTE_LIST=$*

. ./common.sh
. ./commonadmindb.sh

S_SQLAPPLY_RELEASE_ID=
S_SQLAPPLY_RELEASE_BASEDIR=
S_SQLAPPLY_RELEASE_SRCDIR=

function f_local_copyfile() {
	local P_SRCFILE=$1
	local P_DSTDIR=$2
	local P_ALIGNEDDIR=$3
	local P_REGIONS="$4"

	if [ "$P_REGIONS" = "" ]; then
		if [ "$P_ALIGNEDDIR" != "regional" ]; then
			mkdir -p $P_DSTDIR
			f_release_downloadfile $P_SRCFILE $P_DSTDIR
		fi
		return 0
	fi

	local F_SCRIPTBASENAME=`basename $P_SRCFILE`
	local F_SCRIPTNUM=${F_SCRIPTBASENAME%%-*}
	local F_SCRIPTSCHEMA=`echo $F_SCRIPTBASENAME | cut -d "-" -f2`

	local F_SCRIPTNUMUSE
	if [ "$P_ALIGNEDDIR" != "regional" ]; then
		if [[ ! "$F_SCRIPTSCHEMA" =~ "RR" ]]; then
			mkdir -p $P_DSTDIR
			f_release_downloadfile $P_SRCFILE $P_DSTDIR
			return 0
		fi
	else
		# get regions to apply in
		f_release_runcmd "grep \"^\-\- REGIONS \" $P_SRCFILE"
		local F_REGIONS="$C_RELEASE_CMD_RES"

		F_REGIONS=${F_REGIONS#-- REGIONS }
		f_getsubsetexact "$P_REGIONS" "$F_REGIONS"
		P_REGIONS="$C_COMMON_SUBSET"

		# no regions for given file in given db
		if [ "$P_REGIONS" = "" ]; then
			return 0
		fi
	fi

	# if index ends with RR, remove it before adding region number
	F_SCRIPTNUMUSE=${F_SCRIPTNUM%RR}

	echo "sqlapply.sh: duplicate $P_SRCFILE - regions: $P_REGIONS ..."
	local F_SCRIPTTAIL=${F_SCRIPTBASENAME#$F_SCRIPTNUM-$F_SCRIPTSCHEMA-}
	local F_DSTNAME
	mkdir -p $P_DSTDIR
	for region in $P_REGIONS; do
		F_DSTNAME=$F_SCRIPTNUMUSE$region-${F_SCRIPTSCHEMA/RR/$region}-$F_SCRIPTTAIL
		f_release_downloadfile $P_SRCFILE $P_DSTDIR/$F_DSTNAME
		sed -i "s/@region@/$region/g" $P_DSTDIR/$F_DSTNAME
	done
}

function f_local_createrundir() {
	local P_ALIGNEDDIR=$1
	local P_ALIGNEDID=$2
	local P_SRCDIR=$3
	local P_RUNDIR=$4
	local P_REGIONS="$5"

	rm -rf $P_RUNDIR
	mkdir -p $P_RUNDIR

	echo sqlapply.sh: copy distributive from $P_SRCDIR to $P_RUNDIR ...
	if [ "$EXECUTE_LIST" = "" ]; then
		f_release_runcmd "if [ -d $P_SRCDIR ]; then cd $P_SRCDIR; find . -type f | egrep -v \"(^\\./aligned|^\\./manual)\"; fi"
		local F_LIST="$C_RELEASE_CMD_RES"

		for fname in $F_LIST; do
			F_DIRNAME=`dirname $fname`
			f_local_copyfile $P_SRCDIR/$fname $P_RUNDIR/$F_DIRNAME $P_ALIGNEDDIR "$P_REGIONS"
		done
	else
		f_sqlidx_getegrepmask "$EXECUTE_LIST" $P_ALIGNEDID
		local F_GREP="$S_SQL_LISTMASK"

		f_release_runcmd "if [ -d $P_SRCDIR ]; then cd $P_SRCDIR; find . -type f -printf \"%P\\n\" | egrep \"$F_GREP\" | tr \"\\n\" \" \"; fi"
		F_FILES="$C_RELEASE_CMD_RES"

		if [ "$F_FILES" != "" ]; then
			local F_DIRNAME
			local file
			for file in $F_FILES; do
				F_DIRNAME=`dirname $file`
				mkdir -p $P_RUNDIR/$F_DIRNAME
				f_local_copyfile $P_SRCDIR/$file $P_RUNDIR/$F_DIRNAME $P_ALIGNEDDIR "$P_REGIONS"
			done
		fi
	fi
}

function f_local_createrundirall() {
	local P_SRCDIR=$1
	local P_RUNDIR=$2
	local P_ALIGNEDDIRLIST="$3"
	local P_REGIONS="$4"

	echo sqlapply.sh: create run dirs in $P_RUNDIR ...
	f_aligned_getidbyname common
	f_local_createrundir common $S_COMMON_ALIGNEDID $P_SRCDIR $P_RUNDIR "$P_REGIONS"

	local aligneddir
	for aligneddir in $P_ALIGNEDDIRLIST; do
		f_aligned_getidbyname $aligneddir
		f_local_createrundir $aligneddir $S_COMMON_ALIGNEDID $P_SRCDIR/aligned/$aligneddir $P_RUNDIR/aligned/$aligneddir "$P_REGIONS"
	done
}

function f_local_execute_db() {
	local P_DB=$1
	local P_SRCDIR=$2
	local P_RUNDIR=$3
	local P_OUTDIR_POSTFIX=$4

	# get db info
	f_env_getxmlserverinfo $DC $P_DB
	local F_DBMSTYPE=$C_ENV_SERVER_DBMSTYPE
	local F_TNSNAME=$C_ENV_SERVER_DBTNSNAME
	local F_DBALIGNEDDIRLIST="$C_ENV_SERVER_ALIGNED"
	local F_REGIONS="$C_ENV_SERVER_DBREGIONS"

	# default aligned is dc
	if [ "$F_DBALIGNEDDIRLIST" = "" ]; then
		F_DBALIGNEDDIRLIST="$DC"
	fi

	if [ "$C_ENV_SERVER_DBREGIONS" != "" ]; then
		F_DBALIGNEDDIRLIST="$F_DBALIGNEDDIRLIST regional"
	fi

	# prepare source scripts to run
	f_getdbms_relfolderbytype $F_DBMSTYPE
	local F_SRCFOLDER=$S_DBMS_VALUE

	# get release aligned dir list
	local F_SRCDIR=$C_CONFIG_DISTR_PATH/$RELEASEDIR/$F_SRCFOLDER
	local F_ALIGNEDDIRLIST=
	if [ -d $F_SRCDIR/aligned ]; then
		local F_SAVEDIR=`pwd`
		cd $F_SRCDIR/aligned

		F_ALIGNEDDIRLIST=`find . -maxdepth 1 -type d | grep -v "^.$" | sed "s/.\///" | sort | tr "\n" " "`
		F_ALIGNEDDIRLIST=${F_ALIGNEDDIRLIST% }

		cd $F_SAVEDIR
	fi

	f_getsubsetexact "$F_ALIGNEDDIRLIST" "$F_DBALIGNEDDIRLIST"
	local F_USEALIGNEDDIRLIST=$C_COMMON_SUBSET

	f_local_createrundirall $P_SRCDIR/$F_SRCFOLDER $P_RUNDIR "$F_USEALIGNEDDIRLIST" "$C_ENV_SERVER_DBREGIONS"

	# apply
	echo "apply release=$S_SQLAPPLY_RELEASE_BASEDIR to db=$P_DB: common, alignedlist=$F_USEALIGNEDDIRLIST ..."

	./dbmanage.sh $F_DBMSTYPE "execbefore" $S_SQLAPPLY_RELEASE_ID $F_TNSNAME "ignore" "$P_RUNDIR $P_OUTDIR_POSTFIX"
	if [ "$?" != "" ]; then
		echo unsuccessful dbmanage.sh. Exiting
		exit 1
	fi

	# common
	echo "sqlapply.sh: =================================== apply common scripts to db=$P_DB ..."
	f_aligned_getidbyname common

	local F_RES
	if [ "$F_REGIONS" != "" ]; then
		./sqlexecall.sh -statusfile $F_STATUSFILE -regions "$F_REGIONS" $F_DBMSTYPE $DC $P_DB $P_OUTDIR_POSTFIX $S_SQLAPPLY_RELEASE_ID $P_RUNDIR $S_COMMON_ALIGNEDID
		F_RES="$?"
	else
		./sqlexecall.sh -statusfile $F_STATUSFILE $F_DBMSTYPE $DC $P_DB $P_OUTDIR_POSTFIX $S_SQLAPPLY_RELEASE_ID $P_RUNDIR $S_COMMON_ALIGNEDID
		F_RES="$?"
	fi
	if [ "$F_RES" != "0" ]; then
		echo sqlapply.sh: unsuccessful sqlexecall.sh. Exiting
		exit 1
	fi

	# aligned, parent dc by default
	for aligneddir in $F_USEALIGNEDDIRLIST; do
		echo "sqlapply.sh: =================================== apply aligned dir=$aligneddir scripts to db=$P_DB ..."
		f_aligned_getidbyname $aligneddir
		if [ "$F_REGIONS" != "" ]; then
			./sqlexecall.sh -statusfile $F_STATUSFILE -regions "$F_REGIONS" $F_DBMSTYPE $DC $P_DB $P_OUTDIR_POSTFIX-aligned-$aligneddir $S_SQLAPPLY_RELEASE_ID $P_RUNDIR/aligned/$aligneddir $S_COMMON_ALIGNEDID
			F_RES="$?"
		else
			./sqlexecall.sh -statusfile $F_STATUSFILE $F_DBMSTYPE $DC $P_DB $P_OUTDIR_POSTFIX-aligned-$aligneddir $S_SQLAPPLY_RELEASE_ID $P_RUNDIR/aligned/$aligneddir $S_COMMON_ALIGNEDID
			F_RES="$?"
		fi

		if [ "$F_RES" != "0" ]; then
			echo sqlapply.sh: unsuccessful sqlexecall.sh. Exiting
			exit 1
		fi
	done

	echo "sqlapply.sh: =================================== finish release in db=$P_DB"

	./dbmanage.sh $F_DBMSTYPE "execafter" $S_SQLAPPLY_RELEASE_ID $F_TNSNAME "ignore" "$P_RUNDIR $P_OUTDIR_POSTFIX"
	if [ "$?" != "" ]; then
		echo unsuccessful dbmanage.sh. Exiting
		exit 1
	fi
}

function f_release_getreleasedir() {
	f_release_resolverelease "$RELEASEDIR"
	S_SQLAPPLY_RELEASE_BASEDIR=$C_RELEASE_DISTRID

	f_release_getdistrdir $S_SQLAPPLY_RELEASE_BASEDIR
	S_SQLAPPLY_RELEASE_ID=$C_RELEASE_SRCVER
	S_SQLAPPLY_RELEASE_SRCDIR=$C_RELEASE_SRCDIR
}

function f_local_execute_all() {
	f_release_getreleasedir

	# execute in database list
	f_env_getxmlserverlist_bytype $DC "database"
	local F_DBLIST="$C_ENV_XMLVALUE"

	if [ "$GETOPT_DB" != "" ]; then
		f_checkvalidlist "$F_DBLIST" "$GETOPT_DB"
		F_DBLIST="$GETOPT_DB"
	fi

	# create run dirs
	local OUTDIR_POSTFIX=`date "+%Y.%m.%d-%0k.%0M.%0S"`
	local F_RUNDIR=$C_CONFIG_SOURCE_SQL_LOGDIR/$S_SQLAPPLY_RELEASE_BASEDIR-$C_ENV_ID-$DC-$OUTDIR_POSTFIX

	# execute
	echo sqlapply.sh: execute scripts dblist=$F_DBLIST, alignedlist=$F_ALIGNEDDIRLIST ...
	for db in $F_DBLIST; do
		f_local_execute_db $db $S_SQLAPPLY_RELEASE_SRCDIR $F_RUNDIR/$db $OUTDIR_POSTFIX
	done
}

f_local_execute_all
echo sqlapply.sh: SUCCESSFULLY DONE.
