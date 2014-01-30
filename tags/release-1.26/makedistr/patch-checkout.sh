#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

P_PATCHPATH=$1
P_MODULESET=$2
P_MODULENAME=$3
P_MODULEPATH=$4
P_TAG=$5

# check params
if [ "$P_PATCHPATH" = "" ]; then
	echo patch-checkout.sh: P_PATCHPATH not set
	exit 1
fi
if [ "$P_MODULESET" = "" ]; then
	echo patch-checkout.sh: P_MODULESET not set
	exit 1
fi
if [ "$P_MODULENAME" = "" ]; then
	echo patch-checkout.sh: P_MODULENAME not set
	exit 1
fi
if [ "$P_MODULEPATH" = "" ]; then
	echo patch-checkout.sh: P_MODULEPATH not set
	exit 1
fi
if [ "$P_TAG" = "" ]; then
	echo patch-checkout.sh: P_TAG not set
	exit 1
fi

function f_execute_all() {
	# checkout
	./vcscheckout.sh $P_PATCHPATH $P_MODULENAME $P_MODULEPATH ignore $P_TAG
	if [ $? -ne 0 ]; then
        	echo "patch-checkout.sh: having problem to check out"
	        exit 1
	fi
}

f_execute_all

echo patch-checkout.sh: finished.
