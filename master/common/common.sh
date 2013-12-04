#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

S_COMMON_EXTLIST="sh xml txt properties conf config groovy"

function f_dos2unix_file() {
	local P_FILEPATH=$1

	local F_BASENAME=`basename $P_FILEPATH`
	local F_EXT=${F_BASENAME##*.}

	if [[ " $S_COMMON_EXTLIST " =~ " $F_EXT " ]]; then
		F_TMPFILEPATH=$P_FILEPATH-tmp
		cat $P_FILEPATH | tr -d "\r" > $F_TMPFILEPATH
		mv $F_TMPFILEPATH $P_FILEPATH
	fi
}

C_LISTITEM=
function f_getlistitem() {
	local P_ITEM_LIST="$1"
	local P_ITEM_NUMBER=$2

	C_LISTITEM=`echo $P_ITEM_LIST | cut -d " " -f$P_ITEM_NUMBER | sed "s/ //g"`
	if [ "$C_LISTITEM" = "" ]; then
		echo f_getlistitem: unable to extract item pos=$P_ITEM_NUMBER from $P_ITEM_LIST. Exiting
		exit 1
	fi
}

function f_dos2unix_dir() {
	local P_DIRPATH=$1

	if [ ! -d "$P_DIRPATH" ]; then
		echo "f_dos2unix_dir: invalid directory $P_DIRPATH. Exiting"
		exit 1
	fi

	local F_DOSSAVEDIR=`pwd`
	cd $P_DIRPATH
	local F_DOSEXECDIR=`pwd`
	cd $F_DOSSAVEDIR

	local F_DIRPATH_TMP=$P_DIRPATH-TMP
	rm -rf $F_DIRPATH_TMP
	cp -R $P_DIRPATH $F_DIRPATH_TMP

	cd $F_DIRPATH_TMP
	find . -type f \( -name "*.sql" -o -name "*.sh" -o -name "*.xml" -o -name "*.txt" -o -name "*.properties" -o -name "*.conf" -o -name "*.config" \) -exec bash -c "x=\$0; ( cat \"\$x\" | tr -d \"\r\" ) > $F_DOSEXECDIR/\"\$x\"" {} \;

	cd $F_DOSSAVEDIR
	rm -rf $F_DIRPATH_TMP
}

function f_unix2dos_file() {
	local P_FILEPATH=$1

	local F_BASENAME=`basename $P_FILEPATH`
	local F_EXT=${F_BASENAME##*.}

	if [[ " $S_COMMON_EXTLIST " =~ " $F_EXT " ]]; then
		cat $P_FILEPATH | sed 's/$/\r/' > $P_FILEPATH-tmp
		mv $P_FILEPATH-tmp $P_FILEPATH
	fi
}

function f_checkvalidlist() {
	local P_LIST="$1"
	local P_SUBSET="$2"

	P_LIST=`echo $P_LIST | sed "s/^ //g;s/ $//g;s/\n//g"`
	P_SUBSET=`echo $P_SUBSET | sed "s/^ //g;s/ $//g;s/\n//g"`
	local x
	for x in $P_SUBSET; do
		if [[ ! " $P_LIST " =~ " $x " ]]; then
			echo "f_checkvalidlist: check failed - item $x is not in ($P_LIST). Exiting"
			exit 1
		fi
	done
}

C_COMMON_SUBSET=
C_COMMON_UNKNOWNSUBSET=
function f_getsubset() {
	local P_LIST="$1"
	local P_SUBSET="$2"

	P_LIST=`echo $P_LIST | sed "s/^ //g;s/ $//g;s/\n//g"`
	P_SUBSET=`echo $P_SUBSET | sed "s/^ //g;s/ $//g;s/\n//g"`
	
	C_COMMON_UNKNOWNSUBSET=

	# default subset - is full list
	if [ "$P_SUBSET" = "" ]; then
		C_COMMON_SUBSET="$P_LIST"
		return 0
	fi

	C_COMMON_SUBSET=
	local x
	for x in $P_LIST; do
		if [[ " $P_SUBSET " =~ " $x " ]]; then
			C_COMMON_SUBSET="$C_COMMON_SUBSET $x"
		else
			C_COMMON_UNKNOWNSUBSET="$C_COMMON_UNKNOWNSUBSET $x"
		fi
	done

	C_COMMON_SUBSET=`echo $C_COMMON_SUBSET | sed "s/^ //g;s/ $//g;s/\n//g"`
	C_COMMON_UNKNOWNSUBSET=`echo $C_COMMON_UNKNOWNSUBSET | sed "s/^ //g;s/ $//g;s/\n//g"`
}

function f_getsubsetexact() {
	local P_LIST="$1"
	local P_SUBSET="$2"
	P_LIST=`echo $P_LIST | sed "s/^ //g;s/ $//g;s/\n//g"`
	P_SUBSET=`echo $P_SUBSET | sed "s/^ //g;s/ $//g;s/\n//g"`

	C_COMMON_UNKNOWNSUBSET=

	if [ "$P_LIST" = "" ] || [ "$P_SUBSET" = "" ]; then
		C_COMMON_SUBSET=
		return 0
	fi
		
	f_getsubset "$P_LIST" "$P_SUBSET"
}

C_COMMON_LIST=
function f_revertlist() {
	local P_LIST="$1"
	C_COMMON_LIST=
	for x in $P_LIST; do
		C_COMMON_LIST="$x $C_COMMON_LIST"
	done
	C_COMMON_LIST=${C_COMMON_LIST% }
}

C_COMMON_DIRLIST=
function f_getdirfiles() {
	local P_DIRPATH=$1
	C_COMMON_DIRLIST=`find $P_DIRPATH -maxdepth 1 -type f -exec basename {} \; | tr "\n" " "`
}

function f_getdirdirs() {
	local P_DIRPATH=$1
	C_COMMON_DIRLIST=`find $P_DIRPATH -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | tr "\n" " "`
}

function f_getpath_checkrootdir() {
	local P_DIR=$1

	if [ "$P_DIR" = "" ] || [ "$P_DIR" = "/" ] || [[ ! "$P_DIR" =~ ^/ ]] || [[ "$P_DIR" =~ /$ ]]; then
		echo "f_getpath_checkrootdir: invalid root dir=$P_DIR. Exiting"
		exit 1
	fi
}

function f_getpath_checkrelativedir() {
	local P_DIR=$1

	if [ "$P_DIR" = "" ] || [[ "$P_DIR" =~ ^/ ]] || [[ "$P_DIR" =~ /$ ]]; then
		echo "f_getpath_checkrelativedir: invalid relative dir=$P_DIR. Exiting"
		exit 1
	fi
}

C_COMMON_DIRPATH=
function f_getpath_redistserverroot() {
	local P_SERVER=$1

	if [ "$P_SERVER" = "" ]; then
		echo "f_getpath_redistserverroot: invalid params. Exiting"
		exit 1
	fi

	C_COMMON_DIRPATH="$C_CONFIG_REDISTPATH/$P_SERVER"
}

function f_getpath_redistserverreleaseroot() {
	local P_SERVER=$1
	local P_RELEASENAME=$2

	if [ "$P_SERVER" = "" ] || [ "$P_RELEASENAME" = "" ]; then
		echo "f_getpath_redistroot: invalid params. Exiting"
		exit 1
	fi

	C_COMMON_DIRPATH="$C_CONFIG_REDISTPATH/$P_SERVER/$P_RELEASENAME"
}

function f_getpath_redistserverbackuproot() {
	local P_SERVER=$1
	local P_RELEASENAME=$2

	if [ "$P_SERVER" = "" ] || [ "$P_RELEASENAME" = "" ]; then
		echo "f_getpath_redistroot: invalid params. Exiting"
		exit 1
	fi

	C_COMMON_DIRPATH="$C_CONFIG_REDISTPATH/$P_SERVER/$P_RELEASENAME-backup"
}

function f_getpath_redistroot() {
	local P_SERVER=$1
	local P_RELEASENAME=$2
	local P_REDISTTYPE=$3

	if [ "$P_SERVER" = "" ] || [ "$P_RELEASENAME" = "" ] || [ "$P_REDISTTYPE" = "" ]; then
		echo "f_getpath_redistroot: invalid params. Exiting"
		exit 1
	fi

	if [ "$P_REDISTTYPE" = "deploy" ]; then
		C_COMMON_DIRPATH="$C_CONFIG_REDISTPATH/$P_SERVER/$P_RELEASENAME/deploy"
	elif [ "$P_REDISTTYPE" = "deploy.backup" ]; then
		C_COMMON_DIRPATH="$C_CONFIG_REDISTPATH/$P_SERVER/$P_RELEASENAME-backup/deploy"
	elif [ "$P_REDISTTYPE" = "config" ]; then
		C_COMMON_DIRPATH="$C_CONFIG_REDISTPATH/$P_SERVER/$P_RELEASENAME/config"
	elif [ "$P_REDISTTYPE" = "config.backup" ]; then
		C_COMMON_DIRPATH="$C_CONFIG_REDISTPATH/$P_SERVER/$P_RELEASENAME-backup/config"
	elif [ "$P_REDISTTYPE" = "hotdeploy" ]; then
		C_COMMON_DIRPATH="$C_CONFIG_REDISTPATH/$P_SERVER/$P_RELEASENAME/hotdeploy"
	elif [ "$P_REDISTTYPE" = "hotdeploy.backup" ]; then
		C_COMMON_DIRPATH="$C_CONFIG_REDISTPATH/$P_SERVER/$P_RELEASENAME-backup/hotdeploy"
	else
		echo "f_getpath_redistroot: invalid path type=$P_REDISTTYPE. Exiting"
		exit 1
	fi
}

function f_getpath_redistlocation() {
	local P_SERVER=$1
	local P_RELEASENAME=$2
	local P_LOCATION=$3
	local P_REDISTTYPE=$4

	f_getpath_checkrelativedir $P_LOCATION
	f_getpath_redistroot $P_SERVER $P_RELEASENAME $P_REDISTTYPE
	C_COMMON_DIRPATH=$C_COMMON_DIRPATH/$P_LOCATION
}

function f_getpath_runtimelocation() {
	local P_SERVER=$1
	local P_SERVERROOTPATH=$2
	local P_LOCATION=$3

	f_getpath_checkrootdir $P_SERVERROOTPATH
	f_getpath_checkrelativedir $P_LOCATION
	C_COMMON_DIRPATH=$P_SERVERROOTPATH/$P_LOCATION
}

function f_getpath_hotdeployroot() {
	local P_SERVER=$1
	local P_SERVERROOTPATH=$2
	local P_SERVERHOTDEPLOYPATH=$3

	f_getpath_checkrootdir $P_SERVERROOTPATH
	f_getpath_checkrelativedir $P_SERVERHOTDEPLOYPATH
	C_COMMON_DIRPATH=$P_SERVERROOTPATH/$P_SERVERHOTDEPLOYPATH
}

function f_getpath_hotdeploylocation() {
	local P_SERVER=$1
	local P_SERVERROOTPATH=$2
	local P_SERVERHOTDEPLOYPATH=$3
	local P_LOCATION=$4
	local P_HOTDEPLOYTYPE=$5

	f_getpath_checkrootdir $P_SERVERROOTPATH
	f_getpath_checkrelativedir $P_SERVERHOTDEPLOYPATH
	f_getpath_checkrelativedir $P_LOCATION

	if [ "$P_HOTDEPLOYTYPE" = "config" ]; then
		C_COMMON_DIRPATH=$P_SERVERROOTPATH/$P_SERVERHOTDEPLOYPATH/config/$P_LOCATION
	elif [ "$P_HOTDEPLOYTYPE" = "binary" ]; then
		C_COMMON_DIRPATH=$P_SERVERROOTPATH/$P_SERVERHOTDEPLOYPATH/binary/$P_LOCATION
	else
		echo "f_getpath_hotdeploylocation: invalid type=$P_HOTDEPLOYTYPE. Exiting"
		exit 1
	fi
}

S_COMMON_ALIGNEDID=
function f_aligned_getidbyname() {
	local P_NAME=$1

	if [ "$C_CONFIG_ALIGNEDLIST" = "" ]; then
		if [ "$P_NAME" != "common" ]; then
			echo f_aligned_getidbyname: unable to use aligned items due to empty C_CONFIG_ALIGNEDLIST. Exiting
			exit 1
		fi

		S_COMMON_ALIGNEDID=0
	else
		if [ "$P_NAME" = "common" ]; then
			S_COMMON_ALIGNEDID=0
		elif [ "$P_NAME" = "regional" ]; then
			S_COMMON_ALIGNEDID=9
		else
			S_COMMON_ALIGNEDID=`echo $C_CONFIG_ALIGNEDLIST | tr " " "\n" | grep "$P_NAME=" | cut -d "=" -f2 | tr -d "\n"`
			if [ "$S_COMMON_ALIGNEDID" = "" ]; then
				echo f_aligned_getidbyname: unable to find aligned id for name=$P_NAME. Exiting
				exit 1
			fi
		fi
	fi
}
