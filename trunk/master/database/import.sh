#!/bin/sh

cd `dirname $0`
. ./getopts.sh

P_RUNCONFIG=$1
P_CMD=$2

if [ "$P_RUNCONFIG" = "" ]; then
	echo P_RUNCONFIG is not set. Exiting
	exit 1
fi
if [ "$P_CMD" = "" ]; then
	echo P_CMD is not set. Exiting
	exit 1
fi

P_SCHEMA=$3

. ../../etc/config.sh

if [ "$C_CONFIG_PRODUCT_DEPLOYMENT_HOME" = "" ]; then
	echo C_CONFIG_PRODUCT_DEPLOYMENT_HOME is not defined. Exiting
	exit 1
fi

function f_execute_all() {
	local F_CONFIGPATH=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/datapump/$P_RUNCONFIG.sh
	if [ ! -f "$F_CONFIGPATH" ]; then
		echo $F_CONFIGPATH - configuration file does not exist. Exiting
		exit 1
	fi

	local F_TABLELIST=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/datapump/datalight-tables.txt

	# create final execute dir
	F_EXECUTE_DIR=execute-$P_RUNCONFIG-$P_CMD
	rm -rf $F_EXECUTE_DIR
	mkdir $F_EXECUTE_DIR

	# create contents
	cp datapump/* $F_EXECUTE_DIR/
	cat $F_CONFIGPATH >> $F_EXECUTE_DIR/datapump-config.sh
	cp $F_TABLELIST $F_EXECUTE_DIR/

	# execute
	cd $F_EXECUTE_DIR
	./run-import-std.sh $P_CMD $P_SCHEMA
}

f_execute_all
