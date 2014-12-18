#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

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
		'-a')
			export GETOPT_EXECUTEMODE=apply
			shift 1
			;;
		'-f')
			export GETOPT_EXECUTEMODE=force
			shift 1
			;;
		'-x')
			export GETOPT_EXECUTEMODE=anyway
			shift 1
			;;
		'-c')
			export GETOPT_EXECUTEMODE=correct
			shift 1
			;;
		'-r')
			export GETOPT_EXECUTEMODE=rollback
			shift 1
			;;
		'-p')
			export GETOPT_EXECUTEMODE=print
			shift 1
			;;
		'-s')
			export GETOPT_SKIPERRORS=yes # skip (ignore) errors and continue processing (checking SQL)
			shift 1
			;;
		'-m')
			export GETOPT_MOVE_ERRORS=yes # move incorrect scripts to errors folder
			shift 1
			;;
		'-l')
			export GETOPT_DATALOADOPT=yes
			shift 1
			;;
		'-nodist')
			export GETOPT_NODIST=yes # do not copy SQL to distributive
			shift 1
			;;
		'-auth')
			export GETOPT_DBAUTH=yes
			shift 1
			;;
		'-noauth')
			export GETOPT_DBAUTH=no
			shift 1
			;;
		'-aligned')
			if [ "$2" = "" ]; then 
				echo invalid parameter $1 - requires value. Exiting
				exit 1
			fi
			export GETOPT_ALIGNED=$2
			shift 2
			;;
		'-dc')
			if [ "$2" = "" ]; then 
				echo invalid parameter $1 - requires value. Exiting
				exit 1
			fi
			export GETOPT_DC=$2
			shift 2
			;;
		'-db')
			if [ "$2" = "" ]; then 
				echo invalid parameter $1 - requires value. Exiting
				exit 1
			fi
			export GETOPT_DB=$2
			shift 2
			;;
		'-dbpassword')
			if [ "$2" = "" ]; then 
				echo invalid parameter $1 - requires value. Exiting
				exit 1
			fi
			export GETOPT_DBPASSWORD=$2
			shift 2
			;;
		'-statusfile')
			if [ "$2" = "" ]; then 
				echo invalid parameter $1 - requires value. Exiting
				exit 1
			fi
			export GETOPT_STATUSFILE=$2
			shift 2
			;;
		'-folder')
			if [ "$2" = "" ]; then 
				echo invalid parameter $1 - requires value. Exiting
				exit 1
			fi
			export GETOPT_SCRIPTFOLDER=$2
			shift 2
			;;
		'-regions')
			if [ "$2" = "" ]; then 
				echo invalid parameter $1 - requires value. Exiting
				exit 1
			fi
			export GETOPT_REGIONS="$2"
			shift 2
			;;
		*)
			echo getopts.sh: invalid option=$1 in command line. Exiting
			exit 1
	esac
done
