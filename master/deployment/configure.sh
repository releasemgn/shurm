#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh
. ./common.sh

# check params
# should be specific DC
DC=$GETOPT_DC
if [ "$DC" = "" ]; then
	echo configure.sh: DC not set
	exit
fi

P_DIR_TYPE=$1
P_DIR_TEMPLATES=$2
P_DIR_LIVE=$3

if [ "$P_DIR_TYPE" = "" ]; then
	echo configure.sh: P_DIR_TYPE not set
	exit 1
fi
if [ "$P_DIR_TEMPLATES" = "" ]; then
	echo configure.sh: P_DIR_TEMPLATES not set
	exit 1
fi
if [ "$P_DIR_LIVE" = "" ]; then
	echo configure.sh: P_DIR_LIVE not set
	exit 1
fi
shift 3

SRVNAME_LIST=$*

# execute
if [ "$C_ENV_ID" = "" ]; then
	echo configure.sh: C_ENV_ID not set
	exit 1
fi

S_CONFIGURE_TMP="/tmp/$HOSTNAME.$USER.configure.p$$"
S_CONFIGURE_AWKPROGRAM="$S_CONFIGURE_TMP/process.awk"
S_CONFIGURE_PREPAREDTEMPLATES="$S_CONFIGURE_TMP/templates.prepared"

S_CONFIGURE_PROPLIST_SECRET=
S_CONFIGURE_PROPLIST_ENV=
S_CONFIGURE_PROPLIST_DC=
S_CONFIGURE_PROPLIST_SERVER=

