#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
SCRIPTDIR=`pwd`
cd $SCRIPTDIR

. ./getopts.sh

APP_VERSION_SQL=$1
if [ "$APP_VERSION_SQL" = "" ]; then
	echo getsql.sh: missing APP_VERSION_SQL parameter
	exit 1
fi

APP_VERSION_SQL_MAJOR=$2

. ./common.sh

S_GETSVNINFO_TMP="/tmp/$HOSTNAME.$USER.getsvninfo.p$$"

function f_execute_checkparams() {
	if [ "$APP_VERSION_SQL_MAJOR" = "" ]; then
		APP_VERSION_SQL_MAJOR=$C_CONFIG_RELEASE_GROUPFOLDER
	fi

	if [ "$GETOPT_SCRIPTFOLDER" = "" ]; then
		S_RELEASE=`echo $APP_VERSION_SQL | cut -d "-" -f3`
		if [ "$S_RELEASE" = "" ]; then
			echo getsql.sh: invalid APP_VERSION_SQL parameter format
			exit 1
		fi

		# including subfolders: sql, errors, pending...
		S_SQL_SRCDIR=$C_CONFIG_SOURCE_RELEASEROOTDIR/$APP_VERSION_SQL_MAJOR/$APP_VERSION_SQL 
	else
		S_RELEASE=$GETOPT_SCRIPTFOLDER
		S_SQL_SRCDIR=$C_CONFIG_SOURCE_SQL_GLOBALPENDING/$APP_VERSION_SQL
	fi
}

S_LAST_DIRINDEX=
function f_execute_dir() {
	local P_DIR=$1

	if [[ "$P_DIR" =~ "forms." ]] && [[ ! "$P_DIR" =~ "/" ]]; then
		echo "dir=$P_DIR"
		return 0
	fi

	if [[ "$P_DIR" =~ "war." ]] && [[ ! "$P_DIR" =~ "/" ]]; then
		echo "dir=$P_DIR"
		return 0
	fi

	f_sqlidx_getprefix $P_DIR 0
	S_LAST_DIRINDEX=$S_SQL_DIRID

	echo "dir=$P_DIR, index prefix=$S_LAST_DIRINDEX"
}

function f_execute_file() {
	local P_FILE=$1

	local xrindex=${P_FILE%%-*}
	echo "$P_FILE: $S_LAST_DIRINDEX$xrindex"
}

function f_execute_all() {
	f_execute_checkparams

	echo listing scripts from $S_SQL_SRCDIR ...

	svn list -R $C_CONFIG_SVNOLD_AUTH $S_SQL_SRCDIR/sql > $S_GETSVNINFO_TMP
	cat $S_GETSVNINFO_TMP | while read line; do
		line=`echo $line | sed "s/\r//;s/\n//"`
		if [[ "$line" =~ /$ ]]; then
			f_execute_dir "${line%/}"
		else
			f_execute_file "`basename $line`"
		fi
	done

	rm -rf $S_GETSVNINFO_TMP
}

f_execute_all
exit 0
