#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo deployall.sh: DC not set
	exit 1
fi

SRCVERSIONDIR=$1
if [ "$SRCVERSIONDIR" = "" ]; then
	echo deployall.sh: SRCVERSIONDIR not set
	exit 1
fi

# execute
. ./common.sh

function f_local_msg() {
	P_MSG="$1"

	echo $P_MSG
	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" != "true" ]; then
		if [ "$GETOPT_NOCHATMSG" != "yes" ]; then
			./sendchatmsg.sh -dc $DC "[deployall.sh] $P_MSG"
		fi
	fi
}

function f_local_executedc() {
	# inform
	f_local_msg "deploy release $SRCVERSIONDIR ..."

	# stop all
	./stopenv.sh -all -nomsg
	local F_STATUS=$?
	if [ "$F_STATUS" != "0" ]; then
		f_local_msg "errors when stopping environment, deploy cancelled."
		exit 1
	fi

	# rollout core
	./rollout.sh $SRCVERSIONDIR
	F_STATUS=$?
	if [ "$F_STATUS" != "0" ]; then
		f_local_msg "errors when rolling out release, deploy cancelled."
		exit 1
	fi

	# start all
	./startenv.sh -all -nomsg
	F_STATUS=$?
	if [ "$F_STATUS" != "0" ]; then
		f_local_msg "errors when starting environment, deploy cancelled."
		exit 1
	fi

	f_local_msg "successfully deployed"
}

function f_local_execute_all() {
	# check specific version
	if [ "$SRCVERSIONDIR" = "prod" ]; then
		f_release_getfullproddistr
		SRCVERSIONDIR=$C_RELEASE_DISTRID
	fi

	C_DEPLOY_EXECUTE_ECHO_ONLY=true
	C_REDIST_EXECUTE_ECHO_ONLY=true
	if [ "$GETOPT_EXECUTE" = "yes" ]; then
		C_DEPLOY_EXECUTE_ECHO_ONLY=false
		C_REDIST_EXECUTE_ECHO_ONLY=false
	fi

	if [ "$C_DEPLOY_EXECUTE_ECHO_ONLY" = "true" ]; then
		echo "deployall.sh: deploy environment version=$SRCVERSIONDIR (show only)..."
	else
		echo "deployall.sh: deploy environment version=$SRCVERSIONDIR (execute)..."
	fi

	# execute datacenter
	f_local_executedc
}

f_local_execute_all

echo deployall.sh: SUCCESSFULLY DONE.
