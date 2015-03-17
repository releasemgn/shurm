#!/bin/bash

# generate env availability data

cd `dirname $0`

P_DATADIR=$1
P_ENVNAME=$2
P_DC=$3

if [ "$P_DATADIR" = "" ]; then	
	echo P_DATADIR is not set. Exiting.
	exit 1
fi
if [ "$P_ENVNAME" = "" ]; then	
	echo P_ENVNAME is not set. Exiting.
	exit 1
fi

###########################################################

function f_execute_all() {
	local F_DCMARK
	local F_DCPREFIX
	if [ "$P_DC" != "" ]; then
		F_DCMARK=$P_DC
		F_DCPREFIX="$P_DC."
	else
		F_DCMARK="all"
		F_DCPREFIX=
	fi

	mkdir -p $P_DATADIR/$P_ENVNAME
	local F_DATAFILE_FINAL=$P_DATADIR/$P_ENVNAME/checkenv.${F_DCPREFIX}log
	local F_DATAFILE=$F_DATAFILE_FINAL.running

	# run ./checkenv.sh and extract results to a log file
	cd $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/deployment/$P_ENVNAME

	date > $F_DATAFILE
	./checkenv.sh -dc $P_DC >> $F_DATAFILE 2>&1
	local F_STATUS=$?
	date >> $F_DATAFILE

	# add derived data to cumulative log
	if [ "$F_STATUS" = "0" ]; then
		F_XSTATUS=SUCCESS
	else
		F_XSTATUS=FAILED
	fi

	mv $F_DATAFILE $F_DATAFILE_FINAL

	F_DATAFILE=$P_DATADIR/$P_ENVNAME/checkenv.${F_DCPREFIX}history.txt
	echo `date` - status=$F_XSTATUS >> $F_DATAFILE

	F_DATAFILE=$P_DATADIR/$P_ENVNAME/checkenv.${F_DCPREFIX}current.txt
	echo `date` - status=$F_XSTATUS > $F_DATAFILE
}

f_execute_all
