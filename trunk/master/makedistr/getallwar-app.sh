#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SCRIPTDIR=`pwd`

P_DOWNLOAD_DIR=$1
DOWNLOAD_VERSION="$2"
P_DISTR_DSTDIR=$3
P_DISTR_SRCDIR=$4

. ./common.sh

# check params
if [ "$P_DOWNLOAD_DIR" = "" ]; then
	echo P_DOWNLOAD_DIR not set
	exit 1
fi
if [ "$DOWNLOAD_VERSION" = "" ]; then
	echo DOWNLOAD_VERSION not set
	exit 1
fi
if [ "$P_DISTR_DSTDIR" = "" ]; then
	echo P_DISTR_DSTDIR not set
	exit 1
fi

# execute
S_USE_PROD_DISTR=

# handle war/ear setting
if [ "$S_SERVICECALL_EXT" != "" ]; then
	S_SERVICECALL_EXT=ear
fi

if [ "$S_STORAGESERVICE_EXT" != "" ]; then
	S_STORAGESERVICE_EXT=ear
fi

if [ "$S_SERVICECALL_EXT" = "ear" ]; then
	S_SERVICECALL_DIR=APP-INF
else
	S_SERVICECALL_DIR=WEB-INF
fi

if [ "$S_STORAGESERVICE_EXT" = "ear" ]; then
	S_STORAGESERVICE_DIR=APP-INF
else
	S_STORAGESERVICE_DIR=WEB-INF
fi

function f_local_download_core() {
	if [ "$P_DISTR_SRCDIR" = "" ]; then
		echo downloading core servicecall and storageservice from Nexus - to $P_DOWNLOAD_DIR ...
		f_downloadnexus war $C_CONFIG_NEXUS_REPO ru.nvg.idecs.servicecall servicecall $DOWNLOAD_VERSION "$S_SERVICECALL_EXT"
		f_downloadnexus war $C_CONFIG_NEXUS_REPO ru.nvg.idecs.storageservice storageservice $DOWNLOAD_VERSION "$S_STORAGESERVICE_EXT"
	else
		echo copy servicecall and storageservice from $C_CONFIG_DISTR_PATH/$P_DISTR_SRCDIR - to $P_DOWNLOAD_DIR ...
		cp -p $C_CONFIG_DISTR_PATH/$P_DISTR_SRCDIR/servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT
		cp -p $C_CONFIG_DISTR_PATH/$P_DISTR_SRCDIR/storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT
	fi

	# unzip servicecall and storageservice
	unzip servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT -d servicecall-$DOWNLOAD_VERSION > /dev/null
	rm servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT
	mv servicecall-$DOWNLOAD_VERSION servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT

	unzip storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT -d storageservice-$DOWNLOAD_VERSION > /dev/null
	rm storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT
	mv storageservice-$DOWNLOAD_VERSION storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT
}

function f_local_copy_prod() {
	local PREV_DISTR_DIR=`find $C_CONFIG_DISTR_PATH -maxdepth 1 -name "$C_CONFIG_VERSIONBRANCH*-prod"`
	if [ "$PREV_DISTR_DIR" = "" ]; then
		echo unable to find previous distributive in "$C_CONFIG_VERSIONBRANCH*-prod". Exiting
		exit 1
	fi

	echo "copy libraries from $PREV_DISTR_DIR/servicecall.$S_SERVICECALL_EXT to servicecall-prod-libs..."
	unzip $PREV_DISTR_DIR/servicecall-*.$S_SERVICECALL_EXT "$S_SERVICECALL_DIR/lib/*" -d servicecall-prod-libs > /dev/null
}

function f_local_download_libs() {
	# create directory for libs and "cd" to it
	mkdir pgu-services-lib
	cd pgu-services-lib

	# download latest API libs - pfr, fed-common-util
	if [ "$C_CONFIG_PRODUCT" = "fedpgu" ]; then
		echo download API libs for pfr and fed-common-util from Nexus - to pgu-services-lib...
		f_downloadnexus war $C_CONFIG_NEXUS_REPO $C_PGUWARNEXUSGROUPID pfr-api $DOWNLOAD_VERSION "jar"
		f_downloadnexus war $C_CONFIG_NEXUS_REPO ru.atc.pgu.fed.common.util pgu-fed-common-util $DOWNLOAD_VERSION "jar"
	fi

	# download latest built libs for all microportals
	echo download last built libs for all microportals from Nexus - to pgu-services-lib...
	export C_VERSION=$DOWNLOAD_VERSION
	f_execute_wars all DOWNLOADLIB
	rm -rf *.md5

	cd ..
}

