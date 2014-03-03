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

export C_TAG1=$TAG1
export C_TAG2=$TAG2

if [ "$SCOPE" = "" ]; then
	SCOPE=all
fi

f_execute_all "$SCOPE" VCSCOPYTAG

echo codebase-copytags.sh: tags $TAG1 copied to $TAG2
