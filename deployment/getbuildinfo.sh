#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo getbuildinfo.sh: DC not set
	exit 1
fi

SRVNAME_LIST=$*

. ./common.sh
. ./commoninfo.sh

function f_local_getserveriteminfo() {
	local P_SERVER=$1
	local P_HOSTPORT="$2"
	local P_DISTRITEM=$3

	f_distr_readitem $xdistritem

	local F_PARAM="RELEASE"
	if [ "$GETOPT_BUILDINFO" != "" ]; then
		F_PARAM=$GETOPT_BUILDINFO
	fi

	if [ "$C_DISTR_WAR_CONTEXT" = "" ]; then
		return 1
	fi

	local F_BUILDINFOURL="http://$P_HOSTPORT/$C_DISTR_WAR_CONTEXT/htdocs/buildinfo.txt"
	local F_DISTRINFOTYPE=$C_DISTR_BUILDINFO

	if [ "$F_DISTRINFOTYPE" != "static" ] && [ "$F_DISTRINFOTYPE" != "oldstatic" ]; then
		return 1
	fi

	f_info_check_host_buildinfo "$F_BUILDINFOURL" $F_PARAM "$F_DISTRINFOTYPE"
}

function f_local_getserverbuildinfo() {
	local P_SERVER=$1
	local P_HOSTPORT="$2"
	local P_COMPLIST="$3"

	f_distr_getcomplistitems "$P_COMPLIST"
	local F_ITEM_LIST=$C_DISTR_ITEMS

	if [ "$F_ITEM_LIST" = "" ]; then 
		return 1
	fi

	# walk through distr items
	local xdistritem
	for xdistritem in $F_ITEM_LIST; do
		f_local_getserveriteminfo $P_SERVER $P_HOSTPORT $xdistritem
	done
}

function f_local_execute_server_nodes() {
	local P_EXECUTE_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_EXECUTE_SRVNAME $GETOPT_DEPLOYGROUP
	local F_LOCAL_COMPONENT_LIST="$C_ENV_SERVER_COMPONENT_LIST"
	local F_LOCAL_PROXYSERVER=$C_ENV_SERVER_PROXYSERVER
	if [ "$F_LOCAL_PROXYSERVER" = "" ]; then
		echo f_local_execute_server: proxy server not found for web server=$P_EXECUTE_SRVNAME. Skipped.
		return 1
	fi

	# find proxy server
	f_env_getxmlserverinfo $DC $F_LOCAL_PROXYSERVER $GETOPT_DEPLOYGROUP
	local F_SERVER_PORT=$C_ENV_SERVER_PORT

	# iterate by nodes
	local NODE=1
	local hostlogin
	for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
		echo execute server=$P_EXECUTE_SRVNAME node=$NODE...

		local F_HOST=`echo $hostlogin | cut -d "@" -f2`
		f_local_getserverbuildinfo $P_EXECUTE_SRVNAME "$F_HOST:$F_SERVER_PORT" "$F_LOCAL_COMPONENT_LIST"
		NODE=$(expr $NODE + 1)
	done
}

function f_local_execute_server_web() {
	local P_EXECUTE_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_EXECUTE_SRVNAME $GETOPT_DEPLOYGROUP
	local F_LOCAL_WEBDOMAIN=$C_ENV_SERVER_WEBDOMAIN
	local F_LOCAL_COMPONENT_LIST="$C_ENV_SERVER_COMPONENT_LIST"

	f_local_getserverbuildinfo $P_EXECUTE_SRVNAME "$F_LOCAL_WEBDOMAIN" "$F_LOCAL_COMPONENT_LIST"
}

function f_local_execute_server() {
	local P_EXECUTE_SRVNAME=$1

	echo "execute server=$P_EXECUTE_SRVNAME..."

	if [ "$GETOPT_NODES" = "yes" ]; then
		f_local_execute_server_nodes $P_EXECUTE_SRVNAME
	else
		f_local_execute_server_web $P_EXECUTE_SRVNAME
	fi
}

# get server list
function f_local_executedc() {
	echo execute datacenter=$DC...
	f_env_getxmlserverlist $DC
	local F_SERVER_LIST="$C_ENV_XMLVALUE"

	f_checkvalidlist "$F_SERVER_LIST" "$SRVNAME_LIST"
	f_getsubset "$F_SERVER_LIST" "$SRVNAME_LIST"
	F_SERVER_LIST=`echo $C_COMMON_SUBSET | tr " " "\n" | sort -u | tr "\n" " "`

	# iterate servers
	local server
	for server in $F_SERVER_LIST; do
		f_local_execute_server $server
	done
}

# check all processes
echo getbuildinfo.sh: get war status...

# execute datacenter
f_local_executedc

echo getbuildinfo.sh: finished.
