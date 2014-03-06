#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

PATCHPATH=$1
MODULE=$2
MODULEPATH=$3
BRANCH=$4
TAG=$5
DOWNLOADFILE=$6

. ./common.sh

# check params
if [ "$MODULE" = "" ]; then
	echo MODULE not set
	exit 1
fi

# execute
function f_local_vcs_export_svn() {
	local P_VCS_PATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	local CO_PATH
	if [ "$TAG" != "" ]; then
		CO_PATH=$P_SVNPATH/$P_VCS_PATH/$MODULE/tags/$TAG/$DOWNLOADFILE
	else
		CO_PATH=$P_SVNPATH/$P_VCS_PATH/$MODULE/branches/$BRANCH/$DOWNLOADFILE
	fi

	echo "vcsexport.sh: export sources from $CO_PATH to $PATCHPATH..."
	svn export --non-interactive $P_SVNAUTH $CO_PATH $PATCHPATH

	if [ $? -ne 0 ]; then
        	echo "vcsexport.sh: having problem to export $CO_PATH"
	        exit 1
	fi
}

function f_local_vcs_export_git() {
	local P_VCS_PATH=$1

	f_git_getreponame $P_VCS_PATH $MODULE
	local CO_PATH=$C_GIT_REPONAME

	echo "vcsexport.sh: export sources from $CO_PATH (branch=$BRANCH, tag=$TAG) to $PATCHPATH..."
	f_git_refreshmirror $CO_PATH
	if [ "$TAG" != "" ]; then
		f_git_export_fromtag $CO_PATH $PATCHPATH $TAG $DOWNLOADFILE
	else
		f_git_export_frombranch $CO_PATH $PATCHPATH $BRANCH $DOWNLOADFILE
	fi
}

function f_local_vcs_export() {
	local MODULE_PATH_TYPE=${MODULEPATH%%:*}
	local MODULE_PATH_DATA=${MODULEPATH##*:}

	if [ "$MODULE_PATH_TYPE" = "svn" ]; then
		f_local_vcs_export_svn $MODULE_PATH_DATA $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "svnnew" ]; then
		f_local_vcs_export_svn $MODULE_PATH_DATA $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "git" ]; then
		f_local_vcs_export_git $MODULE_PATH_DATA

	else
		echo unknown vcs type=$MODULE_PATH_TYPE. Exiting
		exit 1
	fi
}

f_local_vcs_export

echo vcsexport.sh: done.
exit 0
