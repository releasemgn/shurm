# Copyright 2011-2013 vsavchik@gmail.com

. ../../etc/config.sh

if [ "$C_CONFIG_PRODUCT_DEPLOYMENT_HOME" = "" ]; then
	echo C_CONFIG_PRODUCT_DEPLOYMENT_HOME is not defined. Exiting
	exit 1
fi

function f_download() {
	local P_PROJECT=$1
	local P_FNAME="$2"
	local P_TARGETNAME="$3"

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo $P_PROJECT: wget $P_FNAME...
	fi

	local F_TARGETDIRNAME
	local F_TARGETFINALNAME
	local FBASENAME
	if [ "$P_TARGETNAME" = "" ]; then
		FBASENAME=`basename $P_FNAME`
		F_TARGETFINALNAME=$FBASENAME
	else
		FBASENAME=`basename $P_TARGETNAME`
		F_TARGETDIRNAME=`dirname $P_TARGETNAME`
		mkdir -p $F_TARGETDIRNAME

		F_TARGETFINALNAME=$F_TARGETDIRNAME/$FBASENAME
	fi

	# delete old if partial download
	rm -rf $F_TARGETFINALNAME
	rm -rf $F_TARGETFINALNAME.md5

	wget -q "$P_FNAME" -O $F_TARGETFINALNAME
	F_STATUS=$?

	if [ "$F_STATUS" = "0" ] && [ -f $F_TARGETFINALNAME ]; then
		md5sum $F_TARGETFINALNAME > $F_TARGETFINALNAME.md5
	else
		rm -rf $F_TARGETFINALNAME
		rm -rf $F_TARGETFINALNAME.md5
		echo $P_FNAME: unable to download
		return 1
	fi

	return 0
}

