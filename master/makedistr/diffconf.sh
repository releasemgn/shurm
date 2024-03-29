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
S_DIFF_NEWCOMPS=
S_DIFF_CHGCOMPS=

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

	f_getsubsetexact "$F_DIRCOMPS" "$TARGETS"
	if [ "$C_COMMON_SUBSET" != "$F_DIRCOMPS" ]; then
		echo "targets differ from directory components - target=($TARGETS), checked=($F_DIRCOMPS). Exiting"
		exit 1
	fi

	if [ "$C_COMMON_UNKNOWNSUBSET" != "" ]; then
		echo "unexpected components: $C_COMMON_UNKNOWNSUBSET. Exiting"
		exit 1
	fi

	# verify vs full set of components
	f_distr_getconfcomplist
	local F_ALL=$C_DISTR_CONF_COMPLIST

	f_getsubsetexact "$TARGETS" "$F_ALL"
	if [ "$C_COMMON_UNKNOWNSUBSET" != "" ]; then
		echo "unknown components: $C_COMMON_UNKNOWNSUBSET. Exiting"
		exit 1
	fi
}

function f_local_download_targets() {
	local P_LIVEDIR=$1

	mkdir -p $P_LIVEDIR
	rm -rf $P_LIVEDIR/*

	local F_TEMPLATEDIR=$C_CONFIG_SOURCE_CFG_ROOTDIR/templates

	S_DIFF_NEWCOMPS=
	S_DIFF_CHGCOMPS=
	for comp in $TARGETS; do
		# get comp info and download
		f_distr_getconfcompinfo $comp

		local F_GETPATH=$F_TEMPLATEDIR
		if [ "$C_DISTR_CONF_SUBDIR" != "" ]; then
			F_GETPATH="$F_GETPATH/$C_DISTR_CONF_SUBDIR"
		fi

		local F_CHECK=`svn info $C_CONFIG_SVNOLD_AUTH $F_GETPATH/$comp $P_LIVEDIR/$comp 2>&1 | grep -c "Not a valid URL"`
		if [ "$F_CHECK" = "1" ]; then
			S_DIFF_NEWCOMPS="$S_DIFF_NEWCOMPS $comp"
		else
			svn export $C_CONFIG_SVNOLD_AUTH $F_GETPATH/$comp $P_LIVEDIR/$comp > /dev/null 2>&1
			if [ "$?" != "0" ]; then
				echo "unable to export $F_GETPATH/$comp. Exiting"
				exit 1
			fi

			S_DIFF_CHGCOMPS="$S_DIFF_CHGCOMPS $comp"
		fi
	done

	S_DIFF_NEWCOMPS=${S_DIFF_NEWCOMPS# }
	S_DIFF_CHGCOMPS=${S_DIFF_CHGCOMPS# }

	if [ "$S_DIFF_NEWCOMPS" != "" ]; then
		f_local_out "NEW COMPONENTS: $S_DIFF_NEWCOMPS"
	fi
	if [ "$S_DIFF_CHGCOMPS" != "" ]; then
		f_local_out "UPDATED COMPONENTS: $S_DIFF_CHGCOMPS"
	fi
}

function f_local_check_component_one() {
	local P_CHECKDIR=$1
	local P_COMP=$2

	echo check $P_COMP ...
	f_local_out "UPDATED COMPONENT: $P_COMP"

	if [ "$OUTFILE" = "" ]; then
		diff -b $P_CHECKDIR/$P_COMP $P_COMP
	else
		diff -b $P_CHECKDIR/$P_COMP $P_COMP >> $OUTFILE
	fi
	
	f_local_out "==="
}

function f_local_check_components() {
	local P_CHECKDIR=$1
	local P_LIVEDIR=$2

	if [ "$S_DIFF_CHGCOMPS" = "" ]; then
		echo "no updated components"
		return 0
	fi
		
	# compare updated by component
	f_local_out "==="
	f_local_out "updates:"
	f_local_out "==="

	local F_SAVEDIR=`pwd`
	cd $P_LIVEDIR

	for comp in $S_DIFF_CHGCOMPS; do
		f_local_check_component_one $P_CHECKDIR $comp
	done

	cd $F_SAVEDIR
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

	local F_SAVEDIR=`pwd`
	cd $F_CHECKDIR

	# check actual list
	f_local_check_lists

	# download production configuration targets
	local F_LIVE=$C_CONFIG_ARTEFACTDIR/config.live
	f_local_download_targets $F_LIVE

	cd $F_SAVEDIR

	# check components
	f_local_check_components $F_CHECKDIR $F_LIVE
}

f_local_execute_all

echo diffconf.sh: successfully done
