#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

MODULE=$1

# check params
if [ "$MODULE" = "" ]; then
	echo buildone-core.sh: MODULE not set
	exit 1
fi

. ./common.sh

# execute

echo update tag...
f_execute_core $MODULE UPDATETAGS

export C_TAG=$TAG

echo build...
f_execute_core $MODULE BUILDCORE

echo buildone-core.sh: finished MODULE=$MODULE, TAG=$TAG
