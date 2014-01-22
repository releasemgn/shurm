#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

VERSION=$1
shift 1

SCOPE=$*

# check params
if [ "$VERSION" = "" ]; then
	echo VERSION not set
	exit 1
fi

# execute

. ./common.sh

# core and wars
export C_VERSION=$VERSION # used in common.sh - SETVERSION

if [ "$SCOPE" = "" ]; then
	SCOPE=all
fi

f_execute_all "$SCOPE" SETVERSION

echo codebase-setversion.sh: finished.
