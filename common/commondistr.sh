#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

C_DISTR_XMLFILE=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/distr.xml

C_DISTR_KEY=
C_DISTR_OBSOLETE=
C_DISTR_EXT=
C_DISTR_TYPE=
C_DISTR_OPTIONS=
C_DISTR_DISTBASENAME=
C_DISTR_DISTFOLDER=
C_DISTR_DEPLOYBASENAME=
C_DISTR_WAR_MRID=
C_DISTR_WAR_CONTEXT=
C_DISTR_WAR_STATICEXT=
C_DISTR_BUILDINFO=

C_DISTR_XMLLINE=
C_DISTR_XMLLINEATTR=

C_DISTR_COMPLIST=
C_DISTR_OBSOLETECOMPLIST=
C_DISTR_ITEMS=
C_DISTR_OBSOLETE_ITEMS=

C_DISTR_CONF_COMPLIST=
C_DISTR_CONF_OBSOLETECOMPLIST=
C_DISTR_CONF_KEY=
C_DISTR_CONF_SUBDIR=
C_DISTR_CONF_TYPE=
C_DISTR_CONF_FILES=
C_DISTR_CONF_EXCLUDE=
C_DISTR_CONF_LAYER=

C_DISTR_WSITEMS=
C_DISTR_WSOBSOLETE_ITEMS=

C_DISTR_THIRDPARTYLIST=
C_DISTR_OBSOLETETHIRDPARTYLIST=

C_DISTR_THIRDPARTY_KEY=
C_DISTR_THIRDPARTY_TYPE=
C_DISTR_THIRDPARTY_NEXUSPATH=

function f_distr_getxmlline() {
	local P_XPATH=$1
	local P_NAMEVALUE=$2
	C_DISTR_XMLLINE=`xmlstarlet sel -t -c "$P_XPATH[@name='$P_NAMEVALUE']" $C_DISTR_XMLFILE`

	if [ "$C_DISTR_XMLLINE" = "" ]; then
		C_DISTR_XMLLINEATTR=
		return 1
	fi

	return 0
}

function f_distr_getxmllineattr() {
	local P_XMLELNAME=$1
	local P_XMLATTRNAME=$2

	C_DISTR_XMLLINEATTR=`echo $C_DISTR_XMLLINE | xmlstarlet sel -t -m "$P_XMLELNAME" -v "@$P_XMLATTRNAME"`
}

