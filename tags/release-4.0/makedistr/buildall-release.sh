#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

VERSIONDIR=$1
OUTDIR=$2
MODULE=$3
MODULEPROJECTS="$4"

# check params
if [ "$VERSIONDIR" = "" ]; then
	echo buildall-release.sh: VERSIONDIR not set
	exit 1
fi
if [ "$OUTDIR" = "" ]; then
	echo buildall-release.sh: OUTDIR not set
	exit 1
fi

# execute

. ./common.sh

S_BUILDALL_PROJECTS=
S_BUILDALL_PROJECTS_HEAD=
S_BUILDALL_PROJECTS_TAG=
S_BUILDALL_USETAG=

function f_buildall_maketags() {
	local P_PROJECTSET=$1
	local P_TARGETS="$2"
	local P_BRANCH="$3"

	# compare with source set
	f_source_projectlist $P_PROJECTSET
	if [ "$P_TARGETS" = "all" ]; then
		P_TARGETS="$C_SOURCE_PROJECTLIST"
	else
		f_checkvalidlist "$C_SOURCE_PROJECTLIST" "$P_TARGETS"
		f_getsubset "$C_SOURCE_PROJECTLIST" "$P_TARGETS"
		P_TARGETS="$C_COMMON_SUBSET"
	fi

	# check requested
	local F_REQUESTED="$P_TARGETS"
	if [ "$MODULEPROJECTS" != "" ]; then
		f_getsubset "$C_SOURCE_PROJECTLIST" "$MODULEPROJECTS"
		F_REQUESTED="$C_COMMON_SUBSET"
	fi

	f_checkvalidlist "$P_TARGETS" "$F_REQUESTED"
	f_getsubset "$P_TARGETS" "$F_REQUESTED"
	F_REQUESTED=$C_COMMON_SUBSET
	S_BUILDALL_PROJECTS=$F_REQUESTED

	echo BUILD RELEASE $P_PROJECTSET TARGETS=$S_BUILDALL_PROJECTS, processid=$$...

	# create tags
	if [ "$GETOPT_TAG" != "" ]; then
		S_BUILDALL_USETAG=$GETOPT_TAG
	else
		if [ "$GETOPT_RELEASE" != "" ]; tthen
			S_BUILDALL_USETAG="prod-$GETOPT_RELEASE-candidate"
		else
			f_execute_getversionmode_defaulttag
			S_BUILDALL_USETAG=$C_TAG
		fi
	fi

	# scan requested for tags
	S_BUILDALL_PROJECTS_HEAD=
	S_BUILDALL_PROJECTS_TAG=
	for project in $S_BUILDALL_PROJECTS; do
		f_release_getprojectinfo $P_PROJECTSET $project
		if [ "$C_RELEASE_PROJECT_TAG" = "" ]; then
			local F_BRANCH=$C_RELEASE_PROJECT_BRANCH
			if [ "$F_BRANCH" = "" ]; then
				F_BRANCH=$P_BRANCH
			fi

			if [ "$F_BRANCH" = "" ]; then
				S_BUILDALL_PROJECTS_HEAD="$S_BUILDALL_PROJECTS_HEAD $project"
			else
				# set required tag to release branch
				export C_TAG=$S_BUILDALL_USETAG
				export C_CONFIG_BRANCHNAME=$F_BRANCH
				f_execute_set $P_PROJECTSET "$project" VCSSETBRANCHTAG
			fi
		else
			S_BUILDALL_PROJECTS_TAGPAIR="$S_BUILDALL_PROJECTS_TAG $project=$C_RELEASE_PROJECT_TAG"
		fi
	done

	S_BUILDALL_PROJECTS_HEAD=${S_BUILDALL_PROJECTS_HEAD## }
	S_BUILDALL_PROJECTS_TAGPAIR=${S_BUILDALL_PROJECTS_TAGPAIR## }

	if [ "$S_BUILDALL_PROJECTS_HEAD" != "" ]; then
		echo set default release tag=$S_BUILDALL_USETAG to head in projects=$S_BUILDALL_PROJECTS_HEAD ...
		export C_TAG=
		export C_CONFIG_BRANCHNAME=
		f_execute_all "$S_BUILDALL_PROJECTS_HEAD" UPDATETAGS
	fi

	# copy specific tags
	if [ "$S_BUILDALL_PROJECTS_TAGPAIR" != "" ]; then
		echo set default release tag=$S_BUILDALL_USETAG to specific tag ...
		local F_PROJECT
		local F_SPECIFICTAG
		local pair
		for pair in $S_BUILDALL_PROJECTS_TAGPAIR; do
			F_PROJECT=${pair%%=*}
			F_SPECIFICTAG=${pair##*=}

			echo copy tag=$F_SPECIFICTAG to release tag=$S_BUILDALL_USETAG in project=$F_PROJECT ...
			export C_TAG1=$F_SPECIFICTAG
			export C_TAG2=$S_BUILDALL_USETAG

			f_execute_all "$F_PROJECT" VCSCOPYTAG
		done
	fi
}

function f_buildall_addlog() {
	local P_PROJECTSET=$1
	local P_PROJECT="$2"

	local F_LOG=$OUTDIR/$P_PROJECTSET/$P_PROJECT-build.log
	local F_STATUS=`grep "[INFO|ERROR]] BUILD" $F_LOG`
	if [ "$F_STATUS" = "" ]; then
		F_STATUS="[FATAL] BUILD FAILURE"
	fi

	echo "$P_PROJECT: $F_STATUS (see $F_LOG)" >> $OUTDIR/build.final.out
}

function f_buildall_release_core() {
	local P_TARGETS="$1"
	local P_BRANCH="$2"
	local P_VERSION="$3"

	# analyze build set
	f_buildall_maketags core "$P_TARGETS" "$P_BRANCH"

	echo build tag=$S_BUILDALL_USETAG for core projects=$S_BUILDALL_PROJECTS ...
	export C_TAG=$S_BUILDALL_USETAG
	export C_BUILD_OUTDIR=$OUTDIR/core

	for release_project in $S_BUILDALL_PROJECTS; do
		if [ "$P_VERSION" != "" ]; then
			C_BUILD_APPVERSION=$P_VERSION
		else
			C_BUILD_APPVERSION=$C_CONFIG_APPVERSION
		fi
		f_release_getprojectinfo core $release_project
		if [ "$C_RELEASE_PROJECT_VERSION" != "" ]; then
			C_BUILD_APPVERSION=$C_RELEASE_PROJECT_VERSION
		fi

		export C_BUILD_APPVERSION
		f_execute_core "$release_project" BUILDCORE
		f_buildall_addlog core $release_project
	done
}

function f_buildall_release_war() {
	local P_TARGETS="$1"
	local P_BRANCH="$2"
	local P_VERSION="$3"

	# analyze build set
	f_buildall_maketags war "$P_TARGETS" "$P_BRANCH"

	echo build tag=$S_BUILDALL_USETAG for war projects=$S_BUILDALL_PROJECTS ...
	export C_TAG=$S_BUILDALL_USETAG
	export C_BUILD_OUTDIR=$OUTDIR/war

	for release_project in $S_BUILDALL_PROJECTS; do
		if [ "$P_VERSION" != "" ]; then
			C_BUILD_APPVERSION=$P_VERSION
		else
			C_BUILD_APPVERSION=$C_CONFIG_APPVERSION
		fi
		f_release_getprojectinfo war $release_project
		if [ "$C_RELEASE_PROJECT_VERSION" != "" ]; then
			C_BUILD_APPVERSION=$C_RELEASE_PROJECT_VERSION
		fi

		f_execute_wars "$release_project" BUILDWAR
		f_buildall_addlog war $release_project
	done
}

function f_buildall_release() {
	# find release description
	local F_FNAME_REL=$C_CONFIG_DISTR_PATH/$VERSIONDIR/release.xml
	f_release_setfile $F_FNAME_REL

	f_release_getprojects core
	local F_RELEASE_CORE_TARGETS=$C_RELEASE_TARGETS
	local F_RELEASE_CORE_BRANCH=$C_RELEASE_PROJECTSET_BRANCH
	local F_RELEASE_CORE_VERSION=$C_RELEASE_PROJECTSET_VERSION
	if [ "$F_RELEASE_CORE_BRANCH" = "" ]; then
		F_RELEASE_CORE_BRANCH=$C_CONFIG_BRANCHNAME
	fi

	f_release_getprojects war
	local F_RELEASE_WAR_TARGETS=$C_RELEASE_TARGETS
	local F_RELEASE_WAR_BRANCH=$C_RELEASE_PROJECTSET_BRANCH
	local F_RELEASE_WAR_VERSION=$C_RELEASE_PROJECTSET_VERSION
	if [ "$F_RELEASE_WAR_BRANCH" = "" ]; then
		F_RELEASE_WAR_BRANCH=$C_CONFIG_BRANCHNAME
	fi

	mkdir -p $OUTDIR
	echo FINAL STATUS: > $OUTDIR/build.final.out

	# set tags and build
	if [ "$MODULE" = "core" ] || [ "$MODULE" = "" ]; then
		if [ "$F_RELEASE_CORE_TARGETS" != "" ]; then
			f_buildall_release_core "$F_RELEASE_CORE_TARGETS" "$F_RELEASE_CORE_BRANCH" "$F_RELEASE_CORE_VERSION"
		fi
	fi

	if [ "$MODULE" = "war" ] || [ "$MODULE" = "" ]; then
		if [ "$F_RELEASE_WAR_TARGETS" != "" ]; then
			f_buildall_release_war "$F_RELEASE_WAR_TARGETS" "$F_RELEASE_WAR_BRANCH" "$F_RELEASE_WAR_VERSION"
		fi
	fi

	# getall if requested
	if [ "$GETOPT_DIST" = "yes" ]; then
		echo "get built binaries to distributive..."
		./getall-release.sh $VERSIONDIR $MODULE "$MODULEPROJECTS"
	fi
}

# execute
echo buildall-release.sh VERSIONDIR=$VERSIONDIR

f_buildall_release

echo buildall-release.sh: finished
