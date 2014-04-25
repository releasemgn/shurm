#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

# get build info data for given context
function f_info_check_host_buildinfo() {
	local P_BUILDINFOURL=$1
	local P_FPARAM=$2
	local P_BUILDINFOTYPE=$3

	rm -rf buildinfo.txt
	local WEBPATH=$P_BUILDINFOURL
	wget -q $WEBPATH -O buildinfo.txt
	if [ `ls -s buildinfo.txt | cut -d " " -f1` = "0" ]; then
		echo $WEBPATH: not found.
		return 1
	fi

	local F_STATUS
	if [ "$P_FPARAM" = "RELEASE" ] && [ "$P_BUILDINFOTYPE" = "oldstatic" ]; then
		local F_TAG=`cat buildinfo.txt | grep "TAG=" | sed "s/TAG\=//g"`
		if [ "$F_TAG" = "prod-major" ] || [ "$F_TAG" = "" ]; then
			F_STATUS=`cat buildinfo.txt | grep "VERSION=" | sed "s/VERSION\=//g"`
		else
			F_STATUS=`echo "$F_TAG" | cut -d "-" -f2`
		fi
	else
		F_STATUS=`cat buildinfo.txt | grep "$P_FPARAM=" | sed "s/$P_FPARAM\=//g"`
	fi

	if [ "$F_STATUS" = "" ]; then
		echo $WEBPATH: parameter $P_FPARAM not found
		return 1
	fi

	echo $WEBPATH: $P_FPARAM=$F_STATUS
}

# get/check wsdl
function f_info_check_wsdl() {
	local P_NLBHOST=$1
	local P_SERVER=$2
	local P_LINK=$3
	local P_WSDLOUTDIR=$4

	local FNAME=`echo $P_LINK | sed "s/\//\./g"`
	local LINKNAME=http://$P_NLBHOST/${P_LINK}?wsdl

	mkdir -p $P_WSDLOUTDIR
	wget $LINKNAME -O $P_WSDLOUTDIR/$FNAME.wsdl -a $P_WSDLOUTDIR/$FNAME.log
	if [ -z "`cat $P_WSDLOUTDIR/$FNAME.wsdl`" ]; then
		echo $P_SERVER: $LINKNAME - not found, see $P_WSDLOUTDIR/$FNAME.log
		return 1
	fi

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo $P_SERVER: $LINKNAME - ok.
	fi
	return 0
}
