#!/bin/bash

cd `dirname $0`
		
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
S_OPT_DCMASK=
if [ "$1" = "-dcmask" ]; then
	S_OPT_DCMASK="$2"
	shift 2
fi
if [ "$S_OPT_DCMASK" = "" ]; then
	S_OPT_DCMASK="dc.*"
fi

cd ..
S_PROXY_ENVDIR=`pwd`
F_DCLIST=`find . -maxdepth 1 -type d -name "$S_OPT_DCMASK" | sed "s/\.\///g" | tr " " "\n" | sort | tr "\n" " "`

if [ "$F_DCLIST" = "" ]; then
	echo "$P_PROXY_SCRIPT (multi-dc): no datacenters selected. Exiting"
	exit 1
fi
	
echo $P_PROXY_SCRIPT: execute in datacenters - $F_DCLIST...

if [ "$S_OPT_PROXY_PARALLEL" = "yes" ]; then
	F_LOGDIR=$S_PROXY_ENVDIR/database/plogs
	rm -rf $F_LOGDIR/$P_PROXY_SCRIPT.*
fi

S_PROXY_SCRIPTDIR=`pwd`
for proxy_dc in $F_DCLIST; do
	cd $proxy_dc/database

	if [ "$S_OPT_PROXY_PARALLEL" = "yes" ]; then
		mkdir -p $F_LOGDIR
		F_PROXY_LOGNAME=$F_LOGDIR/$P_PROXY_SCRIPT.$proxy_dc.log
	
		echo $proxy_dc: execute in parallel, see log in $F_PROXY_LOGNAME ...
		echo "execute multi-dc: ./$P_PROXY_SCRIPT $@" > $F_PROXY_LOGNAME
		./$P_PROXY_SCRIPT "$@" >> $F_PROXY_LOGNAME 2>&1 &
	else
		echo "$proxy_dc: execute $@..."
		./$P_PROXY_SCRIPT "$@"
	fi

	cd $S_PROXY_SCRIPTDIR
done

if [ "$S_OPT_PROXY_PARALLEL" = "yes" ]; then
	echo waiting for completion...
	wait
fi

echo "$P_PROXY_SCRIPT (multi-dc): finished."
