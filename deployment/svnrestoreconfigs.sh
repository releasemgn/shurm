#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo svnrestoreconfigs.sh: DC not set
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

S_VERSIONDIR=svnrestoreconfig
S_SVNRESTORE_STGPATH="/tmp/$HOSTNAME.$USER.svnrestoreconfig.p$$"
S_SVNRESTORE_STGPATH_TEMPLATES=$S_SVNRESTORE_STGPATH/templates

function f_local_download_live() {
	local P_SERVER=$1
	local P_HOSTLOGIN=$2
	local P_CONFCOMP=$3
	local P_CONFDEPLOYPATH=$4

	# define restore path
	local F_SVNRESTORE_HOST=`echo $P_HOSTLOGIN | cut -d "@" -f2`
	local F_SVNRESTORE_SVNROOT=$C_CONFIG_SOURCE_CFG_LIVEROOTDIR/$C_ENV_ID
	local F_SVNRESTORE_SVNDIR=$DC/$P_SERVER/$P_CONFCOMP@$F_SVNRESTORE_HOST

	# get destination directory
	F_SVNRESTORE_SRCDIR=$P_CONFDEPLOYPATH

	# export svn configuration set
	F_SVNSTATUS=`svn info $C_CONFIG_SVNOLD_AUTH "$F_SVNRESTORE_SRCDIR" 2>&1 | grep -c 'Not a valid URL'`
	if [ "$F_SVNSTATUS" != "0" ]; then
		echo svnrestoreconfigs.sh: no configuration in $F_SVNRESTORE_SRCDIR. Exiting.
		exit 1
	fi

	# download all stored configuration from svn
	local F_SVN_EXPORTFROM=$F_SVNRESTORE_SVNROOT/$F_SVNRESTORE_SVNDIR
	echo export configuration from $F_SVN_EXPORTFROM to $S_SVNRESTORE_STGPATH/$P_CONFCOMP...
	rm -rf $S_SVNRESTORE_STGPATH/$P_CONFCOMP
	mkdir -p $S_SVNRESTORE_STGPATH
	svn export $C_CONFIG_SVNOLD_AUTH $F_SVN_EXPORTFROM@ $S_SVNRESTORE_STGPATH/$P_CONFCOMP > /dev/null

	# process newlines for configuration files
	f_dos2unix_dir $S_SVNRESTORE_STGPATH/$P_CONFCOMP
}

function f_local_executeconfcomp() {
	local P_SERVER=$1
	local P_HOSTLOGIN=$2
	local P_NODE=$3
	local P_CONFCOMP=$4
	local P_ROOTDIR=$5
	local P_LOCATION=$6

	echo restore configuraton component=$P_CONFCOMP...
	local F_SVCRESTORE_LIVE_SERVER_COMP
	if [ "$C_CONFIG_USE_TEMPLATES" != "yes" ]; then
		F_SVCRESTORE_LIVE_SERVER_COMP=$S_SVNRESTORE_STGPATH/$P_CONFCOMP
		f_local_download_live $P_SERVER $P_HOSTLOGIN $P_CONFCOMP $F_LOCATION
	else
		F_SVCRESTORE_LIVE_SERVER_COMP=$S_SVNRESTORE_STGPATH/$DC/$P_SERVER/$P_HOSTLOGIN/$P_CONFCOMP
	fi

	# redist
	local F_REDIST_FULLSRCDIR=$F_SVCRESTORE_LIVE_SERVER_COMP
	local F_PARTIAL="false"
	f_redist_transfer_configset $P_SERVER $P_HOSTLOGIN $P_ROOTDIR $S_VERSIONDIR $P_LOCATION $P_CONFCOMP "config" $F_PARTIAL $F_REDIST_FULLSRCDIR "local"
	if [ $? -ne 0 ]; then
		echo "transfer failed for $P_CONFCOMP location=$P_LOCATION. Skipped."
		return 1
	fi

	# deploy
	f_redist_rollout_config $P_SERVER $P_HOSTLOGIN $P_NODE $P_ROOTDIR $S_VERSIONDIR $P_LOCATION
}

function f_local_executenode() {
	local P_SERVER=$1
	local P_SERVERTYPE=$2
	local P_HOSTLOGIN=$3
	local P_NODE=$4
	local P_ROOTDIR=$5
	local P_DEPLOYDIR=$6

	# check server has configuration
	f_env_getserverconflist $DC $P_SERVER
	local F_REDIST_CONFLIST=$C_ENV_SERVER_CONFLIST

	if [ "$F_REDIST_CONFLIST" = "" ]; then
		echo no configuration components defined to extract from $P_SERVER. Skipped.
		return 0
	fi

	f_redist_recreatedir $P_SERVER $P_HOSTLOGIN $S_VERSIONDIR

	local F_LOCATIONS=
	local confcomp
	for confcomp in $F_REDIST_CONFLIST; do
		if [ "$EXECUTE_COMPONENT_LIST" = "" ] || [[ " $EXECUTE_COMPONENT_LIST " =~ " $confcomp " ]]; then
			# get destination directory
			f_env_getserverconfinfo $DC $P_SERVER $confcomp
			local F_CONFPATH=$C_ENV_SERVER_COMP_DEPLOYPATH
			if [ "$F_CONFPATH" = "" ]; then
				F_CONFPATH=$P_DEPLOYDIR
			fi

			# create location if new one
			if [[ ! " $F_LOCATIONS " =~ " $F_CONFPATH " ]]; then
				f_redist_createlocation $P_SERVER $P_HOSTLOGIN $S_VERSIONDIR $P_ROOTDIR $F_CONFPATH "config"
				F_LOCATIONS="$F_LOCATIONS $F_CONFPATH"
			fi

			f_local_executeconfcomp $P_SERVER $P_HOSTLOGIN $P_NODE $confcomp $P_ROOTDIR $F_CONFPATH
		fi
	done
}

