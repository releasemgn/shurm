#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

# parsing source.xml

C_SOURCE_XMLFILE=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/source.xml

C_SOURCE_PROJECT=
C_SOURCE_PROJECTLIST=
C_SOURCE_ITEMLIST=
C_SOURCE_PROJECT_MVNCMD=
C_SOURCE_PROJECT_DISTITEM=
C_SOURCE_PROJECT_DISTLIBITEM=

C_SOURCE_VCS=
C_SOURCE_VERSION=
C_SOURCE_GROUP=
C_SOURCE_PATH=
C_SOURCE_JIRA=
C_SOURCE_BRANCH=
C_SOURCE_JAVAVERSION=
C_SOURCE_MAVENVERSION=

C_SOURCE_XMLLINE=
C_SOURCE_XMLLINEATTR=

C_SOURCE_ITEMNAME=
C_SOURCE_ITEMBASENAME=
C_SOURCE_ITEMTYPE=
C_SOURCE_ITEMEXTENSION=
C_SOURCE_ITEMPATH=
C_SOURCE_ITEMVERSION=
C_SOURCE_ITEMSTATICEXTENSION=
C_SOURCE_ITEMFOLDER=

function f_source_getxmlline() {
	local P_XPATH=$1
	local P_NAMEVALUE=$2
	C_SOURCE_XMLLINE=`xmlstarlet sel -t -c "$P_XPATH[@name='$P_NAMEVALUE']" $C_SOURCE_XMLFILE`

	if [ "$C_SOURCE_XMLLINE" = "" ]; then
		C_SOURCE_XMLLINEATTR=
		return 1
	fi

	return 0
}

function f_source_getxmllineattr() {
	local P_XMLELNAME=$1
	local P_XMLATTRNAME=$2

	C_SOURCE_XMLLINEATTR=`echo $C_SOURCE_XMLLINE | xmlstarlet sel -t -m "$P_XMLELNAME" -v "@$P_XMLATTRNAME"`
}

function f_source_readproject() {
	local P_PROJECTSET=$1
	local P_SOURCE_PROJECT=$2

	C_SOURCE_PROJECT=$P_SOURCE_PROJECT
	C_SOURCE_VCS=
	C_SOURCE_VERSION=
	C_SOURCE_GROUP=
	C_SOURCE_PATH=
	C_SOURCE_JIRA=
	C_SOURCE_BRANCH=
	C_SOURCE_JAVAVERSION=
	C_SOURCE_MAVENVERSION=
	C_SOURCE_PROJECT_MVNCMD=
	C_SOURCE_PROJECT_DISTITEM=
	C_SOURCE_PROJECT_DISTLIBITEM=

	if [ "$P_PROJECTSET" = "" ] || [ "$P_SOURCE_PROJECT" = "" ]; then
		echo f_source_readproject: invalid call. Exiting
		exit 1
	fi

	f_source_getxmlline "source/projectset[@type='$P_PROJECTSET']/project" $P_SOURCE_PROJECT
	if [ $? -ne 0 ]; then
		echo f_source_readproject: source project $P_SOURCE_PROJECT not found in $C_SOURCE_XMLFILE. Exiting
		exit 1
	fi

	# read item attrs
	f_source_getxmllineattr project vcs
	C_SOURCE_VCS=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr project version
	C_SOURCE_VERSION=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr project group
	C_SOURCE_GROUP=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr project path
	C_SOURCE_PATH=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr project jira
	C_SOURCE_JIRA=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr project branch
	C_SOURCE_BRANCH=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr project javaversion
	C_SOURCE_JAVAVERSION=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr project mavenversion
	C_SOURCE_MAVENVERSION=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr project mvncmd
	C_SOURCE_PROJECT_MVNCMD=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr project distitem
	C_SOURCE_PROJECT_DISTITEM=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr project distlibitem
	C_SOURCE_PROJECT_DISTLIBITEM=$C_SOURCE_XMLLINEATTR
	if [ "$C_SOURCE_PROJECT_DISTLIBITEM" = "" ]; then
		C_SOURCE_PROJECT_DISTLIBITEM=$P_SOURCE_PROJECT-lib
	fi

	if [ "$C_SOURCE_BRANCH" = "" ]; then
		C_SOURCE_BRANCH=${P_SOURCE_PROJECT}-prod
	fi
}

