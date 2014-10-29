#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

DISTVERSION_SRC=$1
DISTVERSION_DST=$2

# check params
if [ "$DISTVERSION_SRC" = "" ]; then
	echo DISTVERSION_SRC not set
	exit 1
fi
if [ "$DISTVERSION_DST" = "" ]; then
	echo DISTVERSION_DST not set
	exit 1
fi

. ./common.sh

# execute

echo create release $DISTVERSION_SRC distr based on $DISTVERSION_DST distr...

function f_local_prepare() {
	if [ ! -f "$C_CONFIG_DISTR_PATH/$DISTVERSION_SRC/release.xml" ]; then
		echo invalid source release $DISTVERSION_SRC. Exiting
		exit 1
	fi

	# get destination set
	local F_FNAME_REL_DST=$C_CONFIG_DISTR_PATH/$DISTVERSION_DST/release.xml
	f_release_setfile $F_FNAME_REL_DST

	# directory should be empty
	local F_FILESET=`find $C_CONFIG_DISTR_PATH/$DISTVERSION_DST -maxdepth 1 -type f | grep -v "release.xml"`
	if [ "$F_FILESET" != "" ]; then
		echo $C_CONFIG_DISTR_PATH/$DISTVERSION_DST is not empty. Exiting
		exit 1
	fi
}

function f_local_executeall() {
	f_local_prepare

	# set params for copy-releaseproject.sh
	C_RELEASE_COPY_SRCDIR=$DISTVERSION_SRC
	C_RELEASE_COPY_DSTDIR=$DISTVERSION_DST

	# copy wars and core
	f_execute_all all COPYRELEASETORELEASE

	# copy servicecall and storageservice if any
	if [ -f "$C_CONFIG_DISTR_PATH/$DISTVERSION_SRC/servicecall-$C_CONFIG_APPVERSION.ear" ]; then
		./getallwar-app.sh $C_CONFIG_ARTEFACTDIR "ignore" $DISTVERSION_DST $DISTVERSION_SRC
	fi
}

f_local_executeall

echo copy-release.sh: finished.
