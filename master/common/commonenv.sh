#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

# C_ENV_ID
# C_ENV_PATH
# C_ENV_PROPERTY_DISTR_PATH
# C_ENV_PROPERTY_DISTR_USELOCAL
# C_ENV_PROPERTY_DISTR_REMOTEHOST
# C_ENV_PROPERTY_KEYNAME
# C_ENV_PROPERTY_SECRETFILE
# C_ENV_PROPERTY_SKYPE_CHATROOMFILE
# C_ENV_PROPERTY_DBAUTHFILE=

C_ENV_XMLLINE=
C_ENV_XMLVALUE=

C_ENV_LIST=

C_ENV_SERVER_TYPE=
C_ENV_SERVER_HOSTLOGIN_LIST=
C_ENV_SERVER_HOST_LIST=
C_ENV_SERVER_COMPONENT_LIST=
C_ENV_SERVER_ROOTPATH=
C_ENV_SERVER_BINPATH=
C_ENV_SERVER_DEPLOYTYPE=
C_ENV_SERVER_DEPLOYPATH=
C_ENV_SERVER_LINKFROMPATH=
C_ENV_SERVER_LOGPATH=
C_ENV_SERVER_WEBDOMAIN=
C_ENV_SERVER_SERVICENAME=
C_ENV_SERVER_NLBSERVER=
C_ENV_SERVER_PORT=
C_ENV_SERVER_PROXYSERVER=
C_ENV_SERVER_STATICSERVER=
C_ENV_SERVER_STARTTIME=
C_ENV_SERVER_JBOSS_VERSION=
C_ENV_SERVER_SUBORDINATE_SERVERS=
C_ENV_SERVER_DBTNSTYPE=
C_ENV_SERVER_DBTNSNAME=
C_ENV_SERVER_DBREGIONS=
C_ENV_SERVER_ALIGNED=
C_ENV_SERVER_DBSCHEMALIST=
C_ENV_SERVER_HOTDEPLOYSERVER=
C_ENV_SERVER_HOTDEPLOYPATH=

C_ENV_STATUS=

C_ENV_SERVER_LOCATIONLIST=
C_ENV_SEQUENCE=
C_ENV_SEQUENCEITEMS=

C_ENV_LOCATION_COMPONENT_LIST=
C_ENV_LOCATION_DEPLOYPATH=
C_ENV_LOCATION_DEPLOYTYPE=

C_ENV_SERVER_CONFLIST=

C_ENV_SERVER_COMP_DEPLOYPATH=
C_ENV_SERVER_COMP_DEPLOYTYPE=

C_ENV_DEPLOYMENT_SWITCH_HOSTLOGIN=
C_ENV_DEPLOYMENT_SWITCH_COMMAND=
C_ENV_DEPLOYMENT_SWITCH_CONFPATH=
C_ENV_DEPLOYMENT_SWITCH_RUNFILE=
C_ENV_DEPLOYMENT_SWITCH_RUNFIRST=
C_ENV_DEPLOYMENT_SWITCH_RUNSECOND=
C_ENV_DEPLOYMENT_SWITCH_RUNALL=

function f_env_getxmlline() {
	local P_XPATH=$1
	local P_NAMEVALUE=$2

	C_ENV_XMLLINE=`xmlstarlet sel -t -c "$P_XPATH[@name='$P_NAMEVALUE']" $C_ENV_PATH`

	if [ "$C_ENV_XMLLINE" = "" ]; then
		C_ENV_XMLLINE=
		return 1
	fi

	return 0
}

function f_env_getfullxmlline() {
	local P_XPATH=$1

	C_ENV_XMLLINE=`xmlstarlet sel -t -c "$P_XPATH" $C_ENV_PATH`

	if [ "$C_ENV_XMLLINE" = "" ]; then
		C_ENV_XMLLINE=
		return 1
	fi

	return 0
}

function f_env_getxmlvalue() {
	local P_XPATH=$1
	local P_XMLATTRNAME=$2

	C_ENV_XMLVALUE=`xmlstarlet sel -t -m "$P_XPATH" -v "@$P_XMLATTRNAME" $C_ENV_PATH | xmlstarlet unesc`
}

function f_env_getxmlproperty() {
	local P_PROPNAME=$1
	f_env_getxmlvalue "module/property[@name='$P_PROPNAME']" "value"
}

