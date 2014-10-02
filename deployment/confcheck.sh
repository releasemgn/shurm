#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo startenv.sh: DC not set
	exit 1
fi

SRVNAME_LIST=$*

# load common functions
. ./common.sh

S_CONFCHECK_PROPLIST_ENV=
S_CONFCHECK_PROPLIST_DC=
S_CONFCHECK_PROPLIST_SERVER=
S_CONFCHECK_BASELINE_ENV=
S_CONFCHECK_BASELINE_DC=
S_CONFCHECK_BASELINE_SERVER=
S_CONFCHECK_STATUS=

function f_local_checklists() {
	local P_CONTEXT="$1"
	local P_LISTENV="$2"
	local P_LISTBASE="$3"

	# check env in base
	for var in $P_LISTENV; do
		if [ "$var" != "configuration-baseline" ] && [[ ! " $P_LISTBASE " =~ " $var " ]]; then
			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo unexpected variable=$var in $P_CONTEXT
				S_CONFCHECK_STATUS=failed
			else
				echo unexpected variable=$var in $P_CONTEXT. Exiting
				exit 1
			fi
		else
			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo variable=$var in $P_CONTEXT - ok
			fi
		fi
	done

	# check base in env
	for var in $P_LISTBASE; do
		if [ "$var" != "configuration-baseline" ] && [[ ! " $P_LISTENV " =~ " $var " ]]; then
			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo missing variable=$var in $P_CONTEXT
				S_CONFCHECK_STATUS=failed
			else
				echo missing variable=$var in $P_CONTEXT. Exiting
				exit 1
			fi
		else
			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo variable=$var in $P_CONTEXT - ok
			fi
		fi
	done
}

function f_local_checkconf_env() {
	local F_CONFCHECK_PROPLIST=$( 
		. ./setenv.sh $S_CONFCHECK_BASELINE_ENV
		if [ "$?" != "0" ]; then
			echo invalid baseline environment=$S_CONFCHECK_BASELINE_ENV. Exiting
			exit 1
		fi

		f_env_getenvpropertylist
		echo "$C_ENV_XMLVALUE"
		exit 0
	)
	if [[ "$F_CONFCHECK_PROPLIST" =~ "invalid baseline" ]]; then
		echo $F_CONFCHECK_PROPLIST
		exit 1
	fi
	
	f_local_checklists "environment" "$S_CONFCHECK_PROPLIST_ENV" "$F_CONFCHECK_PROPLIST"
}

function f_local_checkconf_dc() {
	local F_CONFCHECK_PROPLIST=$( 
		. ./setenv.sh $S_CONFCHECK_BASELINE_ENV
		if [ "$?" != "0" ]; then
			echo invalid baseline environment=$S_CONFCHECK_BASELINE_ENV. Exiting
			exit 1
		fi

		f_env_getdcstatus $S_CONFCHECK_BASELINE_DC
		if [ "$C_ENV_STATUS" != "valid" ]; then
			echo invalid baseline environment=$S_CONFCHECK_BASELINE_ENV dc=$S_CONFCHECK_BASELINE_DC. Exiting
			exit 1
		fi

		f_env_getdcpropertylist $S_CONFCHECK_BASELINE_DC
		echo "$C_ENV_XMLVALUE"
		exit 0
	)

	if [[ "$F_CONFCHECK_PROPLIST" =~ "invalid baseline" ]]; then
		echo $F_CONFCHECK_PROPLIST
		exit 1
	fi
	f_local_checklists "dc=$DC" "$S_CONFCHECK_PROPLIST_DC" "$F_CONFCHECK_PROPLIST"
}

function f_local_checkconf_server() {
	local P_SERVER=$1

	local F_CONFCHECK_PROPLIST=$( 
		. ./setenv.sh $S_CONFCHECK_BASELINE_ENV
		if [ "$?" != "0" ]; then
			echo invalid baseline environment=$S_CONFCHECK_BASELINE_ENV. Exiting
			exit 1
		fi

		f_env_getserverstatus $S_CONFCHECK_BASELINE_DC $S_CONFCHECK_BASELINE_SERVER
		if [ "$C_ENV_STATUS" != "valid" ]; then
			echo invalid baseline environment=$S_CONFCHECK_BASELINE_ENV dc=$S_CONFCHECK_BASELINE_DC server=$S_CONFCHECK_BASELINE_SERVER. Exiting
			exit 1
		fi

		f_env_getserverpropertylist $S_CONFCHECK_BASELINE_DC $S_CONFCHECK_BASELINE_SERVER
		echo "$C_ENV_XMLVALUE"
		exit 0
	)

	if [[ "$F_CONFCHECK_PROPLIST" =~ "invalid baseline" ]]; then
		echo $F_CONFCHECK_PROPLIST
		exit 1
	fi
	f_local_checklists "dc=$DC server=$P_SERVER" "$S_CONFCHECK_PROPLIST_SERVER" "$F_CONFCHECK_PROPLIST"
}

