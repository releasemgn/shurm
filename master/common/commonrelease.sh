#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

C_RELEASE_FNAME=
C_RELEASE_XMLVALUE=

# C_RELEASE_PROPERTY_OBSOLETE=

C_RELEASE_TARGETS=
C_RELEASE_ITEMS=
C_RELEASE_ALLITEMS=
C_RELEASE_CONFCOMPLIST=
C_RELEASE_CONFCOMPPATH=
C_RELEASE_CONFCOMP_PARTIAL=

C_RELEASE_PROJECT_TAG=
C_RELEASE_PROJECT_BRANCH=
C_RELEASE_PROJECT_VERSION=

C_RELEASE_DISTRID=
C_RELEASE_SRCDIR=
C_RELEASE_SRCVER=

C_RELEASE_CMD_RES=

function f_release_getxmlproperty() {
	local P_PROPNAME=$1
	C_RELEASE_XMLVALUE=`xmlstarlet sel -t -m "release/property[@name='$P_PROPNAME']" -v "@value" $C_RELEASE_FNAME`
}

function f_release_setfile() {
	local P_FNAME=$1

	if [ ! -f "$P_FNAME" ]; then
		echo unable to find release definition file $P_FNAME. Exiting
		exit 1
	fi

	C_RELEASE_FNAME=$P_FNAME

	# release properties
	f_release_getxmlproperty obsolete
	C_RELEASE_PROPERTY_OBSOLETE=$C_RELEASE_XMLVALUE
}

function f_release_getprojectinfo() {
	local P_PROJECTSET=$1
	local P_PROJECT=$2

	C_RELEASE_PROJECT_TAG=
	C_RELEASE_PROJECT_BRANCH=
	C_RELEASE_PROJECT_VERSION=

	# check all case
	local F_CHECKALL=`xmlstarlet sel -t -m "release/build/buildset[@type='$P_PROJECTSET']" -v "@all" $C_RELEASE_FNAME`
	if [ "$F_CHECKALL" = "true" ]; then
		C_RELEASE_PROJECT_TAG=`xmlstarlet sel -t -m "release/build/buildset[@type='$P_PROJECTSET']" -v "@buildtag" $C_RELEASE_FNAME`
	else	
		C_RELEASE_PROJECT_TAG=`xmlstarlet sel -t -m "release/build/buildset[@type='$P_PROJECTSET']/project[@name='$P_PROJECT']" -v "@buildtag" $C_RELEASE_FNAME`
	fi

	C_RELEASE_PROJECT_BRANCH=`xmlstarlet sel -t -m "release/build/buildset[@type='$P_PROJECTSET']/project[@name='$P_PROJECT']" -v "@buildbranch" $C_RELEASE_FNAME`
	C_RELEASE_PROJECT_VERSION=`xmlstarlet sel -t -m "release/build/buildset[@type='$P_PROJECTSET']/project[@name='$P_PROJECT']" -v "@buildversion" $C_RELEASE_FNAME`
}

