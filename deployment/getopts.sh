#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

while [ "$#" -gt "0" ] && [[ "$1" =~ ^-[a-z] ]]; do
	case $1 in
		'-all')
			export GETOPT_ALL=yes
			shift 1
			;;
		'-app')
			export GETOPT_ALL=no
			shift 1
			;;
		'-execute')
			export GETOPT_EXECUTE=yes
			shift 1
			;;
		'-ignoreerrors')
			export GETOPT_IGNOREERRORS=yes
			shift 1
			;;
		'-showonly')
			export GETOPT_EXECUTE=no
			shift 1
			;;
		'-backup')
			export GETOPT_BACKUP=yes
			shift 1
			;;
		'-nobackup')
			export GETOPT_BACKUP=no
			shift 1
			;;
		'-obsolete')
			export GETOPT_OBSOLETE=yes
			shift 1
			;;
		'-noobsolete')
			export GETOPT_OBSOLETE=no
			shift 1
			;;
		'-showall')
			export GETOPT_SHOWALL=yes
			shift 1
			;;
		'-showmain')
			export GETOPT_SHOWALL=no
			shift 1
			;;
		'-conf')
			export GETOPT_DEPLOYCONF=yes
			shift 1
			;;
		'-partialconf')
			export GETOPT_DEPLOYPARTIALCONF=yes
			shift 1
			;;
		'-noconf')
			export GETOPT_DEPLOYCONF=no
			shift 1
			;;
		'-binary')
			export GETOPT_DEPLOYBINARY=yes
			shift 1
			;;
		'-nobinary')
			export GETOPT_DEPLOYBINARY=no
			shift 1
			;;
		'-hot')
			export GETOPT_DEPLOYHOT=yes
			shift 1
			;;
		'-cold')
			export GETOPT_DEPLOYHOT=no
			shift 1
			;;
		'-keepalive')
			export GETOPT_KEEPALIVE=yes
			shift 1
			;;
		'-nokeepalive')
			export GETOPT_KEEPALIVE=no
			shift 1
			;;
		'-skiperrors')
			export GETOPT_SKIPERRORS=yes
			shift 1
			;;
		'-strict')
			export GETOPT_SKIPERRORS=no
			shift 1
			;;
		'-downtime')
			export GETOPT_ZERODOWNTIME=no
			shift 1
			;;
		'-nodowntime')
			export GETOPT_ZERODOWNTIME=yes
			shift 1
			;;
		'-nodes')
			export GETOPT_NODES=yes
			shift 1
			;;
		'-nomsg')
			export GETOPT_NOCHATMSG=yes
			shift 1
			;;
		'-root')
			export GETOPT_ROOTUSER=yes
			shift 1
			;;
		'-force')
			export GETOPT_FORCE=yes
			shift 1
			;;
		'-noforce')
			export GETOPT_FORCE=no
			shift 1
			;;
		'-releasedir')
			export GETOPT_RELEASEDIR=$2
			shift 2
			;;
		'-deploygroup')
			export GETOPT_DEPLOYGROUP=$2
			shift 2
			;;
		'-unit')
			export GETOPT_UNIT=$2
			shift 2
			;;
		'-buildinfo')
			export GETOPT_BUILDINFO=$2
			shift 2
			;;
		'-tag')
			export GETOPT_TAG=$2
			shift 2
			;;
		'-dc')
			export GETOPT_DC=$2
			shift 2
			;;
		*)
			echo getopts.sh: invalid option=$1 in command line. Exiting
			exit 1
	esac
done
