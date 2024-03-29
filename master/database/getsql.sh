#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
SCRIPTDIR=`pwd`
cd $SCRIPTDIR

. ./getopts.sh

APP_VERSION_SQL=$1
APP_VERSION_SQL_MAJOR=$2

. ./common.sh

S_GETSQL_TMP="/tmp/$HOSTNAME.$USER.getsql.p$$"
S_RELEASE=
S_SQL_SRCDIR=

function f_local_usage() {
	echo "
	Usage example:
		./getsql.sh -s -nodist prod-patch-2.3.22
	Options:
		-m      : move incorrect scripts to errors folder
		-s	: skip (ignore) errors and continue processing
		-nodist	: do not copy to distributive
"
}

function f_execute_checkparams() {
	if [ "$GETOPT_RELEASE" != "" ]; then
		if [[ "$GETOPT_RELEASE" =~ ^[0-9]\.[0-9]$ ]]; then
			APP_VERSION_SQL=major-release-$GETOPT_RELEASE
		else
			APP_VERSION_SQL=prod-patch-$GETOPT_RELEASE
		fi
	fi

	# check parameters
	if [ "$APP_VERSION_SQL" = "" ]; then
		echo getsql.sh: invalid APP_VERSION_SQL parameter
		f_local_usage
		exit 1
	fi

	if [ "$APP_VERSION_SQL_MAJOR" = "" ]; then
		APP_VERSION_SQL_MAJOR=$C_CONFIG_RELEASE_GROUPFOLDER
	fi

	if [ "$GETOPT_SCRIPTFOLDER" = "" ]; then
		if [[ "$APP_VERSION_SQL" =~ ^major-release- ]] || [[ "$APP_VERSION_SQL" =~ ^prod-patch- ]]; then
			S_RELEASE=`echo $APP_VERSION_SQL | cut -d "-" -f3`

		elif [[ "$APP_VERSION_SQL" =~ ^demo- ]]; then
			S_DEMO=`echo $APP_VERSION_SQL | cut -d "-" -f2`
			local F_RID=`echo $APP_VERSION_SQL | cut -d "-" -f3`

			if [ "$S_DEMO" = "" ] || [ "$F_RID" = "" ]; then
				echo getsql.sh: demo release invalid folder name format
				exit 1
			fi

			S_RELEASE=$F_RID-demo-$S_DEMO
		else
			echo getsql.sh: invalid folder name format
			exit 1
		fi

		if [ "$S_RELEASE" = "" ]; then
			echo getsql.sh: invalid folder name format
			exit 1
		fi

		S_SQL_SRCDIR=$C_CONFIG_SOURCE_RELEASEROOTDIR/$APP_VERSION_SQL_MAJOR/$APP_VERSION_SQL
	else
		S_RELEASE=$GETOPT_SCRIPTFOLDER
		S_SQL_SRCDIR=$C_CONFIG_SOURCE_SQL_GLOBALPENDING/$APP_VERSION_SQL
	fi
}

function f_execute_dbms() {
	local P_DBMSTYPE=$1
	local P_DBMSFOLDER=$2
	local P_RELEASEFOLDER=$3

	echo download from $S_SQL_SRCDIR/$P_DBMSFOLDER ...
	svn export $C_CONFIG_SVNOLD_AUTH $S_SQL_SRCDIR/$P_DBMSFOLDER $S_GETSQL_TMP/$APP_VERSION_SQL > /dev/null
	if [ $? -ne 0 ]; then
		echo getsql.sh: unsuccessful svn export. Exiting
		exit 1
	fi

	# convert to UNIX
	f_dos2unix_dir $S_GETSQL_TMP/$APP_VERSION_SQL

	# prepare
	APP_VERSION_SQLPREPARED=$APP_VERSION_SQL.prepared
	echo preparing scripts from $S_GETSQL_TMP/$APP_VERSION_SQL to $S_GETSQL_TMP/$APP_VERSION_SQLPREPARED ...

	echo "processing $P_DBMSTYPE scripts from svn ($APP_VERSION_SQL) to $APP_VERSION_SQLPREPARED ..." >> ./sqlprepare.out.txt
	echo "" >> ./sqlprepare.out.txt

	mkdir -p $S_GETSQL_TMP/$APP_VERSION_SQLPREPARED
	./sqlprepare.sh $P_DBMSTYPE $S_GETSQL_TMP/$APP_VERSION_SQL $S_GETSQL_TMP/$APP_VERSION_SQLPREPARED $S_SQL_SRCDIR | tee -a ./sqlprepare.out.txt
	STATUS=$PIPESTATUS # avalable in sh and bash - from http://stackoverflow.com/questions/985876/tee-and-exit-status

	if [ $STATUS -ne 0 ]; then
		echo getsql.sh: unsuccessful sqlprepare.sh. Exiting
		rm -rf $S_GETSQL_TMP
		exit 1
	else
		# Copy to distibutive
		if [ "$GETOPT_NODIST" != "yes" ]; then
			echo
			echo copying $S_GETSQL_TMP/$APP_VERSION_SQLPREPARED to $C_CONFIG_DISTR_PATH/$S_RELEASE/$P_RELEASEFOLDER ...
			rm -rf $C_CONFIG_DISTR_PATH/$S_RELEASE/$P_RELEASEFOLDER
			mkdir -p $C_CONFIG_DISTR_PATH/$S_RELEASE/$P_RELEASEFOLDER

			if [ "`ls $S_GETSQL_TMP/$APP_VERSION_SQLPREPARED`" = "" ]; then
				echo "release script set is empty, no files found."
			else
				cp -R $S_GETSQL_TMP/$APP_VERSION_SQLPREPARED/* $C_CONFIG_DISTR_PATH/$S_RELEASE/$P_RELEASEFOLDER
			fi
		fi
	fi

	# remove temporary directories
	rm -rf $S_GETSQL_TMP
}

function f_execute_all() {
	f_execute_checkparams

	echo getting scripts from $S_SQL_SRCDIR to $S_GETSQL_TMP/$APP_VERSION_SQL ...

	rm -rf $S_GETSQL_TMP
	mkdir -p $S_GETSQL_TMP

	local folders=`svn list $C_CONFIG_SVNOLD_AUTH $S_SQL_SRCDIR | tr -d "/"`
	if [ "$?" != "0" ]; then
		echo unable to access release at $S_SQL_SRCDIR. Exiting
		exit 1
	fi

	f_getdbms_srcfolders "$folders"
	folders="$S_DBMS_VALUE"

	date > ./sqlprepare.out.txt

	local F_DBMSTYPE
	local F_RELEASEFOLDER
	for folder in $folders; do
		f_getdbms_typebysrcfolder $folder
		F_DBMSTYPE=$S_DBMS_VALUE

		f_getdbms_relfolderbytype $F_DBMSTYPE
		F_RELEASEFOLDER=$S_DBMS_VALUE

		f_execute_dbms $F_DBMSTYPE $folder $F_RELEASEFOLDER
	done
}

f_execute_all
echo getsql.sh: successfully finished.
exit 0
