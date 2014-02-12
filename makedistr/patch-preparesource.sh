#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

P_PATCHPATH=$1
P_MODULESET=$2
P_MODULENAME=$3
P_TAG=$4

# check params
if [ "$P_PATCHPATH" = "" ]; then
	echo patch-preparesource.sh: P_PATCHPATH not set
	exit 1
fi
if [ "$P_MODULESET" = "" ]; then
	echo patch-preparesource.sh: P_MODULESET not set
	exit 1
fi
if [ "$P_MODULENAME" = "" ]; then
	echo patch-preparesource.sh: P_MODULENAME not set
	exit 1
fi
if [ "$P_TAG" = "" ]; then
	echo patch-preparesource.sh: P_TAG not set
	exit 1
fi

# execute

. ./common.sh

function f_execute_all() {
	# handle module options

	echo patch-preparesource.sh: prepare source code...

	# add profile for war build
	if [ "$MODULEOPTIONS_WAR" = "true" ] && [ "$MODULEOPTIONS_COMPACT_STATIC" = "true" ]; then
		echo patch-preparesource.sh: prepare for compact war static build...
		./buildwar-addstaticprofile.sh $P_PATCHPATH/web/pom.xml

		if [ $? -ne 0 ]; then
			echo patch-preparesource.sh: prepare for compact war static build failed. Exiting
		        exit 1
		fi
	fi

	if [ "$MODULEOPTIONS_POMNEW" = "true" ]; then
		echo patch-preparesource.sh: prepare for new pom.xml...
		SAVEDIR=`pwd`

		for x in $(find $P_PATCHPATH -name "*.new"); do
			FNAME_ORIGINAL=`echo $x | sed "s/\.new$//"`
			rm $FNAME_ORIGINAL
			cp $x $FNAME_ORIGINAL
		done
	fi

	if [ "$MODULEOPTIONS_SETVERSION" = "true" ]; then
		cd $P_PATCHPATH
		mvn versions:set -DnewVersion=$C_CONFIG_APPVERSION
		cd $SAVEDIR
	fi

	if [ "$MODULEOPTIONS_REPLACESNAPSHOTS" = "true" ]; then
		echo patch-preparesource.sh: replace snapshots...

		for fname in $(find $P_PATCHPATH -name pom.xml); do
			echo patch-preparesource.sh: set $fname to $C_CONFIG_NEXT_MAJORRELEASE from SNAPSHOT...
			cat $fname | sed "s/$C_CONFIG_NEXT_MAJORRELEASE-SNAPSHOT/$C_CONFIG_NEXT_MAJORRELEASE/g" > $fname-new
			rm $fname
			mv $fname-new $fname
		done
	fi
}

f_execute_all

echo patch-preparesource.sh: finished.
