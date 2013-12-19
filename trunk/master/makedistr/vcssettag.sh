#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

MODULE=$1
MODULEPATH=$2
BRANCH=$3
TAG=$4
BRANCHDATE=$5

. ./common.sh

# check params
if [ "$MODULE" = "" ]; then
	echo MODULE not set
	exit 1
fi
if [ "$BRANCH" = "" ]; then
	echo BRANCH not set
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
function f_local_vcs_settag_svn() {
	local P_VCS_PATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	if [ "$BRANCHDATE" != "" ]; then
		svn copy $P_SVNAUTH --revision {"$BRANCHDATE"} $P_SVNPATH/$P_VCS_PATH/$MODULE/$BRANCH $P_SVNPATH/$P_VCS_PATH/$MODULE/tags/$TAG -m "$C_CONFIG_ADM_TRACKER-0000: create tag"
	else
		svn copy $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$MODULE/$BRANCH $P_SVNPATH/$P_VCS_PATH/$MODULE/tags/$TAG -m "$C_CONFIG_ADM_TRACKER-0000: create tag"
	fi
}

function f_local_vcs_settag_git() {
	local P_VCS_PATH=$1

	f_git_getreponame $P_VCS_PATH $MODULE
	local CO_PATH=$C_GIT_REPONAME

	local CO_BRANCH=$BRANCH
	if [[ "$CO_BRANCH" =~ "branches/" ]]; then
		CO_BRANCH=${CO_BRANCH#branches/}
	fi

	f_git_refreshmirror $CO_PATH
	f_git_setmirrortag $CO_PATH $CO_BRANCH $TAG "$C_CONFIG_ADM_TRACKER-0000: create tag" $BRANCHDATE
	f_git_pushmirror $CO_PATH
}

function f_local_vcs_settag() {
	local MODULE_PATH_TYPE=${MODULEPATH%%:*}
	local MODULE_PATH_DATA=${MODULEPATH##*:}

	echo MODULE=$MODULE, MODULEPATH=$MODULEPATH, BRANCH=$BRANCH, TAG=$TAG ...
	./vcsdroptag.sh $MODULE $MODULEPATH $TAG
	if [ "$?" != "0" ]; then
		exit 1
	fi

	if [ "$MODULE_PATH_TYPE" = "svn" ]; then
		f_local_vcs_settag_svn $MODULE_PATH_DATA $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "svnnew" ]; then
		f_local_vcs_settag_svn $MODULE_PATH_DATA $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "git" ]; then
		f_local_vcs_settag_git $MODULE_PATH_DATA

	else
		echo unknown vcs type=$MODULE_PATH_TYPE. Exiting
		exit 1
	fi
}

f_local_vcs_settag

echo vcssettag.sh: done.
