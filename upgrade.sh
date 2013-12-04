#!/bin/bash

cd `dirname $0`

P_DSTDIR=$1

# check target dir
if [ "$P_DSTDIR" = "" ]; then
	echo "P_DSTDIR is empty. Exiting"
	exit 1
fi
if [ ! -d "$P_DSTDIR/master" ]; then
	echo "upgrade.sh: invalid product URM directory $P_DSTDIR . Exiting"
	exit 1
fi

function f_execute_all() {
	# copy master files
	cp -R master/* $P_DSTDIR/master
	local F_STATUS=$?
	if [ "$F_STATUS" != "0" ]; then
		echo "upgrade.sh: cannot copy master to $P_DSTDIR/master . Exiting"
		exit 1
	fi

	# execute configuration script
	local F_SAVEDIR=`pwd`
	cd $P_DSTDIR/master
	./configure.sh
}

f_execute_all

echo upgrade.sh: successfully done
