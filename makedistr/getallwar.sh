#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SCRIPTDIR=`pwd`

DOWNLOAD_DIR=$1
DISTVERSION=$2
DOWNLOAD_PROJECTS="$3"
DOWNLOAD_VERSION="$4"

. ./common.sh

# check params
if [ "$DOWNLOAD_DIR" = "" ]; then
	echo DOWNLOAD_DIR not set
	exit 1
fi

# execute

cd $DOWNLOAD_DIR

# download new ones
echo get web portals and static DOWNLOAD_PROJECTS=$DOWNLOAD_PROJECTS to $DOWNLOAD_DIR...
if [ "$DOWNLOAD_PROJECTS" = "" ]; then
	echo download all wars...
	f_execute_wars all DOWNLOADWAR
else
	for item in $DOWNLOAD_PROJECTS; do
		echo download war=$item...
		f_execute_wars $item DOWNLOADWAR
	done
fi

cd $SCRIPTDIR

./getallwar-app.sh $DOWNLOAD_DIR $DISTVERSION

echo getallwar.sh: dowload done.
