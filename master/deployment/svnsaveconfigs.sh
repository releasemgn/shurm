#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo svnsaveconfigs.sh: DC not set
	exit 1
fi

# check if node syntax
if [[ "$2" =~ ^[1-9] ]]; then
	SRVNAME_LIST=$1
	EXECUTE_NODE=$2
	shift 2
	EXECUTE_COMPONENT_LIST=$*
else
	SRVNAME_LIST=$*
	EXECUTE_NODE=
	EXECUTE_COMPONENT_LIST=
fi

# load common functions
. ./common.sh
. ./commonredistbase.sh
. ./commonredistconf.sh
. ./commonredistmain.sh

# execute
S_SVNSAVE_STGPATH="/tmp/$HOSTNAME.$USER.svnsaveconfig.p$$"

function f_local_executeconfcomp() {
	local P_SERVER=$1
	local P_HOSTLOGIN=$2
	local P_NODE=$3
	local P_CONFCOMP=$4
	local P_ROOTDIR=$5
	local P_LOCATION=$6

	echo extract configuraton component=$P_CONFCOMP...

	# define save path
	local F_HOSTLOGINSVN=${P_HOSTLOGIN/@/-}
	local F_SVNSAVE_SVNROOT=$C_CONFIG_SOURCE_CFG_LIVEROOTDIR/$C_ENV_ID
	local F_SVNSAVE_SVNDIR=$DC/$P_SERVER/$P_CONFCOMP-$F_HOSTLOGINSVN

	local F_SVNSAVE_LOCALDIRLIVE=$S_SVNSAVE_STGPATH/config.live
	local F_SVNSAVE_LOCALDIRCO=$S_SVNSAVE_STGPATH/config.svn
	local F_SVNSAVE_LOCALDIREXP=$S_SVNSAVE_STGPATH/config.exp

	rm -rf $S_SVNSAVE_STGPATH
	mkdir -p $S_SVNSAVE_STGPATH

	f_redist_get_configset $P_SERVER $P_HOSTLOGIN $P_ROOTDIR $P_LOCATION $P_CONFCOMP $F_SVNSAVE_LOCALDIRLIVE
	if [ $? -ne 0 ]; then
		return 1
	fi

	# save configuration to svn
	local F_SVNSTATUS=`svn info $C_CONFIG_SVNOLD_AUTH "$F_SVNSAVE_SVNROOT/$F_SVNSAVE_SVNDIR" 2>&1 | grep -c 'Not a valid URL'`
	if [ "$F_SVNSTATUS" != "0" ]; then
		# create directory in svn first
		svn mkdir --parents $C_CONFIG_SVNOLD_AUTH -m "$C_CONFIG_ADM_TRACKER-0000: create configuration" "$F_SVNSAVE_SVNROOT/$F_SVNSAVE_SVNDIR" > /dev/null
	fi

	svn co $C_CONFIG_SVNOLD_AUTH "$F_SVNSAVE_SVNROOT/$F_SVNSAVE_SVNDIR" "$F_SVNSAVE_LOCALDIRCO" > /dev/null
	if [ $? != 0 ]; then
		echo "unable to checkout live configuration state. Exiting"
		exit 1
	fi

	svn export $C_CONFIG_SVNOLD_AUTH "$F_SVNSAVE_SVNROOT/$F_SVNSAVE_SVNDIR" "$F_SVNSAVE_LOCALDIREXP" > /dev/null
	if [ $? != 0 ]; then
		echo "unable to export live configuration state. Exiting"
		exit 1
	fi

	# rework to svn
	local F_SVNSAVE_DIR=`pwd`

	# delete obsolete
	cd $F_SVNSAVE_LOCALDIREXP
	local F_SVNSAVE_FLIST=`find . -type f | sed "s/^\.\///g" | tr "\n" " "`
	cd $F_SVNSAVE_DIR

	local fname
	for fname in $F_SVNSAVE_FLIST; do
		if [ ! -f "$F_SVNSAVE_LOCALDIRLIVE/$fname" ]; then
			svn delete $F_SVNSAVE_LOCALDIRCO/$fname > /dev/null
			rm -rf $F_SVNSAVE_LOCALDIREXP/$fname
		fi
	done

	# add/change new
	cd $F_SVNSAVE_LOCALDIRLIVE
	F_SVNSAVE_FLIST=`find . -type f | sed "s/^\.\///g" | tr "\n" " "`
	cd $F_SVNSAVE_DIR

	for fname in $F_SVNSAVE_FLIST; do
		mkdir -p `dirname $F_SVNSAVE_LOCALDIRCO/$fname`
		cp $F_SVNSAVE_LOCALDIRLIVE/$fname $F_SVNSAVE_LOCALDIRCO/$fname

		# process newlines for configuration files
		f_unix2dos_file $F_SVNSAVE_LOCALDIRCO/$fname

		if [ ! -f "$F_SVNSAVE_LOCALDIREXP/$fname" ]; then
			svn add --parents $F_SVNSAVE_LOCALDIRCO/$fname > /dev/null
		fi
	done

	# save to svn
	cd $F_SVNSAVE_LOCALDIRCO
	if [ "$GETOPT_RELEASEDIR" != "" ]; then
		F_COMMIT_MSG="released from $GETOPT_RELEASEDIR"
	else
		F_COMMIT_MSG="get config files"
	fi
	local F_COMMITRESULT=`svn commit $C_CONFIG_SVNOLD_AUTH -m "$C_CONFIG_ADM_TRACKER-0000: $F_COMMIT_MSG" | grep -c "^"`
	cd $F_SVNSAVE_DIR

	rm -rf $S_SVNSAVE_STGPATH

	if [ "$F_COMMITRESULT" = "0" ]; then
		echo $P_HOSTLOGIN: no changes at $F_SVNSAVE_SVNROOT/$F_SVNSAVE_SVNDIR
	else
		echo $P_HOSTLOGIN: svn updated at $F_SVNSAVE_SVNROOT/$F_SVNSAVE_SVNDIR
	fi
}

