#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo checkenv.sh: DC not set
	exit 1
fi

# check call form: server node1 node2...
NODE_LIST=
if [[ "$2" =~ ^[1-9] ]]; then
	SRVNAME_LIST=$1
	shift 1
	NODE_LIST=$*
else
	SRVNAME_LIST=$*
fi

# load common functions
. ./common.sh
. ./commoninfo.sh
. ./commonprocess.sh

S_ENV_HOST=
S_CHECKENV_TMP="/tmp/$HOSTNAME.$USER.checkenv.p$$"
S_CHECKENV_WSDL_FAILED=
S_CHECKENV_COMPONENTLIST_FAILED=
S_CHECKENV_NODELIST_FAILED=
S_CHECKENV_PROXY_NODELIST_FAILED=
S_CHECKENV_SERVER_FAILED=
S_CHECKENV_NLB_NODELIST_FAILED=
S_CHECKENV_APP_NODELIST_FAILED=
S_CHECKENV_NLB_COMPLIST_FAILED=
S_CHECKENV_APP_COMPLIST_FAILED=

function f_local_getnode() {
	local P_HOSTLIST=$1
	local P_NODE=$2

	if [ "$P_HOSTLIST" = "" ]; then
		echo f_local_getnode: P_HOSTLIST is empty.
		exit 1
	fi	

	S_ENV_HOST=`echo $P_HOSTLIST | cut -d " " -f$P_NODE | sed "s/ //g"`
	if [ "$S_ENV_HOST" = "" ]; then
		echo f_local_getnode: cannot extract node=$P_NODE from P_HOSTLIST="$P_HOSTLIST"
		exit 1
	fi
}

function f_local_check_wsdl() {
	local P_PROGRAMNAME=$1
	local P_NLBHOST=$2
	local P_COMPONENT=$3
	local P_ENDPOINT=$4

	f_info_check_wsdl $P_NLBHOST $P_COMPONENT $P_ENDPOINT $S_CHECKENV_TMP/$C_ENV_ID/wsdl.$P_PROGRAMNAME
	if [ $? -ne 0 ]; then
		S_CHECKENV_WSDL_FAILED=yes
		return 1
	fi

	return 0
}

function f_local_checkcomponent_endpoints() {
	local P_PROGRAMNAME=$1
	local P_NLBHOST=$2
	local P_COMPONENT=$3

	# get deployment components

	S_CHECKENV_WSDL_FAILED=no
	f_distr_getcomponentwebservices $P_COMPONENT

	S_URLLIST="$C_DISTR_WSITEMS"
	for url in $S_URLLIST; do
		f_local_check_wsdl $P_PROGRAMNAME $P_NLBHOST $P_COMPONENT $url
	done

	if [ "$S_CHECKENV_WSDL_FAILED" = "yes" ]; then
		return 1
	fi

	return 0
}

function f_local_checkone_endpoints() {
	local P_PROGRAMNAME=$1
	local P_NLBHOST=$2
	local P_COMPONENT_LIST="$3"

	S_CHECKENV_COMPONENTLIST_FAILED=
	local component
	for component in $P_COMPONENT_LIST; do
		echo component=$component:
		f_local_checkcomponent_endpoints $P_PROGRAMNAME $P_NLBHOST $component
		if [ $? -ne 0 ]; then
			S_CHECKENV_COMPONENTLIST_FAILED="$S_CHECKENV_COMPONENTLIST_FAILED $component"
		fi
	done

	if [ "$S_CHECKENV_COMPONENTLIST_FAILED" != "" ]; then
		return 1
	fi

	return 0
}

