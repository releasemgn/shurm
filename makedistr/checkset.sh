#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh
. ./common.sh

# execute

function f_execute_all() {
	# get active set
	local F_ACTIVE=`set | grep "^C_CONFIG_" | cut -d "=" -f1 | tr "\n" " "`

	# get required set
	local F_REQUIRED=`cat ~/common/codebase/config.txt | grep "^C_CONFIG_" | tr "\t" ":" | cut -d ":" -f1 | tr "\n" " "`

	# get unknown variables
	F_STATUS=OK
	for var in $F_ACTIVE; do
		if [[ ! " $F_REQUIRED " =~ " $var " ]]; then
			echo "unknown: $var"
			F_STATUS=FAILED
		fi
	done

	for var in $F_REQUIRED; do
		if [[ ! " $F_ACTIVE " =~ " $var " ]]; then
			echo "missing: $var"
			F_STATUS=FAILED
		fi
	done

	echo status=$F_STATUS
}

f_execute_all
