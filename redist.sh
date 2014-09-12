#!/bin/bash

cd `dirname $0`

P_RELEASE=$1
P_PRODUCT=$2

if [ "$P_RELEASE" = "" ]; then
	echo "P_RELEASE is empty. Exiting"
	exit 1
fi

S_PRODUCT_LIST="pgu fedpgu ipsh smev geps esnsi carcass o7sia beta rfc"

function f_execute_product() {
	local P_DIR_TMP=$1
	local P_PNAME=$2

	# dirs
	local F_SAVEDIR=`pwd`
	local F_DIR_RUNCOPY=~/urm/$P_PNAME

	echo "redist.sh: redist URM release $P_RELEASE to product $P_PNAME in $F_DIR_RUNCOPY ..."

	if [ ! -d "$F_DIR_RUNCOPY" ]; then
		echo "redist.sh: $F_DIR_RUNCOPY directory does not exist. Exiting"
		exit 1
	fi

	local F_STAT

	# execute upgrade script
	cd $P_DIR_TMP
	./upgrade.sh $F_DIR_RUNCOPY
	F_STAT=$?
	if [ "$F_STAT" != "0" ]; then
		echo "redist.sh: upgrade.sh execution failed. Exiting"
		exit 1
	fi

	# save in svn
	cd $F_DIR_RUNCOPY/master
	./svnsave.sh
	F_STAT=$?
	if [ "$F_STAT" != "0" ]; then
		echo "redist.sh: svnsave.sh execution failed. Exiting"
		exit 1
	fi

	cd $F_SAVEDIR
}

function f_execute_all() {
	# check product
	if [ "$P_PRODUCT" != "" ] && [[ ! " $S_PRODUCT_LIST " =~ " $P_PRODUCT " ]]; then
		echo "redist.sh: product $P_PRODUCT is not in supported products - $S_PRODUCT_LIST. Exiting"
		exit 1
	fi

	# check release
	cd ..
	if [ ! -f "releases/$P_RELEASE/master.tar" ]; then
		echo "redist.sh: unknown release $P_RELEASE. Exiting"
		exit 1
	fi

	# get release
	local F_CURDIR=`pwd`
	local F_DIR_MASTER=$F_CURDIR/releases/$P_RELEASE
	local F_DIR_TMP=$F_CURDIR/tmprel

	rm -rf $F_DIR_TMP
	mkdir -p $F_DIR_TMP
	cd $F_DIR_TMP
	tar xf $F_DIR_MASTER/master.tar > /dev/null

	# execute
	echo "redist.sh: redist release $P_RELEASE ..."
	for product in $S_PRODUCT_LIST; do
		if [ "$P_PRODUCT" = "" ] || [ "$P_PRODUCT" = "$product" ]; then
			f_execute_product $F_DIR_TMP $product
		fi
	done

	rm -rf $F_DIR_TMP
}

f_execute_all

echo redist.sh: successfully finished
