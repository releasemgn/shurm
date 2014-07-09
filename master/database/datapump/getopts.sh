#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

while [ "$#" -gt "0" ] && [[ $1 =~ ^-[a-z] ]]; do
	case $1 in
		'-showall')
			export GETOPT_SHOWALL=yes
			shift 1
			;;
		'-showonly')
			export GETOPT_EXECUTE=no
			shift 1
			;;
		'-execute')
			export GETOPT_EXECUTE=yes
			shift 1
			;;
		*)
			echo getopts.sh: invalid option=$1 in command line. Exiting
			exit 1
	esac
done
