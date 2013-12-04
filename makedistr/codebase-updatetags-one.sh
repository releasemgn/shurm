#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

MODULE=$1

# check params
if [ "$MODULE" = "" ]; then
	echo codebase-updatetags-one.sh: MODULE not set
	exit 1
fi

. ./common.sh

# execute
f_execute_all $MODULE UPDATETAGS

echo codebase-updatetags-one.sh: tags updated MODULE=$MODULE
