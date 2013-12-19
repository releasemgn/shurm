#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

MODULE=$1

# check params
if [ "$MODULE" = "" ]; then
	echo MODULE not set
	exit 1
fi

. ./common.sh

# execute

echo buildone-war.sh: MODULE=$MODULE...

echo update tag...
f_execute_wars $MODULE UPDATETAGS

export C_TAG=$TAG

echo build...
f_execute_wars $MODULE BUILDWAR

echo buildone-war.sh: finished MODULE=$MODULE