function f_local_deleteold() {
	local P_PATH=$1
	local P_SAVEITEMS="$2"

	local F_SVNSAVE_SVNPATH=$C_CONFIG_SOURCE_CFG_LIVEROOTDIR/$C_ENV_ID/$P_PATH
	local F_SVNSAVE_EXISTING=`svn list $C_CONFIG_SVNOLD_AUTH $F_SVNSAVE_SVNPATH | tr -d "/"`
	
	for item in $F_SVNSAVE_EXISTING; do
		if [[ ! " $P_SAVEITEMS " =~ " $item " ]]; then
			echo delete obsolete configuration item - $item ...
			if [[ "$item" =~ "@" ]]; then
				item="$item@"
			fi

			svn delete $C_CONFIG_SVNOLD_AUTH $F_SVNSAVE_SVNPATH/$item -m "delete by svnsaveconfigs.sh" > /dev/null
			if [ "$?" != "0" ]; then
				echo svn delete failed. Exiting
				exit 1
			fi
		fi
	done
}

function f_local_executenode() {
	local P_SERVER=$1
	local P_HOSTLOGIN=$2
	local P_NODE=$3
	local P_ROOTDIR=$4
	local P_DEPLOYDIR=$5
	local P_REDIST_CONFLIST="$6"

	local confcomp
	for confcomp in $P_REDIST_CONFLIST; do
		if [ "$EXECUTE_COMPONENT_LIST" = "" ] || [[ " $EXECUTE_COMPONENT_LIST " =~ " $confcomp " ]]; then
			# get destination directory
			f_env_getserverconfinfo $DC $P_SERVER $confcomp
			local F_CONFPATH=$C_ENV_SERVER_COMP_DEPLOYPATH
			if [ "$F_CONFPATH" = "" ]; then
				F_CONFPATH=$P_DEPLOYDIR
			fi

			f_local_executeconfcomp $P_SERVER $P_HOSTLOGIN $P_NODE $confcomp $P_ROOTDIR $F_CONFPATH
		fi
	done

	# delete tmp directory
	f_redistr_droptmp $P_SERVER $P_HOSTLOGIN $P_NODE
}

