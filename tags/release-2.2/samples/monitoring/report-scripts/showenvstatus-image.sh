#!/bin/bash

# generate env availability data

cd `dirname $0`

P_DATADIR=$1
P_REPORTDIR=$2
P_RESOURCEDIR=$3
P_RESCONTEXT=$4
P_ENVNAME=$5
P_DC=$6

if [ "$P_DATADIR" = "" ]; then	
	echo P_DATADIR is not set. Exiting.
	exit 1
fi
if [ "$P_REPORTDIR" = "" ]; then	
	echo P_REPORTDIR is not set. Exiting.
	exit 1
fi
if [ "$P_RESOURCEDIR" = "" ]; then	
	echo P_RESOURCEDIR is not set. Exiting.
	exit 1
fi
if [ "$P_RESCONTEXT" = "" ]; then	
	echo P_RESCONTEXT is not set. Exiting.
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

	# calculate status
	local F_STATUS=OK
	
	local F_DATAFILE=$P_DATADIR/$P_ENVNAME/total.${F_DCPREFIX}current.txt
	if [ -f "$F_DATAFILE" ]; then
		F_ONESTATUS=`cat $F_DATAFILE`
		if [[ ! "$F_ONESTATUS" =~ "status=SUCCESS" ]]; then
			F_STATUS=FAILED
		fi
	fi

	# form report
	if [ "$F_STATUS" = "OK" ]; then
		F_IMAGEFILE="running.jpg"
		F_IMAGETEXT="Environment $P_ENVNAME, dc=$F_DCMARK is up and running"
	else
		F_IMAGEFILE="stopped.jpg"
		F_IMAGETEXT="Environment $P_ENVNAME, dc=$F_DCMARK is not working"
	fi

	local F_REPFILE=overall.$P_ENVNAME.${F_DCPREFIX}html
	cp $P_RESOURCEDIR/imageonly.html $F_REPFILE
	local F_RESCONTEXT=${P_RESCONTEXT//\//\\\/}
	local F_IMAGETEXT=${F_IMAGETEXT//\//\\\/}

	sed -i "s/@IMAGE@/$F_RESCONTEXT\\/$F_IMAGEFILE/g" $F_REPFILE
	sed -i "s/@TEXT@/$F_IMAGETEXT/g" $F_REPFILE
	mv $F_REPFILE $P_REPORTDIR
}

f_execute_all
