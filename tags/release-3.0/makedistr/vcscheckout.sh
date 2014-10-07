#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

PATCHPATH=$1
MODULE=$2
MODULEPATH=$3
BRANCH=$4
TAG=$5

. ./common.sh

# check params
if [ "$MODULE" = "" ]; then
	echo MODULE not set
	exit 1
fi

# execute
function f_local_vcs_checkout_svn() {
	local P_VCS_PATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	local CO_PATH
	if [ "$TAG" != "" ]; then
		CO_PATH=$P_SVNPATH/$P_VCS_PATH/$MODULE/tags/$TAG
	else
		XBRANCH=$BRANCH
		if [ "$XBRANCH" != "trunk" ]; then
			XBRANCH=branches/$BRANCH
		fi
		CO_PATH=$P_SVNPATH/$P_VCS_PATH/$MODULE/$XBRANCH
	fi

	local F_REVISION=`svn info --non-interactive $P_SVNAUTH $CO_PATH | grep Revision | tr -d " " | cut -d ":" -f2`

	echo "vcscheckout.sh: checkout sources from $CO_PATH (branch=$BRANCH, tag=$TAG, revision=$F_REVISION) to $PATCHPATH..."
	svn co --non-interactive $P_SVNAUTH $CO_PATH $PATCHPATH

	if [ $? -ne 0 ]; then
        	echo "vcscheckout.sh: having problem to check out $CO_PATH"
	        exit 1
	fi
}

function f_local_vcs_checkout_git() {
	local P_VCS_PATH=$1

	f_git_getreponame $P_VCS_PATH $MODULE
	local CO_PATH=$C_GIT_REPONAME

	f_git_refreshmirror $CO_PATH

	if [ "$TAG" != "" ]; then
		f_git_getmirrortagstatus $CO_PATH $TAG
	fi

	echo "vcscheckout.sh: checkout sources from $CO_PATH (branch=$BRANCH, tag=$TAG, revision=$C_GIT_REPOVERSION) to $PATCHPATH..."
	if [ "$TAG" != "" ]; then
		f_git_createlocal_fromtag $CO_PATH $PATCHPATH $TAG
	else
		f_git_createlocal_frombranch $CO_PATH $PATCHPATH $BRANCH
	fi
}

function f_local_vcs_checkout() {
	local MODULE_PATH_TYPE=${MODULEPATH%%:*}
	local MODULE_PATH_DATA=${MODULEPATH##*:}

	if [ "$MODULE_PATH_TYPE" = "svn" ]; then
		f_local_vcs_checkout_svn $MODULE_PATH_DATA $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "svnnew" ]; then
		f_local_vcs_checkout_svn $MODULE_PATH_DATA $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "git" ]; then
		f_local_vcs_checkout_git $MODULE_PATH_DATA

	else
		echo unknown vcs type=$MODULE_PATH_TYPE. Exiting
		exit 1
	fi
}

f_local_vcs_checkout

echo vcscheckout.sh: done.
exit 0
