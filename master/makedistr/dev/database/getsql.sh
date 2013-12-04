#!/bin/bash 

export LAST_PROD_TAG=`cat ../last-prod-tag.txt`

cd ..
. ./_context.sh

export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ../../../database
. ./getopts.sh
. ./common.sh

./getsql.sh $C_CONFIG_APPVERSION_RELEASEFOLDER
