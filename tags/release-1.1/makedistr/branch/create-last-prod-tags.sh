#!/bin/bash 

# Create tags for all components in last prod release
# Usage examples (run from makedistr/branch) -
# vi last-prod-tag.txt # update vesion when deployed to PROD
# ./create-last-prod-tags.sh

# Copy *-prod tags for all projects from previous release (last-prod-tag minus 1)
# Rename *-prod-candidate tags to *-prod for projects in release.xml (last-prod-tag)

export LAST_PROD_TAG=`cat last-prod-tag.txt`

export VERSION_MODE=branch
cd ..
. ./getopts.sh
. ./common.sh

### function to iterate release.xml (based on makedistr/getall-release.sh)

# read release targets
function f_local_ren_tag_all_release() {

	VERSIONDIR=$1

	# find release description
	local F_FNAME_REL=$C_CONFIG_DISTR_PATH/$VERSIONDIR/release.xml
	f_release_setfile $F_FNAME_REL

	local TAG_VERSION=`echo $VERSIONDIR | cut -d "-" -f1`
	local TAG_rentagALL=prod-${TAG_VERSION}-candidate

	export C_RELEASE_PROPERTY_OBSOLETE=$C_RELEASE_PROPERTY_OBSOLETE

	if [ "$MODULE" = "core" ] || [ "$MODULE" = "" ]; then

		f_release_getprojects core
		local F_RELEASE_CORE_TARGETS=$C_RELEASE_TARGETS

		if [ "$F_RELEASE_CORE_TARGETS" != "" ]; then

			echo Renaming tags RELEASE CORE TARGETS=$F_RELEASE_CORE_TARGETS, processid=$$...

			if [ "$F_RELEASE_CORE_TARGETS" = "all" ]; then
				F_RELEASE_CORE_TARGETS=
			fi

			local MODULELIST="$F_RELEASE_CORE_TARGETS"
			if [ "$MODULEPROJECT" != "" ]; then
				MODULELIST=$MODULEPROJECT
			fi

			./codebase-renametags.sh prod-$PROD_VERSION-candidate prod-$PROD_VERSION core "$MODULELIST"
		fi
	fi

	if [ "$MODULE" = "war" ] || [ "$MODULE" = "" ]; then

		f_release_getprojects war
		local F_RELEASE_WAR_TARGETS=$C_RELEASE_TARGETS

		if [ "$F_RELEASE_WAR_TARGETS" != "" ]; then

			echo Renaming tags RELEASE WAR TARGETS=$F_RELEASE_WAR_TARGETS, processid=$$...

			if [ "$F_RELEASE_WAR_TARGETS" = "all" ]; then
				F_RELEASE_WAR_TARGETS=
			fi

			local MODULELIST="$F_RELEASE_WAR_TARGETS"
			if [ "$MODULEPROJECT" != "" ]; then
				MODULELIST=$MODULEPROJECT
			fi

			./codebase-renametags.sh prod-$PROD_VERSION-candidate prod-$PROD_VERSION war "$MODULELIST"
		fi
	fi

}

PROD_VERSION=$C_CONFIG_VERSIONBRANCH.$LAST_PROD_TAG
PREV_VERSION=$C_CONFIG_VERSIONBRANCH.`expr $LAST_PROD_TAG - 1`

echo -n "Copying prod-$PROD_VERSION tags for all projects from previous release (prod-$PREV_VERSION)... "; sleep 3; echo "started..."

./codebase-copynewtags.sh prod-$PREV_VERSION prod-$PROD_VERSION

echo -n "Renaming prod-$PROD_VERSION-candidate tags to prod-$PROD_VERSION for projects in release.xml... "; sleep 3; echo "started..."

f_local_ren_tag_all_release $PROD_VERSION

cd branch

