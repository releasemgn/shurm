#!/bin/bash

cd `dirname $0`
RUNPATH=`pwd`

# set env/dc context
. ./_context.sh

cd ..
. ./getopts.sh
. ./setenv.sh $C_CONTEXT_ENV

echo "`date`: execute ./svnrestoreconfigs.sh -dc $C_CONTEXT_DC $*" >> $RUNPATH/deploy.log
./svnrestoreconfigs.sh -dc $C_CONTEXT_DC $*
