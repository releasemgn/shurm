#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

. ./getopts.sh

# check params
# should be specific DC or "all"
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo rollout.sh: DC not set
	exit 1
fi

P_MSG=$1

# load common functions
. ./common.sh

# execute
if [ "$C_ENV_PROPERTY_SKYPE_CHATROOMFILE" != "" ]; then
	if [ "$DC" = "all" ]; then
		echo "$P_MSG" >> $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/$C_ENV_PROPERTY_SKYPE_CHATROOMFILE
	else
		echo "$P_MSG (dc=$DC)" >> $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/$C_ENV_PROPERTY_SKYPE_CHATROOMFILE
	fi

	echo sendchatmsg.sh: msg sent to $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/$C_ENV_PROPERTY_SKYPE_CHATROOMFILE
fi
