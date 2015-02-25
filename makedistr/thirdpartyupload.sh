#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

VERSIONDIR=$1

if [ "$VERSIONDIR" = "" ]; then
	echo VERSIONDIR is not set. Exiting
	exit 1
fi

# execute

. common.sh

function f_local_uploadthirdparty_one() {
	local P_DISTITEM=$1
	local P_VERSION=$2

	# get item info
	f_distr_getthirdpartyiteminfo $P_DISTITEM

	local F_FILEPATH=$C_CONFIG_DISTR_PATH/$VERSIONDIR/thirdparty
	local F_FILENAME=$C_DISTR_THIRDPARTY_KEY-$P_VERSION.$C_DISTR_THIRDPARTY_TYPE
	local F_FULLFILENAME=$F_FILEPATH/$F_FILENAME

	# check file exists
	if [ ! -f "$F_FULLFILENAME" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo "$F_FILENAME not found at $F_FILEPATH. Skipped."
		fi
		return 1
	fi

	# check version already uploaded
	local F_THIRDPARTY_REPOSITORY=$C_CONFIG_NEXUS_PATH_THIRDPARTY
	local F_NEXUSMD5NAME=$F_FILENAME.md5
	local F_NEXUSKEYPATH=$F_THIRDPARTY_REPOSITORY/$C_DISTR_THIRDPARTY_NEXUSPATH/$C_DISTR_THIRDPARTY_KEY

	wget -O $F_NEXUSMD5NAME -q $F_NEXUSKEYPATH/$P_VERSION/$F_NEXUSMD5NAME
	local F_MD5_NEXUS=`cat $F_NEXUSMD5NAME`
	rm -rf $F_NEXUSMD5NAME

	if [ "$F_MD5_NEXUS" != "" ]; then
		# version already exists
		if [ "$GETOPT_UPDATENEXUS" != "yes" ]; then
			echo "$P_DISTITEM: version=$P_VERSION is already uploaded at $F_NEXUSKEYPATH. Skipped."
			return 1
		fi
	fi

	mvn deploy:deploy-file --settings=$HOME/.m2/settings.trunk.xml -DrepositoryId=nexus -Durl=$F_THIRDPARTY_REPOSITORY -Dpackaging=$C_DISTR_THIRDPARTY_TYPE -DgeneratePom=true -DgroupId=$C_DISTR_THIRDPARTY_NEXUSPATH -Dversion=$P_VERSION -DartifactId=$C_DISTR_THIRDPARTY_KEY -Dfile=$F_FULLFILENAME
	if [ "$?" != "0" ]; then
		echo "$P_DISTITEM: unable to upload version=$P_VERSION to $F_NEXUSKEYPATH. Exiting"
		exit 1
	fi

	echo "$P_DISTITEM: version=$P_VERSION uploaded to $F_NEXUSKEYPATH"
}

function f_local_uploadthirdparty_all() {
        # load release information
	local F_FNAME_REL_DST=$C_CONFIG_DISTR_PATH/$VERSIONDIR/release.xml
	f_release_setfile $F_FNAME_REL_DST

	# get version number
	local F_TAG_VERSION=`echo $VERSIONDIR | cut -d "-" -f1`

	# load distr data for cross-product exports - thirdparty
	f_distr_getthirdpartylist
	local F_ITEMLIST=$C_DISTR_THIRDPARTYLIST

	# set maven
	export M2_HOME=/usr/local/apache-maven-$C_CONFIG_MAVEN_VERSION
	export M2=$M2_HOME/bin
	export PATH="$PATH:$M2"
	export JAVA_HOME=/usr/java/$C_CONFIG_JAVA_VERSION
	export PATH=$PATH:$JAVA_HOME/bin

	# get thirdparty information
	local distitem
	for distitem in $F_ITEMLIST; do
		f_local_uploadthirdparty_one $distitem $F_TAG_VERSION
	done
}

echo thirdpartyupload.sh VERSIONDIR=$VERSIONDIR

f_local_uploadthirdparty_all

echo thirdpartyupload.sh: successfully done.
