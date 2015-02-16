#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

P_PATCHPATH=$1
P_MODULESET=$2
P_MODULENAME=$3
P_TAG=$4
P_NEXUS_PATH=$5
P_VERSION=$6

# check params
if [ "$P_PATCHPATH" = "" ]; then
	echo patch-build.sh: P_PATCHPATH not set
	exit 1
fi
if [ "$P_MODULESET" = "" ]; then
	echo patch-build.sh: P_MODULESET not set
	exit 1
fi
if [ "$P_MODULENAME" = "" ]; then
	echo patch-build.sh: P_MODULENAME not set
	exit 1
fi
if [ "$P_TAG" = "" ]; then
	echo patch-build.sh: P_TAG not set
	exit 1
fi
if [ "$P_NEXUS_PATH" = "" ]; then
	echo patch-build.sh: P_NEXUS_PATH not set
	exit 1
fi
if [ "$P_VERSION" = "" ]; then
	echo patch-build.sh: P_VERSION not set
	exit 1
fi

# execute

. ./common.sh

function f_build_uploadstatus() {
	local MODULE_PROJECT_NAME=$P_MODULENAME
	local MODULE_ALT_REPO="-DaltDeploymentRepository=nexus2::default::$P_NEXUS_PATH"
	local MODULE_MSETTINGS="--settings=$C_CONFIG_MAVEN_CFGFILE"

	local UPLOAD_MAVEN_VERSION=$C_CONFIG_MAVEN_VERSION

	export M2_HOME=/usr/local/apache-maven-$C_CONFIG_MAVEN_VERSION
	export M2=$M2_HOME/bin
	export PATH="$M2:$PATH"
	export MAVEN_OPTS="-Xmx1g -XX:MaxPermSize=300m -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled"

	# upload versioninfo
	echo $P_TAG > versioninfo.txt
	mvn deploy:deploy-file \
		$MODULE_MSETTINGS \
		-Durl=$P_NEXUS_PATH \
		-DuniqueVersion=false \
	        -Dversion=$P_VERSION \
		-DgroupId=release \
		-DartifactId=$MODULE_PROJECT_NAME \
		-Dfile=versioninfo.txt \
		-Dpackaging=txt \
		-Dclassifier=version \
		-DgeneratePom=true \
		-DrepositoryId=nexus2

	rm -rf versioninfo.txt
}

function f_build_maven() {
	# maven params
	local MODULE_PROJECT_NAME=$P_MODULENAME
	local MODULE_MAVEN_PROFILES=$C_CONFIG_MAVEN_PROFILES
	if [ "$MODULEOPTIONS_COMPACT_STATIC" = "true" ]; then
		if [ "$MODULE_MAVEN_PROFILES" != "" ]; then
			MODULE_MAVEN_PROFILES="${MODULE_MAVEN_PROFILES},without-statics,without-jars"
		else
			MODULE_MAVEN_PROFILES="without-statics,without-jars"
		fi
	fi

	local MODULE_ALT_REPO="-DaltDeploymentRepository=nexus2::default::$P_NEXUS_PATH"
	local MODULE_MSETTINGS="--settings=$C_CONFIG_MAVEN_CFGFILE"

	if [ "$MODULE_MAVEN_CMD" = "" ]; then
		MODULE_MAVEN_CMD=deploy
	fi

	echo build $P_PATCHPATH, profile=$MODULE_MAVEN_PROFILES, options=$C_CONFIG_MAVEN_ADDITIONAL_OPTIONS, cmd=$MODULE_MAVEN_CMD using maven to nexus path $P_NEXUS_PATH...

	# set java environment
	local BUILD_JAVA_VERSION=$C_CONFIG_JAVA_VERSION
	if [ "$C_SOURCE_JAVAVERSION" != "" ]; then
		BUILD_JAVA_VERSION=$C_SOURCE_JAVAVERSION
	fi

	if [ "$BUILD_JAVA_VERSION" = "" ]; then
		echo BUILD_JAVA_VERSION is not defined - java version is unknown. Exiting.
		exit 1
	fi

	export JAVA_HOME=/usr/java/$BUILD_JAVA_VERSION
	export PATH=$JAVA_HOME/bin:$PATH

	# set maven environment
	local BUILD_MAVEN_VERSION=$C_CONFIG_MAVEN_VERSION
	if [ "$C_SOURCE_MAVENVERSION" != "" ]; then
		BUILD_MAVEN_VERSION=$C_SOURCE_MAVENVERSION
	fi

	if [ "$BUILD_MAVEN_VERSION" = "" ]; then
		echo BUILD_MAVEN_VERSION is not defined - maven version is unknown. Exiting.
		exit 1
	fi

	local F_MAVEN_CMD="mvn -B -P $MODULE_MAVEN_PROFILES $C_CONFIG_MAVEN_ADDITIONAL_OPTIONS clean $MODULE_MAVEN_CMD $MODULE_ALT_REPO $MODULE_MSETTINGS -Dmaven.test.skip=true"

	export M2_HOME=/usr/local/apache-maven-$BUILD_MAVEN_VERSION
	export M2=$M2_HOME/bin
	export PATH="$M2:$PATH"
	export MAVEN_OPTS="-Xmx1g -XX:MaxPermSize=300m -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled"
	echo using maven:
	which mvn
	mvn --version

	# execute maven
	cd $P_PATCHPATH
	echo execute: $F_MAVEN_CMD
	$F_MAVEN_CMD

	if [ $? -ne 0 ]; then
		echo "patch-build.sh: maven build failed. Exiting"
		exit 1
	fi
}