function f_local_check_endpoints_nlb() {
	local P_PROGRAMNAME=$1
	local P_NLBHOSTLIST="$2"
	local P_COMPONENT_LIST="$3"

	# iterate nlb nodes
	local KNLB=1
	local F_NLBN=`echo "$P_NLBHOSTLIST" | tr " " "\n" | grep -c "@"`
	S_CHECKENV_NODELIST_FAILED=
	local F_CHECKENV_COMPONENTLIST_FAILED=
	while [ ! "$KNLB" -gt $F_NLBN ]; do
		f_local_getnode "$P_NLBHOSTLIST" $KNLB
		S_ENV_HOST=`echo $S_ENV_HOST | cut -d "@" -f2 | sed "s/ //g"`

		echo nlb node$KNLB=$S_ENV_HOST:
		f_local_checkone_endpoints $P_PROGRAMNAME $S_ENV_HOST "$P_COMPONENT_LIST"
		if [ $? -ne 0 ]; then
			S_CHECKENV_NODELIST_FAILED="$S_CHECKENV_NODELIST_FAILED $KNLB"
			F_CHECKENV_COMPONENTLIST_FAILED="$F_CHECKENV_COMPONENTLIST_FAILED $S_CHECKENV_COMPONENTLIST_FAILED"
		fi
	        KNLB=$(expr $KNLB + 1)
	done

	S_CHECKENV_COMPONENTLIST_FAILED=`echo $F_CHECKENV_COMPONENTLIST_FAILED | tr " " "\n" | sort -u | tr "\n" " "`

	if [ "$S_CHECKENV_NODELIST_FAILED" != "" ]; then
		return 1
	fi

	return 0
}

function f_local_check_endpoints_app() {
	local P_PROGRAMNAME=$1
	local P_APPHOSTLIST="$2"
	local P_APPPORT=$3
	local P_COMPONENT_LIST="$4"

	# iterate app nodes
	local KAPP=1
	local F_APPN=`echo "$P_APPHOSTLIST" | tr " " "\n" | grep -c "@"`
	S_CHECKENV_NODELIST_FAILED=
	local F_CHECKENV_COMPONENTLIST_FAILED=
	while [ ! "$KAPP" -gt $F_APPN ]; do
		if [ "$NODE_LIST" = "" ] || [[ "$NODE_LIST" =~ "$KAPP" ]]; then
			f_local_getnode "$P_APPHOSTLIST" $KAPP
			S_ENV_HOST=`echo $S_ENV_HOST | cut -d "@" -f2 | sed "s/ //g"`

			echo app node$KAPP=$S_ENV_HOST:
			f_local_checkone_endpoints $P_PROGRAMNAME $S_ENV_HOST:$P_APPPORT "$P_COMPONENT_LIST"
			if [ $? -ne 0 ]; then
				S_CHECKENV_NODELIST_FAILED="$S_CHECKENV_NODELIST_FAILED $KAPP"
				F_CHECKENV_COMPONENTLIST_FAILED="$F_CHECKENV_COMPONENTLIST_FAILED $S_CHECKENV_COMPONENTLIST_FAILED"
			fi
		fi
	        KAPP=$(expr $KAPP + 1)
	done

	S_CHECKENV_COMPONENTLIST_FAILED=`echo $F_CHECKENV_COMPONENTLIST_FAILED | tr " " "\n" | sort -u | tr "\n" " "`

	if [ "$S_CHECKENV_NODELIST_FAILED" != "" ]; then
		return 1
	fi

	return 0
}

function f_local_checkone_endpoints_app() {
	local P_PROGRAMNAME=$1
	local P_APPHOST="$2"
	local P_APPPORT=$3
	local P_COMPONENT_LIST="$4"

	S_ENV_HOST=`echo $P_APPHOST | cut -d "@" -f2`

	echo app node=$S_ENV_HOST:
	f_local_checkone_endpoints $P_PROGRAMNAME $S_ENV_HOST:$P_APPPORT "$P_COMPONENT_LIST"
	return $?
}

function f_local_check_endpoints() {
	local P_PROGRAMNAME=$1
	local P_NLBHOSTLIST="$2"
	local P_APPHOSTLIST="$3"
	local P_APPPORT=$4
	local P_COMPONENT_LIST="$5"

	S_CHECKENV_SERVER_FAILED=
	S_CHECKENV_NLB_NODELIST_FAILED=
	S_CHECKENV_APP_NODELIST_FAILED=
	S_CHECKENV_NLB_COMPLIST_FAILED=
	S_CHECKENV_APP_COMPLIST_FAILED=

	echo $P_PROGRAMNAME: check endpoints
	local F_CHECKENV_LIST_FAILED=
	if [ "$NODE_LIST" = "" ]; then
		f_local_check_endpoints_nlb $P_PROGRAMNAME "$P_NLBHOSTLIST" "$P_COMPONENT_LIST"
		if [ $? -ne 0 ]; then
			S_CHECKENV_NLB_NODELIST_FAILED=$S_CHECKENV_NODELIST_FAILED
			S_CHECKENV_NLB_COMPLIST_FAILED=$S_CHECKENV_COMPONENTLIST_FAILED
		fi
	fi
	f_local_check_endpoints_app $P_PROGRAMNAME "$P_APPHOSTLIST" $P_APPPORT "$P_COMPONENT_LIST"
	if [ $? -ne 0 ]; then
		S_CHECKENV_APP_NODELIST_FAILED=$S_CHECKENV_NODELIST_FAILED
		S_CHECKENV_APP_COMPLIST_FAILED=$S_CHECKENV_COMPONENTLIST_FAILED
	fi

	if [ "$S_CHECKENV_NLB_NODELIST_FAILED" != "" ] || [ "$S_CHECKENV_APP_NODELIST_FAILED" != "" ]; then
		return 1
	fi

	return 0
}

