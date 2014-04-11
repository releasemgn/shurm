#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

# check params
P_ENVNAME=$1
P_DC=$2

if [ "$P_DC" != "" ]; then
	shift 2
	P_SERVERS=$*
	echo configure environment=$P_ENVNAME, data center=$P_DC, servers=$P_SERVERS...
else
	P_SERVERS=
	echo configure all environments...
fi

# load common functions
. ./common.sh

S_CONFIGURE_ROOT="/tmp/$HOSTNAME.$USER.configure.p$$"
S_CONFIGURE_TEMPLATES=$S_CONFIGURE_ROOT/templates

# execute
function f_local_execute_one() {
	local P_ENVNAME=$1

	echo ========================= configure environment $P_ENVNAME...

	# create staging area
	local F_CONFIGURE_STG_LIVE=$S_CONFIGURE_ROOT/$P_ENVNAME/live
	rm -rf $F_CONFIGURE_STG_LIVE/$P_DC
	mkdir -p $F_CONFIGURE_STG_LIVE/$P_DC
	echo generate configuration files to $F_CONFIGURE_STG_LIVE ...

	# load environment and execute configuring
	. ./setenv.sh $P_ENVNAME
	./configure.sh -dc $P_DC $S_CONFIGURE_TEMPLATES $F_CONFIGURE_STG_LIVE $P_SERVERS
	if [ $? -ne 0 ]; then
		echo "configureall.sh: configure.sh failed. Exiting"
		exit 1
	fi
}

function f_local_execute_allenvs() {
	local ENVSCOPE
	if [ "$P_ENVNAME" = "" ]; then
		# get environment list
		local F_FULLENVLIST=
		for envfile in `find $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/env -name *.xml`; do
			local F_ENVNAME=`basename $envfile | sed "s/.xml$//"`
			F_FULLENVLIST="$F_ENVNAME $F_FULLENVLIST"
		done

		ENVSCOPE="$F_FULLENVLIST"
	else
		ENVSCOPE=$P_ENVNAME
	fi

	# extract templates
	rm -rf $S_CONFIGURE_TEMPLATES
	echo download templates to $S_CONFIGURE_TEMPLATES ...

	local F_TEMPLATE_SOURCE=$C_CONFIG_SVNOLD_PATH/releases/$C_CONFIG_PRODUCT/configuration/templates
	svn export $C_CONFIG_SVNOLD_AUTH $F_TEMPLATE_SOURCE $S_CONFIGURE_TEMPLATES > /dev/null

	# handle dos/unix differences
	f_dos2unix_dir $S_CONFIGURE_TEMPLATES

	if [ ! -d $S_CONFIGURE_TEMPLATES ]; then
		echo f_local_extract_templates: unable to export templates from $F_TEMPLATE_SOURCE to $S_CONFIGURE_TEMPLATES. Exiting
		exit 1
	fi

	local envname
	for envname in $ENVSCOPE; do
		f_local_execute_one $envname
	done
}

# configure all
f_local_execute_allenvs

echo configureall.sh: finished.