function f_source_projectlist() {
	local P_PROJECTSET=$1

	# obtain project list by version mode
	local F_SOURCE_VERSIONMASK=
	if [ "$VERSION_MODE" = "branch" ]; then
		F_SOURCE_VERSIONMASK="[@version='branch']"
	fi
	if [ "$VERSION_MODE" = "majorbranch" ]; then
		F_SOURCE_VERSIONMASK="[@version='branch' or @version='majorbranch']"
	fi

	C_SOURCE_PROJECTLIST=`xmlstarlet sel -t -m "source/projectset[@type='$P_PROJECTSET']/project$F_SOURCE_VERSIONMASK" -v "@name" -o " " $C_SOURCE_XMLFILE`
}

function f_source_projectitemlist() {
	local P_PROJECTSET=$1
	local P_SOURCE_PROJECT=$2

	C_SOURCE_ITEMLIST=`xmlstarlet sel -t -m "source/projectset[@type='$P_PROJECTSET']/project[@name='$P_SOURCE_PROJECT']/distitem" -v "@name" -o " " $C_SOURCE_XMLFILE`
}

function f_source_readdistitem() {
	local P_PROJECTSET=$1
	local P_SOURCE_PROJECT=$2
	local P_DISTITEM=$3

	C_SOURCE_ITEMNAME=
	C_SOURCE_ITEMBASENAME=
	C_SOURCE_ITEMTYPE=
	C_SOURCE_ITEMEXTENSION=
	C_SOURCE_ITEMPATH=
	C_SOURCE_ITEMVERSION=
	C_SOURCE_ITEMSTATICEXTENSION=
	C_SOURCE_ITEMFOLDER=

	if [ "$P_PROJECTSET" = "" ] || [ "$P_SOURCE_PROJECT" = "" ] || [ "$P_DISTITEM" = "" ]; then
		echo f_source_readdistitem: invalid call. Exiting
		exit 1
	fi

	f_source_getxmlline "source/projectset[@type='$P_PROJECTSET']/project[@name='$P_SOURCE_PROJECT']/distitem" $P_DISTITEM
	if [ $? -ne 0 ]; then
		echo f_source_readdistitem: source project item $P_DISTITEM not found in $C_SOURCE_XMLFILE. Exiting
		exit 1
	fi

	C_SOURCE_ITEMNAME=$P_DISTITEM

	# read item attrs
	f_source_getxmllineattr distitem type
	C_SOURCE_ITEMTYPE=$C_SOURCE_XMLLINEATTR
	f_source_getxmllineattr distitem basename
	C_SOURCE_ITEMBASENAME=$C_SOURCE_XMLLINEATTR
	if [ "$C_SOURCE_ITEMBASENAME" = "" ]; then
		C_SOURCE_ITEMBASENAME=$C_SOURCE_ITEMNAME
	fi

	f_source_getxmllineattr distitem extension
	C_SOURCE_ITEMEXTENSION=$C_SOURCE_XMLLINEATTR

	if [ "$C_SOURCE_ITEMTYPE" != "generated" ]; then
		f_source_getxmllineattr distitem path
		C_SOURCE_ITEMPATH=$C_SOURCE_XMLLINEATTR
		f_source_getxmllineattr distitem version
		C_SOURCE_ITEMVERSION=$C_SOURCE_XMLLINEATTR
	fi

	if [ "$C_SOURCE_ITEMTYPE" = "staticwar" ]; then
		f_source_getxmllineattr distitem staticextension
		C_SOURCE_ITEMSTATICEXTENSION=$C_SOURCE_XMLLINEATTR

		if [ "$C_SOURCE_ITEMSTATICEXTENSION" = "" ]; then
			C_SOURCE_ITEMSTATICEXTENSION="-webstatic.tar.gz"
		fi
	fi

	f_source_getxmllineattr distitem folder
	C_SOURCE_ITEMFOLDER=$C_SOURCE_XMLLINEATTR
}