function f_env_getxmldcproperty() {
	local P_DC=$1
	local P_PROPNAME=$2
	f_env_getxmlvalue "module/datacenter[@name='$P_DC']/property[@name='$P_PROPNAME']" "value"
}

function f_env_setpath() {
	local P_ENVPATH=$1

	# check environment file exists
	if [ ! -f $P_ENVPATH ]; then
		echo $P_ENVPATH file does not exist. Exiting.
		exit 1
	fi

	export C_ENV_PATH=$P_ENVPATH

	f_env_getxmlproperty "id"
	export C_ENV_ID=$C_ENV_XMLVALUE

	# get source directory
	f_env_getxmlproperty "distr-path"
	export C_ENV_PROPERTY_DISTR_PATH=$C_ENV_XMLVALUE

	f_env_getxmlproperty "distr-use-local"
	export C_ENV_PROPERTY_DISTR_USELOCAL=$C_ENV_XMLVALUE

	export C_ENV_PROPERTY_DISTR_REMOTEHOST=
	if [ "$C_ENV_PROPERTY_DISTR_USELOCAL" != "true" ]; then
		f_env_getxmlproperty "distr-remotehost"
		export C_ENV_PROPERTY_DISTR_REMOTEHOST=$C_ENV_XMLVALUE
	fi

	# set environment runtime options if not set in command line
	if [ "$GETOPT_EXECUTE" = "" ]; then
		f_env_getxmlproperty "execute"
		export GETOPT_EXECUTE=$C_ENV_XMLVALUE
	fi

	if [ "$GETOPT_BACKUP" = "" ]; then
		f_env_getxmlproperty "backup"
		export GETOPT_BACKUP=$C_ENV_XMLVALUE
	fi

	if [ "$GETOPT_OBSOLETE" = "" ]; then
		f_env_getxmlproperty "obsolete"
		export GETOPT_OBSOLETE=$C_ENV_XMLVALUE
	fi

	if [ "$GETOPT_DEPLOYCONF" = "" ]; then
		f_env_getxmlproperty "configuration-deploy"
		export GETOPT_DEPLOYCONF=$C_ENV_XMLVALUE
	fi

	if [ "$GETOPT_PROD" = "" ]; then
		f_env_getxmlproperty "prod"
		export GETOPT_PROD=$C_ENV_XMLVALUE
	fi

	if [ "$GETOPT_DBAUTH" = "" ]; then
		f_env_getxmlproperty "db-auth"
		export GETOPT_DBAUTH=$C_ENV_XMLVALUE
	fi

	f_env_getxmlproperty "keyname"
	export C_ENV_PROPERTY_KEYNAME=$C_ENV_XMLVALUE

	f_env_getxmlproperty "db-authfile"
	export C_ENV_PROPERTY_DBAUTHFILE=$C_ENV_XMLVALUE

	f_env_getxmlproperty "configuration-keepalive"
	export GETOPT_KEEPALIVE=$C_ENV_XMLVALUE

	f_env_getxmlproperty "configuration-secretpropertyfile"
	export C_ENV_PROPERTY_SECRETFILE=$C_ENV_XMLVALUE

	f_env_getxmlproperty "configuration-chatroomfile"
	export C_ENV_PROPERTY_SKYPE_CHATROOMFILE=$C_ENV_XMLVALUE
}