function f_local_checkenv_generic() {
	local P_PROGRAMNAME=$1
	local P_COMPONENT_LIST="$2"
	local P_ENV_HOSTLOGINLIST="$3"
	local P_ENV_ROOTDIR=$4
	local P_ENV_BINPATH=$5
	local P_NLBHOSTLIST="$6"
	local P_APPPORT=$7

	S_CHECKENV_SERVER_FAILED=
	S_CHECKENV_NLB_NODELIST_FAILED=
	S_CHECKENV_APP_NODELIST_FAILED=
	S_CHECKENV_NLB_COMPLIST_FAILED=
	S_CHECKENV_APP_COMPLIST_FAILED=

	echo check $P_PROGRAMNAME...

	if [ "$P_NLBHOSTLIST" != "" ] && [ "$NODE_LIST" = "" ]; then
		f_local_check_endpoints_nlb $P_PROGRAMNAME "$P_NLBHOSTLIST" "$P_COMPONENT_LIST"
		if [ $? -ne 0 ]; then
			S_CHECKENV_NLB_NODELIST_FAILED=$S_CHECKENV_NODELIST_FAILED
			S_CHECKENV_NLB_COMPLIST_FAILED=$S_CHECKENV_COMPONENTLIST_FAILED
		fi
	fi

	# iterate nodes
	local KJ=1
	local F_NJ=`echo "$P_ENV_HOSTLOGINLIST" | tr " " "\n" | grep -c "@"`
	while [ ! "$KJ" -gt $F_NJ ]; do
		if [ "$NODE_LIST" = "" ] || [[ "$NODE_LIST" =~ "$KJ" ]]; then
			f_local_getnode "$P_ENV_HOSTLOGINLIST" $KJ

			echo node$KJ=$S_ENV_HOST:
			f_process_check_generic $DC $P_PROGRAMNAME $S_ENV_HOST $P_ENV_ROOTDIR/$P_ENV_BINPATH

			# check endpoints	
			if [ "$C_PROCESS_STATUS" = "STARTED" ]; then
				if [ "$P_APPPORT" != "" ]; then
					f_local_checkone_endpoints_app $P_PROGRAMNAME $S_ENV_HOST $P_APPPORT "$P_COMPONENT_LIST"
					if [ $? -ne 0 ]; then
						S_CHECKENV_APP_NODELIST_FAILED="$S_CHECKENV_APP_NODELIST_FAILED $KJ"
						S_CHECKENV_APP_COMPLIST_FAILED="$S_CHECKENV_APP_COMPLIST_FAILED $S_CHECKENV_COMPONENTLIST_FAILED"
					fi
				fi
			else
				S_CHECKENV_APP_NODELIST_FAILED="$S_CHECKENV_APP_NODELIST_FAILED $KJ"
			fi
		fi
	        KJ=$(expr $KJ + 1)
	done

	S_CHECKENV_APP_COMPLIST_FAILED=`echo $S_CHECKENV_APP_COMPLIST_FAILED | tr " " "\n" | sort -u | tr "\n" " "`

	if [ "$S_CHECKENV_APP_NODELIST_FAILED" != "" ]; then
		return 1
	fi

	return 0
}