function f_local_execute_server() {
	local P_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_SRVNAME $GETOPT_DEPLOYGROUP
	local F_REDIST_ROOTDIR=$C_ENV_SERVER_ROOTPATH
	local F_REDIST_DEPLOYDIR=$C_ENV_SERVER_DEPLOYPATH

	local F_SERVER_TYPE=$C_ENV_SERVER_TYPE
	local F_SERVERCATEGORY
	if [ "$F_SERVER_TYPE" = "generic.server" ] || [ "$F_SERVER_TYPE" = "service" ] || [ "$F_SERVER_TYPE" = "generic.web" ] ||
		[ "$C_ENV_SERVER_TYPE" = "generic.command" ]; then
		F_SERVERCATEGORY=generic
	else
		echo ignore server=$P_SRVNAME, type=$F_SERVER_TYPE
		return 1
	fi

	echo ============================================ execute server=$P_SRVNAME...

	# check server has configuration
	f_env_getserverconflist $DC $P_SRVNAME
	local F_REDIST_CONFLIST=$C_ENV_SERVER_CONFLIST
	local F_REDIST_SAVEITEMS=

	# iterate by nodes
	if [ "$F_REDIST_CONFLIST" != "" ]; then
		local NODE=1
		local hostlogin
		local hostloginsvn
		local hostloginsvnconf
		for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
			if [ "$EXECUTE_NODE" = "" ] || [ "$EXECUTE_NODE" = "$NODE" ]; then
				echo execute server=$P_SRVNAME node=$NODE...
				f_local_executenode $P_SRVNAME "$hostlogin" $NODE "$F_REDIST_ROOTDIR" "$F_REDIST_DEPLOYDIR" "$F_REDIST_CONFLIST"
			fi
			NODE=$(expr $NODE + 1)

			hostloginsvn=${hostlogin/@/-}
			hostloginsvnconf=`echo "$F_REDIST_CONFLIST " | sed "s/ /-$hostloginsvn /g"`
			F_REDIST_SAVEITEMS="$F_REDIST_SAVEITEMS $hostloginsvnconf"
		done
	fi

	# delete old
	if [ "$GETOPT_FORCE" = "yes" ] && [ "$EXECUTE_NODE" = "" ]; then
		f_local_deleteold $DC/$P_SRVNAME "$F_REDIST_SAVEITEMS"
	fi
}

# get server list
function f_local_executedc() {
	echo execute datacenter=$DC...
	f_env_getxmlserverlist $DC
	local F_SERVER_LIST=$C_ENV_XMLVALUE

	f_checkvalidlist "$F_SERVER_LIST" "$SRVNAME_LIST"
	f_getsubset "$F_SERVER_LIST" "$SRVNAME_LIST"
	F_SERVER_LIST=$C_COMMON_SUBSET

	# iterate servers
	local server
	for server in $F_SERVER_LIST; do
		f_local_execute_server $server
	done

	# delete old
	if [ "$GETOPT_FORCE" = "yes" ] && [ "$SRVNAME_LIST" = "" ]; then
		f_local_deleteold $DC "$F_SERVER_LIST"
	fi

	# delete tmp
	rm -rf $S_SVNSAVE_STGPATH
}

# copy configuration files from environment to svn (except for windows-based)
echo "svnsaveconfigs.sh: save runtime configuration..."

# execute datacenter
f_local_executedc

echo svnsaveconfigs.sh: SUCCESSFULLY DONE.
