#!/bin/bash 

P_PARAMS=$*

# execute
export VERSION_MODE=trunk

cd ..

./custom.sh $P_PARAMS
