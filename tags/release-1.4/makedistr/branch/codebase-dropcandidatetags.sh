#!/bin/bash 

export VERSION_MODE=branch
export LAST_PROD_TAG=`cat last-prod-tag.txt`
export OUTDIR=branch

cd ..
./codebase-dropcandidatetags.sh
cd branch
