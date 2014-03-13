#!/bin/bash

cd `dirname $0`
S_PROXY_SCRIPTDIR=`pwd`
		
P_PROXY_SCRIPT=$1
if [ "$P_PROXY_SCRIPT" = "" ]; then
	P_PROXY_SCRIPT is empty. Exiting
	exit 1
fi

shift 1

S_OPT_PROXY_PARALLEL=no
if [ "$1" = "-parallel" ]; then
	S_OPT_PROXY_PARALLEL=yes
	shift 1
fi

P_DCMASK=
if [ "$1" = "-dc" ]; then
	P_DCMASK=$2
	shift 2
fi

if [ "$P_DCMASK" = "" ] || [ "$P_DCMASK" = "all" ]; then
	P_DCMASK="dc.*"
fi
if [ "$P_DCMASK" = "K" ]; then
	P_DCMASK="dc.k*"
fi

if [ "$P_DCMASK" = "" ]; then
	echo P_DCMASK is not set. Exiting.
	exit 1
fi

P_DCLIST=`find . -maxdepth 1 -type d -name "$P_DCMASK" | sed "s/\.\///g" | tr " " "\n" | grep -v "^.$" | grep -v "_template" | grep -v ".svn" | grep -v "plogs" | sort | tr "\n" " "`

if [ "$P_DCLIST" = "" ]; then
	echo "$P_PROXY_SCRIPT (multi-dc): no datacenters selected. Exiting"
	exit 1
fi
	
echo $P_PROXY_SCRIPT: execute in datacenters - $P_DCLIST...

if [ "$S_OPT_PROXY_PARALLEL" = "yes" ]; then
	F_LOGDIR=$S_PROXY_SCRIPTDIR/plogs
	rm -rf $F_LOGDIR/$P_PROXY_SCRIPT.*
fi

S_PROCESS_LIST=
S_PROCESS_LIST_STATUS=0
for proxy_dc in $P_DCLIST; do
	cd $proxy_dc

	if [ "$S_OPT_PROXY_PARALLEL" = "yes" ]; then
		mkdir -p $F_LOGDIR
		F_PROXY_LOGNAME=$S_PROXY_SCRIPTDIR/plogs/$P_PROXY_SCRIPT.$proxy_dc.log
	
		echo $proxy_dc: execute in parallel, see log in $F_PROXY_LOGNAME ...
		echo "execute multi-dc: ./$P_PROXY_SCRIPT $@" > $F_PROXY_LOGNAME
		./$P_PROXY_SCRIPT "$@" >> $F_PROXY_LOGNAME 2>&1 &
		S_PROCESS_LIST="$S_PROCESS_LIST $!"
	else
		echo "$proxy_dc: execute $@..."
		./$P_PROXY_SCRIPT "$@"
		F_PROCESS_STATUS=$?
		if [ "$F_PROCESS_STATUS" != "0" ]; then
			S_PROCESS_LIST_STATUS=1
		fi
	fi

	cd $S_PROXY_SCRIPTDIR
done

if [ "$S_OPT_PROXY_PARALLEL" = "yes" ]; then
	echo waiting for completion...
	for proc in $S_PROCESS_LIST; do
		wait $proc
		F_PROCESS_STATUS=$?
		if [ "$F_PROCESS_STATUS" != "0" ]; then
			S_PROCESS_LIST_STATUS=1
		fi
	done
fi

if [ "$S_PROCESS_LIST_STATUS" = "0" ]; then
	echo "$P_PROXY_SCRIPT (multi-dc): finished, status is SUCCESSFUL"
else
	echo "$P_PROXY_SCRIPT (multi-dc): finished, status is FAILED"
fi

exit $S_PROCESS_LIST_STATUS
