#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SCOPE=$*

. ./common.sh

# check params
if [ "$C_CONFIG_APPVERSION_TAG" = "" ]; then
	echo C_CONFIG_APPVERSION_TAG not set
	exit 1
fi
if [ "$C_CONFIG_PROD_TAG" = "" ]; then
	echo C_CONFIG_PROD_TAG not set
	exit 1
fi

# execute

# re-create candidate tags
CANDIDATETAG=$C_CONFIG_APPVERSION_TAG
PRODTAG=$C_CONFIG_PROD_TAG

./codebase-droptags.sh $PRODTAG $SCOPE
./codebase-copytags.sh $CANDIDATETAG $PRODTAG SCOPE

echo codebase-finishtags.sh: tags finished PRODTAG=$PRODTAG
