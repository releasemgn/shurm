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

# run in context of deployment scripts
cd $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/deployment

. ./getopts.sh
. ./setenv.sh $P_ENVNAME.xml
. ./common.sh

. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/monitoring.sh

S_TOTALSTATUS=

function f_execute_checknlb() {
	local P_HOST=$1

	if [ "$C_MONITORING_CONF_URL" = "" ]; then
		echo C_MONITORING_CONF_URL is not set. Unable to check database
		exit 1
	fi
	if [ "$C_MONITORING_CONF_POSTDATA" = "" ]; then
		echo C_MONITORING_CONF_POSTDATA is not set. Unable to check database
		exit 1
	fi
	if [ "$C_MONITORING_CONF_SUCCESSTEXT" = "" ]; then
		echo C_MONITORING_CONF_SUCCESSTEXT is not set. Unable to check database
		exit 1
	fi

	# make request
	local F_WGET=`curl http://$P_HOST/$C_MONITORING_CONF_URL --silent --data \'$C_MONITORING_CONF_POSTDATA\' 2>&1`
	echo $F_WGET > $P_DATADIR/$P_ENVNAME/checkdb-$P_HOST.log
	if [[ "$F_WGET" =~ $C_MONITORING_CONF_SUCCESSTEXT ]]; then
		return 0
	fi

	return 1
}

function f_execute_dc() {
	P_DC=$1

	if [ "$C_MONITORING_CONF_DNSPROP" = "" ]; then
		echo C_MONITORING_CONF_DNSPROP is not set. Unable to check database
		exit 1
	fi

	f_env_getdcpropertyfinalvalue $P_DC "$C_MONITORING_CONF_DNSPROP"
	local F_NLBHOST=$C_ENV_XMLVALUE
	f_execute_checknlb $F_NLBHOST

	local F_DCSTATUS=$?
	local F_DCSTATUSTEXT=OK
	if [ "$F_DCSTATUS" != "0" ]; then
		S_TOTALSTATUS=FAILED
		F_DCSTATUSTEXT=FAILED
	fi

	# log
	local F_DATAFILE=$P_DATADIR/$P_ENVNAME/checkdb.dc-$P_DC-history.txt
	echo "`date` - dc=$P_DC, status=$F_DCSTATUSTEXT" >> $F_DATAFILE
}

function f_execute_all() {
	# get dc list
	f_env_getdclist
	local F_DCLIST=$C_ENV_XMLVALUE

	S_TOTALSTATUS=SUCCESS

	# execute
	f_execute_dc $P_DC

	local F_DCMARK
	local F_DCPREFIX
	if [ "$P_DC" != "" ]; then
		F_DCMARK=$P_DC
		F_DCPREFIX="$P_DC."
	else
		F_DCMARK="all"
		F_DCPREFIX=
	fi

	# current total status
	F_DATAFILE=$P_DATADIR/$P_ENVNAME/checkdb.${F_DCPREFIX}current.txt
	F_DATE=`date`
	echo "$F_DATE - status=$S_TOTALSTATUS" > $F_DATAFILE
}

f_execute_all
