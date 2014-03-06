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

# upload any file
function f_upload_file() {
	local P_HOSTLOGIN=$1
	local P_LOCALFILE=$2
	local P_REMOTENAME=$3
	local P_MD5NAME=$4
	local P_STATEINFO="$5"

	if [ ! -f "$P_LOCALFILE" ]; then
		echo "f_upload_file: file $P_LOCALFILE is missing, skipped."
		return 1
	fi

	# calculate md5
	local F_SRCDIRNAME=`dirname $P_LOCALFILE`
	local F_MD5SRCPATH=$F_SRCDIRNAME/$P_MD5NAME
	local F_REDIST_MD5_SRC=`if [ -f "$F_MD5SRCPATH" ]; then cat $F_MD5SRCPATH; else ( md5sum $P_LOCALFILE | cut -d " " -f1 ); fi`

	# check duplicate
	local F_NEWSTATEINFO="$P_REMOTENAME:$F_REDIST_MD5_SRC"
	if [ "$GETOPT_FORCE" != "yes" ]; then
		if [ "$F_NEWSTATEINFO" = "$P_STATEINFO" ]; then
			echo "$P_HOSTLOGIN: $P_REMOTENAME - no changes. Skipped."
			return 0
		fi
	fi

	echo "$P_HOSTLOGIN: copy $P_LOCALFILE to $P_REMOTENAME (src md5=$F_REDIST_MD5_SRC)..."

	local F_DSTDIRNAME=`dirname $P_REMOTENAME`
	local F_MD5DSTPATH=$F_DSTDIRNAME/$P_MD5NAME
	f_run_cmd $P_HOSTLOGIN "rm -rf $F_MD5DSTPATH"
	if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
		scp -q -B -p -i $C_ENV_PROPERTY_KEYNAME $P_LOCALFILE $P_HOSTLOGIN:$P_REMOTENAME
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		scp -q -B -p $P_LOCALFILE $P_HOSTLOGIN:$P_REMOTENAME
		if [ $? -ne 0 ]; then
			return 1
		fi
	fi

	# get destination md5
	f_run_cmd $P_HOSTLOGIN "md5sum $P_REMOTENAME | cut -d\" \" -f1"
	local F_REDIST_MD5_DST=$RUN_CMD_RES

	# check copy succeeded
	if [ "$F_REDIST_MD5_SRC" != "$F_REDIST_MD5_DST" ]; then
		echo "f_upload_file: copy failed $P_LOCALFILE to $P_REMOTENAME (dst md5=$F_REDIST_MD5_DST). Exiting."
		exit 1
	fi

	f_run_cmdcheck $P_HOSTLOGIN "echo $F_NEWSTATEINFO > $F_MD5DSTPATH; echo `date`: $USER - uploaded $P_REMOTENAME >> ~/upload.log"
	return 0
}

# upload any file from remote source
function f_upload_remotefile() {
	local P_SRC_HOSTLOGIN=$1
	local P_DST_HOSTLOGIN=$2
	local P_SRCFILE=$3
	local P_DSTFILE=$4
	local P_MD5NAME=$5
	local P_STATEINFO="$6"

	# calculate md5
	f_run_cmd $P_SRC_HOSTLOGIN "if [ ! -f $P_SRCFILE ]; then echo true; fi"
	if [ "$RUN_CMD_RES" = "true" ]; then
		echo "f_upload_remotefile: file $P_SRCFILE is missing in $P_SRCDIR, skipped."
		return 1
	fi

	# calculate md5
	local F_SRCDIRNAME=`dirname $P_SRCFILE`
	local F_MD5SRCPATH=$F_SRCDIRNAME/$P_MD5NAME
	f_run_cmd $P_SRC_HOSTLOGIN "if [ -f "$F_MD5SRCPATH" ]; then cat $F_MD5SRCPATH; else ( md5sum $P_SRCFILE | cut -d\" \" -f1 ); fi"
	local F_REDIST_MD5_SRC=$RUN_CMD_RES

	# check duplicate
	local F_NEWSTATEINFO="$P_DSTFILE:$F_REDIST_MD5_SRC"
	if [ "$GETOPT_FORCE" != "yes" ]; then
		if [ "$F_NEWSTATEINFO" = "$P_STATEINFO" ]; then
			echo "f_upload_remotefile: $P_DSTFILE - no changes. Skipped."
			return 0
		fi
	fi

	echo "$P_DST_HOSTLOGIN: copy $P_SRCFILE to $P_DSTFILE (src md5=$F_REDIST_MD5_SRC)..."

	local F_DSTDIRNAME=`dirname $P_DSTFILE`
	local F_MD5DSTPATH=$F_DSTDIRNAME/$P_MD5NAME
	local F_LOCALNAME=$HOSTNAME.$USER.redist.p$$.tmp-scpfile
	f_run_cmd $P_DST_HOSTLOGIN "rm -rf $F_MD5DSTPATH"
	if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
		scp -q -B -p -i $C_ENV_PROPERTY_KEYNAME $P_SRC_HOSTLOGIN:$P_SRCFILE $F_LOCALNAME
		scp -q -B -p -i $C_ENV_PROPERTY_KEYNAME $F_LOCALNAME $P_DST_HOSTLOGIN:$P_DSTFILE
		rm -rf $F_LOCALNAME
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		scp -q -B -p $P_SRC_HOSTLOGIN:$P_SRCFILE $F_LOCALNAME
		scp -q -B -p $F_LOCALNAME $P_DST_HOSTLOGIN:$P_DSTFILE
		rm -rf $F_LOCALNAME
		if [ $? -ne 0 ]; then
			return 1
		fi
	fi

	# get destination md5
	f_run_cmd $P_DST_HOSTLOGIN "md5sum $P_DSTFILE | cut -d\" \" -f1"
	local F_REDIST_MD5_DST=$RUN_CMD_RES

	# check copy succeeded
	if [ "$F_REDIST_MD5_SRC" != "$F_REDIST_MD5_DST" ]; then
		echo "f_upload_remotefile: copy failed $P_SRCFILE to $P_DSTFILE (dst md5=$F_REDIST_MD5_DST). Exiting."
		exit 1
	fi

	f_run_cmdcheck $P_DST_HOSTLOGIN "echo $F_NEWSTATEINFO > $F_MD5DSTPATH; echo `date`: $USER - uploaded $P_DSTFILE >> ~/upload.log"
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