function f_local_templates_configure() {
	local P_SERVER=$1

	# create from templates
	./configure.sh -dc $DC templates $S_SVNRESTORE_STGPATH_TEMPLATES $S_SVNRESTORE_STGPATH $P_SERVER
}

function f_local_execute_server() {
	local P_SERVER=$1

	f_env_getxmlserverinfo $DC $P_SERVER $GETOPT_DEPLOYGROUP
	local F_REDIST_ROOTDIR=$C_ENV_SERVER_ROOTPATH
	local F_REDIST_DEPLOYDIR=$C_ENV_SERVER_DEPLOYPATH

	local F_SERVERTYPE
	if [ "$C_ENV_SERVER_TYPE" = "generic.server" ] || [ "$C_ENV_SERVER_TYPE" = "service" ] || [ "$C_ENV_SERVER_TYPE" = "generic.web" ] ||
		[ "$C_ENV_SERVER_TYPE" = "generic.command" ]; then
		F_SERVERTYPE=generic
	else
		echo ignore server=$P_SERVER, type=$C_ENV_SERVER_TYPE
		return 1
	fi

	echo ============================================ execute server=$P_SERVER...

	if [ "$C_CONFIG_USE_TEMPLATES" = "yes" ]; then
		f_local_templates_configure $P_SERVER
	fi

	# iterate by nodes
	local NODE=1
	local hostlogin
	for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
		if [ "$EXECUTE_NODE" = "" ] || [ "$EXECUTE_NODE" = "$NODE" ]; then
			echo execute server=$P_SERVER node=$NODE...
			f_local_executenode $P_SERVER $F_SERVERTYPE "$hostlogin" $NODE $F_REDIST_ROOTDIR $F_REDIST_DEPLOYDIR
		fi
		NODE=$(expr $NODE + 1)
	done
}

# extract templates
function f_local_templates_extract() {
	# define restore path
	local F_TEMPLATE_SVNROOT=$C_CONFIG_SOURCE_CFG_ROOTDIR/templates
	if [ "$GETOPT_TAG" != "" ]; then
		F_TEMPLATE_SVNROOT=$C_CONFIG_SOURCE_CFG_ROOTDIR/tags/$GETOPT_TAG
	fi

	# export svn configuration set
	local F_SVNSTATUS=`svn info $C_CONFIG_SVNOLD_AUTH "$F_TEMPLATE_SVNROOT" 2>&1 | grep -c 'Not a valid URL'`
	if [ "$F_SVNSTATUS" != "0" ]; then
		echo svnrestoreconfigs.sh: no configuration in $F_TEMPLATE_SVNROOT. Exiting.
		exit 1
	fi

	# download all stored configuration from svn
	echo export configuration from $F_TEMPLATE_SVNROOT to $S_SVNRESTORE_STGPATH_TEMPLATES...
	rm -rf $S_SVNRESTORE_STGPATH_TEMPLATES
	mkdir -p `dirname $S_SVNRESTORE_STGPATH_TEMPLATES`
	svn export $C_CONFIG_SVNOLD_AUTH $F_TEMPLATE_SVNROOT $S_SVNRESTORE_STGPATH_TEMPLATES > /dev/null

	# process newlines for configuration files
	f_dos2unix_dir $S_SVNRESTORE_STGPATH_TEMPLATES
}

# get server list
function f_local_executedc() {
	if [ "$GETOPT_BACKUP" = "no" ]; then
		C_REDIST_NOBACKUP=true
	fi

	C_REDIST_EXECUTE_ECHO_ONLY=true
	if [ "$GETOPT_EXECUTE" = "yes" ]; then
		C_REDIST_EXECUTE_ECHO_ONLY=false
	fi

	if [ "$C_REDIST_EXECUTE_ECHO_ONLY" = "true" ]; then
		echo "svnrestoreconfigs.sh: restore runtime configuration (show only)..."
	else
		echo "svnrestoreconfigs.sh: restore runtime configuration (execute)..."
	fi

	# handle templates
	if [ "$C_CONFIG_USE_TEMPLATES" = "yes" ]; then
		f_local_templates_extract
	fi

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

	# delete tmp
	rm -rf $S_SVNRESTORE_STGPATH
}

# copy configuration files from svn to environment (except for windows-based)

# execute datacenter
f_local_executedc

echo svnrestoreconfigs.sh: SUCCESSFULLY DONE.
