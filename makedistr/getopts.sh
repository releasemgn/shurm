#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

while [ "$#" -gt "0" ]; do
	case $1 in
		'-get')
			export GETOPT_GET=yes
			shift 1
			;;
		'-dist')
			export GETOPT_DIST=yes
			shift 1
			;;
		'-showall')
			export GETOPT_SHOWALL=yes
			shift 1
			;;
		'-showonly')
			export GETOPT_SHOWONLY=yes
			shift 1
			;;
		'-showmain')
			export GETOPT_SHOWALL=no
			shift 1
			;;
		'-updatenexus')
			export GETOPT_UPDATENEXUS=yes
			shift 1
			;;
		'-nocheck')
			export GETOPT_CHECK=no
			shift 1
			;;
		'-release')
			export GETOPT_RELEASE=$2
			shift 2
			;;
		'-branch')
			export GETOPT_BRANCH=$2
			shift 2
			;;
		'-tag')
			export GETOPT_TAG=$2
			shift 2
			;;
		*)
			return 0
	esac
done