function f_copy_specific_prod() {
	local P_LIB_PROJECT=$1

	if [ "$P_LIB_PROJECT" = "pgu-pfr" ]; then
		cp -p ../servicecall-prod-libs/$S_SERVICECALL_DIR/lib/pfr-api-$DOWNLOAD_VERSION.jar ../servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT/$S_SERVICECALL_DIR/lib
		cp -p ../servicecall-prod-libs/$S_SERVICECALL_DIR/lib/pfr-api-$DOWNLOAD_VERSION.jar ../storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT/$S_STORAGESERVICE_DIR/lib
	elif [ "$P_LIB_PROJECT" = "pgu-fed-common" ]; then
		cp -p ../servicecall-prod-libs/$S_SERVICECALL_DIR/lib/pgu-fed-common-util-$DOWNLOAD_VERSION.jar ../servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT/$S_SERVICECALL_DIR/lib
		cp -p ../servicecall-prod-libs/$S_SERVICECALL_DIR/lib/pgu-fed-common-util-$DOWNLOAD_VERSION.jar ../storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT/$S_STORAGESERVICE_DIR/lib
	fi
}

function f_copy_specific_built() {
	local P_LIB_PROJECT=$1

	if [ "$P_LIB_PROJECT" = "pgu-pfr" ]; then
		cp -p pfr-api-$DOWNLOAD_VERSION.jar ../servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT/$S_SERVICECALL_DIR/lib
		cp -p pfr-api-$DOWNLOAD_VERSION.jar ../storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT/$S_STORAGESERVICE_DIR/lib
	elif [ "$P_LIB_PROJECT" = "pgu-fed-common" ]; then
		cp -p pgu-fed-common-util-$DOWNLOAD_VERSION.jar ../servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT/$S_SERVICECALL_DIR/lib
		cp -p pgu-fed-common-util-$DOWNLOAD_VERSION.jar ../storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT/$S_STORAGESERVICE_DIR/lib
	fi
}

function f_local_get_projectlib() {
	local P_PROJECT=$1

	f_source_readproject war $P_PROJECT
	local F_PROJECT_DISTITEM=$C_SOURCE_PROJECT_DISTITEM

	# get dist item details
	f_distr_readitem $F_PROJECT_DISTITEM
	local F_ISOBSOLETE=$C_DISTR_OBSOLETE

	# compare with release information
	if [ "$C_RELEASE_PROPERTY_OBSOLETE" = "false" ] && [ "$F_ISOBSOLETE" = "true" ]; then
		return 1
	fi
	if [ "$C_RELEASE_PROPERTY_OBSOLETE" = "true" ] && [ "$F_ISOBSOLETE" = "false" ]; then
		return 1
	fi

	local lib=$C_SOURCE_PROJECT_DISTLIBITEM-$DOWNLOAD_VERSION.jar

	local RELEASED_TO_PROD=no
	if [ "$S_USE_PROD_DISTR" = "yes" ]; then
		if [ -f ../servicecall-prod-libs/$S_SERVICECALL_DIR/lib/$lib ]; then
			RELEASED_TO_PROD=yes
		fi
	fi

	# echo GETOPT_DIST=$GETOPT_DIST - check if $lib exists in $P_DISTR_DSTDIR/$P_PROJECT ...
	if [ "$S_USE_PROD_DISTR" = "yes" ] && [ ! -f $C_CONFIG_DISTR_PATH/$P_DISTR_DSTDIR/$F_PROJECT_DISTITEM*war ] && [ "$RELEASED_TO_PROD" = "yes" ]; then
		# if microportal is NOT in current distributive & present in current PROD - then copy lib from PROD
		if [ -f ../servicecall-prod-libs/$S_SERVICECALL_DIR/lib/$lib ]; then
			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo copy library $lib from servicecall-prod-libs to servicecall and storageservice...
			fi
       			cp -p ../servicecall-prod-libs/$S_SERVICECALL_DIR/lib/$lib ../servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT/$S_SERVICECALL_DIR/lib
	        	cp -p ../servicecall-prod-libs/$S_SERVICECALL_DIR/lib/$lib ../storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT/$S_STORAGESERVICE_DIR/lib

			f_copy_specific_prod $P_PROJECT
		else
			echo $lib: not found in servicecall-prod-libs. Skipped.
		fi
	else
		# copy from nexus by default, otherwise keep as source
		if [ "$P_DISTR_SRCDIR" = "" ]; then
			if [ -f $lib ]; then
				echo copy new library $lib from pgu-services-lib to servicecall and storageservice...
				cp -p $lib ../servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT/$S_SERVICECALL_DIR/lib
       				cp -p $lib ../storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT/$S_STORAGESERVICE_DIR/lib

				f_copy_specific_built $P_PROJECT
			else
				echo $lib: not found in pgu-services-lib. Skipped.
			fi
		fi
	fi
}

