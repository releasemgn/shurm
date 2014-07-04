#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

BRANCH1=$1
BRANCH2=$2
shift 2

SCOPE=$*

# check params
if [ "$BRANCH1" = "" ]; then
	echo BRANCH1 not set
	exit 1
fi
if [ "$BRANCH2" = "" ]; then
	echo BRANCH2 not set
	exit 1
fi

# execute

. ./common.sh

# core and wars
export C_BRANCH1=$BRANCH1
export C_BRANCH2=$BRANCH2

if [ "$SCOPE" = "" ]; then
	SCOPE=all
fi

f_execute_all "$SCOPE" VCSCOPYBRANCH

echo codebase-copybranch.sh: branch $BRANCH1 copied to $BRANCH2
