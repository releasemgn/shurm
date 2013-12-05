#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

MODULE=$1
MODULEPATH=$2
BRANCH1=$3
BRANCH2=$4

. ./common.sh

# check params
if [ "$MODULE" = "" ]; then
	echo MODULE not set
	exit 1
fi
if [ "$MODULEPATH" = "" ]; then
	echo MODULEPATH not set
	exit 1
fi
if [ "$BRANCH1" = "" ]; then
	echo BRANCH1 not set
	exit 1
fi
if [ "$BRANCH2" = "" ]; then
	echo BRANCH2 not set
	exit 1
fi
if [ "$C_CONFIG_SVNOLD_PATH" = "" ]; then
	echo C_CONFIG_SVNOLD_PATH not set
	exit 1
fi

# execute
function f_local_vcs_renamebranch_svn() {
	local P_VCS_PATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	# check source status
	BRANCH1X=$BRANCH1
	if [ "$BRANCH1X" != "trunk" ]; then
		BRANCH1X=branches/$BRANCH1
	fi
	local CHECK_NOT_EXISTS=`svn info $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$MODULE/$BRANCH1X 2>&1 | grep "Not a valid"`

	if [ "$CHECK_NOT_EXISTS" != "" ]; then
		echo $P_SVNPATH/$P_VCS_PATH/$MODULE/$BRANCH1X: svn path does not exist. Exiting
		exit 1
	fi

	# check destination status
	BRANCH2X=$BRANCH2
	if [ "$BRANCH2X" != "trunk" ]; then
		BRANCH2X=branches/$BRANCH2
	fi
	CHECK_NOT_EXISTS=`svn info $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$MODULE/$BRANCH2X 2>&1 | grep "Not a valid"`

	if [ "$CHECK_NOT_EXISTS" = "" ]; then
		echo drop new branch - already exists...
		svn delete $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$MODULE/$BRANCH2X -m "$C_CONFIG_ADM_TRACKER-0000: drop branch before svnrename"
	fi

	svn rename $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$MODULE/$BRANCH1X $P_SVNPATH/$P_VCS_PATH/$MODULE/$BRANCH2X -m "$C_CONFIG_ADM_TRACKER-0000: rename branch"
}

function f_local_vcs_renamebranch_git() {
	local P_VCS_PATH=$1

	f_git_getreponame $P_VCS_PATH $MODULE
	local CO_PATH=$C_GIT_REPONAME

	f_git_refreshmirror $CO_PATH
	f_git_getmirrorbranchstatus $CO_PATH $BRANCH1
	if [ "$?" != "0" ]; then
		echo $CO_PATH: branch $BRANCH1 does not exist. Exiting
		exit 1
	fi

	f_git_getmirrorbranchstatus $CO_PATH $BRANCH2
	if [ "$?" = "0" ]; then
		# drop branch
		f_git_dropmirrorbranch $CO_PATH $BRANCH2
		f_git_pushmirror $CO_PATH
	fi

	f_git_copymirrorbranch_frombranch $CO_PATH $BRANCH1 $BRANCH2 "$C_CONFIG_ADM_TRACKER-0000: create branch $BRANCH2 from $BRANCH1"
	f_git_dropmirrorbranch $CO_PATH $BRANCH1
	f_git_pushmirror $CO_PATH
}

function f_local_vcs_renamebranch() {
	local MODULE_PATH_TYPE=${MODULEPATH%%:*}
	local MODULE_PATH_DATA=${MODULEPATH##*:}

	if [ "$MODULE_PATH_TYPE" = "svn" ]; then
		f_local_vcs_renamebranch_svn $MODULE_PATH_DATA $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "svnnew" ]; then
		f_local_vcs_renamebranch_svn $MODULE_PATH_DATA $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "git" ]; then
		f_local_vcs_renamebranch_git $MODULE_PATH_DATA

	else
		echo unknown vcs type=$MODULE_PATH_TYPE. Exiting
		exit 1
	fi
}

f_local_vcs_renamebranch

echo vcsrenamebranch.sh: finished MODULE=$MODULE, MODULEPATH=$MODULEPATH, BRANCH1=$BRANCH1, BRANCH2=$BRANCH2