function f_local_generatenodecomponentfiles() {
	local P_SERVER=$1
	local P_NODEHOSTLOGIN=$2
	local P_CONFCOMPNAME=$3

	# check component is defined in templates
	if [ ! -d $S_CONFIGURE_PREPAREDTEMPLATES/$P_CONFCOMPNAME ]; then
		if [ "$GETOPT_DEPLOYPARTIALCONF" != "yes" ]; then
			echo f_local_generatenodecomponentfiles: $P_CONFCOMPNAME component is not found in $S_CONFIGURE_PREPAREDTEMPLATES. Exiting
			exit 1
		fi
		return 1
	fi

	# check dir type
	local F_COMPSUBDIR=$P_CONFCOMPNAME
	if [ "$P_DIR_TYPE" = "templates" ]; then
		f_distr_getconfcompinfo $P_CONFCOMPNAME
		if [ "$C_DISTR_CONF_SUBDIR" != "" ]; then
			F_COMPSUBDIR=$C_DISTR_CONF_SUBDIR/$P_CONFCOMPNAME
		fi
	fi

	# process component files
	local F_LOCAL_DIR_FROM=$S_CONFIGURE_PREPAREDTEMPLATES/$F_COMPSUBDIR
	local F_LOCAL_DIR_TO=$P_DIR_LIVE/$DC/$P_SERVER/$P_NODEHOSTLOGIN/$P_CONFCOMPNAME

	echo generate component=$P_CONFCOMPNAME to $F_LOCAL_DIR_TO ...

	rm -rf $F_LOCAL_DIR_TO
	mkdir -p $F_LOCAL_DIR_TO

	local F_COMPSAVEDIR=`pwd`
	cd $F_LOCAL_DIR_FROM

	local fname
	local fname_dst
	for fname in `find . -type d`; do
		fname_dst=$F_LOCAL_DIR_TO/$fname
		mkdir -p $fname_dst
	done

	for fname in `find . -type f`; do
		fname_dst=$F_LOCAL_DIR_TO/$fname
		mkdir -p `dirname $fname_dst`

		local F_BASENAME=`basename $fname`
		local F_EXT=${F_BASENAME##*.}

		if [[ " $S_COMMON_EXTLIST " =~ " $F_EXT " ]]; then
			# copy and process parameters
			awk -f $S_CONFIGURE_AWKPROGRAM $fname > $fname_dst
		else
			# copy binary as is
			cp $fname $fname_dst
		fi

	done

	cd $F_COMPSAVEDIR
}

function f_local_generatenodefiles() {
	local P_SERVER=$1
	local P_NODEHOSTLOGIN=$2
	local P_CONFCOMPLIST="$3"

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo "configure node=$P_NODEHOSTLOGIN, components=($P_CONFCOMPLIST)..."
	fi

	local F_LOCAL_SAVEPATH=`pwd`
	cd $S_CONFIGURE_PREPAREDTEMPLATES

	# generate template files
	local comp
	for comp in $P_CONFCOMPLIST; do
		f_local_generatenodecomponentfiles $P_SERVER $P_NODEHOSTLOGIN $comp
	done

	cd $F_LOCAL_SAVEPATH
}

function f_local_construct_addawkvar() {
	local P_VAR=$1
	local P_VALUE=$2

	local awk_var=`echo $P_VAR | tr ".-" "__"`
	P_VALUE=${P_VALUE/&/\\\\&}

	echo "$awk_var=\"$P_VALUE\";" >> $S_CONFIGURE_AWKPROGRAM
	echo "gsub(/@$P_VAR@/, $awk_var);" >> $S_CONFIGURE_AWKPROGRAM
}

function f_local_construct_awk() {
	local P_SERVER=$1

	S_CONFIGURE_AWK_VARS=
	echo "{" > $S_CONFIGURE_AWKPROGRAM

	# add server-level props
	local var
	for var in $S_CONFIGURE_PROPLIST_SERVER; do
		f_env_getserverpropertyvalue $DC $P_SERVER $var
		f_local_construct_addawkvar server.$var "$C_ENV_XMLVALUE"

		# handle unprefixed variables
		f_local_construct_addawkvar $var "$C_ENV_XMLVALUE"
	done

	# add dc-level props
	for var in $S_CONFIGURE_PROPLIST_DC; do
		f_env_getdcpropertyvalue $DC $var
		f_local_construct_addawkvar dc.$var "$C_ENV_XMLVALUE"

		# handle unprefixed variables
		if [[ ! " $S_CONFIGURE_PROPLIST_SERVER " =~ " $var " ]]; then
			f_local_construct_addawkvar $var "$C_ENV_XMLVALUE"
		fi
	done

	# add env-level props
	for var in $S_CONFIGURE_PROPLIST_ENV; do
		f_env_getenvpropertyvalue $var
		f_local_construct_addawkvar env.$var "$C_ENV_XMLVALUE"

		# handle unprefixed variables
		if [[ ! " $S_CONFIGURE_PROPLIST_SERVER " =~ " $var " ]] && [[ ! " $S_CONFIGURE_PROPLIST_DC " =~ " $var " ]]; then
			f_local_construct_addawkvar $var "$C_ENV_XMLVALUE"
		fi
	done

	# add secret props
	for var in $S_CONFIGURE_PROPLIST_SECRET; do
		f_env_getsecretpropertyvalue $var
		f_local_construct_addawkvar secret.$var "$C_ENV_XMLVALUE"

		# handle unprefixed variables
		if [[ ! " $S_CONFIGURE_PROPLIST_ENV " =~ " $var " ]] && [[ ! " $S_CONFIGURE_PROPLIST_SERVER " =~ " $var " ]] && [[ ! " $S_CONFIGURE_PROPLIST_DC " =~ " $var " ]]; then
			f_local_construct_addawkvar $var "$C_ENV_XMLVALUE"
		fi
	done

	echo "print" >> $S_CONFIGURE_AWKPROGRAM
	echo "}" >> $S_CONFIGURE_AWKPROGRAM
}

function f_local_getproperties_secret() {
	# read secret properties...
	f_env_getsecretpropertylist
	f_revertlist "$C_ENV_XMLVALUE"
	S_CONFIGURE_PROPLIST_SECRET="$C_COMMON_LIST"
}

function f_local_getproperties_env() {
	# read env properties...
	f_env_getenvpropertylist
	f_revertlist "$C_ENV_XMLVALUE"
	S_CONFIGURE_PROPLIST_ENV="$C_COMMON_LIST"
}

function f_local_getproperties_dc() {
	# echo read data center properties...
	f_env_getdcpropertylist $DC
	f_revertlist "$C_ENV_XMLVALUE"
	S_CONFIGURE_PROPLIST_DC="$C_COMMON_LIST"
}

function f_local_getproperties_server() {
	local P_SERVER=$1

	# echo read server properties...
	f_env_getserverpropertylist $DC $P_SERVER
	f_revertlist "$C_ENV_XMLVALUE"
	S_CONFIGURE_PROPLIST_SERVER="$C_COMMON_LIST"
}

function f_local_prepare_templates() {
	local P_SERVER=$1
	local P_COMPLIST="$2"

	rm -rf $S_CONFIGURE_PREPAREDTEMPLATES
	mkdir -p `dirname $S_CONFIGURE_PREPAREDTEMPLATES`
	cp -R $P_DIR_TEMPLATES $S_CONFIGURE_PREPAREDTEMPLATES

	local preparescript
	local F_COMPDIR
	for preparescript in `find $S_CONFIGURE_PREPAREDTEMPLATES -maxdepth 2 -name "preconfigure.sh"`; do
		F_COMPDIR=`dirname $preparescript`
		F_COMPNAME=`basename $F_COMPDIR`
		
		if [[ " $P_COMPLIST " =~ " $F_COMPNAME " ]]; then
			local savedir=`pwd`
			cd $F_COMPDIR

			chmod 777 preconfigure.sh
			echo "$P_SERVER: execute custom configuration script in $F_COMPDIR..."
			. ./preconfigure.sh $C_ENV_ID $DC $P_SERVER

			# remove script
			rm -rf preconfigure.sh

			cd $savedir
		fi
	done
}

function f_local_execute_server() {
	local P_SERVER=$1

	f_env_getserverconflist $DC $P_SERVER
	local F_CONFCOMPLIST="$C_ENV_SERVER_CONFLIST"

	if [ "$F_CONFCOMPLIST" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo server $P_SERVER: no configuration components defined. Skipped.
		fi
		return 1
	fi
	
	# read server info
	f_env_getxmlserverinfo $DC $P_SERVER
	local F_NODELIST="$C_ENV_SERVER_HOSTLOGIN_LIST"

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo configure server $P_SERVER...
	fi

	# read server properties
	f_local_getproperties_server $P_SERVER

	# construct awk string to handle properties
	f_local_construct_awk $P_SERVER

	# prepare templates
	f_local_prepare_templates $P_SERVER "$F_CONFCOMPLIST"

	# generate files by templates
	local nodehostlogin
	for nodehostlogin in $F_NODELIST; do
		f_local_generatenodefiles $P_SERVER $nodehostlogin "$F_CONFCOMPLIST"
	done
}

function f_local_execute_dc() {
	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo configure data center $DC...
	fi

	# read properties
	f_local_getproperties_dc

	# configure by server
	f_env_getxmlserverlist $DC
	local F_DC_SERVERLIST="$C_ENV_XMLVALUE"

	if [ "$SRVNAME_LIST" = "" ]; then
		SRVNAME_LIST="$F_DC_SERVERLIST"
	fi

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo configure data center servers...
	fi

	f_checkvalidlist "$F_DC_SERVERLIST" "$SRVNAME_LIST"
	local server
	for server in $SRVNAME_LIST; do
		f_local_execute_server $server
	done
}

function f_local_execute_env() {
	rm -rf $S_CONFIGURE_TMP
	mkdir -p $S_CONFIGURE_TMP

	# set environment
	echo configure environment $C_ENV_ID in $P_DIR_LIVE using templates in $P_DIR_TEMPLATES ...

	# read properties
	f_local_getproperties_secret
	f_local_getproperties_env

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo prepare templates in $S_CONFIGURE_PREPAREDTEMPLATES ...
	fi

	f_local_execute_dc

	# delete tmp
	rm -rf $S_CONFIGURE_TMP
}

# configure all
f_local_execute_env

echo configure.sh: finished.
