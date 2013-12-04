#!/bin/bash 

cd ..
. ./_context.sh

export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ../../../database
. ./getopts.sh
. ./common.sh

./getsql.sh $C_CONFIG_APPVERSION_RELEASEFOLDER
