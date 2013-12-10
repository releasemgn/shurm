#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

VERSIONDIR=$1
MODULE=$2
MODULEPROJECTS="$3"

# check params
if [ "$VERSIONDIR" = "" ]; then
	echo getall-release.sh: VERSIONDIR not set
	exit 1
fi

# override params by options
if [ "$GETOPT_RELEASE" != "" ]; then
	VERSIONDIR=$GETOPT_RELEASE
fi

OUTDIR=$VERSION_MODE/$VERSIONDIR
mkdir -p $OUTDIR

# execute

. ./common.sh

function f_local_get_projectitems() {
	local P_MODULETYPE=$1
	local P_MODULELIST="$2"

	local F_DISTITEMS=
	local module
	for module in $P_MODULELIST; do
		# get module dist items in release.xml if any
		f_release_getprojectitems $P_MODULETYPE $module

		if [ "$C_RELEASE_ITEMS" != "" ]; then
			F_DISTITEMS="$F_DISTITEMS $C_RELEASE_ITEMS"
		else
			if [ "$C_RELEASE_ALLITEMS" != "false" ]; then
				# get all project items from source.xml
				f_source_projectitemlist $P_MODULETYPE $module
				F_DISTITEMS="$F_DISTITEMS $C_SOURCE_ITEMLIST"
			fi
		fi
	done

	F_DISTITEMS=${F_DISTITEMS% }
	F_DISTITEMS=${F_DISTITEMS# }
		
	echo executing in makedistr: ./getall.sh $VERSIONDIR $TAG_GETALL $P_MODULETYPE "$MODULELIST" "$F_DISTITEMS"...
	./getall.sh $VERSIONDIR $TAG_GETALL $P_MODULETYPE "$MODULELIST" "$F_DISTITEMS"
}

# read release targets
function f_local_getall_release() {
	# find release description
	local F_FNAME_REL=$C_CONFIG_DISTR_PATH/$VERSIONDIR/release.xml
	f_release_setfile $F_FNAME_REL

	local TAG_VERSION=`echo $VERSIONDIR | cut -d "-" -f1`
	local TAG_GETALL=prod-${TAG_VERSION}-candidate

	export C_RELEASE_PROPERTY_OBSOLETE=$C_RELEASE_PROPERTY_OBSOLETE

	if [ "$MODULE" = "core" ] || [ "$MODULE" = "" ]; then
		f_release_getprojects core
		local F_RELEASE_CORE_TARGETS=$C_RELEASE_TARGETS

		if [ "$F_RELEASE_CORE_TARGETS" != "" ]; then
			echo GET RELEASE CORE TARGETS=$F_RELEASE_CORE_TARGETS, processid=$$...

			if [ "$F_RELEASE_CORE_TARGETS" = "all" ]; then
				F_RELEASE_CORE_TARGETS=
			fi

			local MODULELIST="$F_RELEASE_CORE_TARGETS"
			if [ "$MODULEPROJECTS" != "" ]; then
				MODULELIST=$MODULEPROJECTS
			fi

			f_local_get_projectitems core "$MODULELIST"
		fi
	fi

	if [ "$MODULE" = "war" ] || [ "$MODULE" = "" ]; then
		f_release_getprojects war
		local F_RELEASE_WAR_TARGETS=$C_RELEASE_TARGETS

		if [ "$F_RELEASE_WAR_TARGETS" != "" ]; then

			if [ "$F_RELEASE_WAR_TARGETS" = "all" ]; then
				F_RELEASE_WAR_TARGETS=
			fi

			local MODULELIST="$F_RELEASE_WAR_TARGETS"
			if [ "$MODULEPROJECTS" != "" ]; then
				MODULELIST=$MODULEPROJECTS
			fi

			echo downloading from Nexus - $MODULELIST
			echo RELEASE WAR TARGETS: $F_RELEASE_WAR_TARGETS, processid=$$...

			echo executing in makedistr: ./getall.sh $VERSIONDIR $TAG_GETALL war "$MODULELIST"
			./getall.sh $VERSIONDIR $TAG_GETALL war "$MODULELIST"
		fi
	fi

	if [ "$MODULE" = "config" ] || [ "$MODULE" = "" ]; then
		f_release_getconfcomplist
		local F_RELEASE_CONFIG_TARGETS=$C_RELEASE_CONFCOMPLIST

		if [ "$F_RELEASE_CONFIG_TARGETS" != "" ]; then
			echo RELEASE CONFIG TARGETS: $F_RELEASE_CONFIG_TARGETS...

			if [ "$F_RELEASE_CONFIG_TARGETS" = "all" ]; then
				F_RELEASE_CONFIG_TARGETS=
			fi

			echo executing in makedistr: ./getall.sh $VERSIONDIR $TAG_GETALL config "$F_RELEASE_CONFIG_TARGETS"
			./getall.sh $VERSIONDIR $TAG_GETALL config ignore "$F_RELEASE_CONFIG_TARGETS"
		fi
	fi

	if [ "$MODULE" = "prebuilt" ] || [ "$MODULE" = "" ]; then
		f_release_getprojects prebuilt
		local F_RELEASE_PREBUILT_TARGETS=$C_RELEASE_TARGETS

		if [ "$F_RELEASE_PREBUILT_TARGETS" != "" ]; then
			echo GET RELEASE PREBUILT TARGETS=$F_RELEASE_PREBUILT_TARGETS, processid=$$...

			if [ "$F_RELEASE_PREBUILT_TARGETS" = "all" ]; then
				F_RELEASE_PREBUILT_TARGETS=
			fi

			local MODULELIST="$F_RELEASE_PREBUILT_TARGETS"
			if [ "$MODULEPROJECTS" != "" ]; then
				MODULELIST=$MODULEPROJECTS
			fi

			f_local_get_projectitems prebuilt "$MODULELIST"
		fi
	fi

}

# execute
echo getall-release.sh VERSIONDIR=$VERSIONDIR

f_local_getall_release

echo getall-release.sh: finished