function f_distr_readitem() {
	local P_KEY=$1
	local P_RETURN_IF_NOT_FOUND=$2

	C_DISTR_KEY=$P_KEY
	C_DISTR_OBSOLETE=
	C_DISTR_EXT=
	C_DISTR_TYPE=
	C_DISTR_OPTIONS=
	C_DISTR_DISTBASENAME=
	C_DISTR_DISTFOLDER=
	C_DISTR_DEPLOYBASENAME=
	C_DISTR_WAR_MRID=
	C_DISTR_WAR_CONTEXT=
	C_DISTR_WAR_STATICEXT=
	C_DISTR_BUILDINFO=

	if [ "$P_KEY" = "" ]; then
		echo f_distr_readitem: invalid call. Exiting
		exit 1
	fi

	f_distr_getxmlline "module/distributive/binary-list/distitem" $C_DISTR_KEY
	if [ $? -ne 0 ]; then
		if [ -z $P_RETURN_IF_NOT_FOUND ]; then
			echo f_distr_readitem: distribution item $C_DISTR_KEY not found in distr.xml. Exiting
			exit 1
		else	
			echo f_distr_readitem: distribution item $C_DISTR_KEY not found in distr.xml
			return 1
		fi
	fi

	# read items
	f_distr_getxmllineattr distitem type
	C_DISTR_TYPE=$C_DISTR_XMLLINEATTR

	f_distr_getxmllineattr distitem obsolete
	C_DISTR_OBSOLETE=$C_DISTR_XMLLINEATTR

	f_distr_getxmllineattr distitem distname
	C_DISTR_DISTBASENAME=$C_DISTR_XMLLINEATTR
	if [ "$C_DISTR_DISTBASENAME" = "" ]; then
		C_DISTR_DISTBASENAME=$C_DISTR_KEY
	fi

	f_distr_getxmllineattr distitem folder
	C_DISTR_DISTFOLDER=$C_DISTR_XMLLINEATTR

	f_distr_getxmllineattr distitem buildinfo
	C_DISTR_BUILDINFO=$C_DISTR_XMLLINEATTR

	f_distr_getxmllineattr distitem deployname
	C_DISTR_DEPLOYBASENAME=$C_DISTR_XMLLINEATTR
	if [ "$C_DISTR_DEPLOYBASENAME" = "" ]; then
		C_DISTR_DEPLOYBASENAME=$C_DISTR_DISTBASENAME
	fi

	f_distr_getxmllineattr distitem options
	C_DISTR_OPTIONS=$C_DISTR_XMLLINEATTR
		
	# binary item
	if [ "$C_DISTR_TYPE" = "binary" ]; then
		f_distr_getxmllineattr distitem extension
		C_DISTR_EXT=$C_DISTR_XMLLINEATTR
		if [ "$C_DISTR_EXT" = "" ]; then
			echo f_distr_readitem: invalid line in distr.xml for distribution item $C_DISTR_KEY. Exiting
			exit 1
		fi

		return 0
	fi

	# war item and static
	if [ "$C_DISTR_TYPE" = "war" ] || [ "$C_DISTR_TYPE" = "pguwar" ]; then
		C_DISTR_EXT=".war"

		f_distr_getxmllineattr distitem mrid
		C_DISTR_WAR_MRID=$C_DISTR_XMLLINEATTR

		f_distr_getxmllineattr distitem context
		C_DISTR_WAR_CONTEXT=$C_DISTR_XMLLINEATTR
		if [ "$C_DISTR_WAR_CONTEXT" = "" ]; then
			C_DISTR_WAR_CONTEXT=$C_DISTR_DEPLOYBASENAME
		fi

		f_distr_getxmllineattr distitem extension
		C_DISTR_WAR_STATICEXT=$C_DISTR_XMLLINEATTR
		if [ "$C_DISTR_WAR_STATICEXT" = "" ]; then
			C_DISTR_WAR_STATICEXT="-webstatic.tar.gz"
		fi
		
		return 0
	fi

	# archive item
	if [ "$C_DISTR_TYPE" = "archive.direct" ] || [ "$C_DISTR_TYPE" = "archive.child" ] || [ "$C_DISTR_TYPE" = "archive.subdir" ]; then
		f_distr_getxmllineattr distitem extension
		C_DISTR_EXT=$C_DISTR_XMLLINEATTR
		if [ "$C_DISTR_EXT" = "" ]; then
			C_DISTR_EXT=".tar.gz"
		fi

		return 0
	fi

	echo f_distr_readitem: distribution item $C_DISTR_KEY has unknown type. Exiting
	exit 1
}

function f_dist_getcomplist() {
	if [ "$GETOPT_OBSOLETE" = "yes" ]; then
		if [ "$GETOPT_UNIT" = "" ]; then
			C_DISTR_COMPLIST=`xmlstarlet sel -t -m "module/deployment-binaries/component[string-length(@obsolete)=0 or @obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
		else
			C_DISTR_COMPLIST=`xmlstarlet sel -t -m "module/deployment-binaries/component[@unit='$GETOPT_UNIT' and (string-length(@obsolete)=0 or @obsolete='true')]" -v "@name" -o " " $C_DISTR_XMLFILE`
		fi
		C_DISTR_OBSOLETECOMPLIST=
	else
		if [ "$P_UNIT" = "" ]; then
			C_DISTR_COMPLIST=`xmlstarlet sel -t -m "module/deployment-binaries/component[string-length(@obsolete)=0 or @obsolete='false']" -v "@name" -o " " $C_DISTR_XMLFILE`
			C_DISTR_OBSOLETECOMPLIST=`xmlstarlet sel -t -m "module/deployment-binaries/component[@obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
		else
			C_DISTR_COMPLIST=`xmlstarlet sel -t -m "module/deployment-binaries/component[@unit='$GETOPT_UNIT' and (string-length(@obsolete)=0 or @obsolete='false')]" -v "@name" -o " " $C_DISTR_XMLFILE`
			C_DISTR_OBSOLETECOMPLIST=`xmlstarlet sel -t -m "module/deployment-binaries/component[@unit='$GETOPT_UNIT' and @obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
		fi
	fi
}

function f_distr_getconfcomplist() {
	if [ "$GETOPT_OBSOLETE" = "yes" ]; then
		if [ "$GETOPT_UNIT" = "" ]; then
			C_DISTR_CONF_COMPLIST=`xmlstarlet sel -t -m "module/distributive/configuration/component[string-length(@obsolete)=0 or @obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
		else
			C_DISTR_CONF_COMPLIST=`xmlstarlet sel -t -m "module/distributive/configuration/component[@unit='$GETOPT_UNIT' and (string-length(@obsolete)=0 or @obsolete='true')]" -v "@name" -o " " $C_DISTR_XMLFILE`
		fi
		C_DISTR_CONF_OBSOLETECOMPLIST=
	else
		if [ "$GETOPT_UNIT" = "" ]; then
			C_DISTR_CONF_COMPLIST=`xmlstarlet sel -t -m "module/distributive/configuration/component[string-length(@obsolete)=0 or @obsolete='false']" -v "@name" -o " " $C_DISTR_XMLFILE`
			C_DISTR_CONF_OBSOLETECOMPLIST=`xmlstarlet sel -t -m "module/distributive/configuration/component[@obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
		else
			C_DISTR_CONF_COMPLIST=`xmlstarlet sel -t -m "module/distributive/configuration/component[@unit='$GETOPT_UNIT' and (string-length(@obsolete)=0 or @obsolete='false')]" -v "@name" -o " " $C_DISTR_XMLFILE`
			C_DISTR_CONF_OBSOLETECOMPLIST=`xmlstarlet sel -t -m "module/distributive/configuration/component[@unit='$GETOPT_UNIT' and @obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
		fi
	fi
}

