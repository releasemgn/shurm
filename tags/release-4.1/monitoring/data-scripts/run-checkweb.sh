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

P_URLSET="$*"

if [ "$P_DC" != "all" ]; then
	F_DCMARK=$P_DC
	F_DCPREFIX="$P_DC."
else
	F_DCMARK="all"
	F_DCPREFIX=
fi

###########################################################

S_DETAILS=

function f_execute_checkurl() {
	local P_URL=$1
	local P_FILE=$2

	local F_CMD="wget --spider -S \"$P_URL\""
	echo check url using $F_CMD ...

	local F_WGET=`wget --spider -S "$P_URL" 2>&1`
	local F_STATUS=`echo "$F_WGET" | grep "HTTP/" | awk '{print \$2}' | tail -1`

	if [ "$F_STATUS" != "200" ] && [ "$F_STATUS" != "302" ]; then
		echo "$P_URL=$F_STATUS" >> $P_FILE
		return 1
	fi

	if [[ "$F_WGET" =~ "/static_errors/" ]]; then
		echo "$P_URL=static_errors_page" >> $P_FILE
		return 1
	fi

	echo "$P_URL=OK" >> $P_FILE
	return 0
}

function f_execute_all() {
	mkdir -p $P_DATADIR/$P_ENVNAME
	local F_DATAFILE_FINAL=$P_DATADIR/$P_ENVNAME/checkweb.${F_DCPREFIX}log
	local F_DATAFILE=$F_DATAFILE_FINAL.running

	local F_DATE=`date`
	local F_STATUS
	local F_XSTATUS=SUCCESS

	echo "date=$F_DATE" > $F_DATAFILE
	for url in $P_URLSET; do
		f_execute_checkurl $url $F_DATAFILE
		F_STATUS=$?

		if [ "$F_STATUS" != "0" ]; then
			F_XSTATUS=FAILED
		fi
	done

	echo "STATUS=$F_XSTATUS" >> $F_DATAFILE

	# add derived data to cumulative log
	mv $F_DATAFILE $F_DATAFILE_FINAL

	F_DATAFILE=$P_DATADIR/$P_ENVNAME/checkweb.${F_DCPREFIX}history.txt
	echo "$F_DATE - status=$F_XSTATUS" >> $F_DATAFILE

	F_DATAFILE=$P_DATADIR/$P_ENVNAME/checkweb.${F_DCPREFIX}current.txt
	echo "$F_DATE - status=$F_XSTATUS" > $F_DATAFILE
}

f_execute_all
