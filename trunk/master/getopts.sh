#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

while [ "$#" -gt "0" ] && [[ "$1" =~ ^-[a-z] ]]; do
	case $1 in
		'-nomsg')
			export GETOPT_NOCHATMSG=yes
			shift 1
			;;
		'-showonly')
			export GETOPT_SHOWONLY=yes
			shift 1
			;;
		'-env')
			export GETOPT_ENV=$2
			shift 2
			;;
		*)
			echo getopts.sh: invalid option=$1 in command line. Exiting
			exit 1
	esac
done

. ../etc/config.sh

if [ "$C_CONFIG_PRODUCT_DEPLOYMENT_HOME" = "" ]; then
	echo C_CONFIG_PRODUCT_DEPLOYMENT_HOME is not defined. Exiting
	exit 1
fi
