#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

PATCHPATH=$1
MODULE=$2
REPOSITORY=$3
MODULEPATH=$4
COMMENT=$5

. ./common.sh

# check params
if [ "$MODULE" = "" ]; then
	echo MODULE not set
	exit 1
fi

# execute
function f_local_vcs_commit_svn() {
	local P_VCS_PATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	if [ ! -d "$PATCHPATH" ]; then
		echo invalid path=$PATCHPATH. Exiting
		exit 1
	fi

	local F_SAVEDIR=`pwd`
	cd $PATCHPATH

	svn commit -m "$COMMENT" $P_SVNAUTH
	local F_RES=$?

	cd $F_SAVEDIR

	if [ $F_RES -ne 0 ]; then
        	echo "vcscommit.sh: having problem to commit $PATCHPATH"
	        exit 1
	fi
}

function f_local_vcs_commit_git() {
	local P_VCS_PATH=$1

	local F_SAVEDIR=`pwd`
	cd $PATCHPATH

	# automatically add modified
	local F_LIST=`git diff --name-only`
	if [ "$F_LIST" != "" ]; then
		git add $F_LIST
	fi

	git commit -m "PGU-0000: set version"
	git push origin

	f_git_getreponame $P_VCS_PATH $REPOSITORY

	echo send to remote in $C_SOURCE_PROJECT.git ...
	f_git_pushmirror $C_GIT_REPONAME

	cd $F_SAVEDIR
}

function f_local_vcs_commit() {
	local MODULE_PATH_TYPE=${MODULEPATH%%:*}
	local MODULE_PATH_DATA=${MODULEPATH##*:}

	if [ "$MODULE_PATH_TYPE" = "svn" ]; then
		f_local_vcs_commit_svn $MODULE_PATH_DATA $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "svnnew" ]; then
		f_local_vcs_commit_svn $MODULE_PATH_DATA $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "git" ]; then
		f_local_vcs_commit_git $MODULE_PATH_DATA

	else
		echo unknown vcs type=$MODULE_PATH_TYPE. Exiting
		exit 1
	fi
}

f_local_vcs_commit

echo vcscommit.sh: done.
exit 0
