#!/bin/bash

# generate web availability data

cd `dirname $0`

P_DATADIR=$1
P_ENVNAME=$2

if [ "$P_DATADIR" = "" ]; then	
	echo P_DATADIR is not set. Exiting.
	exit 1
fi
if [ "$P_ENVNAME" = "" ]; then	
	echo P_ENVNAME is not set. Exiting.
	exit 1
fi
shift 2

P_URLSET="$*"

###########################################################

S_DETAILS=

function f_add_rrd() {
	P_DATETS="$1"

	local F_CHECKENVFILE=$P_DATADIR/$P_ENVNAME/checkenv.log
	local F_DBFILE=$P_DATADIR/$P_ENVNAME/checkdb.current.txt
	local F_WEBFILE=$P_DATADIR/$P_ENVNAME/checkweb.current.txt
	local F_ENVFILE=$P_DATADIR/$P_ENVNAME/checkenv.current.txt

	local F_DBSTATUS=`if [ -f $F_DBFILE ]; then cat $F_DBFILE | tr -d "\n" | cut -d "=" -f2; fi`
	local F_WEBSTATUS=`if [ -f $F_WEBFILE ]; then cat $F_WEBFILE | tr -d "\n" | cut -d "=" -f2; fi`
	local F_ENVSTATUS=`if [ -f $F_ENVFILE ]; then cat $F_ENVFILE | tr -d "\n" | cut -d "=" -f2; fi`

	F_STATUSTOTAL="10"
	F_DBVALUE="10"
	if [ "$F_DBSTATUS" != "SUCCESS" ]; then
		F_DBVALUE="1"
		F_STATUSTOTAL="1"
	fi

	F_WEBVALUE="10"
	if [ "$F_WEBSTATUS" != "SUCCESS" ]; then
		F_WEBVALUE="1"
		F_STATUSTOTAL="1"
	fi

	F_STATUSENV="10"
	if [ "$F_ENVSTATUS" != "SUCCESS" ]; then
		F_STATUSENV="1"
		F_STATUSTOTAL="1"
	fi

	# process checkenv
	X_CHECKSTART=`head -1 $F_CHECKENVFILE | tr -d "\n"`
	X_CHECKSTOP=`tail -1 $F_CHECKENVFILE | tr -d "\n"`
	F_CHECKTIME=$(($(date -d "$X_CHECKSTOP" "+%s") - $(date -d "$X_CHECKSTART" "+%s")))

	F_XSTATUS=SUCCESS
	if [ "$F_STATUSTOTAL" = "1" ]; then
		F_CHECKTIME="1"
		F_XSTATUS=FAILED
	fi

	F_DATAFILE=$P_DATADIR/$P_ENVNAME/total.current.txt
	echo "$F_DATE - status=$F_XSTATUS" > $F_DATAFILE

	F_DATAFILE=$P_DATADIR/$P_ENVNAME/total.history.txt
	echo "$F_DATE - status=$F_XSTATUS" >> $F_DATAFILE

	local F_RRDFILE=$P_DATADIR/$P_ENVNAME/env.rrd
	~/common/monitoring/rrd-fill.sh $F_RRDFILE "$P_DATETS" $F_STATUSTOTAL $F_STATUSENV $F_DBVALUE $F_WEBVALUE $F_CHECKTIME
}

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
	local F_DATAFILE_FINAL=$P_DATADIR/$P_ENVNAME/checkweb.log
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

	F_DATAFILE=$P_DATADIR/$P_ENVNAME/checkweb.history.txt
	echo "$F_DATE - status=$F_XSTATUS" >> $F_DATAFILE

	F_DATAFILE=$P_DATADIR/$P_ENVNAME/checkweb.current.txt
	echo "$F_DATE - status=$F_XSTATUS" > $F_DATAFILE

	# calculate total status and add rrd data
	f_add_rrd "$F_DATE"
}

f_execute_all
