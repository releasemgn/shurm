#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

SCOPE=$*

cd `dirname $0`
. ./getopts.sh

. ./common.sh

# check params
if [ "$C_CONFIG_APPVERSION_TAG" = "" ]; then
	echo C_CONFIG_APPVERSION_TAG not set
	exit 1
fi

# execute

# re-create candidate tags
TAG=$C_CONFIG_APPVERSION_TAG
echo TAG=$TAG

./codebase-droptags.sh $TAG $SCOPE

echo codebase-dropcandidatetags.sh: candidate tags dropped TAG=$TAG
