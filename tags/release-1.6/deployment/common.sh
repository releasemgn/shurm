#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ../../etc/config.sh

if [ "$C_CONFIG_PRODUCT_DEPLOYMENT_HOME" = "" ]; then
	echo C_CONFIG_PRODUCT_DEPLOYMENT_HOME is not defined. Exiting
	exit 1
fi

# run any command
function f_run_cmd() {
	local P_COMMON_HOSTLOGIN="$1"
	local P_CMD="$2"

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo "$P_COMMON_HOSTLOGIN cmd: $P_CMD ..."
	fi

	RUN_CMD_RES=
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
	return 0
}

function f_run_cmdcheck() {
	local P_COMMON_HOSTLOGIN="$1"
	local P_CMD="$2"

	f_run_cmd "$P_COMMON_HOSTLOGIN" "$P_CMD"
	if [ "$RUN_CMD_RES" != "" ]; then
		echo $P_COMMON_HOSTLOGIN: failed execute "$P_CMD" - $RUN_CMD_RES. Exiting
		exit 1
	fi
}

# upload any file
function f_upload_file() {
	local P_COMMON_HOSTLOGIN=$1
	local P_LOCALFILE=$2
	local P_REMOTENAME=$3

	if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
		scp -q -B -p -i $C_ENV_PROPERTY_KEYNAME $P_LOCALFILE $P_COMMON_HOSTLOGIN:$P_REMOTENAME
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		scp -q -B -p $P_LOCALFILE $P_COMMON_HOSTLOGIN:$P_REMOTENAME
		if [ $? -ne 0 ]; then
			return 1
		fi
	fi

	f_run_cmdcheck $P_COMMON_HOSTLOGIN "echo `date`: $USER - uploaded $P_REMOTENAME >> ~/upload.log"
	return 0
}

# download any file
function f_download_file() {
	local P_COMMON_HOSTLOGIN=$1
	local P_REMOTENAME=$2
	local P_LOCALFILE=$3

	if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
		scp -q -B -p -i $C_ENV_PROPERTY_KEYNAME $P_COMMON_HOSTLOGIN:$P_REMOTENAME $P_LOCALFILE
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		scp -q -B -p $P_COMMON_HOSTLOGIN:$P_REMOTENAME $P_LOCALFILE
		if [ $? -ne 0 ]; then
			return 1
		fi
	fi

	return 0
}

# download any dir
function f_download_dir() {
	local P_COMMON_HOSTLOGIN=$1
	local P_REMOTEDIR=$2
	local P_LOCALDIR=$3

	if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
		scp -q -r -B -p -i $C_ENV_PROPERTY_KEYNAME $P_COMMON_HOSTLOGIN:$P_REMOTEDIR $P_LOCALDIR
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		scp -q -r -B -p $P_COMMON_HOSTLOGIN:$P_REMOTEDIR $P_LOCALDIR
		if [ $? -ne 0 ]; then
			return 1
		fi
	fi

	return 0
}

# find file
C_COMMON_FINDFILE_NAME=
function f_find_file() {
	local P_SRCDIR=$1
	local P_XBASENAME=$2
	local P_XEXTENTION=$3
	local P_XHOSTLOGIN=$4

	if [ "$P_XHOSTLOGIN" = "" ]; then
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

# upload any file from remote source
function f_upload_remotefile() {
	local P_SRC_HOSTLOGIN=$1
	local P_DST_HOSTLOGIN=$2
	local P_SRCFILE=$3
	local P_DSTFILE=$4

	if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
		scp -q -B -p -i $C_ENV_PROPERTY_KEYNAME $P_SRC_HOSTLOGIN:$P_SRCFILE tmp-scpfile
		scp -q -B -p -i $C_ENV_PROPERTY_KEYNAME tmp-scpfile $P_DST_HOSTLOGIN:$P_DSTFILE
		rm -rf tmp-scpfile
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		scp -q -B -p $P_SRC_HOSTLOGIN:$P_SRCFILE tmp-scpfile
		scp -q -B -p tmp-scpfile $P_DST_HOSTLOGIN:$P_DSTFILE
		rm -rf tmp-scpfile
		if [ $? -ne 0 ]; then
			return 1
		fi
	fi

	f_run_cmdcheck $P_DST_HOSTLOGIN "echo `date`: $USER - uploaded $P_DSTFILE >> ~/upload.log"
	return 0
}

# upload script
function f_upload_script() {
	local P_COMMON_HOSTLOGIN=$1
	local P_SCRIPT=$2
	local P_SCRIPTNAME=$3

	if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
		scp -q -B -p -i $C_ENV_PROPERTY_KEYNAME $P_SCRIPT $P_COMMON_HOSTLOGIN:$P_SCRIPTNAME
		ssh -i $C_ENV_PROPERTY_KEYNAME -n $P_COMMON_HOSTLOGIN "chmod 700 $P_SCRIPTNAME"
	else
		scp -q -B -p $P_SCRIPT $P_COMMON_HOSTLOGIN:$P_SCRIPTNAME
		ssh -n $P_COMMON_HOSTLOGIN "chmod 700 $P_SCRIPTNAME"
	fi
}

# load configuration xml helpers

. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/common.sh
. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/commondistr.sh
. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/commonenv.sh
. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/commonrelease.sh
