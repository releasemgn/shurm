#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

MODULE=$1
REPOSITORY=$2
MODULEPATH=$3
TAG1=$4
TAG2=$5

. ./common.sh

# check params
if [ "$MODULE" = "" ]; then
	echo MODULE not set
	exit 1
fi
if [ "$REPOSITORY" = "" ]; then
	echo REPOSITORY not set
	exit 1
fi
if [ "$TAG1" = "" ]; then
	echo TAG1 not set
	exit 1
fi
if [ "$TAG2" = "" ]; then
	echo TAG2 not set
	exit 1
fi
if [ "$C_CONFIG_SVNOLD_PATH" = "" ]; then
	echo C_CONFIG_SVNOLD_PATH not set
	exit 1
fi

# execute
function f_local_vcs_copynewtag_svn() {
	local P_VCS_PATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	# check source status
	local CHECK_NOT_EXISTS=`svn info $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/tags/$TAG1 2>&1 | grep "Not a valid"`

	if [ "$CHECK_NOT_EXISTS" != "" ]; then
		echo $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/tags/$TAG1: svn path does not exist. Exiting
		exit 1
	fi

	# check destination status
	CHECK_NOT_EXISTS=`svn info $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/tags/$TAG2 2>&1 | grep "Not a valid"`

	if [ "$CHECK_NOT_EXISTS" = "" ]; then
		echo skip copy tag - already exists. Exiting
		exit 0
	fi

	svn copy $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/tags/$TAG1 $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/tags/$TAG2 -m "$C_CONFIG_ADM_TRACKER-0000: copy tag"
}

function f_local_vcs_copynewtag_git() {
	local P_VCS_PATH=$1

	f_git_getreponame $P_VCS_PATH $REPOSITORY
	local CO_PATH=$C_GIT_REPONAME

	f_git_refreshmirror $CO_PATH
	f_git_getmirrortagstatus $CO_PATH $TAG1
	if [ "$?" != "0" ]; then
		echo $CO_PATH: tag $TAG1 does not exist. Exiting
		exit 1
	fi

	f_git_getmirrortagstatus $CO_PATH $TAG2
	if [ "$?" = "0" ]; then
		echo $CO_PATH: tag $TAG2 exists. Exiting
		exit 1
	fi

	f_git_copymirrortag_fromtag $CO_PATH $TAG1 $TAG2 "$C_CONFIG_ADM_TRACKER-0000: create tag from $TAG1"
	f_git_pushmirror $CO_PATH
}

function f_local_vcs_copynewtag() {
	local MODULE_PATH_TYPE=${MODULEPATH%%:*}
	local MODULE_PATH_DATA=${MODULEPATH##*:}

	if [ "$MODULE_PATH_TYPE" = "svn" ]; then
		f_local_vcs_copynewtag_svn $MODULE_PATH_DATA $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "svnnew" ]; then
		f_local_vcs_copynewtag_svn $MODULE_PATH_DATA $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "git" ]; then
		f_local_vcs_copynewtag_git $MODULE_PATH_DATA

	else
		echo unknown vcs type=$MODULE_PATH_TYPE. Exiting
		exit 1
	fi
}

f_local_vcs_copynewtag

echo vcscopynewtag.sh: finished MODULE=$MODULE, REPOSITORY=$REPOSITORY, MODULEPATH=$MODULEPATH, TAG1=$TAG1, TAG2=$TAG2
