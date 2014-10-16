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
	local P_USEVERSION=$3

	local module
	local F_DEFAULTMODULELIST=
	local F_DEFAULTDISTITEMS=
	local F_MODULEVERSION=
	local F_MODULEITEMS=

	local F_RELEASEMODULELIST="$P_MODULELIST"
	if [ "$F_RELEASEMODULELIST" = "all" ]; then
		F_RELEASEMODULELIST=
	fi

	for module in $F_RELEASEMODULELIST; do
		f_release_getprojectinfo

		# get module dist items in release.xml if any
		f_release_getprojectinfo $P_MODULETYPE $module
		F_MODULEVERSION=$C_RELEASE_PROJECT_VERSION

		if [ "$F_MODULEVERSION" = "" ]; then
			F_MODULEVERSION=$P_USEVERSION
		fi

		f_release_getprojectitems $P_MODULETYPE $module
		F_MODULEITEMS="$C_RELEASE_ITEMS"

		if [ "$F_MODULEITEMS" = "" ]; then
			if [ "$C_RELEASE_ALLITEMS" != "false" ]; then
				# get all project items from source.xml
				f_source_projectitemlist $P_MODULETYPE $module
				F_MODULEITEMS="$C_SOURCE_ITEMLIST"
			fi
		fi

		if [ "$F_MODULEVERSION" = "" ]; then
			F_DEFAULTMODULELIST="$F_DEFAULTMODULELIST $module"
			F_DEFAULTDISTITEMS="$F_DEFAULTDISTITEMS $F_MODULEITEMS"
		else
			# get versioned module items
			if [ "$F_MODULEITEMS" != "" ]; then
				echo executing in makedistr: ./getall.sh $VERSIONDIR $TAG_GETALL $P_MODULETYPE "$module" "$F_MODULEITEMS" "$F_MODULEVERSION"...
				./getall.sh $VERSIONDIR $TAG_GETALL $P_MODULETYPE "$module" "$F_MODULEITEMS" "$F_MODULEVERSION"
			fi
		fi
	done

	F_DEFAULTMODULELIST=${F_DEFAULTMODULELIST# }
	F_DEFAULTDISTITEMS=${F_DEFAULTDISTITEMS# }

	if [ "$F_DEFAULTMODULELIST" != "" ] || [ "$P_MODULELIST" = "all" ]; then		
		echo executing in makedistr: ./getall.sh $VERSIONDIR $TAG_GETALL $P_MODULETYPE "$F_DEFAULTMODULELIST" "$F_DEFAULTDISTITEMS"...
		./getall.sh $VERSIONDIR $TAG_GETALL $P_MODULETYPE "$F_DEFAULTMODULELIST" "$F_DEFAULTDISTITEMS" $P_USEVERSION
	fi
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
		local F_RELEASE_CORE_VERSION=$C_RELEASE_PROJECT_VERSION

		if [ "$F_RELEASE_CORE_TARGETS" != "" ]; then
			echo GET RELEASE CORE TARGETS=$F_RELEASE_CORE_TARGETS, processid=$$...

			local MODULELIST="$F_RELEASE_CORE_TARGETS"
			if [ "$MODULEPROJECTS" != "" ]; then
				MODULELIST=$MODULEPROJECTS
			fi

			f_local_get_projectitems core "$MODULELIST" $F_RELEASE_CORE_VERSION
		fi
	fi

	if [ "$MODULE" = "war" ] || [ "$MODULE" = "" ]; then
		f_release_getprojects war
		local F_RELEASE_WAR_TARGETS=$C_RELEASE_TARGETS
		local F_RELEASE_WAR_VERSION=$C_RELEASE_PROJECT_VERSION

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
			./getall.sh $VERSIONDIR $TAG_GETALL war "$MODULELIST" $F_RELEASE_WAR_VERSION
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
