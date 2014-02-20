#!/bin/bash 

P_PARAMS=$*

# execute
export VERSION_MODE=majorbranch

cd ..

./custom.sh $P_PARAMS
