#!/bin/bash 

MODULE=$1

export VERSION_MODE=branch

cd ..
. ./common.sh

export OUTDIR=branch/$C_CONFIG_VERSION_NEXT_FULL
mkdir -p $OUTDIR

TSVALUE=`date +%Y-%m-%d.%H-%M-%S`
F_SINCE=tags/prod-$C_CONFIG_VERSION_LAST_FULL
F_TILL=tags/prod-$C_CONFIG_VERSION_NEXT_FULL-candidate

./diffbranchsince.sh $F_SINCE $F_TILL $OUTDIR $MODULE > $OUTDIR/getdiff-$TSVALUE.out 2>&1

cd branch