function f_local_checkenv_service() {
	local P_PROGRAMNAME=$1
	local P_SERVICENAME=$2
	local P_COMPONENT_LIST="$3"
	local P_ENV_HOSTLOGINLIST="$4"

	echo check $P_PROGRAMNAME...

	# iterate nodes
	local KJ=1
	local F_NJ=`echo "$P_ENV_HOSTLOGINLIST" | tr " " "\n" | grep -c "@"`
	while [ ! "$KJ" -gt $F_NJ ]; do
		if [ "$NODE_LIST" = "" ] || [[ "$NODE_LIST" =~ "$KJ" ]]; then
			f_local_getnode "$P_ENV_HOSTLOGINLIST" $KJ

			echo node$KJ=$S_ENV_HOST:
			f_process_check_service $DC $P_PROGRAMNAME $P_SERVICENAME $S_ENV_HOST
			if [ "$C_PROCESS_STATUS" != "STARTED" ]; then
				S_CHECKENV_APP_NODELIST_FAILED="$S_CHECKENV_APP_NODELIST_FAILED $KJ"
			fi
		fi
	        KJ=$(expr $KJ + 1)
	done

	S_CHECKENV_APP_COMPLIST_FAILED=`echo $S_CHECKENV_APP_COMPLIST_FAILED | tr " " "\n" | sort -u | tr "\n" " "`

	if [ "$S_CHECKENV_APP_NODELIST_FAILED" != "" ]; then
		return 1
	fi

	return 0
}

function f_local_checkenv_database_one() {
	local P_PROGRAMNAME=$1
	local P_ENV_HOSTLOGIN=$2

	# check host is available
	f_run_cmd $P_ENV_HOSTLOGIN "echo -n ok"
	if [ "$RUN_CMD_RES" != "ok" ]; then
		echo $P_ENV_HOSTLOGIN: host is not available
		return 1
	fi

	return 0
}

function f_local_checkenv_database() {
	local P_PROGRAMNAME=$1
	local P_TNSNAME=$2
	local P_ENV_HOSTLOGINLIST="$3"

	echo check $P_PROGRAMNAME...

	# iterate nodes
	local KJ=1
	local F_NJ=`echo "$P_ENV_HOSTLOGINLIST" | tr " " "\n" | grep -c "@"`
	while [ ! "$KJ" -gt $F_NJ ]; do
		if [ "$NODE_LIST" = "" ] || [[ "$NODE_LIST" =~ "$KJ" ]]; then
			f_local_getnode "$P_ENV_HOSTLOGINLIST" $KJ

			echo node$KJ=$S_ENV_HOST:
			f_local_checkenv_database_one $P_PROGRAMNAME $S_ENV_HOST

			if [ "$?" != "0" ]; then
				S_CHECKENV_APP_NODELIST_FAILED="$S_CHECKENV_APP_NODELIST_FAILED $KJ"
			fi
		fi
	        KJ=$(expr $KJ + 1)
	done

	if [ "$S_CHECKENV_APP_NODELIST_FAILED" != "" ]; then
		return 1
	fi

	# check tnsname is sql client is available
	local F_FINDSQLPLUS=`which sqlplus 2>&1`
	if [ "$F_FINDSQLPLUS" != "" ] && [[ ! "$F_FINDSQLPLUS" =~ "no sqlplus" ]]; then
		local F_TNSSTATUS=`sqlplus wrong/wrong@$P_TNSNAME < /dev/null | grep ORA`
		if [[ ! "$F_TNSSTATUS" =~ "invalid username/password" ]]; then
			echo "database server tnsname=$P_TNSNAME is not available"
			S_CHECKENV_SERVER_FAILED=tnsname
			return 1
		fi
	fi

	return 0
}

