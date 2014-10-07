#!/bin/bash

# generate env availability data

cd `dirname $0`

P_DATADIR=$1
P_REPORTDIR=$2
P_RESOURCEDIR=$3
P_RESCONTEXT=$4
P_ENVNAME=$5
P_MAXSIZE=$6
P_DC=$7

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
if [ "$P_MAXSIZE" = "" ]; then	
	echo P_MAXSIZE is not set. Exiting.
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

	# form report
	DELAYS_GRAPH_SCALE="-l 0 -u $P_MAXSIZE -r"
	NOW=now

	scale="$DELAYS_GRAPH_SCALE"
	geometry="-w 1024 -h 200 -i"

	now="$NOW"
	max_color="#FF0000"
	min_color="#0000FF"
	avg_color="#00FF00"
	color="--color GRID#C0C0C0"

	local F_SAVEDIR=`pwd`
	cd $P_DATADIR/$P_ENVNAME

	local F_CREATEFILE=env.${F_DCPREFIX}png
	local rrdfile=env.${F_DCPREFIX}rrd
	rrdtool graph $F_CREATEFILE \
		$scale -v "secs" -t "$P_ENVNAME, dc=$F_DCMARK checkenv.sh execution time (0 if not running)" \
		$geometry $color \
		--color BACK#E4E4E4 \
		--end $now \
		--start end-1d \
		--x-grid MINUTE:1:HOUR:1:HOUR:1:0:%H \
		DEF:linec=$rrdfile:checkenv-time:MIN:step=60 LINE1:linec$min_color:"Min" \
		DEF:linea=$rrdfile:checkenv-time:AVERAGE:step=60 LINE1:linea$avg_color:"Avg" \
		DEF:lineb=$rrdfile:checkenv-time:MAX:step=60 LINE1:lineb$max_color:"Max" 

	local F_REPFILE=$P_REPORTDIR/overall.$P_ENVNAME.${F_DCPREFIX}png
	mv $F_CREATEFILE $F_REPFILE

	cd $F_SAVEDIR
}

f_execute_all
