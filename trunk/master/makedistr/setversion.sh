#!/bin/bash

# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

P_MODULENAME=$1
P_REPOSITORY=$2
P_MODULEPATH=$3
P_BRANCH=$4
P_VERSION=$5

. ./common.sh

function f_local_setvesion() {
	# checkout
	local F_MODE=$VERSION_MODE
	if [ "$F_MODE" = "" ]; then
		F_MODE="default"
	fi

	local PATCHPATH=$C_CONFIG_BUILDPATH/$F_MODE/$P_MODULENAME
	echo setversion.sh MODULENAME=$P_MODULENAME, REPOSITORY=$P_REPOSITORY MODULEPATH=$P_MODULEPATH, BRANCH=$P_BRANCH, VERSION=$P_VERSION, PATCHPATH=$PATCHPATH ...

	rm -rf $PATCHPATH
	./vcscheckout.sh "$PATCHPATH" "$P_MODULENAME" "$P_REPOSITORY" "$P_MODULEPATH" "$P_BRANCH" > /dev/null

	if [ "$?" != "0" ]; then
		echo error calling vcscheckout.sh. Exiting
		exit 1
	fi

	# set version
	export JAVA_HOME=/usr/java/$C_CONFIG_JAVA_VERSION
	export PATH=$JAVA_HOME/bin:$PATH

	if [ "$C_CONFIG_MAVEN_VERSION" = "" ]; then
		echo C_CONFIG_MAVEN_VERSION is not defined - maven version is unknown. Exiting
		exit 1
	fi
	
	F_MAVEN_CMD="mvn versions:set -DnewVersion=$P_VERSION"

	export M2_HOME=/usr/local/apache-maven-$C_CONFIG_MAVEN_VERSION
	export M2=$M2_HOME/bin
	export PATH="$M2:$PATH"

	local F_SAVEDIR=`pwd`
	cd $PATCHPATH

	echo execute: $F_MAVEN_CMD
	$F_MAVEN_CMD

	if [ "$?" != "0" ]; then
		cd $F_SAVEDIR
		echo error calling mvn. Exiting
		exit 1
	fi

	# handle git specifics
	if [[ "$P_MODULEPATH" =~ ^git: ]]; then
		for pom in `find . -name "pom.xml"`; do
			git add $pom
		done
	fi

	cd $F_SAVEDIR
	
	./vcscommit.sh $PATCHPATH "$P_MODULENAME" "$P_REPOSITORY" "$P_MODULEPATH" "PGU-0000: set version $P_VERSION"

	if [ "$?" != "0" ]; then
		echo error calling vcscommit.sh. Exiting
		exit 1
	fi
}

f_local_setvesion

echo setversion.sh: successfully done.
