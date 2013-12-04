#!/bin/sh

if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

#############################################################
# product identification
C_CONFIG_PRODUCT=myproduct
C_CONFIG_PRODUCT_DEPLOYMENT_HOME=$MYPRODUCT_DEPLOYMENT_HOME
C_CONFIG_REDISTPATH=/var/redist

#
#############################################################
#############################################################
# product parameters

C_CONFIG_ADM_JIRA=MYPRODUCT
C_CONFIG_COMMIT_JIRALIST="$C_CONFIG_ADM_JIRA"
C_CONFIG_JAVA_VERSION=jdk1.6.0_29
C_CONFIG_MAVEN_VERSION=2.2.1
C_CONFIG_MAVEN_ADDITIONAL_OPTIONS="-Dfile.encoding=UTF-8"
C_CONFIG_MAVEN_PROFILES="all-components,all-modules"
C_CONFIG_MODULE_BUILD_OPTIONS_CORE="-Mc"
C_CONFIG_MODULE_BUILD_OPTIONS_WAR=notused

C_CONFIG_SCHEMAADMIN=myproductadm
C_CONFIG_SCHEMAADMIN_RELEASES=admindb_releases
C_CONFIG_SCHEMAADMIN_SCRIPTS=admindb_scripts
C_CONFIG_SCHEMAFEDLIST="$C_CONFIG_SCHEMAADMIN users operations"
C_CONFIG_SCHEMAREGLIST=""
C_CONFIG_SCHEMAALLLIST="$C_CONFIG_SCHEMAFEDLIST $C_CONFIG_SCHEMAREGLIST"

C_CONFIG_USE_TEMPLATES=yes
C_CONFIG_USE_WAR=no

#
#############################################################
#############################################################
# not subject to change - usually the same for any product

C_CONFIG_NEXUS_BASE=http://nexus_host_port/nexus
C_CONFIG_NEXUS_PATH_THIRDPARTY=$C_CONFIG_NEXUS_BASE/content/repositories/thirdparty

C_CONFIG_SVNOLD_PATH=http://svn_host_port/svn
C_CONFIG_SVNNEW_PATH=http://svn_host_port/svn

if [ -f $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/.auth/svnold.auth.txt ]; then
	C_CONFIG_SVNOLD_AUTH=`cat $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/.auth/svnold.auth.txt | tr -d "\n"`
else
	if [ -f ~/.auth/svnold.auth.txt ]; then
		C_CONFIG_SVNOLD_AUTH=`cat ~/.auth/svnold.auth.txt | tr -d "\n"`
	else
		C_CONFIG_SVNOLD_AUTH=
	fi
fi

if [ -f $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/.auth/svnnew.auth.txt ]; then
	C_CONFIG_SVNNEW_AUTH=`cat $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/.auth/svnnew.auth.txt | tr -d "\n"`
else
	if [ -f ~/.auth/svnnew.auth.txt ]; then
		C_CONFIG_SVNNEW_AUTH=`cat ~/.auth/svnnew.auth.txt | tr -d "\n"`
	else
		C_CONFIG_SVNNEW_AUTH=
	fi
fi

C_CONFIG_GITMIRRORPATH=~/build/git

C_CONFIG_ARTEFACTDIR=~/build/artefacts/$C_CONFIG_PRODUCT
C_CONFIG_DISTR_PATH=~/distr/$C_CONFIG_PRODUCT
C_CONFIG_SOURCE_RELEASEROOTDIR=$C_CONFIG_SVNOLD_PATH/releases/$C_CONFIG_PRODUCT/changes
C_CONFIG_SOURCE_CFG_ROOTDIR=$C_CONFIG_SVNOLD_PATH/releases/$C_CONFIG_PRODUCT/configuration
C_CONFIG_SOURCE_CFG_LIVEROOTDIR=$C_CONFIG_SVNOLD_PATH/releases/$C_CONFIG_PRODUCT/configuration/live
C_CONFIG_SOURCE_SQL_GLOBALPENDING=$C_CONFIG_SVNOLD_PATH/releases/$C_CONFIG_PRODUCT/database

#
#############################################################
#############################################################
# release numbering and release folders

C_CONFIG_VERSION_BRANCH_MAJOR=1
C_CONFIG_VERSION_BRANCH_MINOR=7
C_CONFIG_VERSIONBRANCH=$C_CONFIG_VERSION_BRANCH_MAJOR.$C_CONFIG_VERSION_BRANCH_MINOR
C_CONFIG_VERSION_BRANCH_NEXTMINOR=`expr $C_CONFIG_VERSION_BRANCH_MINOR + 1`