function f_env_getlist_byname() {
	local F_ENVFILE_LIST=`find $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/env -maxdepth 1 -type f -exec basename {} \;`
	C_ENV_LIST=
	local fenv
	for fenv in $F_ENVFILE_LIST; do
		local F_ENVNAME=${fenv%.*}
		C_ENV_LIST="$C_ENV_LIST $F_ENVNAME"
	done
	C_ENV_LIST=${C_ENV_LIST# }
}

function f_env_getlist_byid() {
	local F_ENVFILE_LIST=`find $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/env -maxdepth 1 -type f`
	C_ENV_LIST=
	local fenv
	for fenv in $F_ENVFILE_LIST; do
		f_env_setpath $fenv
		C_ENV_LIST="$C_ENV_LIST $C_ENV_ID"
	done
	C_ENV_LIST=${C_ENV_LIST# }
}

function f_env_getdclist() {
	C_ENV_XMLVALUE=`xmlstarlet sel -t -m "module/datacenter" -v "@name" -o " " $C_ENV_PATH`
}

function f_env_getxmllineattr() {
	local P_XMLELNAME=$1
	local P_XMLATTRNAME=$2
	local P_REQUIRED=$3

	if [ -z "$C_ENV_XMLLINE" ]; then
		echo "f_env_getxmllineattr: string not found"
		exit 1
	fi

	C_ENV_XMLVALUE=`echo $C_ENV_XMLLINE | xmlstarlet sel -t -m "$P_XMLELNAME" -v "@$P_XMLATTRNAME"`

	if [ "$C_ENV_XMLVALUE" = "" ] && [ "$P_REQUIRED" = "required" ]; then
		echo f_env_getxmllineattr: $P_XMLATTRNAME attribute is required in $C_ENV_XMLLINE. Exiting
		exit 1
	fi
}

function f_env_getdcstatus() {
	local P_DC=$1
	C_ENV_STATUS=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']" -o "valid" $C_ENV_PATH`
}

function f_env_getserverstatus() {
	local P_DC=$1
	local P_SERVER=$2
	C_ENV_STATUS=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']" -o "valid" $C_ENV_PATH`
}

function f_env_getxmlserverlist() {
	local P_DC=$1
	C_ENV_XMLVALUE=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server" -v "@name" -o " " $C_ENV_PATH`
	C_ENV_XMLVALUE=${C_ENV_XMLVALUE% }
}

function f_env_getxmlserverlist_bytype() {
	local P_DC=$1
	local P_TYPELIST="$2"

	f_env_getxmlserverlist $P_DC
	local F_ENV_FULLSRVLIST=$C_ENV_XMLVALUE

	local F_ENV_SELSRVLIST=
	local server
	for server in $F_ENV_FULLSRVLIST; do
		f_env_getxmlvalue "module/datacenter[@name='$P_DC']/server[@name='$server']" "type"
		local F_ENV_SERVERTYPE=$C_ENV_XMLVALUE
		if [[ " $P_TYPELIST " =~ " $F_ENV_SERVERTYPE " ]]; then
			F_ENV_SELSRVLIST="$F_ENV_SELSRVLIST $server"
		fi
	done

	C_ENV_XMLVALUE=${F_ENV_SELSRVLIST# }
}

function f_env_getxmlservernodeinfo() {
	local P_DC=$1
	local P_SERVER=$2
	local P_DEPLOYGROUP=$3

	# by deploygroup
	if [ "$P_DEPLOYGROUP" = "" ] || [ "$P_DEPLOYGROUP" = "normal" ]; then
		C_ENV_SERVER_HOSTLOGIN_LIST=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/node" -v "@hostlogin" -o " " $C_ENV_PATH`
	elif [ "$P_DEPLOYGROUP" = "default" ]; then
		C_ENV_SERVER_HOSTLOGIN_LIST=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/node[string-length(@deploygroup)=0 or @deploygroup='default']" -v "@hostlogin" -o " " $C_ENV_PATH`
	else
		C_ENV_SERVER_HOSTLOGIN_LIST=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/node[@deploygroup='$P_DEPLOYGROUP']" -v "@hostlogin" -o " " $C_ENV_PATH`
	fi

	C_ENV_SERVER_HOST_LIST=
	local hostlogin
	for hostlogin in $C_ENV_SERVER_HOSTLOGIN_LIST; do
		C_ENV_SERVER_HOST_LIST="$C_ENV_SERVER_HOST_LIST ${hostlogin##*@}"
	done

	C_ENV_SERVER_HOST_LIST=${C_ENV_SERVER_HOST_LIST## }
}

function f_env_getxmlserverinfo() {
	local P_DC=$1
	local P_SERVER=$2
	local P_DEPLOYGROUP=$3

	C_ENV_SERVER_TYPE=
	C_ENV_SERVER_HOSTLOGIN_LIST=
	C_ENV_SERVER_COMPONENT_LIST=
	C_ENV_SERVER_CONFLIST=
	C_ENV_SERVER_ROOTPATH=
	C_ENV_SERVER_BINPATH=
	C_ENV_SERVER_DEPLOYTYPE=
	C_ENV_SERVER_DEPLOYPATH=
	C_ENV_SERVER_LINKFROMPATH=
	C_ENV_SERVER_LOGPATH=
	C_ENV_SERVER_WEBDOMAIN=
	C_ENV_SERVER_SERVICENAME=
	C_ENV_SERVER_NLBSERVER=
	C_ENV_SERVER_PORT=
	C_ENV_SERVER_STARTTIME=
	C_ENV_SERVER_PROXYSERVER=
	C_ENV_SERVER_STATICSERVER=
	C_ENV_SERVER_SUBORDINATE_SERVERS=
	C_ENV_SERVER_DBTNSTYPE=
	C_ENV_SERVER_DBTNSNAME=
	C_ENV_SERVER_DBREGIONS=
	C_ENV_SERVER_ALIGNED=
	C_ENV_SERVER_DBSCHEMALIST=
	C_ENV_SERVER_HOTDEPLOYSERVER=
	C_ENV_SERVER_HOTDEPLOYPATH=

	f_env_getxmlline "module/datacenter[@name='$P_DC']/server" "$P_SERVER"
	if [ -z "$C_ENV_XMLLINE" ]; then
		echo f_env_getxmlserverinfo: server DC=$P_DC, name=$P_SERVER not found in $C_ENV_PATH. Exiting
		exit 1
	fi

	f_env_getxmllineattr server "type" required
	C_ENV_SERVER_TYPE=$C_ENV_XMLVALUE
	C_ENV_SERVER_CONFLIST=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/configure" -v "@component" -o " " $C_ENV_PATH`

	f_env_getxmllineattr server "starttime"
	C_ENV_SERVER_STARTTIME=$C_ENV_XMLVALUE

	f_env_getxmllineattr server "deploytype"
	C_ENV_SERVER_DEPLOYTYPE=$C_ENV_XMLVALUE

	f_env_getxmllineattr server "deploypath"
	C_ENV_SERVER_DEPLOYPATH=$C_ENV_XMLVALUE

	if [ "$C_ENV_SERVER_DEPLOYTYPE" = "" ]; then
		C_ENV_SERVER_DEPLOYTYPE="default"
	fi

	if [ "$C_ENV_SERVER_DEPLOYTYPE" = "links-multidir" ] || [ "$C_ENV_SERVER_DEPLOYTYPE" = "links-sinledir" ]; then
		f_env_getxmllineattr server "linkfrompath" required
		C_ENV_SERVER_LINKFROMPATH=$C_ENV_XMLVALUE
	fi

	f_env_getxmllineattr server "subordinate-servers"
	C_ENV_SERVER_SUBORDINATE_SERVERS="$C_ENV_XMLVALUE"

	# read deployment components
	C_ENV_SERVER_COMPONENT_LIST=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/deploy" -v "@component" -o " " $C_ENV_PATH`

	if [ "$C_ENV_SERVER_DEPLOYTYPE" != "none" ] && [ "$C_ENV_SERVER_DEPLOYTYPE" != "manual" ]; then
		f_env_getxmllineattr server "rootpath" required
		C_ENV_SERVER_ROOTPATH=$C_ENV_XMLVALUE
	fi

	f_env_getxmllineattr server "aligned"
	C_ENV_SERVER_ALIGNED=$C_ENV_XMLVALUE

	f_env_getxmllineattr server "nlbserver"
	C_ENV_SERVER_NLBSERVER=$C_ENV_XMLVALUE

	f_env_getxmllineattr server "port"
	C_ENV_SERVER_PORT=$C_ENV_XMLVALUE

	if [ "$C_ENV_SERVER_DEPLOYTYPE" != "none" ] && [ "$C_ENV_SERVER_DEPLOYTYPE" != "manual" ] && [ "$C_ENV_SERVER_TYPE" != "service" ]; then
		f_env_getxmllineattr server "binpath" required
		C_ENV_SERVER_BINPATH=$C_ENV_XMLVALUE
	fi

	f_env_getxmllineattr server "hotdeployserver"
	C_ENV_SERVER_HOTDEPLOYSERVER=$C_ENV_XMLVALUE
	f_env_getxmllineattr server "hotdeploypath"
	C_ENV_SERVER_HOTDEPLOYPATH=$C_ENV_XMLVALUE

	f_env_getxmllineattr server "webdomain"
	C_ENV_SERVER_WEBDOMAIN=$C_ENV_XMLVALUE

	f_env_getxmllineattr server "proxy-server"
	C_ENV_SERVER_PROXYSERVER=$C_ENV_XMLVALUE

	f_env_getxmllineattr server "static-server"
	C_ENV_SERVER_STATICSERVER=$C_ENV_XMLVALUE
	if [ "$C_ENV_SERVER_STATICSERVER" = "" ]; then
		C_ENV_SERVER_STATICSERVER=$C_ENV_SERVER_PROXYSERVER
	fi

	f_env_getxmllineattr server "jboss-version"
	C_ENV_SERVER_JBOSS_VERSION=$C_ENV_XMLVALUE

	f_env_getxmllineattr server "logfilepath"
	C_ENV_SERVER_LOGPATH=$C_ENV_XMLVALUE

	if [ "$C_ENV_SERVER_TYPE" = "service" ]; then
		f_env_getxmllineattr server "servicename" required
		C_ENV_SERVER_SERVICENAME=$C_ENV_XMLVALUE

	elif [ "$C_ENV_SERVER_TYPE" = "database" ]; then
		f_env_getxmllineattr server "tnstype" required
		C_ENV_SERVER_DBTNSTYPE=$C_ENV_XMLVALUE
		f_env_getxmllineattr server "tnsname" required
		C_ENV_SERVER_DBTNSNAME=$C_ENV_XMLVALUE
		f_env_getxmllineattr server "regions"
		C_ENV_SERVER_DBREGIONS=$C_ENV_XMLVALUE

		if [ "$C_ENV_SERVER_DBTNSTYPE" = "all" ]; then
			C_ENV_SERVER_DBSCHEMALIST=$C_CONFIG_SCHEMAALLLIST

		elif [ "$C_ENV_SERVER_DBTNSTYPE" = "fed" ]; then
			C_ENV_SERVER_DBSCHEMALIST=$C_CONFIG_SCHEMAFEDLIST

		elif [ "$C_ENV_SERVER_DBTNSTYPE" = "reg" ]; then
			C_ENV_SERVER_DBSCHEMALIST=$C_CONFIG_SCHEMAREGLIST

		elif [ "$C_ENV_SERVER_DBTNSTYPE" = "custom" ]; then
			f_env_getxmllineattr server "schemalist" required
			C_ENV_SERVER_DBSCHEMALIST=$C_ENV_XMLVALUE
		fi

		# check valid
		if [ "$C_ENV_SERVER_DBSCHEMALIST" = "" ]; then
			echo schema list is undefined for DC=$P_DC, DB=$P_SERVER. Exiting
			exit 1
		fi
	fi

	# read nodes
	f_env_getxmlservernodeinfo $P_DC $P_SERVER $P_DEPLOYGROUP
}

function f_env_getserverlocations() {
	local P_DC=$1
	local P_SERVER=$2

	C_ENV_SERVER_LOCATIONLIST=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/deploy" -v "@deploypath" -o " " $C_ENV_PATH`
	C_ENV_SERVER_LOCATIONLIST=${C_ENV_SERVER_LOCATIONLIST% }
	local F_DEF_DEPLOYPATH=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']" -v "@deploypath" $C_ENV_PATH`
	if  [ "$F_DEF_DEPLOYPATH" != "" ]; then
		C_ENV_SERVER_LOCATIONLIST="$C_ENV_SERVER_LOCATIONLIST $F_DEF_DEPLOYPATH"
	fi

	C_ENV_SERVER_LOCATIONLIST=`echo $C_ENV_SERVER_LOCATIONLIST | tr " " "\n" | grep -v "^$" | sort -u | tr "\n" " "`
	C_ENV_SERVER_LOCATIONLIST=${C_ENV_SERVER_LOCATIONLIST# }
	C_ENV_SERVER_LOCATIONLIST=${C_ENV_SERVER_LOCATIONLIST% }
}

function f_env_getlocationinfo() {
	local P_DC=$1
	local P_SERVER=$2
	local P_LOCATION=$3

	local F_DEF_DEPLOYPATH=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']" -v "@deploypath" $C_ENV_PATH`
	if [ "$P_LOCATION" = "default" ]; then
		P_LOCATION=$F_DEF_DEPLOYPATH
	fi

	local F_DEFDEPLOYTYPE=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']" -v "@deploytype" $C_ENV_PATH`
	if [ "$F_DEFDEPLOYTYPE" = "" ]; then
		F_DEFDEPLOYTYPE="default"
	fi

	C_ENV_LOCATION_DEPLOYPATH=$P_LOCATION

	local F_COMPSET
	if [ "$P_LOCATION" = "$F_DEF_DEPLOYPATH" ]; then
		F_COMPSET=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/deploy[@deploypath='$F_DEF_DEPLOYPATH' or string-length(@deploypath)=0]" -v "@component" -o "=@" -v "@deploytype" -o "@ " $C_ENV_PATH`
	else
		F_COMPSET=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/deploy[@deploypath='$P_LOCATION']" -v "@component" -o "=@" -v "@deploytype" -o "@ " $C_ENV_PATH`
	fi

	F_COMPSET=${F_COMPSET% }
	F_COMPSET=${F_COMPSET//@@/@$F_DEFDEPLOYTYPE@}
	F_COMPSET=${F_COMPSET//@/}

	C_ENV_LOCATION_COMPONENT_LIST=`echo "$F_COMPSET" | tr " " "\n" | cut -d "=" -f1 | tr "\n" " "`
	C_ENV_LOCATION_COMPONENT_LIST=${C_ENV_LOCATION_COMPONENT_LIST% }
	C_ENV_LOCATION_DEPLOYTYPE=

	if [ "$C_ENV_LOCATION_COMPONENT_LIST" != "" ]; then
		local F_DEPLOYTYPES=`echo "$F_COMPSET" | tr " " "\n" | cut -d "=" -f2 | sort -u`
		local F_DEPLOYNUM=`echo "$F_DEPLOYTYPES" | grep -c .`
		if [ "$F_DEPLOYNUM" != "1" ]; then
			echo f_env_getlocationinfo: found different deploy types for location=$P_LOCATION. Exiting
			exit 1
		fi

		C_ENV_LOCATION_DEPLOYTYPE=`echo "$F_DEPLOYTYPES" | tr -d "\n"`
	fi

	if [ "$C_ENV_LOCATION_DEPLOYTYPE" = "" ]; then
		C_ENV_LOCATION_DEPLOYTYPE=$F_DEFDEPLOYTYPE
	fi
}

function f_env_getcompdeploytypes() {
	local P_DC=$1
	local P_SERVER=$2
	local P_COMPLIST="$3"

	local F_DEFDEPLOYTYPE=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']" -v "@deploytype" $C_ENV_PATH`
	if [ "$F_DEFDEPLOYTYPE" = "" ]; then
		F_DEFDEPLOYTYPE="default"
	fi

	local F_LIST=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/deploy" -v "@component" -o " " -v "@deploytype" -n $C_ENV_PATH`
	local F_LINE
	C_ENV_XMLVALUE=
	for comp in $P_COMPLIST; do
		local F_LINETYPE=`echo "$F_LIST" | grep ^$comp | cut -d " " -f2 | tr -d "\n"`
		if [ "$F_LINETYPE" = "" ]; then
			F_LINETYPE=$F_DEFDEPLOYTYPE
		fi
		if [[ ! " $C_ENV_XMLVALUE " =~ " $F_LINETYPE " ]]; then
			C_ENV_XMLVALUE="$C_ENV_XMLVALUE $F_LINETYPE"
		fi
	done

	C_ENV_XMLVALUE=${C_ENV_XMLVALUE# }
}

function f_env_getdeploytypeinfo() {
	local P_DC=$1
	local P_SERVER=$2
	local P_DEPLOYTYPE=$3

	local F_DEF_DEPLOYTYPE=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']" -v "@deploytype" $C_ENV_PATH`
	if [ "$F_DEF_DEPLOYTYPE" = "" ]; then
		F_DEF_DEPLOYTYPE="default"
	fi

	if [ "$P_DEPLOYTYPE" = "$F_DEF_DEPLOYTYPE" ]; then
		C_ENV_LOCATION_COMPONENT_LIST=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/deploy[@deploytype='$F_DEF_DEPLOYTYPE' or string-length(@deploytype)=0]" -v "@component" -o " " $C_ENV_PATH`
	else
		C_ENV_LOCATION_COMPONENT_LIST=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/deploy[@deploytype='$P_DEPLOYTYPE']" -v "@component" -o " " $C_ENV_PATH`
	fi
}

function f_env_getserverconflist() {
	local P_DC=$1
	local P_SERVER=$2

	C_ENV_SERVER_CONFLIST=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/configure" -v "@component" -o " " $C_ENV_PATH`
}

function f_env_getserverconfinfo() {
	local P_DC=$1
	local P_SERVER=$2
	local P_COMPONENT=$3

	C_ENV_SERVER_COMP_DEPLOYPATH=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/configure[@component='$P_COMPONENT']" -v "@deploypath" $C_ENV_PATH`
	C_ENV_SERVER_COMP_DEPLOYTYPE=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']/configure[@component='$P_COMPONENT']" -v "@deploytype" $C_ENV_PATH`

	if [ "$C_ENV_SERVER_COMP_DEPLOYPATH" = "" ]; then
		echo f_env_getserverconfinfo: server DC=$P_DC, name=$P_SERVER, comp=$P_COMPONENT deploypath attribute not set in $C_ENV_PATH. Exiting
		exit 1
	fi

	if [ "$C_ENV_SERVER_COMP_DEPLOYTYPE" = "" ]; then
		local F_DEFDEPLOYTYPE=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']" -v "@deploytype" $C_ENV_PATH`
		if [ "$F_DEFDEPLOYTYPE" = "" ]; then
			F_DEFDEPLOYTYPE="default"
		fi

		C_ENV_SERVER_COMP_DEPLOYTYPE=$F_DEFDEPLOYTYPE
	fi
}

function f_env_getzerodowntimeinfo() {
	local P_DC=$1

	f_env_getfullxmlline "module/datacenter[@name='$P_DC']/deployment/zerodowntime"

	f_env_getxmllineattr zerodowntime "switch-hostlogin" required
	C_ENV_DEPLOYMENT_SWITCH_HOSTLOGIN=$C_ENV_XMLVALUE

	f_env_getxmllineattr zerodowntime "switch-command" required
	C_ENV_DEPLOYMENT_SWITCH_COMMAND=$C_ENV_XMLVALUE

	f_env_getxmllineattr zerodowntime "switch-confpath" required
	C_ENV_DEPLOYMENT_SWITCH_CONFPATH=$C_ENV_XMLVALUE

	f_env_getxmllineattr zerodowntime "configuration-runfile" required
	C_ENV_DEPLOYMENT_SWITCH_RUNFILE=$C_ENV_XMLVALUE

	f_env_getxmllineattr zerodowntime "configuration-runfirst" required
	C_ENV_DEPLOYMENT_SWITCH_RUNFIRST=$C_ENV_XMLVALUE

	f_env_getxmllineattr zerodowntime "configuration-runsecond" required
	C_ENV_DEPLOYMENT_SWITCH_RUNSECOND=$C_ENV_XMLVALUE

	f_env_getxmllineattr zerodowntime "configuration-runall" required
	C_ENV_DEPLOYMENT_SWITCH_RUNALL=$C_ENV_XMLVALUE
}

function f_env_getsecretpropertylist() {
	# read secret properties...
	if [ "$C_ENV_PROPERTY_SECRETFILE" = "" ]; then
		C_ENV_XMLVALUE=""
		return 0
	fi

	if [ ! -f "$C_ENV_PROPERTY_SECRETFILE" ]; then
		echo "f_env_getsecretpropertylist: unable to find secret property file $C_ENV_PROPERTY_SECRETFILE . Exiting
		exit 1
	fi

	C_ENV_XMLVALUE=`cat $C_ENV_PROPERTY_SECRETFILE | cut -d "=" -f1` | tr "\n" " "`
}

function f_env_getenvpropertylist() {
	# extract from property elements
	C_ENV_XMLVALUE=`xmlstarlet sel -t -m "module/property" -v "@name" -o " " $C_ENV_PATH`
}

function f_env_getdcpropertylist() {
	local P_DC=$1

	# extract from property elements
	C_ENV_XMLVALUE=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/property" -v "@name" -o " " $C_ENV_PATH`
}

function f_env_getserverpropertylist() {
	local P_DC=$1
	local P_SERVER=$2

	# extract from attrs
	C_ENV_XMLVALUE=`xmlstarlet sel -t -c "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']" $C_ENV_PATH | xmlstarlet el -a | grep "server/@" | sed "s/server\/@//g" | tr "\n" " "`
}

function f_env_getsecretpropertyvalue() {
	local P_PROPNAME=$1

	# extract from secret property file
	C_ENV_XMLVALUE=`cat $C_ENV_PROPERTY_SECRETFILE | grep "^$P_PROPNAME=" | cut -d "=" -f2` | tr -d "\n"`
}

function f_env_getenvpropertyvalue() {
	local P_PROPNAME=$1

	# extract from property element
	C_ENV_XMLVALUE=`xmlstarlet sel -t -m "module/property[@name='$P_PROPNAME']" -v "@value" $C_ENV_PATH | xmlstarlet unesc`
}

function f_env_getdcpropertyvalue() {
	local P_DC=$1
	local P_PROPNAME=$2

	# extract from property element
	C_ENV_XMLVALUE=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/property[@name='$P_PROPNAME']" -v "@value" $C_ENV_PATH | xmlstarlet unesc`
}

function f_env_getserverpropertyvalue() {
	local P_DC=$1
	local P_SERVER=$2
	local P_XMLATTRNAME=$3

	C_ENV_XMLVALUE=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/server[@name='$P_SERVER']" -v "@$P_XMLATTRNAME" $C_ENV_PATH | xmlstarlet unesc`
}

function f_env_getstartsequence() {
	local P_DC=$1
	C_ENV_SEQUENCE=`xmlstarlet sel -t -m "module/datacenter[@name='$P_DC']/startorder/startgroup" -v "@name" -o "=" -v "@servers" -o ";" $C_ENV_PATH`
}

function f_env_revertsequence() {
	P_SEQUENCE="$1"
	C_ENV_SEQUENCE=`echo $P_SEQUENCE | tr ';' '\n' | tac | tr '\n' ';'`
}

function f_env_getsequencegroups() {
	local P_SEQUENCE="$1"
	C_ENV_SEQUENCEITEMS=`echo $P_SEQUENCE | tr ';' '\n' | cut -d "=" -f1 | tr '\n' ' '`
}

function f_env_getsequencegroupservers() {
	local P_SEQUENCE="$1"
	local P_GROUP=$2
	C_ENV_SEQUENCEITEMS=`echo $P_SEQUENCE | tr ';' '\n' | grep "$P_GROUP=" | cut -d "=" -f2 | tr -d '\n'`
}

function f_env_selectfilteredserver_deps() {
	local P_DC=$1
	local P_SERVER=$2
	local P_FILTERSERVERS="$3"

	C_ENV_SEQUENCEITEMS=

	f_env_getxmlserverinfo $P_DC $P_SERVER

	if [ "$C_ENV_SERVER_PROXYSERVER" != "" ]; then
		if [[ " $P_FILTERSERVERS " =~ " $C_ENV_SERVER_PROXYSERVER " ]]; then
			C_ENV_SEQUENCEITEMS="$C_ENV_SEQUENCEITEMS $C_ENV_SERVER_PROXYSERVER"
		fi
	fi

	local subserver
	for subserver in $C_ENV_SERVER_SUBORDINATE_SERVERS; do
		if [[ " $P_FILTERSERVERS " =~ " $subserver " ]]; then
			C_ENV_SEQUENCEITEMS="$C_ENV_SEQUENCEITEMS $subserver"
		fi
	done		

	C_ENV_SEQUENCEITEMS=${C_ENV_SEQUENCEITEMS# }
}

function f_env_selectfilteredgroupservers() {
	local P_DC=$1
	local P_GROUPSERVERS="$2"
	local P_FILTERSERVERS="$3"

	local server
	local F_SERVERS=
	for server in $P_GROUPSERVERS; do
		if [[ " $P_FILTERSERVERS " =~ " $server " ]]; then
			# server is included w/o proxy and subordinates
			F_SERVERS="$F_SERVERS $server"
		else
			# check to include server proxy and subordinates instead of server
			f_env_selectfilteredserver_deps $P_DC $server "$P_FILTERSERVERS"
			if [ "$C_ENV_SEQUENCEITEMS" != "" ]; then
				F_SERVERS="$F_SERVERS $C_ENV_SEQUENCEITEMS"
			fi
		fi
	done

	C_ENV_SEQUENCEITEMS=${F_SERVERS# }
}

function f_env_getfilteredsequence() {
	local P_DC=$1
	local P_SEQUENCE="$2"
	local P_FILTERSERVERS="$3"

	f_env_getsequencegroups "$P_SEQUENCE"
	local F_GROUPLIST="$C_ENV_SEQUENCEITEMS"

	local F_GROUPSERVERS
	C_ENV_SEQUENCE=
	for group in $F_GROUPLIST; do
		f_env_getsequencegroupservers "$P_SEQUENCE" $group
		F_GROUPSERVERS="$C_ENV_SEQUENCEITEMS"

		f_env_selectfilteredgroupservers $P_DC "$F_GROUPSERVERS" "$P_FILTERSERVERS"
		F_USESERVERS="$C_ENV_SEQUENCEITEMS"
		if [ "$F_USESERVERS" != "" ]; then
			C_ENV_SEQUENCE="$C_ENV_SEQUENCE$group=$F_USESERVERS;"
		fi
	done
}

