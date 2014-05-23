#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

TARGETDIR=$1
COMMITMSG=$2
shift 2

SCOPE=$*

# check params
if [ "$TARGETDIR" = "" ]; then
	echo TARGETDIR not set
	exit 1
fi

# execute

. ./common.sh

# core and wars
export C_TARGETDIR=$TARGETDIR
export C_COMMITMSG=$COMMITMSG

if [ "$SCOPE" = "" ]; then
	SCOPE=all
fi

f_execute_all "$SCOPE" VCSCOMMIT

echo codebase-commit.sh: finished.
