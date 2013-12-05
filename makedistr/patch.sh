#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

P_MODULESET=$1
P_MODULENAME=$2
P_MODULEPATH=$3
P_TAG=$4
P_VERSION=$5
P_NEXUS_PATH=$6
P_MODULEOPTIONS=$7
P_BUILDOUTDIR=$8

# check params
if [ "$P_MODULESET" = "" ]; then
	echo patch.sh: P_MODULESET not set
	exit 1
fi
if [ "$P_MODULENAME" = "" ]; then
	echo patch.sh: P_MODULENAME not set
	exit 1
fi
if [ "$P_MODULEPATH" = "" ]; then
	echo patch.sh: P_MODULEPATH not set
	exit 1
fi
if [ "$P_TAG" = "" ]; then
	echo patch.sh: P_TAG not set
	exit 1
fi
if [ "$P_VERSION" = "" ]; then
	echo patch.sh: P_VERSION not set
	exit 1
fi
if [ "$P_NEXUS_PATH" = "" ]; then
	echo patch.sh: P_NEXUS_PATH not set
	exit 1
fi
if [ "$P_MODULEOPTIONS" = "" ]; then
	echo patch.sh: P_MODULEOPTIONS not set
	exit 1
fi
if [ "$P_BUILDOUTDIR" = "" ]; then
	echo patch.sh: P_BUILDOUTDIR not set
	exit 1
fi

if [ "$VERSION_MODE" = "" ]; then
	echo patch.sh: VERSION_MODE not set
	exit 1
fi

# handle build options

if [ `expr match "$P_MODULEOPTIONS" "-M.*"` = 0 ]; then
	echo patch.sh: 'P_MODULEOPTIONS is expected in form -M<options>, options=$P_MODULEOPTIONS'. Exiting
	exit 1
else
	MODULEOPTIONS=${P_MODULEOPTIONS:3}
fi

if [ `expr match "$MODULEOPTIONS" ".*w.*"` != 0 ]; then
	# war build
	export MODULEOPTIONS_WAR=true
fi
if [ `expr match "$MODULEOPTIONS" ".*s.*"` != 0 ]; then
	# add profile for war build
	export MODULEOPTIONS_COMPACT_STATIC=true
fi
if [ `expr match "$MODULEOPTIONS" ".*n.*"` != 0 ]; then
	# replace original files with .new ones
	export MODULEOPTIONS_POMNEW=true
fi
if [ `expr match "$MODULEOPTIONS" ".*v.*"` != 0 ]; then
	# force set version
	export MODULEOPTIONS_SETVERSION=true
fi
if [ `expr match "$MODULEOPTIONS" ".*r.*"` != 0 ]; then
	# clear all snapshots from release
	export MODULEOPTIONS_REPLACESNAPSHOTS=true
fi

# execute

. ./common.sh

function f_execute_all() {
	echo patch.sh: VERSION_MODE=$VERSION_MODE, P_MODULESET=$P_MODULESET, P_MODULENAME=$P_MODULENAME, P_MODULEPATH=$P_MODULEPATH, P_TAG=$P_TAG, P_VERSION=$P_VERSION, P_NEXUS_PATH=$P_NEXUS_PATH, P_MODULEOPTIONS=$P_MODULEOPTIONS, P_BUILDOUTDIR=$P_BUILDOUTDIR > $P_BUILDOUTDIR/$P_MODULENAME-build.log

	local PATCHPATH=$HOME/build/$VERSION_MODE/$P_MODULENAME

	echo rm -rf $PATCHPATH... >> $P_BUILDOUTDIR/$P_MODULENAME-build.log 2>&1
	rm -rf $PATCHPATH 

	# checkout sources
	./patch-checkout.sh $PATCHPATH $P_MODULESET $P_MODULENAME $P_MODULEPATH $P_TAG >> $P_BUILDOUTDIR/$P_MODULENAME-build.log 2>&1
	if [ $? -ne 0 ]; then
		echo "patch.sh: checkout failed. Exiting"
		exit 1
	fi

	# execute source preprocessing
	./patch-preparesource.sh $PATCHPATH $P_MODULESET $P_MODULENAME $P_TAG >> $P_BUILDOUTDIR/$P_MODULENAME-build.log 2>&1
	if [ $? -ne 0 ]; then
		echo "patch.sh: prepare source failed. Exiting"
		exit 1
	fi

	# check source code
	./patch-checksourcecode.sh $PATCHPATH $P_MODULESET $P_MODULENAME $P_VERSION >> $P_BUILDOUTDIR/$P_MODULENAME-build.log 2>&1
	if [ $? -ne 0 ]; then
		echo "patch.sh: maven build skipped - source code invalid ($PATCHPATH). Exiting"
		exit 1
	fi

	# build
	./patch-build.sh $PATCHPATH $P_MODULESET $P_MODULENAME $P_TAG $P_NEXUS_PATH $P_VERSION >> $P_BUILDOUTDIR/$P_MODULENAME-build.log 2>&1
	if [ $? -ne 0 ]; then
		echo "patch.sh: build failed. Exiting"
		exit 1
	fi

	# remove directory if build was successful
	rm -rf $PATCHPATH
}

f_execute_all

echo patch.sh: finished
