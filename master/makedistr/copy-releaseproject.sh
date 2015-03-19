#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

P_SET=$1
P_PROJECT=$2

. ./common.sh

# requires preset vars:
# 	C_RELEASE_COPY_SRCDIR
#	C_RELEASE_COPY_DSTDIR
# requires destination folder release set

# execute

function f_local_copyfile() {
	local P_LOCAL_FILE=$1

	local F_NAME_SRC=$C_CONFIG_DISTR_PATH/$C_RELEASE_COPY_SRCDIR/$P_LOCAL_FILE
	local F_NAME_DST=$C_CONFIG_DISTR_PATH/$C_RELEASE_COPY_DSTDIR/$P_LOCAL_FILE

	if [ -f "$F_NAME_SRC" ]; then
		cp -p $F_NAME_SRC $F_NAME_DST
	fi
}

function f_local_downloadwar() {
	# check dst release xml
	if [[ " $C_RELEASE_COPY_WARLIST " =~ " $P_PROJECT " ]]; then
		local WAR_FILENAME=$P_PROJECT-web-$C_CONFIG_APPVERSION.war
		local STATIC_FILENAME=$P_PROJECT-web-$C_CONFIG_APPVERSION-webstatic.tar.gz
	
		f_local_copyfile $WAR_FILENAME
		f_local_copyfile $STATIC_FILENAME
	fi
}

function f_local_downloadcore() {
	f_source_projectitemlist core $P_PROJECT
	local F_RELEASE_SOURCE_ITEMLIST=$C_SOURCE_ITEMLIST

	# read dst release project info
	f_release_getprojectitems core $P_PROJECT
	local F_RELEASE_PROJECT_ITEMS=$C_RELEASE_ITEMS

	local item
	for item in $F_RELEASE_SOURCE_ITEMLIST; do
		# copy if none specified or matched
		if [ "$F_RELEASE_PROJECT_ITEMS" = "" ] || [[ " $F_RELEASE_PROJECT_ITEMS " =~ " $item " ]]; then
			f_source_readdistitem core $P_PROJECT $item
			local F_ITEMNAME=$C_SOURCE_ITEMBASENAME-$C_CONFIG_APPVERSION$C_SOURCE_ITEMEXTENSION

			f_local_copyfile $F_ITEMNAME
		fi
	done
}

# war case
if [ "$P_SET" = "war" ]; then
	f_local_downloadwar
else
	f_local_downloadcore
fi
