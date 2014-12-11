#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SCRIPTDIR=`pwd`

DOWNLOAD_DIR=$1
SVNSOURCEDIR=$2
DOWNLOAD_ITEM_LIST="$3"
DOWNLOAD_VERSION="$4"

. ./common.sh

# check params
if [ "$DOWNLOAD_DIR" = "" ]; then
	echo DOWNLOAD_DIR not set
	exit 1
fi
if [ "$SVNSOURCEDIR" = "" ]; then
	echo SVNSOURCEDIR not set
	exit 1
fi

# execute
S_ENVLIST=

function f_local_copydistr() {
	local P_STGPATH=$1
	local P_COMP_LIST="$2"

	if [ "$DISTRDIR" = "" ]; then
		echo getallconfig.sh: DISTRDIR is not set. Exiting
		exit 1
	else
		rm -rf $DISTRDIR/config
	fi

	echo copy configuration to $DISTRDIR ...
	cp -R $P_STGPATH $DISTRDIR/config
}

function f_local_prepare_templates() {
	local P_STGPATH=$1
	local P_COMP_LIST="$2"

	# check directory contains templates/comp/file with comps from C_DISTR_CONF_COMPLIST
	echo check template files in $P_STGPATH ...
	f_getdirdirs $P_STGPATH
	if [[ ! " $C_COMMON_DIRLIST " =~ " templates " ]]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo configuration files not found in release directory. Skipped.
		fi
		return 1
	fi

	f_getdirdirs $P_STGPATH/templates
	local F_SVNCOMPS="$C_COMMON_DIRLIST"
	f_checkvalidlist "$C_DISTR_CONF_COMPLIST" "$F_SVNCOMPS"

	# delete any comps not in release set
	local comp
	for comp in $F_SVNCOMPS; do
		if [[ ! " $P_COMP_LIST " =~ " $comp " ]]; then
			rm -rf $P_STGPATH/templates/$comp
		else
			echo $P_STGPATH/templates/$comp configuration created.
		fi
	done
}

function f_local_prepare_files_server() {
	local P_STGPATH=$1
	local P_ENV=$2
	local P_DC=$3
	local P_SERVER=$4
	local P_COMP_LIST="$5"

	f_env_getserverconflist $P_DC $P_SERVER
	local F_ENVCOMPLIST="$C_ENV_SERVER_CONFLIST"
	f_getdirdirs $P_STGPATH/$P_ENV/$P_DC/$P_SERVER
	local F_SVNCOMPS="$C_COMMON_DIRLIST"
	f_checkvalidlist "$F_ENVCOMPLIST" "$F_SVNCOMPS"

	# delete any comps not in release set
	local comp
	for comp in $F_SVNCOMPS; do
		if [[ ! " $P_COMP_LIST " =~ " $comp " ]]; then
			rm -rf $P_STGPATH/$P_ENV/$P_DC/$P_SERVER/$comp
		else
			echo $P_STGPATH/$P_ENV/$P_DC/$P_SERVER/$comp configuration created.
		fi
	done
}

function f_local_prepare_files_dc() {
	local P_STGPATH=$1
	local P_ENV=$2
	local P_DC=$3
	local P_COMP_LIST="$4"

	f_env_getxmlserverlist $P_DC "startorder"
	local F_ENVSERVERLIST="$C_ENV_XMLVALUE"
	f_getdirdirs $P_STGPATH/$P_ENV/$P_DC
	local F_SVNSERVERS="$C_COMMON_DIRLIST"
	f_checkvalidlist "$F_ENVSERVERLIST" "$F_SVNSERVERS"

	local envserver
	for envserver in $F_SVNSERVERS; do
		f_local_prepare_files_server $P_STGPATH $P_ENV $P_DC $envserver "$P_COMP_LIST"
	done
}

function f_local_prepare_files_env() {
	local P_STGPATH=$1
	local P_ENV=$2
	local P_COMP_LIST="$3"

	f_env_setpath $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/env/$P_ENV.xml

	f_env_getdclist
	local F_ENVDCLIST="$C_ENV_XMLVALUE"
	f_getdirdirs $P_STGPATH/$P_ENV
	local F_SVNDCS="$C_COMMON_DIRLIST"
	f_checkvalidlist "$F_ENVDCLIST" "$F_SVNDCS"

	local envdc
	for envdc in $F_SVNDCS; do
		f_local_prepare_files_dc $P_STGPATH $P_ENV $envdc "$P_COMP_LIST"
	done
}

