#!/bin/sh
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`

P_LIMITTIME=$1
P_CHECK_SCRIPT=$2

if [ "$P_LIMITTIME" = "" ]; then
	echo P_LIMITTIME not set. Exiting
	exit 1
fi
if [ "$P_CHECK_SCRIPT" = "" ]; then
	echo P_CHECK_SCRIPT not set. Exiting
	exit 1
fi

shift 2

# execute specific check script
if [ ! -f "./data-scripts/$P_CHECK_SCRIPT" ]; then
	echo "`date`: unable to execute missing `pwd`/data-scripts/$P_CHECK_SCRIPT. Exiting" >> check.log
	exit 1
fi

# load profiles settings
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

if [ -f ~/.bash_profile ]; then
	. ~/.bash_profile
fi

F_DATADIR=~/monitoring.info/$C_CONFIG_PRODUCT/data

echo "`date`: execute `pwd`/data-scripts/$P_CHECK_SCRIPT $F_DATADIR $@ ..." >> check.log
if [ "$P_LIMITTIME" = "0" ]; then
	./data-scripts/$P_CHECK_SCRIPT $F_DATADIR "$@" >> check.log 2>&1
else
	./limittime.sh $P_LIMITTIME ./data-scripts/$P_CHECK_SCRIPT $F_DATADIR "$@" >> check.log 2>&1
fi
