#!/bin/bash 

PRODTAGFILE=last-prod-tag.txt

export VERSION_MODE=branch
export LAST_PROD_TAG=`cat $PRODTAGFILE`
export OUTDIR=branch

cd ..
. ./common.sh

./codebase-finishtags.sh
cd branch

echo $C_CONFIG_NEXT_VERSION_BUILD > $PRODTAGFILE
svn commit --username builder --password builder -m "$C_CONFIG_ADM_TRACKER-0000: finish prod tag"
