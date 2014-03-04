#!/bin/bash

cd `dirname $0`
RUNPATH=`pwd`

# set env/dc context
. ./_context.sh

cd ../..
. ./getopts.sh

./configureall.sh $C_CONTEXT_ENV $C_CONTEXT_DC $*