function f_local_execute_server_single() {
	local P_SRVNAME=$1

	f_env_getxmlserverinfo $DC $P_SRVNAME $GETOPT_DEPLOYGROUP

	# check by type
	local F_LOCAL_SRVNAME=$P_SRVNAME
	local F_SERVER_TYPE=$C_ENV_SERVER_TYPE
	if [ "$F_SERVER_TYPE" = "generic.web" ]; then
		f_local_checkenv_generic $P_SRVNAME "$C_ENV_SERVER_COMPONENT_LIST" "$C_ENV_SERVER_HOSTLOGIN_LIST" "$C_ENV_SERVER_ROOTPATH" "$C_ENV_SERVER_BINPATH"

	elif [ "$F_SERVER_TYPE" = "generic.server" ] || [ "$F_SERVER_TYPE" = "generic.command" ]; then
		if [ "$GETOPT_FORCE" = "no" ] && [ "$F_SERVER_TYPE" = "generic.command" ]; then
			return 1
		fi

		local F_GENERIC_PROGRAMNAME=$P_SRVNAME
		local F_GENERIC_HOSTLOGIN_LIST=$C_ENV_SERVER_HOSTLOGIN_LIST
		local F_GENERIC_SERVER_ROOTPATH=$C_ENV_SERVER_ROOTPATH
		local F_GENERIC_SERVER_BINPATH=$C_ENV_SERVER_BINPATH
		local F_GENERIC_NLBSERVER=$C_ENV_SERVER_NLBSERVER
		local F_GENERIC_PORT=$C_ENV_SERVER_PORT
		local F_GENERIC_COMPONENT_LIST=$C_ENV_SERVER_COMPONENT_LIST

		local F_NLB_HOSTLOGIN_LIST
		if [ "$F_GENERIC_NLBSERVER" != "" ]; then
			f_env_getxmlserverinfo $DC $F_GENERIC_NLBSERVER $GETOPT_DEPLOYGROUP
			F_NLB_HOSTLOGIN_LIST=$C_ENV_SERVER_HOSTLOGIN_LIST
		else
			F_NLB_HOSTLOGIN_LIST=
		fi
		f_local_checkenv_generic $F_GENERIC_PROGRAMNAME "$F_GENERIC_COMPONENT_LIST" "$F_GENERIC_HOSTLOGIN_LIST" "$F_GENERIC_SERVER_ROOTPATH" "$F_GENERIC_SERVER_BINPATH" "$F_NLB_HOSTLOGIN_LIST" $F_GENERIC_PORT

	elif [ "$F_SERVER_TYPE" = "service" ]; then
		local F_GENERIC_PROGRAMNAME=$P_SRVNAME
		local F_GENERIC_SERVICENAME=$C_ENV_SERVER_SERVICENAME
		local F_GENERIC_HOSTLOGIN_LIST=$C_ENV_SERVER_HOSTLOGIN_LIST
		local F_GENERIC_COMPONENT_LIST=$C_ENV_SERVER_COMPONENT_LIST

		f_local_checkenv_service $F_GENERIC_PROGRAMNAME $F_GENERIC_SERVICENAME "$F_GENERIC_COMPONENT_LIST" "$F_GENERIC_HOSTLOGIN_LIST"

	elif [ "$F_SERVER_TYPE" = "generic.windows" ]; then
		local F_GENERIC_PROGRAMNAME=$P_SRVNAME
		local F_GENERIC_HOSTLOGIN_LIST=$C_ENV_SERVER_HOSTLOGIN_LIST
		local F_GENERIC_NLBSERVER=$C_ENV_SERVER_NLBSERVER
		local F_GENERIC_PORT=$C_ENV_SERVER_PORT
		local F_GENERIC_COMPONENT_LIST=$C_ENV_SERVER_COMPONENT_LIST

		f_env_getxmlserverinfo $DC $F_GENERIC_NLBSERVER $GETOPT_DEPLOYGROUP
		local F_NLB_HOSTLOGIN_LIST=$C_ENV_SERVER_HOSTLOGIN_LIST
		f_local_check_endpoints $F_GENERIC_PROGRAMNAME "$F_NLB_HOSTLOGIN_LIST" "$F_GENERIC_HOSTLOGIN_LIST" $F_GENERIC_PORT "$F_GENERIC_COMPONENT_LIST"

	elif [ "$F_SERVER_TYPE" = "database" ]; then
		f_local_checkenv_database $P_SRVNAME $C_ENV_SERVER_DBTNSNAME "$C_ENV_SERVER_HOSTLOGIN_LIST"

	else
		echo unknown server type=$F_SERVER_TYPE. Exiting
		exit 1
	fi
}

