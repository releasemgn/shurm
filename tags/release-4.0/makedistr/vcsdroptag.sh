#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

MODULE=$1
REPOSITORY=$2
MODULEPATH=$3
TAG=$4

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
if [ "$TAG" = "" ]; then
	echo TAG not set
	exit 1
fi
if [ "$C_CONFIG_SVNOLD_PATH" = "" ]; then
	echo C_CONFIG_SVNOLD_PATH not set
	exit 1
fi

# execute
function f_local_vcs_droptag_svn() {
	local P_VCS_PATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	F_SVNSTATUS=`svn info $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/tags/$TAG 2>&1 | grep -c 'Not a valid URL'`
	if [ "$F_SVNSTATUS" != "0" ]; then
		echo tag $TAG does not exist. Skipped.
		exit 0
	fi

	svn delete $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/tags/$TAG -m "$C_CONFIG_ADM_TRACKER-0000: drop tag"
}

function f_local_vcs_droptag_git() {
	local P_VCS_PATH=$1

	f_git_getreponame $P_VCS_PATH $REPOSITORY
	local CO_PATH=$C_GIT_REPONAME

	f_git_refreshmirror $CO_PATH
	f_git_getmirrortagstatus $CO_PATH $TAG
	if [ "$?" != "0" ]; then
		echo tag $TAG does not exist. Skipped.
		exit 0
	fi

	f_git_dropmirrortag $CO_PATH $TAG
	f_git_pushmirror $CO_PATH
}

function f_local_vcs_droptag() {
	local MODULE_PATH_TYPE=${MODULEPATH%%:*}
	local MODULE_PATH_DATA=${MODULEPATH##*:}

	if [ "$MODULE_PATH_TYPE" = "svn" ]; then
		f_local_vcs_droptag_svn $MODULE_PATH_DATA $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "svnnew" ]; then
		f_local_vcs_droptag_svn $MODULE_PATH_DATA $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "git" ]; then
		f_local_vcs_droptag_git $MODULE_PATH_DATA

	else
		echo unknown vcs type=$MODULE_PATH_TYPE. Exiting
		exit 1
	fi
}

f_local_vcs_droptag

echo vcsdroptag.sh: finished MODULE=$MODULE, REPOSITORY=$REPOSITORY, MODULEPATH=$MODULEPATH, TAG=$TAG
