#!/bin/bash 

P_PARAMS=$*

# execute
export VERSION_MODE=branch

cd ..

./custom.sh $P_PARAMS