function f_local_execute_server() {
	local P_EXECUTE_SRVNAME=$1

	# remove old wsdl
	rm -rf $S_CHECKENV_TMP/$C_ENV_ID/wsdl.$P_EXECUTE_SRVNAME
	mkdir -p $S_CHECKENV_TMP/$C_ENV_ID/wsdl.$P_EXECUTE_SRVNAME

	f_env_getxmlserverinfo $DC $P_EXECUTE_SRVNAME $GETOPT_DEPLOYGROUP
	local F_PROXYSERVER=$C_ENV_SERVER_PROXYSERVER

	echo ============================================ check server=$P_EXECUTE_SRVNAME...

	S_CHECKENV_SERVER_FAILED=
	S_CHECKENV_NLB_NODELIST_FAILED=
	S_CHECKENV_NLB_COMPLIST_FAILED=
	S_CHECKENV_APP_NODELIST_FAILED=
	S_CHECKENV_APP_COMPLIST_FAILED=

	# check proxy first
	S_CHECKENV_PROXY_NODELIST_FAILED=
	if [ "$F_PROXYSERVER" != "" ]; then
		echo check proxy server=$F_PROXYSERVER...
		f_local_execute_server_single $F_PROXYSERVER
		S_CHECKENV_PROXY_NODELIST_FAILED=$S_CHECKENV_APP_NODELIST_FAILED

		S_CHECKENV_SERVER_FAILED=
		S_CHECKENV_NLB_NODELIST_FAILED=
		S_CHECKENV_NLB_COMPLIST_FAILED=
		S_CHECKENV_APP_NODELIST_FAILED=
		S_CHECKENV_APP_COMPLIST_FAILED=
	fi

	echo check main server...
	f_local_execute_server_single $P_EXECUTE_SRVNAME

	# check status
	local F_STATUSOBJECT="$DC.$P_EXECUTE_SRVNAME"
	if [ "$S_CHECKENV_SERVER_FAILED" = "" ] && [ "$S_CHECKENV_PROXY_NODELIST_FAILED" = "" ] && [ "$S_CHECKENV_NLB_NODELIST_FAILED" = "" ] && [ "$S_CHECKENV_APP_NODELIST_FAILED" = "" ]; then
		echo "## server $F_STATUSOBJECT check OK"
		return 0
	fi

	local MSG="## server $F_STATUSOBJECT check FAILED:"
	if [ "$S_CHECKENV_SERVER_FAILED" != "" ]; then
		MSG="$MSG server.failed=$S_CHECKENV_SERVER_FAILED"
	fi
	if [ "$S_CHECKENV_PROXY_NODELIST_FAILED" != "" ]; then
		MSG="$MSG proxy.nodes.failed=($S_CHECKENV_PROXY_NODELIST_FAILED)"
	fi
	if [ "$S_CHECKENV_NLB_NODELIST_FAILED" != "" ]; then
		MSG="$MSG nlb.nodes.failed=($S_CHECKENV_NLB_NODELIST_FAILED)"
	fi
	if [ "$S_CHECKENV_APP_NODELIST_FAILED" != "" ]; then
		MSG="$MSG app.nodes.failed=($S_CHECKENV_APP_NODELIST_FAILED)"
	fi
	echo $MSG

	return 1
}

S_CHECKENV_SERVERLIST_FAILED=

# get server list
function f_local_execute_all() {
	# check all processes
	echo checkenv.sh: check environment...

	rm -rf $S_CHECKENV_TMP
	mkdir -p $S_CHECKENV_TMP

	echo execute datacenter=$DC...
	f_env_getxmlserverlist $DC
	local F_SERVER_LIST=$C_ENV_XMLVALUE

	f_checkvalidlist "$F_SERVER_LIST" "$SRVNAME_LIST"
	f_getsubset "$F_SERVER_LIST" "$SRVNAME_LIST"
	local F_SERVER_LIST=$C_COMMON_SUBSET

	S_CHECKENV_SERVERLIST_FAILED=

	# iterate servers
	local server
	for server in $F_SERVER_LIST; do
		f_local_execute_server $server
		if [ $? -ne 0 ]; then
			S_CHECKENV_SERVERLIST_FAILED="$S_CHECKENV_SERVERLIST_FAILED $server"
		fi
	done

	rm -rf $S_CHECKENV_TMP

	local F_STATUSOBJECT="$DC"
	if [ "$S_CHECKENV_SERVERLIST_FAILED" != "" ]; then
		echo "## dc $F_STATUSOBJECT check FAILED: issues on servers - $S_CHECKENV_SERVERLIST_FAILED"
		return 1
	fi

	echo "## dc $F_STATUSOBJECT check OK"
	echo "checkenv.sh: status is SUCCESSFUL"
	return 0
}

f_local_execute_all
S_FINALSTATUS=$?

echo checkenv.sh: finished.
exit $S_FINALSTATUS