function f_release_getprojects() {
	local P_PROJECTSET=$1

	# check all case
	local F_CHECKALL=`xmlstarlet sel -t -m "release/build/buildset[@type='$P_PROJECTSET']" -v "@all" $C_RELEASE_FNAME`
	if [ "$F_CHECKALL" = "true" ]; then
		C_RELEASE_TARGETS="all"
	else	
		C_RELEASE_TARGETS=`xmlstarlet sel -t -m "release/build/buildset[@type='$P_PROJECTSET']/project" -v "@name" -o " " $C_RELEASE_FNAME`
		C_RELEASE_TARGETS=${C_RELEASE_TARGETS% }
		C_RELEASE_TARGETS=${C_RELEASE_TARGETS# }
	fi
}

function f_release_getprojectitems() {
	local P_PROJECTSET=$1
	local P_PROJECTNAME=$2

	C_RELEASE_ALLITEMS=`xmlstarlet sel -t -m "release/build/buildset[@type='$P_PROJECTSET']/project[@name='$P_PROJECTNAME']" -v "@all" $C_RELEASE_FNAME`
	if [ "$C_RELEASE_ALLITEMS" = "" ]; then
		C_RELEASE_ALLITEMS="true"
	fi

	C_RELEASE_ITEMS=`xmlstarlet sel -t -m "release/build/buildset[@type='$P_PROJECTSET']/project[@name='$P_PROJECTNAME']/distitem" -v "@name" -o " " $C_RELEASE_FNAME`
	C_RELEASE_ITEMS=${C_RELEASE_ITEMS% }
	C_RELEASE_ITEMS=${C_RELEASE_ITEMS# }
}

function f_release_getconfcomplist() {
	# check all case
	local F_CHECKALL=`xmlstarlet sel -t -m "release/configure" -v "@all" $C_RELEASE_FNAME`
	if [ "$F_CHECKALL" = "true" ]; then
		C_RELEASE_CONFCOMPLIST="all"
	else
		C_RELEASE_CONFCOMPLIST=`xmlstarlet sel -t -m "release/configure/component" -v "@name" -o " " $C_RELEASE_FNAME`
		C_RELEASE_CONFCOMPLIST=${C_RELEASE_CONFCOMPLIST% }
		C_RELEASE_CONFCOMPLIST=${C_RELEASE_CONFCOMPLIST# }
	fi
}

function f_release_getconfcomppath() {
	local P_DC=$1
	local P_SERVER=$2
	local P_HOSTNAME=$3
	local P_CONFCOMP=$4
	local P_CONFCOMPLAYER=$5

	if [ "$P_CONFCOMPLAYER" = "env" ]; then
		C_RELEASE_CONFCOMPPATH=common/$P_CONFCOMP
	elif [ "$P_CONFCOMPLAYER" = "datacenter" ]; then
		C_RELEASE_CONFCOMPPATH=$P_DC/common/$P_CONFCOMP
	elif [ "$P_CONFCOMPLAYER" = "server" ]; then
		C_RELEASE_CONFCOMPPATH=$P_DC/$P_SERVER/$P_CONFCOMP
	elif [ "$P_CONFCOMPLAYER" = "node" ]; then
		C_RELEASE_CONFCOMPPATH=$P_DC/$P_SERVER/$P_CONFCOMP@$P_HOSTNAME
	else
		echo f_release_getconfcomppath: invalid configuration component layer=$P_CONFCOMPLAYER. Exiting
		exit 1
	fi
}

function f_release_getconfcompinfo() {
	local P_CONFCOMP=$1
	C_RELEASE_CONFCOMP_PARTIAL=`xmlstarlet sel -t -m "release/configure/component[@name='$P_CONFCOMP']" -v "@partial" $C_RELEASE_FNAME`
}

# run any command
function f_release_runcmd() {
	local P_CMD="$1"

	C_RELEASE_CMD_RES=
	if [ "$C_ENV_PROPERTY_DISTR_USELOCAL" = "true" ]; then
		C_RELEASE_CMD_RES=`(eval $P_CMD) 2>&1`
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		if [ "$C_ENV_PROPERTY_DISTR_REMOTEHOST" = "" ]; then
			echo "C_ENV_PROPERTY_DISTR_REMOTEHOST is not set. Exiting
			exit 1
		fi

		if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
			C_RELEASE_CMD_RES=`ssh -i $C_ENV_PROPERTY_KEYNAME -n $C_ENV_PROPERTY_DISTR_REMOTEHOST "$P_CMD" 2>&1`
			if [ $? -ne 0 ]; then
				return 1
			fi
		else
			C_RELEASE_CMD_RES=`ssh -n $C_ENV_PROPERTY_DISTR_REMOTEHOST "$P_CMD" 2>&1`
			if [ $? -ne 0 ]; then
				return 1
			fi
		fi
	fi
	return 0
}

function f_release_runcmdcheck() {
	local P_CMD="$1"

	f_release_runcmd $P_CMD
	if [ $? -ne 0 ]; then
		if [ "$C_ENV_PROPERTY_DISTR_USELOCAL" = "true" ]; then
			echo f_release_runcmdcheck: unable to execute $P_CMD. Exiting
		else
			echo f_release_runcmdcheck: unable to execute $P_CMD on $C_ENV_PROPERTY_DISTR_REMOTEHOST. Exiting
		fi
		exit 1
	fi
}

function f_release_getfullproddistr() {
	C_RELEASE_DISTRID=

	f_release_runcmdcheck "find $C_ENV_PROPERTY_DISTR_PATH -maxdepth 1 -name \"*-prod\" -exec basename {} \\;"
	local F_NAME=$C_RELEASE_CMD_RES

	# check content
	local F_WORDS=`echo $F_NAME | wc -w`
	if [ "$F_WORDS" = "0" ]; then
		echo f_release_getfullproddistr: unable to find prod distributive. Exiting
		exit 1
	fi

	if [ "$F_WORDS" != "1" ]; then
		echo f_release_getfullproddistr: ambiguus distributives - $F_NAME. Exiting
		exit 1
	fi

	C_RELEASE_DISTRID=$F_NAME
}

function f_release_resolverelease() {
	P_RELEASE=$1

	C_RELEASE_DISTRID=
	if [ "$P_RELEASE" = "prod" ]; then
		f_release_getfullproddistr
	elif [ "$P_RELEASE" = "last" ]; then
		C_RELEASE_DISTRID=$C_CONFIG_VERSION_LAST_FULL
	elif [ "$P_RELEASE" = "next" ]; then
		C_RELEASE_DISTRID=$C_CONFIG_VERSION_NEXT_FULL
	else
		C_RELEASE_DISTRID=$P_RELEASE
	fi
}

function f_release_getdistrdir() {
	local P_RELEASENAME=$1

	C_RELEASE_SRCDIR=$C_ENV_PROPERTY_DISTR_PATH/$P_RELEASENAME
	C_RELEASE_SRCVER=`basename $C_RELEASE_SRCDIR | cut -d "-" -f1`
	if [ "$C_RELEASE_SRCVER" = "" ]; then
		echo redist.sh: SRCDIR is expected having name=VERSION-anything, value=$C_RELEASE_SRCDIR
		exit 1
	fi

	echo check source dir $C_RELEASE_SRCDIR...
	f_release_runcmdcheck "if [ -d "$C_RELEASE_SRCDIR" ]; then echo true; fi"
	if [ "$C_RELEASE_CMD_RES" != "true" ]; then
		if [ "$C_ENV_PROPERTY_DISTR_USELOCAL" = "true" ]; then
			echo local release directory $C_RELEASE_SRCDIR does not exist. Exiting
		else
			echo "$P_DISTR_HOSTLOGIN: local release directory $C_RELEASE_SRCDIR does not exist". Exiting
		fi
		exit 1
	fi

	if [ "$C_ENV_PROPERTY_DISTR_USELOCAL" = "true" ]; then
		echo "local source dir found path=$C_RELEASE_SRCDIR, version=$C_RELEASE_SRCVER."
	else
		echo "$P_DISTR_HOSTLOGIN: source dir found path=$C_RELEASE_SRCDIR, version=$C_RELEASE_SRCVER."
	fi
}

function f_release_getfile() {
	local P_SRCPATH=$1
	local P_DSTPATH=$2

	if [ "$C_ENV_PROPERTY_DISTR_USELOCAL" = "true" ]; then
		if [ ! -f "$P_SRCPATH" ]; then
			echo file is not found - $P_SRCPATH. Exiting
			exit 1
		fi

		cp -p $P_SRCPATH $P_DSTPATH
		if [ $? -ne 0 ]; then
			return 1
		fi

	else
		if [ "$C_ENV_PROPERTY_DISTR_REMOTEHOST" = "" ]; then
			echo "C_ENV_PROPERTY_DISTR_REMOTEHOST is not set. Exiting
			exit 1
		fi

		# get remote file - using key file if any
		if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
			scp -q -B -p -i $C_ENV_PROPERTY_KEYNAME $C_ENV_PROPERTY_DISTR_REMOTEHOST:$P_SRCPATH $P_DSTPATH
			if [ $? -ne 0 ]; then
				return 1
			fi
		else
			scp -q -B -p $C_ENV_PROPERTY_DISTR_REMOTEHOST:$P_SRCPATH $P_DSTPATH
			if [ $? -ne 0 ]; then
				return 1
			fi
		fi
	fi

	return 0
}

function f_release_getdir() {
	local P_SRCPATH=$1
	local P_DSTPATH=$2

	if [ "$C_ENV_PROPERTY_DISTR_USELOCAL" = "true" ]; then
		if [ -d "$P_SRCPATH" ]; then
			cp -R $P_SRCPATH $P_DSTPATH
			if [ $? -ne 0 ]; then
				return 1
			fi
		fi
	else
		f_release_runcmdcheck "if [ -d $P_SRCPATH ]; then echo ok; fi"
		if [ "$C_RELEASE_CMD_RES" = "ok" ]; then
			if [ "$C_ENV_PROPERTY_KEYNAME" != "" ]; then
				scp -q -r -B -p -i $C_ENV_PROPERTY_KEYNAME $C_ENV_PROPERTY_DISTR_REMOTEHOST:$P_SRCPATH $P_DSTPATH
				if [ $? -ne 0 ]; then
					return 1
				fi
			else
				scp -q -r -B -p $C_ENV_PROPERTY_DISTR_REMOTEHOST:$P_SRCPATH $P_DSTPATH
				if [ $? -ne 0 ]; then
					return 1
				fi
			fi
		fi
	fi

	return 0
}
