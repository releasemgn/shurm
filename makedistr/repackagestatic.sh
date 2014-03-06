#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

BIPROJECT=$1
BIVERSION=$2

# check params
if [ "$BIPROJECT" = "" ]; then
	echo BIPROJECT not set
	exit 1
fi
if [ "$BIVERSION" = "" ]; then
	echo BIVERSION not set
	exit 1
fi

. getopts.sh
. common.sh

WAR_FILENAME=$BIPROJECT-web-$BIVERSION.war
STATIC_FILENAME=$BIPROJECT-web-$BIVERSION-webstatic.tar.gz

F_SCRIPT_SAVEDIR=`pwd`
cd $C_CONFIG_ARTEFACTDIR

f_repackage_staticdistr $BIPROJECT $BIVERSION $WAR_FILENAME $STATIC_FILENAME

cd $F_SCRIPT_SAVEDIR
