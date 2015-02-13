#!/bin/bash 
# Copyright 2011-2015 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

CONFDIR=$1
TARGETS="$2"
OUTFILE=$3

. ./common.sh

# check params
if [ "$CONFDIR" = "" ]; then
	echo CONFDIR not set
	exit 1
fi

# execute

function f_local_out() {
	local P_MSG="$1"

	if [ "$OUTFILE" = "" ]; then
		echo "$P_MSG"
	else
		echo "$P_MSG" >> $OUTFILE
	fi
}

function f_local_check_lists() {
	# get directory component list
	f_getdirdirs .
	local F_DIRCOMPS="$C_COMMON_DIRLIST"
	if [ "$F_DIRCOMPS" = "" ]; then
		if [ "$TARGETS" = "" ]; then
			echo "no configuration in release. Skipped."
			f_local_out "No configuration changes in release."
			exit 0
		fi
	fi

	f_getsubsetexact "$TARGETS" "$F_DIRCOMPS"
	if [ "$C_COMMON_SUBSET" != "$TARGETS" ]; then
		echo "targets differ from directory components - $TARGETS. Exiting"
		exit 1
	fi

	if [ "$C_COMMON_UNKNOWNSUBSET" != "" ]; then
		echo "unexpected components: $C_COMMON_UNKNOWNSUBSET. Exiting"
		exit 1
	fi

	# verify vs full set of components
	f_distr_getconfcomplist
	local F_ALL=$C_DISTR_CONF_COMPLIST

	f_getsubsetexact "$F_ALL" "$TARGETS"
	if [ "$C_COMMON_UNKNOWNSUBSET" != "" ]; then
		echo "unknown components: $C_COMMON_UNKNOWNSUBSET. Exiting"
		exit 1
	fi
}

function f_local_download_targets() {
	local P_LIVEDIR=$1

	mkdir -p $P_LIVEDIR

	local F_TEMPLATEDIR=$C_CONFIG_SOURCE_CFG_ROOTDIR/templates

	echo download targets...
	for comp in $TARGETS; do
		# get comp info and download
		f_distr_getconfcompinfo $comp

		local F_GETPATH=$F_TEMPLATEDIR
		if [ "$C_DISTR_CONF_SUBDIR" != "" ]; then
			F_GETPATH="$F_GETPATH/$C_DISTR_CONF_SUBDIR
		fi

		svn export $C_CONFIG_SVNOLD_AUTH $F_GETPATH $P_LIVEDIR > /dev/null
		if [ "$?" != "0" ]; then
			echo "unable to export $F_GETPATH. Exiting"
			exit 1
		fi
	done
}

function f_local_check_components() {
}

function f_local_execute_all() {
	if [ "$C_CONFIG_USE_TEMPLATES" != "yes" ]; then
		echo "product does not use templates. Exiting"
		exit 1
	fi

	# go to configuration directory
	local F_CHECKDIR=$CONFDIR/templates
	if [ ! -d "$F_CHECKDIR" ]; then
		echo "template directory does not exist. Exiting"
		exit 1
	fi

	rm -rf $OUTFILE

	cd $F_CHECKDIR

	# check actual list
	f_local_check_lists

	# download production configuration targets
	local F_LIVE=$C_CONFIG_ARTEFACTDIR/config.live
	f_local_download_targets $F_LIVE

	rm -rf $F_LIVE
	mkdir -p $F_LIVE

	# check components
	f_local_check_components $F_LIVE
	
}

f_local_execute_all

echo diffconf.sh: successfully done
