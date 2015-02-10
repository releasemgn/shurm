#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SOURCE_DIR=$1
P_MODULESET=$2
P_MODULENAME=$3
P_VERSION=$4

USAGE="Usage: ./check-source-code.sh BUILD_DIR/MODULE_PROJECT_NAME"

# check params
if [ -z "$SOURCE_DIR" ]; then
	echo Source code directory not specified
	echo "$USAGE"
        exit 1
fi

if [ "$GETOPT_CHECK" = "no" ]; then
	echo skip codebase checks due to GETOPT_CHECK=no
	exit 0
fi

. ./common.sh

function f_execute_all() {

	# check pom version
	local MAIN_POM_VER=`cat $SOURCE_DIR/pom.xml | sed "s/xmlns/ignore/g;s/xsi://g;s/:xsi/ignore/g" | xmlstarlet sel -t -m "project/version" -v .`

	# check if property
	if [[ "$MAIN_POM_VER" =~ \$\{.*\} ]]; then
		local F_VAR=${MAIN_POM_VER#\${}
		F_VAR=${F_VAR%\}}
		MAIN_POM_VER=`cat $SOURCE_DIR/pom.xml | sed "s/xmlns/ignore/g;s/xsi://g;s/:xsi/ignore/g" | xmlstarlet sel -t -m "project/properties/$F_VAR" -v .`
	fi

	if [ "$MAIN_POM_VER" != "$P_VERSION" ]; then
		echo "invalid pom.xml version: $MAIN_POM_VER, expected $P_VERSION. Exiting"
		exit 1
	fi

	# all checks passed
}

f_execute_all

exit 0
