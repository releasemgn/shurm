#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

MODULE=$1
MODULEPATH=$2
TAG1=$3
TAG2=$4

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
function f_local_vcs_renametag_svn() {
	local P_VCS_PATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	# check source status
	local CHECK_NOT_EXISTS=`svn info $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$MODULE/tags/$TAG1 2>&1 | grep "Not a valid"`

	if [ "$CHECK_NOT_EXISTS" != "" ]; then
		echo $P_SVNPATH/$P_VCS_PATH/$MODULE/tags/$TAG1: svn path does not exist. Exiting
		exit 1
	fi

	# check destination status
	CHECK_NOT_EXISTS=`svn info $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$MODULE/tags/$TAG2 2>&1 | grep "Not a valid"`

	if [ "$CHECK_NOT_EXISTS" = "" ]; then
		echo drop new tag - already exists...
		svn delete $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$MODULE/tags/$TAG2 -m "$C_CONFIG_ADM_TRACKER-0000: drop tag before svnrename"
	fi

	svn rename $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$MODULE/tags/$TAG1 $P_SVNPATH/$P_VCS_PATH/$MODULE/tags/$TAG2 -m "$C_CONFIG_ADM_TRACKER-0000: rename tag"
}

function f_local_vcs_renametag_git() {
	local P_VCS_PATH=$1

	f_git_getreponame $P_VCS_PATH $MODULE
	local CO_PATH=$C_GIT_REPONAME

	f_git_refreshmirror $CO_PATH
	f_git_getmirrortagstatus $CO_PATH $TAG1
	if [ "$?" != "0" ]; then
		echo $CO_PATH: tag $TAG1 does not exist. Exiting
		exit 1
	fi

	f_git_getmirrortagstatus $CO_PATH $TAG2
	if [ "$?" = "0" ]; then
		# drop tag
		f_git_dropmirrortag $CO_PATH $TAG2
		f_git_pushmirror $CO_PATH
	fi

	f_git_copymirrortag_fromtag $CO_PATH $TAG1 $TAG2 "$C_CONFIG_ADM_TRACKER-0000: create tag from $TAG1"
	f_git_dropmirrortag $CO_PATH $TAG1
	f_git_pushmirror $CO_PATH
}

function f_local_vcs_renametag() {
	local MODULE_PATH_TYPE=${MODULEPATH%%:*}
	local MODULE_PATH_DATA=${MODULEPATH##*:}

	if [ "$MODULE_PATH_TYPE" = "svn" ]; then
		f_local_vcs_renametag_svn $MODULE_PATH_DATA $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "svnnew" ]; then
		f_local_vcs_renametag_svn $MODULE_PATH_DATA $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "git" ]; then
		f_local_vcs_renametag_git $MODULE_PATH_DATA

	else
		echo unknown vcs type=$MODULE_PATH_TYPE. Exiting
		exit 1
	fi
}

f_local_vcs_renametag

echo vcsrenametag.sh: finished MODULE=$MODULE, MODULEPATH=$MODULEPATH, TAG1=$TAG1, TAG2=$TAG2
