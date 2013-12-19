#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

TAG1=$1
TAG2=$2
shift 2

SCOPE=$*

# check params
if [ "$TAG1" = "" ]; then
	echo TAG1 not set
	exit 1
fi
if [ "$TAG2" = "" ]; then
	echo TAG2 not set
	exit 1
fi

# execute

. ./common.sh

# core and wars
export C_TAG1=$TAG1
export C_TAG2=$TAG2

if [ "$SCOPE" = "" ]; then
	SCOPE=all
fi

f_execute_all "$SCOPE" VCSRENAMETAG

echo codebase-renametags.sh: tags $TAG1 renamed to $TAG2