function f_local_prepare_files() {
	local P_STGPATH=$1
	local P_COMP_LIST="$2"

	# check directory contains envname/dc/server/comp/file
	echo check configuration files in $P_STGPATH ...

	# get env list
	f_getdirdirs $P_STGPATH
	local F_SVNENVS="$C_COMMON_DIRLIST"
	f_checkvalidlist "$S_ENVLIST" "$F_SVNENVS"

	# check dc
	local envname
	for envname in $F_SVNENVS; do
		f_local_prepare_files_env $P_STGPATH $envname "$P_COMP_LIST"
	done
}

function f_local_exportall() {
	local P_SRCSVNPATH=$1
	local P_STGPATH=$2
	local P_COMP_LIST="$3"

	# remove old
	rm -rf $P_STGPATH

	local F_SVNSTATUS
	if [ "$C_CONFIG_USE_TEMPLATES" = "yes" ]; then
		F_SVNSTATUS=`svn info $C_CONFIG_SVNOLD_AUTH "$P_SRCSVNPATH/templates" 2>&1 | grep -c 'Not a valid URL'`
	else
		F_SVNSTATUS=`svn info $C_CONFIG_SVNOLD_AUTH "$P_SRCSVNPATH" 2>&1 | grep -c 'Not a valid URL'`
	fi

	if [ "$F_SVNSTATUS" != "0" ]; then
		echo getallconfig.sh: no configuration in $F_SRCPATH. Skipped.
		exit 0
	fi

	# download all stored configuration from svn
	echo export configuration from $P_SRCSVNPATH to $P_STGPATH...
	svn export $C_CONFIG_SVNOLD_AUTH $P_SRCSVNPATH $P_STGPATH > /dev/null
	if [ ! -d "$P_STGPATH" ]; then
		echo unable to export configuration from $P_SRCSVNPATH. Exiting
		exit 1
	fi

	# process newlines
	f_dos2unix_dir $P_STGPATH

	# check validity of exported data and remove non-release components
	if [ "$C_CONFIG_USE_TEMPLATES" = "yes" ]; then
		f_local_prepare_templates $P_STGPATH "$P_COMP_LIST"
	else
		f_local_prepare_files $P_STGPATH "$P_COMP_LIST"
	fi
}

function f_local_download_configall() {
	local F_SRCPATH=$C_CONFIG_SOURCE_RELEASEROOTDIR/$SVNSOURCEDIR/config

	echo get configuration to $DOWNLOAD_DIR...
	local F_STGPATH=$DOWNLOAD_DIR/config

	# get components
	f_distr_getconfcomplist
	local F_CONFCOMPLIST=$C_DISTR_CONF_COMPLIST

	if [ "$DOWNLOAD_ITEM_LIST" = "" ]; then
		S_DOWNLOAD_ITEM_LIST=$F_CONFCOMPLIST
	else
		f_checkvalidlist "$F_CONFCOMPLIST" "$DOWNLOAD_ITEM_LIST"
		f_getsubset "$F_CONFCOMPLIST" "$DOWNLOAD_ITEM_LIST"
		S_DOWNLOAD_ITEM_LIST=$C_COMMON_SUBSET
	fi

	if [ "$S_DOWNLOAD_ITEM_LIST" = "" ]; then
		echo getallconfig.sh: no configuration to deploy. Skipped.
		exit 0
	fi

	# get env list
	f_env_getlist_byname
	S_ENVLIST="$C_ENV_LIST"

	echo download configuration items: $S_DOWNLOAD_ITEM_LIST...
	f_local_exportall $F_SRCPATH $F_STGPATH "$S_DOWNLOAD_ITEM_LIST"

	# iterate by environment - copy to distr
	if [ "$GETOPT_DIST" = "yes" ]; then
		f_local_copydistr $F_STGPATH
	fi
}

f_local_download_configall

echo getallconfig.sh: download done.