function f_distr_getcomponentitems() {
	local P_COMPONENT=$1
	if [ "$GETOPT_OBSOLETE" = "yes" ]; then
		C_DISTR_ITEMS=`xmlstarlet sel -t -m "module/deployment-binaries/component[@name='$P_COMPONENT']/distitem[string-length(@obsolete)=0 or @obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
		C_DISTR_OBSOLETE_ITEMS=
	else
		C_DISTR_ITEMS=`xmlstarlet sel -t -m "module/deployment-binaries/component[@name='$P_COMPONENT']/distitem[string-length(@obsolete)=0 or @obsolete='false']" -v "@name" -o " " $C_DISTR_XMLFILE`
		C_DISTR_OBSOLETE_ITEMS=`xmlstarlet sel -t -m "module/deployment-binaries/component[@name='$P_COMPONENT']/distitem[@obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
	fi
}

function f_distr_getcomplistitems() {
	local P_COMPLIST="$1"

	local F_DISTR_ITEMS=
	local F_DISTR_OBSOLETE_ITEMS=
	local comp
	for comp in $P_COMPLIST; do
		f_distr_getcomponentitems $comp
		F_DISTR_ITEMS="$F_DISTR_ITEMS $C_DISTR_ITEMS"
		F_DISTR_OBSOLETE_ITEMS="$F_DISTR_OBSOLETE_ITEMS $C_DISTR_OBSOLETE_ITEMS"
	done

	C_DISTR_ITEMS=`echo $F_DISTR_ITEMS | tr ' ' '\n' | sort -u | tr '\n' ' '`
	C_DISTR_OBSOLETE_ITEMS=`echo $F_DISTR_OBSOLETE_ITEMS | tr ' ' '\n' | sort -u | tr '\n' ' '`
}

function f_distr_getcomplistitems_bytype() {
	local P_COMPLIST="$1"
	local P_TYPELIST="$2"

	f_distr_getcomplistitems "$P_COMPLIST"
	local F_DISTR_ITEMS=$C_DISTR_ITEMS
	local F_DISTR_OBSOLETE_ITEMS=$C_DISTR_OBSOLETE_ITEMS

	C_DISTR_ITEMS=
	C_DISTR_OBSOLETE_ITEMS=
	local distitem
	local F_DISTR_TYPE
	for distitem in $F_DISTR_ITEMS; do
		F_DISTR_TYPE=`xmlstarlet sel -t -m "module/distributive/binary-list/distitem[@name='$distitem']" -v "@type" $C_DISTR_XMLFILE`
		if [[ " $P_TYPELIST " =~ " $F_DISTR_TYPE " ]]; then
			C_DISTR_ITEMS="$C_DISTR_ITEMS $distitem"
		fi
	done

	for distitem in $F_DISTR_OBSOLETE_ITEMS; do
		F_DISTR_TYPE=`xmlstarlet sel -t -m "module/distributive/binary-list/distitem[@name='$distitem']" -v "@type" $C_DISTR_XMLFILE`
		if [[ " $P_TYPELIST " =~ " $F_DISTR_TYPE " ]]; then
			C_DISTR_OBSOLETE_ITEMS="$C_DISTR_OBSOLETE_ITEMS $distitem"
		fi
	done
}

