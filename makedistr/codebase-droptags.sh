#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

TAG=$1
shift 1

SCOPE=$*

# check params
if [ "$TAG" = "" ]; then
	echo TAG not set
	exit 1
fi

# execute

. ./common.sh

echo C_TAG=$TAG

# core and wars
export C_TAG=$TAG # used in common.sh - VCSDROPTAG

if [ "$SCOPE" = "" ]; then
	SCOPE=all
fi

f_execute_all "$SCOPE" VCSDROPTAG

echo codebase-droptags.sh: tags dropped TAG=$TAG
