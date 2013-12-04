#!/bin/bash 

MODULE=$1

export VERSION_MODE=branch
export LAST_PROD_TAG=`cat last-prod-tag.txt`

cd ..
. ./common.sh

export OUTDIR=branch/$C_CONFIG_VERSIONBRANCH.$C_CONFIG_NEXT_VERSION_BUILD
mkdir -p $OUTDIR

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
F_SINCE=tags/prod-$C_CONFIG_VERSIONBRANCH.$C_CONFIG_LAST_VERSION_BUILD
F_TILL=tags/prod-$C_CONFIG_VERSIONBRANCH.$C_CONFIG_NEXT_VERSION_BUILD-candidate

./diffbranchsince.sh $F_SINCE $F_TILL $OUTDIR $MODULE > $OUTDIR/getdiff-$TSVALUE.out 2>&1

cd branch
