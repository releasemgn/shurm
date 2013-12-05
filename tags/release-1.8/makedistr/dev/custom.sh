#!/bin/bash 

cd `dirname $0`
RUNDIR=`pwd`

. ../getopts.sh

P_PARAMS=$*

# execute
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..

./custom.sh $P_PARAMS
