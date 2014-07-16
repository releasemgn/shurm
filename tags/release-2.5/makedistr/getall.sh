#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

DISTVERSION=$1
TAG_BUILD=$2
DOWNLOAD_PROJECTSET=$3
DOWNLOAD_PROJECTLIST="$4"
DOWNLOAD_ITEMLIST="$5"
DOWNLOAD_VERSION="$6"

# check params
if [ "$DISTVERSION" = "" ]; then
	echo DISTVERSION not set
	exit 1
fi
if [ "$TAG_BUILD" = "" ]; then
	echo TAG_BUILD not set
	exit 1
fi

. ./common.sh

if [ "$C_CONFIG_ARTEFACTDIR" = "" ]; then
	echo C_CONFIG_ARTEFACTDIR not set
	exit 1
fi

# execute

function f_execute_all() {
	if [ "$DOWNLOAD_VERSION" = "" ]; then
		DOWNLOAD_VERSION=$C_CONFIG_APPVERSION

		if [ "$DOWNLOAD_VERSION" = "" ]; then
			echo "getall.sh: C_CONFIG_APPVERSION is not set in config.sh. Exiting..."
			exit 1
		fi
	fi

	echo DISTVERSION=$DISTVERSION, TAG_BUILD=$TAG_BUILD, VERSION_MODE=$VERSION_MODE, PROJECTSET=$DOWNLOAD_PROJECTSET, PROJECTLIST=$DOWNLOAD_PROJECTLIST, ITEMS=$DOWNLOAD_ITEMLIST, DOWNLOAD_VERSION=$DOWNLOAD_VERSION

	mkdir -p $C_CONFIG_ARTEFACTDIR

	export DISTRDIR=$C_CONFIG_DISTR_PATH/$DISTVERSION # required for serviceCall and storageService processing, even without -dist option
	if [ "$GETOPT_DIST" = "yes" ]; then
		mkdir -p $DISTRDIR
	fi

	if [ "$DOWNLOAD_PROJECT" = "" ]; then
		rm -rf $C_CONFIG_ARTEFACTDIR/*
	fi

	# download core
	if [ "$DOWNLOAD_PROJECTSET" = "core" ] || [ "$DOWNLOAD_PROJECTSET" = "" ]; then
		./getallcore.sh $C_CONFIG_ARTEFACTDIR $DISTVERSION "$DOWNLOAD_PROJECTLIST" "$DOWNLOAD_ITEMLIST" "$DOWNLOAD_VERSION"
	fi

	# download microportals
	if [ "$C_CONFIG_USE_WAR" = "yes" ]; then
		if [ "$DOWNLOAD_PROJECTSET" = "war" ] || [ "$DOWNLOAD_PROJECTSET" = "" ]; then
			./getallwar.sh $C_CONFIG_ARTEFACTDIR $DISTVERSION "$DOWNLOAD_PROJECTLIST" "$DOWNLOAD_VERSION"
		fi
	fi

	local F_RELEASE_FOLDER=$C_CONFIG_APPVERSION_RELEASEFOLDER
	if [ "$GETOPT_RELEASE" != "" ]; then
		if [[ "$GETOPT_RELEASE" =~ ^[0-9]+\.[0-9]+$ ]]; then
			F_RELEASE_FOLDER=major-release-$GETOPT_RELEASE
		else
			F_RELEASE_FOLDER=prod-patch-$GETOPT_RELEASE
		fi
	fi
	
	if [ "$DOWNLOAD_PROJECTSET" = "config" ] || [ "$DOWNLOAD_PROJECTSET" = "" ]; then
		./getallconfig.sh $C_CONFIG_ARTEFACTDIR $C_CONFIG_RELEASE_GROUPFOLDER/$F_RELEASE_FOLDER "$DOWNLOAD_ITEMLIST" "$DOWNLOAD_VERSION"
	fi

	if [ "$DOWNLOAD_PROJECTSET" = "prebuilt" ] || [ "$DOWNLOAD_PROJECTSET" = "" ]; then
		./getallprebuilt.sh $C_CONFIG_ARTEFACTDIR $DISTVERSION "$DOWNLOAD_PROJECTLIST" "$DOWNLOAD_ITEMLIST" "$DOWNLOAD_VERSION"
	fi
}

f_execute_all
