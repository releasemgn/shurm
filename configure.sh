#!/bin/bash

cd `dirname $0`

X_ENVLIST="$*"

S_LISTING_FILE=master.files.info

function f_execute_add_wrappers() {
	local P_PREFIX=$1
	local P_ENV=$2
	local P_TYPE=$3

	local L_LISTING_FILE=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/$S_LISTING_FILE
	local L_WRAPPERS_DIR=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/wrappers/$P_TYPE

	# create top wrappers
	local L_FNAME
	local F_DIR
	cat $L_LISTING_FILE | grep "core:wrappers/$P_TYPE/" | sed "s/core:wrappers\/$P_TYPE\///" | while read line; do
		L_FNAME=$line
		if [ ! -f "$L_WRAPPERS_DIR/$L_FNAME" ]; then
			echo "configure.sh: unexpected - missing file $L_WRAPPERS_DIR/$L_FNAME. Exiting"
			exit 1
		fi

		F_DIR=`dirname $L_FNAME`
		mkdir -p $F_DIR

		cp $L_WRAPPERS_DIR/$L_FNAME $F_DIR
		echo "$P_PREFIX/$L_FNAME" >> $L_LISTING_FILE
	done
}

function f_execute_dc() {
	local P_PREFIX=$1
	local P_ENV=$2
	local P_DC=$3
	local P_TYPE=$4

	local L_LISTING_FILE=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/$S_LISTING_FILE

	# make context file
	(
		echo "#!/bin/bash"
		echo ""
		echo "C_CONTEXT_ENV=$P_ENV.xml"
		echo "C_CONTEXT_DC=$P_DC"
	) > _context.sh

	echo "$P_PREFIX/_context.sh" >> $L_LISTING_FILE

	f_execute_add_wrappers $P_PREFIX $P_ENV $P_TYPE
}

function f_execute_env() {
	local P_ENV=$1

	# setup environment
	local F_CURDIR=`pwd`

	export C_CONFIG_PRODUCT_DEPLOYMENT_HOME=`dirname $F_CURDIR`
	cd deployment
	. ./setenv.sh $P_ENV.xml
	. ./common.sh

	echo "configure environment $C_ENV_ID ..."

	# filter out given environment information
	local L_LISTING_FILE=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/$S_LISTING_FILE
	cat $L_LISTING_FILE | grep -v "^env:deployment/$C_ENV_ID/" > tmpfile
	mv tmpfile $L_LISTING_FILE

	# generate environment proxy files
	f_env_getdclist
	local F_DCLIST="$C_ENV_XMLVALUE"
	local F_DCN=`echo $F_DCLIST | wc -w`

	if [ "$F_DCN" = "0" ]; then
		echo "environment has no datacenters defined. Skipped."
		return 1
	fi

	# create env files
	mkdir -p $C_ENV_ID
	cd $C_ENV_ID

	local F_STAT
	if [ "$F_DCN" = "1" ]; then
		f_execute_dc "env:deployment/$C_ENV_ID" $P_ENV $F_DCLIST "singledc"
		F_STAT=$?
		if [ "$F_STAT" != "0" ]; then
			echo "configure.sh: f_execute_dc failed. Exiting"
			exit 1
		fi
	else
		f_execute_add_wrappers "env:deployment/$C_ENV_ID" $P_ENV "multidc-top"
		F_STAT=$?
		if [ "$F_STAT" != "0" ]; then
			echo "configure.sh: f_execute_multi_top failed. Exiting"
			exit 1
		fi

		for dc in $F_DCLIST; do
			if [[ ! "$dc" =~ ^dc\. ]]; then
				echo "configure.sh: invalid dc=$dc, should be dc.xxx. Exiting"
				exit 1
			fi

			mkdir -p $dc
			cd $dc

			f_execute_dc "env:deployment/$C_ENV_ID/$dc" $P_ENV $dc "multidc"
			F_STAT=$?
			if [ "$F_STAT" != "0" ]; then
				echo "configure.sh: f_execute_dc failed. Exiting"
				exit 1
			fi
			cd ..
		done
	fi
}       	

function f_execute_all() {
	# check exists
	local F_CONFUGURE_LIST
	if [ "$X_ENVLIST" != "" ]; then
		F_CONFUGURE_LIST="$X_ENVLIST"
	else
		# by default - configure all in etc/env
		F_CONFUGURE_LIST=`find ../etc/env -type f -name "*.xml" | sed "s/^\.\.\/etc\/env\///;s/\.xml$//" | tr "\n" " "`

		# filter out all environment info from listing file
		cat $S_LISTING_FILE | grep -v "^env:" > tmpfile
		mv tmpfile $S_LISTING_FILE
	fi

	# do configuration
	for env in $F_CONFUGURE_LIST; do
		if [ ! -f "../etc/env/$env.xml" ]; then
			echo "configure.sh: unable to find environment definition file ../etc/env/$env.xml. Exiting"
			exit 1
		fi

		( f_execute_env $env )
	done
}

f_execute_all

echo "configure.sh: successully finished."
