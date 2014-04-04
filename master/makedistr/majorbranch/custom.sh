#!/bin/bash 

cd `dirname $0`
. ../getopts.sh
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

P_PARAMS=$*

# execute
cd ..

./custom.sh $P_PARAMS