function f_local_update_libs() {
	# copy all libs from -
	#   current release - if microportal exists in current release distributive
	#   previous release (prod) - otherwise

	f_source_projectlist war
	local F_LOCAL_PROJECTSET=$C_SOURCE_PROJECTLIST

	cd pgu-services-lib

	if [[ " $F_LOCAL_PROJECTSET " =~ " pgu-fed " ]]; then
		# pgu-fed-common-util - always use last built
		if [ "$P_DISTR_SRCDIR" = "" ]; then
			f_copy_specific_built pgu-fed-common
		fi
	fi

	echo copy libs to servicecall and storageservice from pgu-services-lib and servicecall-prod-libs...
	local project
	for project in $F_LOCAL_PROJECTSET; do
		f_local_get_projectlib $project
	done

	cd ..
}

function f_local_create_binaries() {
	# Compress modified servicecall and storageservice

	echo compressing patched servicecall.$S_SERVICECALL_EXT ...
	jar cfvM servicecall-$DOWNLOAD_VERSION.jar -C servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT/ . > /dev/null
	rm -rf servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT
	mv servicecall-$DOWNLOAD_VERSION.jar servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT
	f_md5_and_copydistr servicecall-$DOWNLOAD_VERSION.$S_SERVICECALL_EXT

	echo compressing patched storageservice.$S_STORAGESERVICE_EXT ...
	jar cfvM storageservice-$DOWNLOAD_VERSION.jar -C storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT/ . > /dev/null
	rm -rf storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT
	mv storageservice-$DOWNLOAD_VERSION.jar storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT
	f_md5_and_copydistr storageservice-$DOWNLOAD_VERSION.$S_STORAGESERVICE_EXT
}

function f_local_download_deps() {
	./getallcore.sh $P_DOWNLOAD_DIR ignore pgu-portal pgu-dependencies $DOWNLOAD_VERSION
}

function f_local_executeall() {
	echo getallwar-app.sh: create servicecall.$S_SERVICECALL_EXT and storageservice.$S_STORAGESERVICE_EXT...

	S_USE_PROD_DISTR=yes
	if [ "$GETOPT_ALL" = "yes" ] || [ "$VERSION_MODE" != "branch" ]; then
		S_USE_PROD_DISTR=no
	fi

	cd $P_DOWNLOAD_DIR
	rm -rf pgu-services-lib
	rm -rf servicecall-prod-libs

	f_local_download_core

	# unzip servicecall libs - from current PROD (distr/xxx-prod) - action for branch mode only
	if [ "$S_USE_PROD_DISTR" = "yes" ]; then
		f_local_copy_prod
	fi

	f_local_download_libs
	f_local_update_libs
	f_local_create_binaries

	rm -rf pgu-services-lib
	rm -rf servicecall-prod-libs
	cd $SCRIPTDIR

	f_local_download_deps
}

f_local_executeall
