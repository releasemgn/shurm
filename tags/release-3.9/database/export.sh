#!/bin/sh

cd `dirname $0`
. ./getopts.sh

P_RUNCONFIG=$1

if [ "$P_RUNCONFIG" = "" ]; then
	echo P_RUNCONFIG is not set. Exiting
	exit 1
fi

P_SCHEMA=$2

. ./common.sh

function f_execute_all() {
	local F_CONFIGPATH=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/datapump/$P_RUNCONFIG.sh
	if [ ! -f "$F_CONFIGPATH" ]; then
		echo $F_CONFIGPATH - configuration file does not exist. Exiting
		exit 1
	fi

	# check server and define database type
	f_get_dbmstype $F_CONFIGPATH
	local F_DBMSTYPE=S_DBMS_TYPE

	# create final execute dir
	local F_EXECUTE_DIR=execute-$P_RUNCONFIG

	rm -rf $F_EXECUTE_DIR
	mkdir $F_EXECUTE_DIR

	# create contents
	# create contents
	cp datapump/* $F_EXECUTE_DIR/
	cp specific/$F_DBMSTYPE.sh $F_EXECUTE_DIR/
	cp specific/datapump/$F_DBMSTYPE/* $F_EXECUTE_DIR/

	echo "C_CONFIG_PRODUCT=$C_CONFIG_PRODUCT" >> $F_EXECUTE_DIR/datapump-config.sh
	echo "C_CONFIG_SVNOLD_PATH=$C_CONFIG_SVNOLD_PATH" >> $F_EXECUTE_DIR/datapump-config.sh
	echo "C_CONFIG_SCHEMAALLLIST=\"$C_CONFIG_SCHEMAALLLIST\"" >> $F_EXECUTE_DIR/datapump-config.sh

	cat $F_EXECUTE_DIR/datapump-default.sh >> $F_EXECUTE_DIR/datapump-config.sh
	cat $F_CONFIGPATH >> $F_EXECUTE_DIR/datapump-config.sh

	local F_TABLELIST=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/datapump/datalight-tables.txt
	cp $F_TABLELIST $F_EXECUTE_DIR/

	# execute
	cd $F_EXECUTE_DIR
	./run-export-std.sh $P_SCHEMA
}

f_execute_all

echo export.sh: successfully finished
