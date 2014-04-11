#!/bin/bash


P_SRCDIR=$1

function f_run_cmd() {
	local P_COMMON_HOSTLOGIN="$1"
	local P_CMD="$2"

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo "$P_COMMON_HOSTLOGIN cmd: $P_CMD ..."
	fi

	RUN_CMD_RES=
	if [ "$P_COMMON_HOSTLOGIN" = "local" ]; then
		RUN_CMD_RES=`(eval $P_CMD) 2>&1`
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
			RUN_CMD_RES=`ssh -i $C_ENV_PROPERTY_KEYNAME -n $P_COMMON_HOSTLOGIN "$P_CMD" 2>&1`
			if [ $? -ne 0 ]; then
				return 1
			fi
		else
			RUN_CMD_RES=`ssh -n $P_COMMON_HOSTLOGIN "$P_CMD" 2>&1`
			if [ $? -ne 0 ]; then
				return 1
			fi
		fi
	fi
	return 0
}

function f_find_file() {
	local P_SRCDIR=$1
	local P_XBASENAME=$2
	local P_XEXTENTION=$3
	local P_XHOSTLOGIN=$4

	if [ "$P_XHOSTLOGIN" = "" ] || [ "$P_XHOSTLOGIN" = "local" ]; then
		C_COMMON_FINDFILE_NAME=`if [ -d "$P_SRCDIR" ]; then cd $P_SRCDIR; find . -maxdepth 1 -type f -name "*$P_XEXTENTION" | egrep "./$P_XBASENAME$P_XEXTENTION|./.*[0-9]-$P_XBASENAME$P_XEXTENTION|./$P_XBASENAME-[0-9].*$P_XEXTENTION"; fi`
	else
		f_run_cmd $P_XHOSTLOGIN "if [ -d "$P_SRCDIR" ]; then cd $P_SRCDIR; find . -maxdepth 1 -type f -name \"*$P_XEXTENTION\" | egrep \"./$P_XBASENAME$P_XEXTENTION|./.*[0-9]-$P_XBASENAME$P_XEXTENTION|./$P_XBASENAME-[0-9].*$P_XEXTENTION\"; fi"
		C_COMMON_FINDFILE_NAME=$RUN_CMD_RES
	fi

	local F_LOCAL_COUNT=`echo "$C_COMMON_FINDFILE_NAME" | wc -l`
	if [ "$F_LOCAL_COUNT" != "1" ]; then
		local F_SHOWNAMES=`echo $C_COMMON_FINDFILE_NAME | tr "\n" " "`
		echo "f_find_file: too many files ($F_SHOWNAMES) with $P_XBASENAME$P_XEXTENTION exist in $P_SRCDIR. Exiting."
		exit 1
	fi
}


function f_redist_findsourcefile() {
	local P_SRCDIR=$1
	
	C_SOURCE_FILE=

	f_find_file $P_SRCDIR $C_DISTR_DISTBASENAME $C_DISTR_EXT $P_DISTR_HOSTLOGIN
	C_SOURCE_FILE=$C_COMMON_FINDFILE_NAME

	# ensure correct file
	if [ "$C_SOURCE_FILE" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo f_redist_findsourcefile: file $C_DISTR_DISTBASENAME$C_DISTR_EXT not found in $P_SRCDIR. Skipped.
		fi
		return 1
	fi

}

function f_execute_all() {
	local P_SRCDIR=$1
	f_redist_findsourcefile $P_SRCDIR
	}

f_execute_all $P_SRCDIR	