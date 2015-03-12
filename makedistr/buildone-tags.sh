#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

BUILDOUTDIR=$1
MODULESET=$2
MODULE=$3
REPOSITORY=$4
MODULEPATH=$5
TAG=$6
MODULEOPTIONS=$7
MODULEVERSION=$8

# check params
if [ "$BUILDOUTDIR" = "" ]; then
	echo buildone-tags.sh: BUILDOUTDIR not set
	exit 1
fi
if [ "$MODULESET" = "" ]; then
	echo buildone-tags.sh: MODULESET not set
	exit 1
fi
if [ "$MODULE" = "" ]; then
	echo buildone-tags.sh: MODULE not set
	exit 1
fi
if [ "$REPOSITORY" = "" ]; then
	echo buildone-tags.sh: REPOSITORY not set
	exit 1
fi
if [ "$MODULEPATH" = "" ]; then
	echo buildone-tags.sh: MODULEPATH not set
	exit 1
fi
if [ "$TAG" = "" ]; then
	echo buildone-tags.sh: TAG not set
	exit 1
fi
if [ "$MODULEOPTIONS" = "" ]; then
	echo buildone-tags.sh: MODULEOPTIONS not set
	exit 1
fi

. ./common.sh

function f_execute_alltags() {
	if [ "$MODULEVERSION" = "" ]; then
		if [ "$C_CONFIG_APPVERSION" = "" ]; then
			echo buildone-tags.sh: C_CONFIG_APPVERSION not set
			exit 1
		fi
		MODULEVERSION=$C_CONFIG_APPVERSION
	fi

	# execute
	echo MODULESET=$MODULESET, MODULE=$MODULE, REPOSITORY=$REPOSITORY, TAG=$TAG, VERSION=$MODULEVERSION, MODULEOPTIONS=$MODULEOPTIONS
	mkdir -p $BUILDOUTDIR

	# checkout sources
	local F_NEXUS_PATH=$C_CONFIG_NEXUS_BASE/content/repositories/$C_CONFIG_NEXUS_REPO
	./patch.sh $MODULESET $MODULE $REPOSITORY $MODULEPATH $TAG $MODULEVERSION $F_NEXUS_PATH $MODULEOPTIONS $BUILDOUTDIR
	if [ $? -ne 0 ]; then
		BUILDSTATUS=FAILED
	else
		BUILDSTATUS=SUCCESSFUL
	fi

	# check status
	echo buildone-tags.sh: build finished for MODULE=$MODULE, TAG=$TAG, VERSION=$MODULEVERSION, BUILDSTATUS=$BUILDSTATUS
	if [ "$BUILDSTATUS" != "SUCCESSFUL" ]; then
		exit 1
	fi
}

f_execute_alltags

exit 0
