#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

cd `dirname $0`
SCRIPTDIR=`pwd`

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo redist.sh: DC not set
	exit 1
fi

P_SRCVERSIONDIR=$1
if [ "$P_SRCVERSIONDIR" = "" ]; then
	echo redist.sh: P_SRCVERSIONDIR not set
	exit 1
fi

shift 1
SRVNAME_LIST=$*

# load common functions
. ./common.sh
. ./commonredistbase.sh
. ./commonredistconf.sh
. ./commonredistmain.sh

# execute
S_REDIST_TMP="/tmp/$HOSTNAME.$USER.redist.p$$"

S_REDIST_SRCVER=
S_REDIST_SRCDIR=
S_REDIST_DIST_ITEMS=
S_REDIST_DIST_OBSOLETE_ITEMS=
S_REDIST_STATIC_ITEMS=

S_REDIST_CONFCOMPLIST=
S_REDIST_RELEASE_CONFIGS=
S_REDIST_RELEASE_TEMPLATES=
S_REDIST_RELEASE_GENERATED=

function f_local_filter_static() {
	local P_CHECK_ITEMS="$1"

	S_REDIST_STATIC_ITEMS=
	local item
	for item in $P_CHECK_ITEMS; do
		f_distr_readitem $item
		if [ "$C_DISTR_WAR_CONTEXT" != "" ]; then
			S_REDIST_STATIC_ITEMS="$S_REDIST_STATIC_ITEMS $item"
		fi
	done

	S_REDIST_STATIC_ITEMS=${S_REDIST_STATIC_ITEMS## }
}

function f_local_getdistitems() {
	local P_TYPE=$1
	local P_COMPONENTLIST="$2"

	# collect distribution items for all components
	S_REDIST_DIST_ITEMS=
	S_REDIST_DIST_OBSOLETE_ITEMS=
	local component
	for component in $P_COMPONENTLIST; do
		f_distr_getcomponentitems $component
		if [ "$C_DISTR_ITEMS" != "" ]; then
			S_REDIST_DIST_ITEMS="$S_REDIST_DIST_ITEMS $C_DISTR_ITEMS"
		fi
		if [ "$C_DISTR_OBSOLETE_ITEMS" != "" ]; then
			S_REDIST_DIST_OBSOLETE_ITEMS="$S_REDIST_DIST_OBSOLETE_ITEMS $C_DISTR_OBSOLETE_ITEMS"
		fi
	done

	if [ "$S_REDIST_DIST_ITEMS" != "" ]; then
		S_REDIST_DIST_ITEMS=`echo $S_REDIST_DIST_ITEMS | tr " " "\n" | sort -u | tr "\n" " "`
	fi

	if [ "$S_REDIST_DIST_OBSOLETE_ITEMS" != "" ]; then
		S_REDIST_DIST_OBSOLETE_ITEMS=`echo $S_REDIST_DIST_OBSOLETE_ITEMS | tr " " "\n" | sort -u | tr "\n" " "`
	fi

	# filter static items if required
	if [ "$P_TYPE" = "static" ]; then
		f_local_filter_static "$S_REDIST_DIST_ITEMS"
		S_REDIST_DIST_ITEMS=$S_REDIST_STATIC_ITEMS

		f_local_filter_static "$S_REDIST_DIST_OBSOLETE_ITEMS"
		S_REDIST_DIST_OBSOLETE_ITEMS=$S_REDIST_STATIC_ITEMS
	fi

	S_REDIST_DIST_ITEMS=${S_REDIST_DIST_ITEMS% }
	S_REDIST_DIST_OBSOLETE_ITEMS=${S_REDIST_DIST_OBSOLETE_ITEMS% }
}

function f_local_executestaticnode() {
	local P_SERVER=$1
	local P_STATICSERVER=$2
	local P_LOCAL_HOSTLOGIN=$3
	local P_NODE=$4
	local P_DISTITEMS="$5"
	local P_ROOTDIR=$6
	local P_LOCATION=$7

	f_redist_createlocation $P_STATICSERVER $P_LOCAL_HOSTLOGIN $P_SRCVERSIONDIR $P_ROOTDIR $P_LOCATION "deploy"
	f_redist_transfer_staticset $P_STATICSERVER $P_LOCAL_HOSTLOGIN $P_ROOTDIR "$P_DISTITEMS" $P_SRCVERSIONDIR $P_LOCATION $S_REDIST_SRCDIR "release"
}

function f_local_executestatic() {
	local P_SERVER=$1
	local P_STATICSERVER=$2
	local P_COMPONENTLIST=$3

	# get unit component set
	f_dist_getcomplist
	F_UNITCOMPS=$C_DISTR_COMPLIST

	# get components to deploy
	f_getsubsetexact "$F_UNITCOMPS" "$P_COMPONENTLIST"
	F_REDIST_COMPONENT_LIST=$C_COMMON_SUBSET

	# collect distribution items for all components
	f_local_getdistitems "static" "$F_REDIST_COMPONENT_LIST"

	if [ "$S_REDIST_DIST_ITEMS" = "" ]; then
		return 1
	fi

	f_env_getxmlserverinfo $DC $P_STATICSERVER $GETOPT_DEPLOYGROUP
	if [ "$C_ENV_SERVER_DEPLOYPATH" = "" ]; then
		echo f_local_executestatic: deploy path is unknown for server=$P_STATICSERVER. Exiting.
		exit 1
	fi

	echo update server=$P_SERVER static files ...

	local F_REDIST_ROOTDIR=$C_ENV_SERVER_ROOTPATH
	local F_REDIST_LOCATION=$C_ENV_SERVER_DEPLOYPATH

	local NODE=1
	local hostlogin
	for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
		echo execute static server=$P_STATICSERVER node=$NODE, host=$hostlogin...
		f_local_executestaticnode $P_SERVER $P_STATICSERVER "$hostlogin" $NODE "$S_REDIST_DIST_ITEMS" $F_REDIST_ROOTDIR $F_REDIST_LOCATION
		NODE=$(expr $NODE + 1)
	done
}

function f_local_executelocation() {
	local P_CLUSTER_MODE=$1
	local P_SERVER=$2
	local P_HOSTLOGIN=$3
	local P_LINKFROM_DIR="$4"
	local P_NODE=$5
	local P_ROOTDIR=$6
	local P_DEPLOYDIR="$7"
	local P_LOCATION=$8
	local P_UNITCOMPS="$9"

	# get components by location
	f_env_getlocationinfo $DC $P_SERVER $P_LOCATION
	local F_REDIST_COMPONENT_LIST="$C_ENV_LOCATION_COMPONENT_LIST"
	local F_LOC_DEPLOYTYPE=$C_ENV_LOCATION_DEPLOYTYPE

	# use path for default location
	local F_LOCATIONFINAL=$P_LOCATION
	if [ "$P_LOCATION" = "default" ]; then
		F_LOCATIONFINAL=$P_DEPLOYDIR
	fi

	# get components to deploy
	f_getsubsetexact "$P_UNITCOMPS" "$F_REDIST_COMPONENT_LIST"
	F_REDIST_COMPONENT_LIST=$C_COMMON_SUBSET

	if [ "$F_REDIST_COMPONENT_LIST" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo redist location=$F_LOCATIONFINAL no components to deploy, skipped.
		fi
		return 1
	fi

	f_redist_getdirtype $P_CLUSTER_MODE $P_NODE $F_LOC_DEPLOYTYPE "deploy"
	if [ "$C_REDIST_DIRTYPE" = "none" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo ignore deploy binary location=$P_LOCATION clustermode=$P_CLUSTER_MODE node=$P_NODE deploytype=$F_LOC_DEPLOYTYPE
		fi
		return 1
	fi

	# collect distribution items for all components
	f_local_getdistitems "binary" "$F_REDIST_COMPONENT_LIST"
	F_REDIST_DIST_ITEMS="$S_REDIST_DIST_ITEMS"
	F_REDIST_DIST_OBSOLETE_ITEMS="$S_REDIST_DIST_OBSOLETE_ITEMS"

	if [ "$F_REDIST_DIST_ITEMS" = "" ] && [ "$F_REDIST_DIST_OBSOLETE_ITEMS" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo redist location=$F_LOCATIONFINAL no items to deploy, skipped.
		fi
		return 1
	fi

	echo redist location=$F_LOCATIONFINAL deploytype=$F_LOC_DEPLOYTYPE components=$F_REDIST_COMPONENT_LIST dirtype=$C_REDIST_DIRTYPE ...
	f_redist_createlocation $P_SERVER $P_HOSTLOGIN $P_SRCVERSIONDIR $P_ROOTDIR $F_LOCATIONFINAL $C_REDIST_DIRTYPE

	if [ "$F_REDIST_DIST_ITEMS" != "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo transfer items - $F_REDIST_DIST_ITEMS...
		fi

		f_redist_transfer_fileset $P_SERVER $F_LOC_DEPLOYTYPE $P_HOSTLOGIN $P_ROOTDIR "$F_REDIST_DIST_ITEMS" $P_SRCVERSIONDIR $F_LOCATIONFINAL "$P_LINKFROM_DIR" $S_REDIST_SRCDIR "release"
	fi

	if [ "$F_REDIST_DIST_OBSOLETE_ITEMS" != "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo prepare to delete obsolete items - $F_REDIST_DIST_OBSOLETE_ITEMS...
		fi

		f_redist_prepare_deleteobsolete $P_SERVER $F_LOC_DEPLOYTYPE $P_HOSTLOGIN $P_ROOTDIR $P_SRCVERSIONDIR $F_LOCATIONFINAL "$P_LINKFROM_DIR" "$F_REDIST_DIST_OBSOLETE_ITEMS"
	fi
}

function f_local_executeconfcomp() {
	local P_CLUSTER_MODE=$1
	local P_SERVER=$2
	local P_HOSTLOGIN=$3
	local P_NODE=$4
	local P_ROOTDIR=$5
	local P_DEPLOYDIR=$6
	local P_CONFCOMP=$7
	local P_DIRTYPE=$8

	# get source directory information
	f_distr_getconfcompinfo $P_CONFCOMP

	# get release information
	f_release_getconfcompinfo $P_CONFCOMP
	local F_PARTIAL=$C_RELEASE_CONFCOMP_PARTIAL
	if [ "$F_PARTIAL" = "" ]; then
		F_PARTIAL="true"
	fi

	echo "redist configuraton component=$P_CONFCOMP (partial=$F_PARTIAL)..."

	local F_REDIST_FULLSRCDIR=
	local F_REDIST_SRCHOST=
	if [ "$C_CONFIG_USE_TEMPLATES" = "yes" ]; then
		# copy from generated locally
		F_REDIST_FULLSRCDIR=$S_REDIST_RELEASE_GENERATED/$DC/$P_SERVER/$P_HOSTLOGIN/$P_CONFCOMP
		F_REDIST_SRCHOST="local"
	else
		# source directory information
		local F_HOST=${P_HOSTLOGIN#*@}

		f_release_getconfcomppath $DC $P_SERVER $F_HOST $P_CONFCOMP $C_DISTR_CONF_LAYER
		F_REDIST_FULLSRCDIR=$S_REDIST_SRCDIR/config/$C_ENV_ID/$C_RELEASE_CONFCOMPPATH
		F_REDIST_SRCHOST="release"
	fi

	f_redist_transfer_configset $P_SERVER $P_HOSTLOGIN $P_ROOTDIR $P_SRCVERSIONDIR $P_DEPLOYDIR $P_CONFCOMP $P_DIRTYPE "$F_PARTIAL" $F_REDIST_FULLSRCDIR $F_REDIST_SRCHOST
}

function f_local_executenode_binary() {
	local P_CLUSTER_MODE=$1
	local P_SERVER=$2
	local P_HOSTLOGIN=$3
	local P_NODE=$4
	local P_ROOTDIR=$5
	local P_DEPLOYDIR="$6"
	local P_LINKFROM_DIR="$7"

	if [ "$GETOPT_DEPLOYBINARY" = "no" ]; then
		return 1
	fi

	echo redist app=$P_SERVER node=$P_NODE, host=$P_HOSTLOGIN...
	# get deployment locations
	f_env_getserverlocations $DC $P_SERVER
	local F_ENV_LOCATIONS=$C_ENV_SERVER_LOCATIONLIST

	if [ "$GETOPT_SHOWALL" = "yes" ] && [ "$F_ENV_LOCATIONS" = "" ]; then
		echo server=$P_SERVER - no locations. Skipped.
		return 0
	fi

	# get unit component set
	f_dist_getcomplist
	F_UNITCOMPS=$C_DISTR_COMPLIST

	# execute by location
	local location
	for location in $F_ENV_LOCATIONS; do
		f_local_executelocation $P_CLUSTER_MODE $P_SERVER $P_HOSTLOGIN "$P_LINKFROM_DIR" $P_NODE $P_ROOTDIR "$P_DEPLOYDIR" "$location" "$F_UNITCOMPS"
	done
}

function f_local_executenode_config() {
	local P_CLUSTER_MODE=$1
	local P_SERVER=$2
	local P_HOSTLOGIN=$3
	local P_NODE=$4
	local P_ROOTDIR=$5
	local P_DEPLOYDIR=$6

	if [ "$GETOPT_DEPLOYCONF" != "yes" ]; then
		return 1
	fi

	# check configuration deployment
	if [ "$S_REDIST_CONFCOMPLIST" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo no configuration components requested to deploy in release.xml. Skipped.
		fi
		return 0
	fi

	# check server has configuration
	f_env_getserverconflist $DC $P_SERVER
	local F_REDIST_CONFLIST=$C_ENV_SERVER_CONFLIST

	if [ "$F_REDIST_CONFLIST" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo no configuration components defined to deploy to $P_SERVER. Skipped.
		fi
		return 0
	fi

	# get configuration components to deploy
	f_getsubsetexact "$F_REDIST_CONFLIST" "$S_REDIST_CONFCOMPLIST"
	F_REDIST_CONFLIST=$C_COMMON_SUBSET

	# get unit component set
	f_distr_getconfcomplist
	F_UNITCOMPS=$C_DISTR_CONF_COMPLIST
	f_getsubsetexact "$F_UNITCOMPS" "$F_REDIST_CONFLIST"
	F_REDIST_CONFLIST=$C_COMMON_SUBSET

	if [ "$F_REDIST_CONFLIST" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo no configuration components requested to deploy to $P_SERVER. Skipped.
		fi
		return 0
	fi

	# redist configuration
	local F_LOCATIONS=
	echo redist configuration app=$P_SERVER node=$P_NODE, host=$P_HOSTLOGIN...
	local confcomp
	for confcomp in $F_REDIST_CONFLIST; do
		# get destination directory
		f_env_getserverconfinfo $DC $P_SERVER $confcomp
		local F_CONFPATH=$C_ENV_SERVER_COMP_DEPLOYPATH
		if [ "$F_CONFPATH" = "" ]; then
			F_CONFPATH=$P_DEPLOYDIR
		fi

		f_redist_getdirtype $P_CLUSTER_MODE $P_NODE $C_ENV_SERVER_COMP_DEPLOYTYPE "config"
		if [ "$C_REDIST_DIRTYPE" != "none" ]; then
			# create location if new one
			if [[ ! " $F_LOCATIONS " =~ " $F_CONFPATH " ]]; then
				f_redist_createlocation $P_SERVER $P_HOSTLOGIN $P_SRCVERSIONDIR $P_ROOTDIR $F_CONFPATH $C_REDIST_DIRTYPE
				F_LOCATIONS="$F_LOCATIONS $F_CONFPATH"
			fi

			f_local_executeconfcomp $P_CLUSTER_MODE $P_SERVER $P_HOSTLOGIN $P_NODE $P_ROOTDIR $F_CONFPATH $confcomp $C_REDIST_DIRTYPE
		fi
	done
}

function f_local_executenode() {
	local P_CLUSTER_MODE=$1
	local P_SERVER=$2
	local P_HOSTLOGIN=$3
	local P_NODE=$4
	local P_ROOTDIR=$5
	local P_DEPLOYDIR=$6
	local P_LINKFROM_DIR="$7"

	f_local_executenode_binary $P_CLUSTER_MODE $P_SERVER $P_HOSTLOGIN $P_NODE $P_ROOTDIR "$P_DEPLOYDIR" "$P_LINKFROM_DIR"
	f_local_executenode_config $P_CLUSTER_MODE $P_SERVER $P_HOSTLOGIN $P_NODE $P_ROOTDIR "$P_DEPLOYDIR"
}

function f_local_execute_server() {
	local P_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_SRVNAME $GETOPT_DEPLOYGROUP
	local F_REDIST_ROOTDIR=$C_ENV_SERVER_ROOTPATH
	local F_REDIST_DEPLOYDIR=$C_ENV_SERVER_DEPLOYPATH
	local F_REDIST_DEPLOYTYPE=$C_ENV_SERVER_DEPLOYTYPE
	local F_REDIST_LINKFROM_DIR=$C_ENV_SERVER_LINKFROMPATH
	local F_HOTDEPLOYSERVER=$C_ENV_SERVER_HOTDEPLOYSERVER
	local F_REDIST_STATICSERVER=$C_ENV_SERVER_STATICSERVER
	local F_SERVERTYPE=$C_ENV_SERVER_TYPE
	local F_HOSTLOGINLIST="$C_ENV_SERVER_HOSTLOGIN_LIST"
	local F_SERVER_COMPONENT_LIST=$C_ENV_SERVER_COMPONENT_LIST

	# ignore manually deployed and not deployed
	if [ "$F_REDIST_DEPLOYTYPE" = "manual" ] || [ "$F_REDIST_DEPLOYTYPE" = "none" ]; then
		echo server $P_SRVNAME DEPLOYTYPE=$F_REDIST_DEPLOYTYPE. Skipped.
		return 1
	fi

	local NODE

	echo ============================================ execute server=$P_SRVNAME, type=$F_SERVERTYPE...

	# cluster hot deploy - redist hotdeploy components to admin server only
	local F_CLUSTER_MODE=no
	if [ "$F_HOTDEPLOYSERVER" != "" ]; then
		NODE=admin
		F_CLUSTER_MODE=yes
		f_local_executenode $F_CLUSTER_MODE $P_SRVNAME $F_HOTDEPLOYSERVER $NODE $F_REDIST_ROOTDIR "$F_REDIST_DEPLOYDIR"
	fi

	# iterate by nodes
	local hostlogin
	NODE=1
	for hostlogin in $F_HOSTLOGINLIST; do
		echo execute server=$P_SRVNAME node=$NODE...

		# deploy both binaries and configs to each node
		f_local_executenode $F_CLUSTER_MODE $P_SRVNAME "$hostlogin" $NODE $F_REDIST_ROOTDIR "$F_REDIST_DEPLOYDIR" "$F_REDIST_LINKFROM_DIR"
		NODE=$(expr $NODE + 1)
	done

	if [ "$GETOPT_DEPLOYBINARY" != "no" ] && [ "$F_REDIST_STATICSERVER" != "" ]; then
		f_local_executestatic $P_SRVNAME $F_REDIST_STATICSERVER "$F_SERVER_COMPONENT_LIST"
	fi
}

# prepare
function f_local_prepare_conf() {
	f_release_getconfcomplist
	S_REDIST_CONFCOMPLIST="$C_RELEASE_CONFCOMPLIST"

	if [ "$S_REDIST_CONFCOMPLIST" = "" ]; then
		return 0
	fi

	if [ "$C_CONFIG_USE_TEMPLATES" != "yes" ]; then
		return 0
	fi

	# templates processing
	# cleanup
	S_REDIST_RELEASE_CONFIGS=$S_REDIST_TMP/$C_ENV_ID/download/config
	S_REDIST_RELEASE_TEMPLATES=$S_REDIST_RELEASE_CONFIGS/templates
	S_REDIST_RELEASE_GENERATED=$S_REDIST_RELEASE_CONFIGS/generated
	rm -rf $S_REDIST_RELEASE_CONFIGS
	mkdir -p $S_REDIST_RELEASE_GENERATED

	# copy from release and generate environment files using templates
	f_release_downloaddir $S_REDIST_SRCDIR/config/templates $S_REDIST_RELEASE_TEMPLATES

	# check any templates in release directory
	if [ ! -d "$S_REDIST_RELEASE_TEMPLATES" ]; then
		echo configuration templates are not found in release directory. Skipped.
		return 1
	fi

	# configure
	if [ "$S_REDIST_CONFCOMPLIST" = "all" ]; then
		f_distr_getconfcomplist
		S_REDIST_CONFCOMPLIST="$C_DISTR_CONF_COMPLIST"

		./configure.sh -dc $DC release $S_REDIST_RELEASE_TEMPLATES $S_REDIST_RELEASE_GENERATED $SRVNAME_LIST
		if [ "$?" != "0" ]; then
			echo f_local_prepare_conf: unsuccessul configure.sh. Exiting
			exit 1
		fi
	else
		./configure.sh -partialconf -dc $DC release $S_REDIST_RELEASE_TEMPLATES $S_REDIST_RELEASE_GENERATED $SRVNAME_LIST
		if [ "$?" != "0" ]; then
			echo f_local_prepare_conf: unsuccessul configure.sh. Exiting
			exit 1
		fi
	fi
}

function f_local_prepare() {
	if [ "$GETOPT_BACKUP" = "no" ]; then
		C_REDIST_NOBACKUP=true
	fi

	# get source directory
	local F_REDIST_RELEASE_FILE=$S_REDIST_TMP/$C_ENV_ID/download/$P_SRCVERSIONDIR-release.xml
	mkdir -p `dirname $F_REDIST_RELEASE_FILE`

	# check source dir
	f_release_getdistrdir $P_SRCVERSIONDIR
	S_REDIST_SRCDIR=$C_RELEASE_SRCDIR
	S_REDIST_SRCVER=$C_RELEASE_SRCVER

	# activate release.xml
	f_release_downloadfile $S_REDIST_SRCDIR/release.xml $F_REDIST_RELEASE_FILE
	f_release_setfile $F_REDIST_RELEASE_FILE

	# check obsolete status
	if [ "$GETOPT_OBSOLETE" = "yes" ] && [ "$C_RELEASE_PROPERTY_OBSOLETE" = "false" ]; then
		echo trying to redist non-obsolete release using GETOPT_OBSOLETE=$GETOPT_OBSOLETE. Exiting
		exit 1
	fi
	if [ "$GETOPT_OBSOLETE" = "no" ] && [ "$C_RELEASE_PROPERTY_OBSOLETE" = "true" ]; then
		echo trying to redist obsolete release using GETOPT_OBSOLETE=$GETOPT_OBSOLETE. Exiting
		exit 1
	fi

	# read relase configuration if required
	if [ "$GETOPT_DEPLOYCONF" = "yes" ]; then
		f_local_prepare_conf
	else
		S_REDIST_CONFCOMPLIST=
	fi
}

function f_local_recreate_folders() {
	local P_SRVNAME=$1
	local P_HOSTLOGIN_LIST="$2"

	local NODE=1
	local hostlogin
	for hostlogin in $P_HOSTLOGIN_LIST; do
		f_redist_recreatedir $P_SRVNAME $hostlogin $P_SRCVERSIONDIR
		NODE=$(expr $NODE + 1)
	done
}

# get server list
function f_local_executedc() {
	echo execute datacenter=$DC...
	f_env_getxmlserverlist $DC
	local F_SERVER_LIST=$C_ENV_XMLVALUE

	f_checkvalidlist "$F_SERVER_LIST" "$SRVNAME_LIST"
	f_getsubset "$F_SERVER_LIST" "$SRVNAME_LIST"
	F_SERVER_LIST=$C_COMMON_SUBSET

	# if configuration deployment requested - validate environment data
	if [ "$GETOPT_DEPLOYCONF" = "yes" ]; then
		./confcheck.sh -execute $F_SERVER_LIST
		if [ "$?" != "0" ]; then
			echo confcheck.sh failed: invalid environment data. Exiting
			exit 1
		fi
	fi

	# for all servers do recreate redist folders
	local server
	for server in $F_SERVER_LIST; do
		f_env_getxmlserverinfo $DC $server $GETOPT_DEPLOYGROUP

		if [ "$C_ENV_SERVER_DEPLOYTYPE" != "manual" ]; then
			local F_STATICSERVER=$C_ENV_SERVER_STATICSERVER
			local F_ADMINSERVER=$C_ENV_SERVER_HOTDEPLOYSERVER

			f_local_recreate_folders $server "$C_ENV_SERVER_HOSTLOGIN_LIST"

			if [ "$F_STATICSERVER" != "" ]; then
				f_env_getxmlserverinfo $DC $F_STATICSERVER $GETOPT_DEPLOYGROUP
				f_local_recreate_folders $F_STATICSERVER "$C_ENV_SERVER_HOSTLOGIN_LIST"
			fi

			if [ "$F_ADMINSERVER" != "" ]; then
				f_local_recreate_folders $server "$F_ADMINSERVER"
			fi
		fi
	done

	# iterate servers
	local server
	for server in $F_SERVER_LIST; do
		f_local_execute_server $server
	done
}

function f_local_execute_all() {
	f_release_resolverelease "$P_SRCVERSIONDIR"
	P_SRCVERSIONDIR=$C_RELEASE_DISTRID

	echo redist.sh: execute dc=$DC, releasedir=$P_SRCVERSIONDIR, servers=$SRVNAME_LIST...

	rm -rf $S_REDIST_TMP
	mkdir -p $S_REDIST_TMP

	# resdist all std binaries (except for windows-based)
	echo redist.sh: copy distribution package to environment staging area...

	# execute datacenter
	f_local_prepare
	f_local_executedc
}

f_local_execute_all

echo redist.sh: SUCCESSFULLY DONE.
