#!/bin/bash 

# Usage example: ./checkset.sh

. ./_context.sh
export VERSION_MODE=$C_CONTEXT_VERSIONMODE

cd ..
. ./getopts.sh
. ./common.sh

./checkset.sh