C_CONFIG_RELEASE_GROUPFOLDER=R_${C_CONFIG_VERSION_BRANCH_MAJOR}_${C_CONFIG_VERSION_BRANCH_NEXTMINOR}
C_CONFIG_NEXT_MAJORRELEASE=$C_CONFIG_VERSION_BRANCH_MAJOR.$C_CONFIG_VERSION_BRANCH_NEXTMINOR

C_CONFIG_LAST_VERSION_BUILD=$LAST_PROD_TAG
C_CONFIG_NEXT_VERSION_BUILD=`expr $C_CONFIG_LAST_VERSION_BUILD + 1`

C_CONFIG_VERSION_LAST_FULL=$C_CONFIG_VERSIONBRANCH.$C_CONFIG_LAST_VERSION_BUILD
C_CONFIG_VERSION_NEXT_FULL=$C_CONFIG_VERSIONBRANCH.$C_CONFIG_NEXT_VERSION_BUILD

#
#############################################################
#############################################################
# defined by version mode

C_CONFIG_APPVERSION=
C_CONFIG_APPVERSION_TAG=
C_CONFIG_BRANCHNAME=
C_CONFIG_MAVEN_CFGFILE=
C_CONFIG_NEXUS_REPO=
C_CONFIG_PROD_TAG=
C_CONFIG_APPVERSION_RELEASEFOLDER=

if [ "$VERSION_MODE" = "dev" ]; then
	C_CONFIG_APPVERSION=$C_CONFIG_NEXT_MAJORRELEASE-SNAPSHOT
	C_CONFIG_APPVERSION_TAG=prod-major
	C_CONFIG_BRANCHNAME=trunk
	C_CONFIG_MAVEN_CFGFILE=~/.m2/settings.dev.xml
	C_CONFIG_NEXUS_REPO=snapshots
	C_CONFIG_PROD_TAG=
	C_CONFIG_APPVERSION_RELEASEFOLDER=major-release-$C_CONFIG_NEXT_MAJORRELEASE

elif [ "$VERSION_MODE" = "trunk" ]; then
	C_CONFIG_APPVERSION=$C_CONFIG_NEXT_MAJORRELEASE-SNAPSHOT
	C_CONFIG_APPVERSION_TAG=prod-major
	C_CONFIG_BRANCHNAME=trunk
	C_CONFIG_MAVEN_CFGFILE=~/.m2/settings.trunk.xml
	C_CONFIG_NEXUS_REPO=builder-trunk
	C_CONFIG_PROD_TAG=
	C_CONFIG_APPVERSION_RELEASEFOLDER=major-release-$C_CONFIG_NEXT_MAJORRELEASE

elif [ "$VERSION_MODE" = "majorbranch" ]; then
	C_CONFIG_APPVERSION=$C_CONFIG_NEXT_MAJORRELEASE
	C_CONFIG_APPVERSION_TAG=prod-major
	C_CONFIG_BRANCHNAME=prod-major
	C_CONFIG_MAVEN_CFGFILE=~/.m2/settings.major.xml
	C_CONFIG_NEXUS_REPO=builder-majorbranch
	C_CONFIG_PROD_TAG=
	C_CONFIG_APPVERSION_RELEASEFOLDER=major-release-$C_CONFIG_NEXT_MAJORRELEASE

elif [ "$VERSION_MODE" = "branch" ]; then
	C_CONFIG_APPVERSION=$C_CONFIG_VERSIONBRANCH
	C_CONFIG_APPVERSION_TAG=prod-$C_CONFIG_VERSIONBRANCH.$C_CONFIG_NEXT_VERSION_BUILD-candidate
	C_CONFIG_BRANCHNAME=
	C_CONFIG_MAVEN_CFGFILE=~/.m2/settings.branch.xml
	C_CONFIG_NEXUS_REPO=builder-branch
	C_CONFIG_PROD_TAG=prod-$C_CONFIG_VERSIONBRANCH.$C_CONFIG_LAST_VERSION_BUILD
	C_CONFIG_APPVERSION_RELEASEFOLDER=prod-patch-$C_CONFIG_VERSIONBRANCH.$C_CONFIG_NEXT_VERSION_BUILD
fi

if [ "$GETOPT_BRANCH" != "" ]; then
	C_CONFIG_BRANCHNAME=$GETOPT_BRANCH
fi

C_CONFIG_APPVERSION_SERVICES=notused

#
#############################################################
