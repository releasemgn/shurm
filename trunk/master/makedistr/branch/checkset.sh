#!/bin/bash 

# Usage example: ./checkset.sh

cd `dirname $0`
. ../getopts.sh
. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..
. ./common.sh

./checkset.sh