S_DOWNLOAD_URL=
function f_downloadnexus() {
	local P_PROJECT=$1
	local P_REPO=$2
	local P_GROUPID=$3
	local P_ARTEFACTID=$4
	local P_VERSION=$5
	local P_PACKAGING=$6
	local P_CLASSIFIER=$7
	local P_FOLDER=$8

	local F_REPOPATH=$C_CONFIG_NEXUS_BASE/content/repositories/$P_REPO
	local F_NAME=$P_ARTEFACTID-$P_VERSION
	if [ "$P_CLASSIFIER" != "" ]; then
		F_NAME=$F_NAME-$P_CLASSIFIER
	fi
	F_NAME=$F_NAME.$P_PACKAGING

	local F_GROUPID=${P_GROUPID//.//}
	local F_SUBFILE=$F_NAME
	if [ "$P_FOLDER" != "" ]; then
		F_SUBFILE=$P_FOLDER/$F_SUBFILE
	fi

	S_DOWNLOAD_URL=$F_REPOPATH/$F_GROUPID/$P_ARTEFACTID/$P_VERSION/$F_NAME
	S_DOWNLOAD_URL_REQUEST="$C_CONFIG_NEXUS_BASE/service/local/artifact/maven/redirect?g=$P_GROUPID&a=$P_ARTEFACTID&v=$P_VERSION&r=$P_REPO&p=$P_PACKAGING&"

	if [ "$P_CLASSIFIER" != "" ]; then
		S_DOWNLOAD_URL_REQUEST="${S_DOWNLOAD_URL_REQUEST}c=$P_CLASSIFIER&"
	fi

	f_download $P_PROJECT "$S_DOWNLOAD_URL_REQUEST" $F_SUBFILE
	return $?
}

function f_copy_distr() {
	local P_FNAME=$1
	local P_FOLDER=$2

	local FBASENAME=`basename $P_FNAME`
	if [ "$GETOPT_DIST" = "yes" ]; then
		if [ "$DISTRDIR" = "" ]; then
			echo ERROR: DISTRDIR is not set.
			exit 1
		else
			echo copy $FBASENAME to $DISTRDIR...
			if [ "$P_FOLDER" != "" ]; then
				mkdir -p $DISTRDIR/$P_FOLDER
				cp $P_FOLDER/$FBASENAME $DISTRDIR/$P_FOLDER
			else
				cp $FBASENAME $DISTRDIR
			fi
		fi
	fi
}

function f_download_and_copydistr() {
	local P_PROJECT=$1
	local P_FNAME=$2

	f_download $P_PROJECT $P_FNAME
	if [ $? -ne 0 ]; then
		return 1
	fi

	# copy to dist if requested
	f_copy_distr $P_FNAME
	return 0
}

function f_downloadnexus_and_copydistr() {
	local P_PROJECT=$1
	local P_REPO=$2
	local P_GROUPID=$3
	local P_ARTEFACTID=$4
	local P_VERSION=$5
	local P_PACKAGING=$6
	local P_CLASSIFIER=$7
	local P_FOLDER=$8

	f_downloadnexus $P_PROJECT $P_REPO $P_GROUPID $P_ARTEFACTID $P_VERSION "$P_PACKAGING" "$P_CLASSIFIER" $P_FOLDER
	if [ $? -ne 0 ]; then
		return 1
	fi

	# copy to dist if requested
	f_copy_distr $S_DOWNLOAD_URL $P_FOLDER
	return 0
}

function f_md5_and_copydistr() {
	local P_FNAME=$1

	md5sum $P_FNAME > $P_FNAME.md5
	f_copy_distr $P_FNAME
}

function f_add_buildinfo() {
	local P_FBUILDINFONAME=$1
	local P_BIPROJECT=$2
	local P_BIVERSION=$3
	local P_BIWARFILE=$4
	local P_BISTATICFILE=$5
	local P_TAGNAME=$6

	echo PROJECT=$P_BIPROJECT > $P_FBUILDINFONAME
	echo VERSION=$P_BIVERSION >> $P_FBUILDINFONAME
	echo WARFILENAME=$P_BIWARFILE >> $P_FBUILDINFONAME
	echo WARFILELS=`ls -l $P_BIWARFILE` >> $P_FBUILDINFONAME
	echo TAG=$P_TAGNAME >> $P_FBUILDINFONAME
	echo DATE=`date` >> $P_FBUILDINFONAME
	echo BUILDMACHINE=`hostname` >> $P_FBUILDINFONAME
	echo ------------- >> $P_FBUILDINFONAME
	echo BUILDINFO v.$C_CONFIG_APPVERSION >> $P_FBUILDINFONAME
}

function f_repackage_static() {
	local P_BIPROJECT=$1
	local P_BIVERSION=$2
	local P_BIWARFILE=$3
	local P_BISTATICFILE=$4
	local P_TAGNAME=$5

	if [ ! -f "$P_BISTATICFILE" ]; then
		echo f_repackage_static: $P_BISTATICFILE not found
		return 1
	fi

	rm -rf repackage
	mkdir repackage
	mv $P_BISTATICFILE repackage

	cd repackage
	tar zxmf $P_BISTATICFILE > /dev/null
	rm -rf $P_BISTATICFILE

	local STATIC_CONTEXT=$(ls)
	if [ "$STATIC_CONTEXT" = "" ]; then
		cd ..
		echo f_repackage_static: context not found in static file $P_BISTATICFILE. Exiting
		exit 1
	fi

	if [ ! -d "$STATIC_CONTEXT/htdocs" ]; then
		cd ..
		echo f_repackage_static: invalid static file, context data not found: $P_BISTATICFILE/$STATIC_CONTEXT/htdocs. Exiting
		exit 1
	fi
	cd ..

	# add build info to static
	f_add_buildinfo repackage/$STATIC_CONTEXT/htdocs/buildinfo.txt $P_BIPROJECT $P_BIVERSION $P_BIWARFILE $P_BISTATICFILE $P_TAGNAME

	cd repackage/$STATIC_CONTEXT
	tar zcf $P_BISTATICFILE htdocs >> /dev/null
	mv $P_BISTATICFILE ../..
	cd ../..
	rm -rf repackage

	echo download: $P_BISTATICFILE statics repackaged, STATIC_CONTEXT=$STATIC_CONTEXT.
	return 0
}

function f_repackage_staticdistr() {
	local P_BIPROJECT=$1
	local P_BIVERSION=$2
	local P_BIWARFILE=$3
	local P_BISTATICFILE=$4
	local P_TAGNAME=$5

	f_repackage_static $P_BIPROJECT $P_BIVERSION $P_BIWARFILE $P_BISTATICFILE $P_TAGNAME
	if [ $? -ne 0 ]; then
		return 1
	fi
	
	f_copy_distr $P_BISTATICFILE
	return 0
}

S_RELEASESCOPE_CORE=
S_RELEASESCOPE_WARS=

function f_getreleasescope_matched() {
	P_SCOPE="$1"

	if [ "$GETOPT_RELEASE" != "" ]; then
		local F_FNAME_REL=$C_CONFIG_DISTR_PATH/$GETOPT_RELEASE/release.xml
		f_release_setfile $F_FNAME_REL
	fi

	S_RELEASESCOPE_CORE=
	S_RELEASESCOPE_WARS=

	if [ "$P_SCOPE" != "" ] && [ "$P_SCOPE" != "all" ]; then
		local F_SCOPETYPE=`echo $P_SCOPE | cut -d " " -f1`
		local F_SCOPEDATA=${P_SCOPE## }
		F_SCOPEDATA=`echo $F_SCOPEDATA | sed "s/^[^ ]*//"`
		F_SCOPEDATA=${F_SCOPEDATA## }

		if [[ ! " core war " =~ " $F_SCOPETYPE " ]]; then
			echo invalid build type=$F_SCOPETYPE. Exiting
			exit 1
		fi

		if [ "$GETOPT_RELEASE" != "" ]; then
			f_release_getprojects $F_SCOPETYPE

			if [ "$F_SCOPEDATA" = "" ]; then
				F_SCOPEDATA="$C_RELEASE_TARGETS"
			else
				f_checkvalidlist "$C_RELEASE_TARGETS" "$F_SCOPEDATA"
			fi
		else
			if [ "$F_SCOPEDATA" = "" ]; then
				F_SCOPEDATA=all
			fi
		fi

		if [ "$F_SCOPETYPE" = "core" ]; then
			S_RELEASESCOPE_CORE=$F_SCOPEDATA
		elif [ "$F_SCOPETYPE" = "war" ]; then
			S_RELEASESCOPE_WARS=$F_SCOPEDATA
		fi
	else
		if [ "$GETOPT_RELEASE" != "" ]; then
			f_release_getprojects core
			S_RELEASESCOPE_CORE=$C_RELEASE_TARGETS

			f_release_getprojects war
			S_RELEASESCOPE_WARS=$C_RELEASE_TARGETS
		else
			S_RELEASESCOPE_CORE=all
			S_RELEASESCOPE_WARS=all
		fi
	fi
}

# load configuration xml helpers

. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/common.sh
. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/commonrelease.sh
. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/commonsource.sh
. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/commonenv.sh
. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/commondistr.sh

# load local helpers

. ./commonexecute.sh
. ./commongit.sh
