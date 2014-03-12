#!/bin/bash

cd `dirname $0`

GETOPT_FORCE=no
if [ "$1" = "-force" ]; then
	GETOPT_FORCE=yes
	shift 1
fi

P_RELEASE=$1
P_TAG=$2

P_MASTERAUTH="`cat ~/.auth/svngoogle.auth.txt`"

if [ "$P_MASTERAUTH" = "" ]; then
	echo "P_MASTERAUTH is empty. Exiting"
	exit 1
fi
if [ "$P_RELEASE" = "" ]; then
	echo "P_RELEASE is empty. Exiting"
	exit 1
fi

function f_prepare_master() {
	local P_PATH=$1

	# make unix newlines
	for fn in $(find $P_PATH -name "*.sh" -o -name "*.xml" -o -name "*.txt" -o -name "*.properties" -o -name "*.conf" ); do
		if [ -f $fn ]; then
			cat $fn | sed 's/\r//g' > fntmp
		        mv fntmp $fn
		fi
	done

	# make executable shells
	find $P_PATH -type f -name "*.sh" -exec chmod 744 \{} \;
}

function f_execute_dropold() {
	local P_SVNRELPATH=$1
	local P_SVNTAGPATH=$2
	local P_DISTRPATH=$3

	echo drop old release ...

	# drop release if any
	local F_CHECK=`svn info $P_MASTERAUTH $P_SVNRELPATH 2>&1 | grep "Not a valid URL"`

	if [ "$F_CHECK" = "" ]; then
		svn delete -m "drop old release version" $P_MASTERAUTH $P_SVNRELPATH
		F_CHECK=$?
		if [ "$F_CHECK" != "0" ]; then
			echo "release.sh: unable to delete $P_SVNRELPATH. Exiting"
			exit 1
		fi
	fi

	# drop tag if to be set
	if [ "$P_TAG" = "" ]; then
		F_CHECK=`svn info $P_MASTERAUTH $P_SVNTAGPATH 2>&1 | grep "Not a valid URL"`

		if [ "$F_CHECK" = "" ]; then
			# drop tag
			svn delete -m "drop old release version" $P_MASTERAUTH $P_SVNTAGPATH
			F_CHECK=$?
			if [ "$F_CHECK" != "0" ]; then
				echo "release.sh: unable to delete $P_SVNTAGPATH. Exiting"
				exit 1
			fi
		fi
	fi

	# delete release folder downloaded
	rm -rf $P_DISTRPATH
	svn update $P_MASTERAUTH $P_DISTRPATH
}

function f_execute_all() {
	local F_SAVEDIR=`pwd`
	local F_MASTER_REPOSITORY=`svn info . | grep URL | sed "s/URL:[ ]//;s/\/trunk$//"`

	# check need to create tag
	local F_TAG
	if [ "$P_TAG" = "" ]; then
		F_TAG="release-$P_RELEASE"
	else
		F_TAG=$P_TAG
	fi

	local F_SVNRELPATH=$F_MASTER_REPOSITORY/releases/$P_RELEASE
	local F_TAGPATH=$F_MASTER_REPOSITORY/tags/$F_TAG
	local F_RELEASEPATH=`dirname $F_SAVEDIR`/releases/$P_RELEASE

	if [ "$GETOPT_FORCE" = "no" ]; then
		# drop
		f_execute_dropold $F_SVNRELPATH $F_TAGPATH $F_RELEASEPATH
	fi

	# check release
	echo check release $P_RELEASE exists ...
	local F_CHECK=`svn info $P_MASTERAUTH $F_SVNRELPATH 2>&1 | grep "Not a valid URL"`
	if [ "$F_CHECK" = "" ]; then
		echo "release.sh: release $P_RELEASE already exists. Exiting"
		exit 1
	fi

	# check tag exists
	echo check tag $F_TAG exists ...
	F_CHECK=`svn info $P_MASTERAUTH $F_TAGPATH 2>&1 | grep "Not a valid URL"`

	if [ "$P_TAG" = "" ]; then
		if [ "$F_CHECK" = "" ]; then
			echo "release.sh: tag $F_TAG already exists. Exiting"
			exit 1
		fi

		echo create tag $F_TAG ...
		local F_MASTER_PATH=$F_MASTER_REPOSITORY/trunk/master
		svn copy $P_MASTERAUTH $F_MASTER_PATH $F_TAGPATH -m "release $P_RELEASE" > /dev/null
		F_CHECK=$?
		if [ "$F_CHECK" != "0" ]; then
			echo "release.sh: unable to create tag $F_TAGPATH. Exiting"
			exit 1
		fi
	else
		if [ "$F_CHECK" != "" ]; then
			echo "release.sh: tag $F_TAG does not exist. Exiting"
			exit 1
		fi
	fi

	# export tag
	local F_TMPDIRNAME=reltmp
	rm -rf $F_TMPDIRNAME
	mkdir -p $F_TMPDIRNAME

	echo get master codebase ...
	svn export $P_MASTERAUTH $F_TAGPATH $F_TMPDIRNAME/master > /dev/null
	F_CHECK=$?
	if [ "$F_CHECK" != "0" ]; then
		echo "release.sh: unable to export tag $F_TAGPATH. Exiting"
		exit 1
	fi

	# release files
	svn export $P_MASTERAUTH $F_MASTER_REPOSITORY/trunk/upgrade.sh $F_TMPDIRNAME/upgrade.sh > /dev/null
	cat $F_TMPDIRNAME/upgrade.sh | sed 's/\r//g' > fntmp
        mv fntmp $F_TMPDIRNAME/upgrade.sh
	chmod 744 $F_TMPDIRNAME/upgrade.sh

	cd $F_TMPDIRNAME/master
	find . -type f | sed "s/^\.\//core:/" | sort > ../master.files.info
	mv ../master.files.info .
	svn info $P_MASTERAUTH $F_TAGPATH > master.version.info
	echo "release:master.files.info" >> master.files.info
	echo "release:master.version.info" >> master.files.info
	cd $F_SAVEDIR

	# prepare master codebase for distribution
	echo prepare master codebase ...
	f_prepare_master $F_TMPDIRNAME/master

	rm -rf $F_RELEASEPATH
	mkdir -p $F_RELEASEPATH

	# release folder
	cp $F_TMPDIRNAME/master/master.version.info $F_RELEASEPATH/master.version.info
	cd $F_TMPDIRNAME
	tar cf $F_RELEASEPATH/master.tar * > /dev/null
	F_CHECK=$?
	if [ "$F_CHECK" != "0" ]; then
		echo "release.sh: unable to create tar $F_RELEASEPATH/master.tar. Exiting"
		exit 1
	fi
	cd $F_SAVEDIR

	# commit release
	echo commit release $P_RELEASE ...
	svn add $F_RELEASEPATH > /dev/null
	svn commit $P_MASTERAUTH $F_RELEASEPATH -m "release $P_RELEASE" > /dev/null

	F_CHECK=$?
	if [ "$F_CHECK" != "0" ]; then
		echo "release.sh: unable to commit release path $F_RELEASEPATH. Exiting"
		exit 1
	fi

	rm -rf $F_TMPDIRNAME
}

f_execute_all

echo release.sh: successfully finished
