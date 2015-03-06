#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

MODULE=$1
REPOSITORY=$2
MODULEPATH=$3
TAG=$4
TARGET=$5

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
if [ "$TARGET" = "" ]; then
	echo TARGET not set
	exit 1
fi
if [ "$C_CONFIG_SVNOLD_PATH" = "" ]; then
	echo C_CONFIG_SVNOLD_PATH not set
	exit 1
fi

S_TARGET_TYPE=
S_TARGET_NAME=

# execute
function f_local_vcs_copytag_svn() {
	local P_VCS_PATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	# check source status
	local CHECK_NOT_EXISTS=`svn info $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/tags/$TAG 2>&1 | grep "Not a valid"`

	if [ "$CHECK_NOT_EXISTS" != "" ]; then
		echo $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/tags/$TAG: svn path does not exist. Exiting
		exit 1
	fi

	# check destination status
	CHECK_NOT_EXISTS=`svn info $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/$TARGET 2>&1 | grep "Not a valid"`

	if [ "$CHECK_NOT_EXISTS" = "" ]; then
		echo drop new tag - already exists...
		svn delete $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/$TARGET -m "$C_CONFIG_ADM_TRACKER-0000: drop tag before svncopy"
	fi

	svn copy $P_SVNAUTH $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/tags/$TAG $P_SVNPATH/$P_VCS_PATH/$REPOSITORY/$TARGET -m "$C_CONFIG_ADM_TRACKER-0000: copy tag"
}

function f_local_vcs_copytag_git() {
	local P_VCS_PATH=$1

	f_git_getreponame $P_VCS_PATH $REPOSITORY
	local CO_PATH=$C_GIT_REPONAME

	f_git_refreshmirror $CO_PATH
	f_git_getmirrortagstatus $CO_PATH $TAG
	if [ "$?" != "0" ]; then
		echo $CO_PATH: tag $TAG does not exist. Exiting
		exit 1
	fi

	if [ "$S_TARGET_TYPE" = "tag" ]; then
		f_git_getmirrortagstatus $CO_PATH $S_TARGET_NAME
		if [ "$?" = "0" ]; then
			# drop tag
			f_git_dropmirrortag $CO_PATH $S_TARGET_NAME
			f_git_pushmirror $CO_PATH
		fi

		f_git_copymirrortag_fromtag $CO_PATH $TAG $S_TARGET_NAME "$C_CONFIG_ADM_TRACKER-0000: create tag $S_TARGET_NAME from $TAG"
	else
		f_git_getmirrorbranchstatus $CO_PATH $S_TARGET_NAME
		if [ "$?" = "0" ]; then
			# drop branch
			f_git_dropmirrorbranch $CO_PATH $S_TARGET_NAME
			f_git_pushmirror $CO_PATH
		fi

		f_git_copymirrorbranch_fromtag $CO_PATH $TAG $S_TARGET_NAME "$C_CONFIG_ADM_TRACKER-0000: create branch $S_TARGET_NAME from $TAG"
	fi
	f_git_pushmirror $CO_PATH
}

function f_local_vcs_copytag() {
	local MODULE_PATH_TYPE=${MODULEPATH%%:*}
	local MODULE_PATH_DATA=${MODULEPATH##*:}

	# check target
	if [[ "$TARGET" =~ "tags/" ]]; then
		S_TARGET_TYPE=tag
		S_TARGET_NAME=${TARGET##tags/}
	elif [[ "$TARGET" =~ "branches/" ]]; then
		S_TARGET_TYPE=branch
		S_TARGET_NAME=${TARGET##branches/}
	else
		echo unable to handle type from target=$TARGET. Exiting
		exit 1
	fi

	if [ "$MODULE_PATH_TYPE" = "svn" ]; then
		f_local_vcs_copytag_svn $MODULE_PATH_DATA $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "svnnew" ]; then
		f_local_vcs_copytag_svn $MODULE_PATH_DATA $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	elif [ "$MODULE_PATH_TYPE" = "git" ]; then
		f_local_vcs_copytag_git $MODULE_PATH_DATA

	else
		echo unknown vcs type=$MODULE_PATH_TYPE. Exiting
		exit 1
	fi
}

f_local_vcs_copytag

echo vcscopytag.sh: finished MODULE=$MODULE, REPOSITORY=$REPOSITORY, MODULEPATH=$MODULEPATH, TAG=$TAG, TARGET=$TARGET
