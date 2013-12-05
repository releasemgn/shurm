#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

MARKER=$1
FILENAME=$2
FILENAMEDIFF=$3
MODULE=$4
MODULEPATH=$5
SUBNEXT=$6
SUBPREV=$7

# check params
if [ "$MARKER" = "" ]; then
	echo MARKER not set
	exit 1
fi
if [ "$FILENAME" = "" ]; then
	echo FILENAME not set
	exit 1
fi
if [ "$FILENAMEDIFF" = "" ]; then
	echo FILENAMEDIFF not set
	exit 1
fi
if [ "$MODULE" = "" ]; then
	echo MODULE not set
	exit 1
fi
if [ "$MODULEPATH" = "" ]; then
	echo MODULEPATH not set
	exit 1
fi
if [ "$SUBNEXT" = "" ]; then
	echo SUBNEXT not set
	exit 1
fi
if [ "$SUBPREV" = "" ]; then
	echo SUBPREV not set
	exit 1
fi

# execute

. ./common.sh

function f_local_vcs_diffbranchtag_svn() {
	local P_VCS_PATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	local TMPFILE=$FILENAME.tmp

	# get tag and branch revisions
	local REVSUBPREV=`svn $P_SVNAUTH log $P_SVNPATH/$P_VCS_PATH/$MODULE/$SUBPREV -l 1 | grep "^r" | cut -d" " -f1 | cut -d"r" -f2`
	local REVSUBNEXT=`svn $P_SVNAUTH log $P_SVNPATH/$P_VCS_PATH/$MODULE/$SUBNEXT -l 1 | grep "^r" | cut -d" " -f1 | cut -d"r" -f2`

	echo = $MODULE...
	(
		echo = $MODULE:
		echo "============================================================================================"
		SEDFROM=${SUBPREV//\//\\/}
		SEDTO=${SUBNEXT//\//\\/}
		svn $P_SVNAUTH diff --summarize --old $P_SVNPATH/$P_VCS_PATH/$MODULE/$SUBPREV --new $P_SVNPATH/$P_VCS_PATH/$MODULE/$SUBNEXT | sed "s/$SEDFROM/$SEDTO/g" > $TMPFILE

		echo $MODULE: >> $FILENAME
		echo "============================================================================================" >> $FILENAME
		echo REVSUBPREV=$REVSUBPREV >> $FILENAME
		echo REVSUBNEXT=$REVSUBNEXT >> $FILENAME
		svn $P_SVNAUTH info $P_SVNPATH/$P_VCS_PATH/$MODULE/$SUBNEXT >> $FILENAME

		local LOGFILE=$FILENAME.commits

		echo "$SVNPATH/$P_VCS_PATH/$MODULE/$SUBNEXT:" >> $LOGFILE
		local F_SEDCMD=
		local jira
		for jira in $C_CONFIG_COMMIT_TRACKERLIST; do
			if [ "$F_SEDCMD" != "" ]; then
				F_SEDCMD="$F_SEDCMD;"
			fi
			F_SEDCMD="${F_SEDCMD}s/^$jira/$MARKER\:$jira/"
		done

		cat $TMPFILE | grep -v "=" | sed "s/ [ ]*/ /g" | while read fline; do
			local fop=`echo $fline | cut -d " " -f1`
			local fname=`echo $fline | cut -d " " -f2`

			if [ "xx$fop" = "xx" ] || [ "xx$fop" = "xxD" ]; then
				echo $fname, fop=$fop - ignored >> $LOGFILE
			else
				echo $fname >> $LOGFILE
				echo "==============================================================" >> $LOGFILE
				svn $P_SVNPATH log $fname -r$REVSUBPREV:$REVSUBNEXT | sed "$F_SEDCMD" >> $LOGFILE
				echo execute: svn log $fname -r$REVSUBPREV:$REVSUBNEXT >> $FILENAME
				echo "." >> $LOGFILE
			fi
		done

		cat $TMPFILE
	) >> $FILENAMEDIFF

	rm $TMPFILE
}

function f_local_vcs_diffbranchtag() {
	local MODULE_PATH_TYPE=${MODULEPATH%%:*}
	local MODULE_PATH_DATA=${MODULEPATH##*:}

	echo get diff between $SUBPREV and $SUBNEXT for module=$MODULE ...
	if [ "$MODULE_PATH_TYPE" = "svn" ]; then
		f_local_vcs_diffbranchtag_svn $MODULE_PATH_DATA $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "svnnew" ]; then
		f_local_vcs_diffbranchtag_svn $MODULE_PATH_DATA $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	else
		echo unknown vcs type=$MODULE_PATH_TYPE. Exiting
		exit 1
	fi
}

f_local_vcs_diffbranchtag

echo vcsdiffbranchtag.sh: finished.
