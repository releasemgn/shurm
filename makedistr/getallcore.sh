#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SCRIPTDIR=`pwd`

DOWNLOAD_DIR=$1
DISTVERSION=$2
DOWNLOAD_PROJECT_LIST="$3"
DOWNLOAD_ITEM_LIST="$4"

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

function f_local_download_one() {
	local P_TYPE=$1
	local P_PROJECT=$2
	local P_GROUPID=$3
	local P_ARTEFACTID=$4
	local P_EXT=$5

	local F_CLASSIFIER=
	local F_PACKAGING=
	if [ "$P_EXT" = "" ]; then
		F_CLASSIFIER=webstatic

	elif [[ "$P_EXT" =~ ^- ]]; then
		F_CLASSIFIER=${P_EXT%%.*}
		F_CLASSIFIER=${F_CLASSIFIER#-}
		F_PACKAGING=${P_EXT#*.}

	else
		F_PACKAGING=${P_EXT#.}
	fi

	if [ "$P_TYPE" = "pgustatic" ]; then
		local WAR_FILENAME=$P_ARTEFACTID-$C_CONFIG_APPVERSION_SERVICES.war
		local STATIC_FILENAME=$P_ARTEFACTID-$C_CONFIG_APPVERSION_SERVICES-webstatic.tar.gz

		f_downloadnexus_and_copydistr $P_PROJECT $C_CONFIG_NEXUS_REPO $P_GROUPID $P_ARTEFACTID $C_CONFIG_APPVERSION_SERVICES "war"
		f_downloadnexus $P_PROJECT $C_CONFIG_NEXUS_REPO $P_GROUPID $P_ARTEFACTID $C_CONFIG_APPVERSION_SERVICES "tar.gz" "webstatic"
		f_repackage_staticdistr $P_PROJECT $C_CONFIG_APPVERSION_SERVICES $WAR_FILENAME $STATIC_FILENAME

	elif [ "$P_TYPE" = "static" ]; then
		f_downloadnexus_and_copydistr $P_PROJECT $C_CONFIG_NEXUS_REPO $P_GROUPID $P_ARTEFACTID $C_CONFIG_APPVERSION "war"
		f_downloadnexus_and_copydistr $P_PROJECT $C_CONFIG_NEXUS_REPO $P_GROUPID $P_ARTEFACTID $C_CONFIG_APPVERSION "tar.gz" "$F_CLASSIFIER"

	else
		local F_EXTPACKAGING=${C_SOURCE_ITEMEXTENSION##*.}
		f_downloadnexus_and_copydistr $P_PROJECT $C_CONFIG_NEXUS_REPO $P_GROUPID $P_ARTEFACTID $C_CONFIG_APPVERSION "$F_PACKAGING" "$F_CLASSIFIER" "$C_SOURCE_ITEMFOLDER"
	fi
}

function f_local_download_item() {
	local P_PROJECT=$1
	local P_ITEM=$2

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
	f_source_readdistitem core $P_PROJECT $P_ITEM

	local F_GROUPID=${C_SOURCE_ITEMPATH//\//.}

	if [ "$C_SOURCE_ITEMTYPE" = "nexus" ]; then
		f_local_download_one default $P_PROJECT $F_GROUPID $C_SOURCE_ITEMBASENAME $C_SOURCE_ITEMEXTENSION

	elif [ "$C_SOURCE_ITEMTYPE" = "staticwar" ]; then
		f_local_download_one static $P_PROJECT $F_GROUPID $C_SOURCE_ITEMBASENAME $C_SOURCE_ITEMSTATICEXTENSION

	elif [ "$C_SOURCE_ITEMTYPE" = "pgustaticwar" ]; then
		f_local_download_one pgustatic $P_PROJECT $F_GROUPID $C_SOURCE_ITEMBASENAME

	elif [ "$C_SOURCE_ITEMTYPE" = "generated" ]; then
		echo $P_ITEM: item is generated separately. Skipped.
	fi
}

function f_local_download_project() {
	local P_PROJECT=$1

	# get project items
	f_source_projectitemlist core $P_PROJECT
	local F_PROJECT_ITEMS=$C_SOURCE_ITEMLIST

	if [ "$DOWNLOAD_ITEM_LIST" != "" ]; then
		f_getsubset "$F_PROJECT_ITEMS" "$DOWNLOAD_ITEM_LIST"
		F_PROJECT_ITEMS=$C_COMMON_SUBSET
	fi

	# iterate items
	local item
	for item in $F_PROJECT_ITEMS; do
		f_local_download_item $P_PROJECT $item
	done
}

function f_local_download_core() {
	# get projects
	f_source_projectlist core
	local F_PROJECTLIST=$C_SOURCE_PROJECTLIST

	if [ "$DOWNLOAD_PROJECT_LIST" = "" ]; then
		DOWNLOAD_PROJECT_LIST=$F_PROJECTLIST
	else
		f_checkvalidlist "$F_PROJECTLIST" "$DOWNLOAD_PROJECT_LIST"
		f_getsubset "$F_PROJECTLIST" "$DOWNLOAD_PROJECT_LIST"
		DOWNLOAD_PROJECT_LIST=$C_COMMON_SUBSET
	fi

	# iterate by projects
	local project
	for project in $DOWNLOAD_PROJECT_LIST; do
		f_local_download_project $project
	done
}

echo get core binaries to $DOWNLOAD_DIR...

cd $DOWNLOAD_DIR

f_local_download_core

cd $SCRIPTDIR

echo getallcore.sh: download done.