function f_build_gradle() {
	# set java environment
	local BUILD_JAVA_VERSION=$C_CONFIG_JAVA_VERSION
	if [ "$C_SOURCE_JAVAVERSION" != "" ]; then
		BUILD_JAVA_VERSION=$C_SOURCE_JAVAVERSION
	fi

	if [ "$BUILD_JAVA_VERSION" = "" ]; then
		echo BUILD_JAVA_VERSION is not defined - java version is unknown. Exiting.
		exit 1
	fi

	export JAVA_HOME=/usr/java/$BUILD_JAVA_VERSION
	export PATH=$JAVA_HOME/bin:$PATH

	# set gradle environment
	local BUILD_GRADLE_VERSION=$C_CONFIG_GRADLE_VERSION
	if [ "$C_SOURCE_GRADLEVERSION" != "" ]; then
		BUILD_GRADLE_VERSION=$C_SOURCE_GRADLEVERSION
	fi

	if [ "$BUILD_GRADLE_VERSION" = "" ]; then
		echo BUILD_GRADLE_VERSION is not defined - gradle version is unknown. Exiting.
		exit 1
	fi

	export GR_HOME=/usr/local/apache-maven-$BUILD_MAVEN_VERSION
	export GR=$GR_HOME/bin
	export PATH="$GR:$PATH"

	local F_GRADLE_CMD="gradle clean war"

	cd $P_PATCHPATH

	echo using gradle:
	which gradle
	gradle --version

	# execute gradle
	cd $P_PATCHPATH
	echo execute: $F_GRADLE_CMD
	$F_GRADLE_CMD

	if [ $? -ne 0 ]; then
		echo "patch-build.sh: gradle build failed. Exiting"
		exit 1
	fi
}

function f_execute_all() {
	if [ "$C_CONFIG_MAVEN_VERSION" = "" ]; then
		echo C_CONFIG_MAVEN_VERSION is not defined - default maven version is unknown. Exiting.
		exit 1
	fi

	# get module info
	f_source_readproject $P_MODULESET $P_MODULENAME

	local F_BUILDER=$C_CONFIG_BUILDER
	if [ "$F_BUILDER" = "" ]; then
		F_BUILDER="maven"
	fi

	if [ "$C_SOURCE_BUILDER" != "" ]; then
		F_BUILDER=$C_SOURCE_BUILDER
	fi

	# build
	if [ "$C_SOURCE_BUILDER" = "maven" ] || [ "$C_SOURCE_BUILDER" = "" ]; then
		f_build_maven
	elif [ "$C_SOURCE_BUILDER" = "gradle" ]
		f_build_gradle
	fi

	f_build_uploadstatus
}

f_execute_all

echo patch-build.sh: finished.
