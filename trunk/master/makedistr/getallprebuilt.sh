#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SCRIPTDIR=`pwd`

DOWNLOAD_DIR=$1
DISTVERSION=$2
DOWNLOAD_PROJECT_LIST="$3"
DOWNLOAD_ITEM_LIST="$4"
DOWNLOAD_VERSION="$5"

. ./common.sh

# check params
if [ "$DOWNLOAD_DIR" = "" ]; then
	echo DOWNLOAD_DIR not set
	exit 1
fi
if [ "$DISTVERSION" = "" ]; then
	echo DISTVERSION not set
	exit 1
fi
if [ "$C_CONFIG_APPVERSION" = "" ]; then
	echo C_CONFIG_APPVERSION not set
	exit 1
fi

# execute

function f_local_download_svn() {
	local P_ITEMPATH=$1
	local P_SVNPATH=$2
	local P_SVNAUTH=$3

	# download
	local F_BASENAME=`basename $P_ITEMPATH`
	rm -rf $F_BASENAME
	svn export $P_SVNAUTH $P_SVNPATH/$P_ITEMPATH > /dev/null

	if [ ! -f "$F_BASENAME" ]; then
		echo $P_SVNPATH/$P_ITEMPATH is not found. Skipped.
		return 1
	fi

	# copy to distr if required
	if [ "$GETOPT_DIST" = "yes" ]; then
		if [ "$DISTRDIR" = "" ]; then
			echo getallprebuilt.sh: DISTRDIR is not set.
			exit 1
		fi

		echo copy $F_BASENAME to $DISTRDIR...
		cp $F_BASENAME $DISTRDIR
	fi
}

function f_local_download_nexus() {
	local P_PROJECT=$1
	local P_ITEMPATH=$2

	local F_REPO=$C_CONFIG_NEXUS_BASE/content/repositories/$C_CONFIG_NEXUS_REPO
	if [ "$P_PROJECT" = "thirdparty" ]; then
		F_REPO=$C_CONFIG_NEXUS_PATH_THIRDPARTY
	fi

	# download
	local F_FULLPATH=$F_REPO/$P_ITEMPATH
	f_download_and_copydistr $P_PROJECT $F_FULLPATH
}

function f_local_download_item() {
	local P_PROJECT=$1
	local P_ITEM=$2
	local P_GETVERSION=$3

	# get dist item details
	f_distr_readitem $P_ITEM
	local F_ISOBSOLETE=$C_DISTR_OBSOLETE

	# compare with release information
	if [ "$C_RELEASE_PROPERTY_OBSOLETE" = "false" ] && [ "$F_ISOBSOLETE" = "true" ]; then
		return 1
	fi
	if [ "$C_RELEASE_PROPERTY_OBSOLETE" = "true" ] && [ "$F_ISOBSOLETE" = "false" ]; then
		return 1
	fi

	# get source item details
	f_source_readdistitem prebuilt $P_PROJECT $P_ITEM

	if [ "$C_SOURCE_ITEMTYPE" = "svn" ]; then
		local F_ITEMPATH=`echo $C_SOURCE_ITEMPATH | sed "s/@RELEASE@/$P_GETVERSION/g"`
		f_local_download_svn $F_ITEMPATH $C_CONFIG_SVNOLD_PATH "$C_CONFIG_SVNOLD_AUTH"

	elif [ "$C_SOURCE_ITEMTYPE" = "svnnew" ]; then
		local F_ITEMPATH=`echo $C_SOURCE_ITEMPATH | sed "s/@RELEASE@/$P_GETVERSION/g"`
		f_local_download_svn $F_ITEMPATH $C_CONFIG_SVNNEW_PATH "$C_CONFIG_SVNNEW_AUTH"

	elif [ "$C_SOURCE_ITEMTYPE" = "nexus" ]; then
		if [ "$C_SOURCE_ITEMVERSION" != "" ]; then
			P_GETVERSION=$C_SOURCE_ITEMVERSION
		fi
		local F_ITEMPATH=$C_SOURCE_ITEMPATH/$C_SOURCE_ITEMBASENAME/$P_GETVERSION/$C_SOURCE_ITEMBASENAME-$P_GETVERSION$C_SOURCE_ITEMEXTENSION
		f_local_download_nexus $P_PROJECT $F_ITEMPATH

	else
		echo getallprebuilt.sh: unsupported prebuilt type=$C_SOURCE_ITEMTYPE
	fi
}

function f_local_download_project() {
	local P_PROJECT=$1
	local P_GETVERSION=$2

	# get project items
	f_source_projectitemlist prebuilt $P_PROJECT
	local F_PROJECT_ITEMS=$C_SOURCE_ITEMLIST

	if [ "$DOWNLOAD_ITEM_LIST" != "" ]; then
		f_getsubset "$F_PROJECT_ITEMS" "$DOWNLOAD_ITEM_LIST"
		F_PROJECT_ITEMS=$C_COMMON_SUBSET
	fi

	# iterate items
	local item
	for item in $F_PROJECT_ITEMS; do
		f_local_download_item $P_PROJECT $item $P_GETVERSION
	done
}

function f_local_download_prebuilt() {
	# get projects
	f_source_projectlist prebuilt
	local F_PROJECTLIST=$C_SOURCE_PROJECTLIST

	if [ "$DOWNLOAD_PROJECT_LIST" = "" ]; then
		DOWNLOAD_PROJECT_LIST=$F_PROJECTLIST
	else
		f_checkvalidlist "$F_PROJECTLIST" "$DOWNLOAD_PROJECT_LIST"
		f_getsubset "$F_PROJECTLIST" "$DOWNLOAD_PROJECT_LIST"
		DOWNLOAD_PROJECT_LIST=$C_COMMON_SUBSET
	fi

	# handle version
	local F_GETVERSION=$DOWNLOAD_VERSION
	if [ "$F_GETVERSION" = "" ]; then
		F_GETVERSION=$DISTVERSION
	fi

	# iterate by projects
	local project
	for project in $DOWNLOAD_PROJECT_LIST; do
		f_local_download_project $project $F_GETVERSION
	done
}

echo get prebuilt binaries to $DOWNLOAD_DIR...

cd $DOWNLOAD_DIR

f_local_download_prebuilt

cd $SCRIPTDIR

echo getallprebuilt.sh: download done.