function f_local_execute_env() {
	# read env properties...
	f_env_getenvpropertylist
	S_CONFCHECK_PROPLIST_ENV="$C_ENV_XMLVALUE"

	if [ "$GETOPT_EXECUTE" = "no" ]; then
		# show values
		echo ============================================ show env properties...
		local var
		for var in $S_CONFCHECK_PROPLIST_ENV; do
			f_env_getenvpropertyvalue $var
			echo env.$var=$C_ENV_XMLVALUE
		done
	else
		if [[ " $S_CONFCHECK_PROPLIST_ENV " =~ " configuration-baseline " ]]; then
			f_env_getenvpropertyvalue "configuration-baseline"
			S_CONFCHECK_BASELINE_ENV=$C_ENV_XMLVALUE
			echo ============================================ check env properties baseline=$S_CONFCHECK_BASELINE_ENV ...
			f_local_checkconf_env
		fi
	fi
}

function f_local_execute_dc() {
	# echo read data center=$DC properties...
	f_env_getdcpropertylist $DC
	S_CONFCHECK_PROPLIST_DC="$C_ENV_XMLVALUE"

	if [ "$GETOPT_EXECUTE" = "no" ]; then
		# show values
		echo ============================================ data center=$DC properties...
		local var
		for var in $S_CONFCHECK_PROPLIST_DC; do
			f_env_getdcpropertyvalue $DC $var
			echo dc.$var=$C_ENV_XMLVALUE
		done
	else
		if [[ " $S_CONFCHECK_PROPLIST_ENV " =~ " configuration-baseline " ]] &&
		   [[ " $S_CONFCHECK_PROPLIST_DC " =~ " configuration-baseline " ]]; then
			f_env_getdcpropertyvalue $DC "configuration-baseline"
			S_CONFCHECK_BASELINE_DC=$C_ENV_XMLVALUE
			echo ============================================ check dc=$DC properties baseline=$S_CONFCHECK_BASELINE_DC ...
			f_local_checkconf_dc
		fi
	fi
}

function f_local_execute_server() {
	local P_SERVER=$1

	# echo read server properties...
	f_env_getserverpropertylist $DC $P_SERVER
	S_CONFCHECK_PROPLIST_SERVER="$C_ENV_XMLVALUE"

	if [ "$GETOPT_EXECUTE" = "no" ]; then
		# show values
		echo ============================================ data center=$DC server=$P_SERVER properties...
		local var
		for var in $S_CONFCHECK_PROPLIST_SERVER; do
			f_env_getserverpropertyvalue $DC $P_SERVER $var
			echo server.$var=$C_ENV_XMLVALUE
		done
	else
		if [[ " $S_CONFCHECK_PROPLIST_ENV " =~ " configuration-baseline " ]] &&
		   [[ " $S_CONFCHECK_PROPLIST_DC " =~ " configuration-baseline " ]] &&
		   [[ " $S_CONFCHECK_PROPLIST_SERVER " =~ " configuration-baseline " ]]; then
			f_env_getserverpropertyvalue $DC $P_SERVER "configuration-baseline"
			S_CONFCHECK_BASELINE_SERVER=$C_ENV_XMLVALUE
			echo ============================================ check dc=$DC server=$P_SERVER properties baseline=$S_CONFCHECK_BASELINE_SERVER...
			f_local_checkconf_server $P_SERVER
		fi
	fi
}

# get server list
function f_local_executedc() {
	echo check configuration parameters in datacenter=$DC...
	S_CONFCHECK_STATUS=ok

	# read properties
	f_local_execute_env

	# read properties
	f_local_execute_dc

	f_env_getxmlserverlist $DC
	local F_SERVER_LIST=$C_ENV_XMLVALUE

	f_checkvalidlist "$F_SERVER_LIST" "$SRVNAME_LIST"
	f_getsubset "$F_SERVER_LIST" "$SRVNAME_LIST"
	F_SERVER_LIST=$C_COMMON_SUBSET

	# execute server list
	for server in $F_SERVER_LIST; do
		f_local_execute_server "$server"
	done

	if [ "$S_CONFCHECK_STATUS" != "ok" ]; then
		echo confcheck.sh: configuration check failed. Exiting
		exit 1
	fi
}

# execute datacenter
f_local_executedc

echo confcheck.sh: SUCCESSFULLY DONE.
exit 0
