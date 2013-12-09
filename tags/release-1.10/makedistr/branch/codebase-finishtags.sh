#!/bin/bash 

export VERSION_MODE=branch
export OUTDIR=branch

cd ..
. ./common.sh
./codebase-finishtags.sh

PRODTAGFILE=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/last-prod-tag.txt

echo $C_CONFIG_NEXT_VERSION_BUILD > $PRODTAGFILE
svn commit --username builder --password builder -m "$C_CONFIG_ADM_TRACKER-0000: finish prod tag" $PRODTAGFILE
