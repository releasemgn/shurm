#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SRCVER=$1
shift 1

SCOPE=$*

# check params
if [ "$SRCVER" = "" ]; then
	echo SRCVER not set
	exit 1
fi

. ./common.sh

# execute

# re-create candidate tags
TAG=$SRCVER-candidate
echo set TAG=$TAG

./codebase-droptags.sh $TAG $SCOPE

echo codebase-dropoldcandidatetags.sh: old tags dropped TAG=$TAG
