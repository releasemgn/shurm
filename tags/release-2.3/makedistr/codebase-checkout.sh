#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

TARGETDIR=$1
shift 1

SCOPE=$*

# check params
if [ "$TARGETDIR" = "" ]; then
	echo TARGETDIR not set
	exit 1
fi

# execute

. ./common.sh

# core and wars
export C_TARGETDIR=$TARGETDIR # used in common.sh

if [ "$SCOPE" = "" ]; then
	SCOPE=all
fi

f_execute_all "$SCOPE" VCSCHECKOUT

echo codebase-checkout.sh: finished.
