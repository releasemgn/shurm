#!/bin/bash 

export VERSION_MODE=branch
export OUTDIR=branch

cd ..
./codebase-dropcandidatetags.sh
cd branch
