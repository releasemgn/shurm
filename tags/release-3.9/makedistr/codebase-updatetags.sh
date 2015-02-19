#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SCOPE=$*

. ./common.sh

# check params

# execute

# core and wars
if [ "$SCOPE" = "" ]; then
	SCOPE=all
fi

f_execute_all "$SCOPE" UPDATETAGS

echo codebase-updatetags.sh: tags updated TAG=$TAG
