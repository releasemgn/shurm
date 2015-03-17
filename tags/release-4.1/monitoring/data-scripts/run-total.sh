#!/bin/bash

# generate web availability data

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
if [ "$P_DC" = "" ]; then	
	echo P_DC is not set. Exiting.
	exit 1
fi
shift 3

if [ "$P_DC" != "all" ]; then
	F_DCMARK=$P_DC
	F_DCPREFIX="$P_DC."
else
	F_DCMARK="all"
	F_DCPREFIX=
fi

###########################################################

function f_create_rrd() {
	local P_FILE=$1

	rrdtool create $P_FILE \
		--start 20150101 \
		--step 60 \
		DS:total:GAUGE:1000:0:U 	\
		DS:checkenv:GAUGE:1000:0:U 	\
		DS:checkenv-time:GAUGE:1000:0:U 	\
		RRA:AVERAGE:0.5:5:1000 \
		RRA:MAX:0.5:5:1000 \
		RRA:MIN:0.5:5:1000
}

function f_add_rrd() {
	local P_DATETS="$1"
	local P_RRDFILE=$2

	local F_CHECKENVFILE=$P_DATADIR/$P_ENVNAME/checkenv.${F_DCPREFIX}log
	local F_DBFILE=$P_DATADIR/$P_ENVNAME/checkdb.${F_DCPREFIX}current.txt
	local F_WEBFILE=$P_DATADIR/$P_ENVNAME/checkweb.${F_DCPREFIX}current.txt
	local F_ENVFILE=$P_DATADIR/$P_ENVNAME/checkenv.${F_DCPREFIX}current.txt

	F_STATUSTOTAL="10"

	if [ -f $F_DBFILE ]; then
		local F_DBSTATUS=`cat $F_DBFILE | tr -d "\n" | cut -d "=" -f2`

		if [ "$F_DBSTATUS" != "SUCCESS" ]; then
			F_STATUSTOTAL="1"
		fi
	fi

	if [ -f $F_WEBFILE ]; then
		local F_WEBSTATUS=`cat $F_WEBFILE | tr -d "\n" | cut -d "=" -f2`

		if [ "$F_WEBSTATUS" != "SUCCESS" ]; then
			F_STATUSTOTAL="1"
		fi
	fi

	if [ -f $F_ENVFILE ]; then
		local F_ENVSTATUS=`cat $F_ENVFILE | tr -d "\n" | cut -d "=" -f2`

		if [ "$F_ENVSTATUS" != "SUCCESS" ]; then
			F_STATUSTOTAL="1"
		fi
	fi

	local F_CHECKTIME
	if [ "$F_STATUSTOTAL" <> "1" ]; then
		# process checkenv
		local X_CHECKSTART=`head -1 $F_CHECKENVFILE | tr -d "\n"`
		local X_CHECKSTOP=`tail -1 $F_CHECKENVFILE | tr -d "\n"`

		F_CHECKTIME=$(($(date -d "$X_CHECKSTOP" "+%s") - $(date -d "$X_CHECKSTART" "+%s")))
	else
		F_CHECKTIME="1"
	fi

	F_DATAFILE=$P_DATADIR/$P_ENVNAME/total.${F_DCPREFIX}current.txt
	echo "$P_DATETS - status=$F_XSTATUS" > $F_DATAFILE

	F_DATAFILE=$P_DATADIR/$P_ENVNAME/total.${F_DCPREFIX}history.txt
	echo "$P_DATETS - status=$F_XSTATUS" >> $F_DATAFILE

	local X_FILE=$P_RRDFILE
	local X_VALUES="$F_STATUSTOTAL:$F_CHECKTIME"
	local X_TS=`date -d "$P_DATETS" "+%s"`

	echo "rrdtool update: $P_DATETS=$X_TS:$X_VALUES" >> $X_FILE.log
	rrdtool update $X_FILE $X_TS:$X_VALUES
}

function f_execute_all() {
	local F_RRDFILE=$P_DATADIR/$P_ENVNAME/env.${F_DCPREFIX}rrd

	if [ ! -f $F_RRDFILE ]; then
		f_create_rrd $F_RRDFILE
	fi

	# calculate total status and add rrd data
	local F_DATE=`date`

	f_add_rrd "$F_DATE" $F_RRDFILE
}

f_execute_all