function f_distr_getconfcompinfo() {
	local P_COMPONENT="$1"

	C_DISTR_CONF_KEY=$P_COMPONENT

	f_distr_getxmlline "module/distributive/configuration/component" $C_DISTR_CONF_KEY
	if [ $? -ne 0 ]; then
		echo f_distr_getconfcompinfo: configuration item $C_DISTR_CONF_KEY not found in distr.xml. Exiting
		exit 1
	fi

	C_DISTR_CONF_TYPE=
	C_DISTR_CONF_SUBDIR=
	C_DISTR_CONF_LAYER=
	C_DISTR_CONF_FILES=
	C_DISTR_CONF_EXCLUDE=

	# read items
	f_distr_getxmllineattr component type
	C_DISTR_CONF_TYPE=$C_DISTR_XMLLINEATTR

	f_distr_getxmllineattr component subdir
	C_DISTR_CONF_SUBDIR=$C_DISTR_XMLLINEATTR

	f_distr_getxmllineattr component layer
	C_DISTR_CONF_LAYER=$C_DISTR_XMLLINEATTR

	if [ "$C_DISTR_CONF_TYPE" = "" ] || [ "$C_DISTR_CONF_LAYER" = "" ]; then
		echo f_distr_getconfcompinfo: invalid line in distr.xml for configuration component $P_COMPONENT. Exiting
		exit 1
	fi

	if [ "$C_DISTR_CONF_TYPE" = "mixed-dir" ] || [ "$C_DISTR_CONF_TYPE" = "files" ]; then
		f_distr_getxmllineattr component files
		C_DISTR_CONF_FILES=$C_DISTR_XMLLINEATTR
	fi

	f_distr_getxmllineattr component exclude
	C_DISTR_CONF_EXCLUDE=$C_DISTR_XMLLINEATTR

	f_distr_getxmllineattr component obsolete
	C_DISTR_OBSOLETE=$C_DISTR_XMLLINEATTR
}

function f_distr_getcomponentwebservices() {
	local P_COMPONENT=$1
	if [ "$GETOPT_OBSOLETE" = "yes" ]; then
		C_DISTR_WSITEMS=`xmlstarlet sel -t -m "module/deployment-binaries/component[@name='$P_COMPONENT']/webservice[string-length(@obsolete)=0 or @obsolete='true']" -v "@url" -o " " $C_DISTR_XMLFILE`
		C_DISTR_WSOBSOLETE_ITEMS=
	else
		C_DISTR_WSITEMS=`xmlstarlet sel -t -m "module/deployment-binaries/component[@name='$P_COMPONENT']/webservice[string-length(@obsolete)=0 or @obsolete='false']" -v "@url" -o " " $C_DISTR_XMLFILE`
		C_DISTR_WSOBSOLETE_ITEMS=`xmlstarlet sel -t -m "module/deployment-binaries/component[@name='$P_COMPONENT']/webservice[@obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
	fi
}

function f_distr_getthirdpartylist() {
	if [ "$GETOPT_OBSOLETE" = "yes" ]; then
		C_DISTR_THIRDPARTYLIST=`xmlstarlet sel -t -m "module/distributive/thirdparty/distitem[string-length(@obsolete)=0 or @obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
		C_DISTR_OBSOLETETHIRDPARTYLIST=
	else
		C_DISTR_THIRDPARTYLIST=`xmlstarlet sel -t -m "module/distributive/thirdparty/distitem[string-length(@obsolete)=0 or @obsolete='false']" -v "@name" -o " " $C_DISTR_XMLFILE`
		C_DISTR_OBSOLETETHIRDPARTYLIST=`xmlstarlet sel -t -m "module/distributive/thirdparty/distitem[@obsolete='true']" -v "@name" -o " " $C_DISTR_XMLFILE`
	fi
}

function f_distr_getthirdpartyiteminfo() {
	local P_TPITEM="$1"

	C_DISTR_THIRDPARTY_KEY=$P_TPITEM

	f_distr_getxmlline "module/distributive/thirdparty/distitem" $C_DISTR_THIRDPARTY_KEY
	if [ $? -ne 0 ]; then
		echo f_distr_getthirdpartyiteminfo: configuration item $C_DISTR_THIRDPARTY_KEY not found in distr.xml. Exiting
		exit 1
	fi

	# read items
	f_distr_getxmllineattr distitem type
	C_DISTR_THIRDPARTY_TYPE=$C_DISTR_XMLLINEATTR

	f_distr_getxmllineattr distitem nexuspath
	C_DISTR_THIRDPARTY_NEXUSPATH=$C_DISTR_XMLLINEATTR
}
