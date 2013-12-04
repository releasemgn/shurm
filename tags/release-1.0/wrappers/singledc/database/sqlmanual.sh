#!/bin/bash

cd `dirname $0`
RUNPATH=`pwd`

# set env/dc context
. ../_context.sh

cd ../../../database/patches
. ./getopts.sh
. ./setenv.sh $C_CONTEXT_ENV

./sqlmanual.sh -dc $C_CONTEXT_DC $*
