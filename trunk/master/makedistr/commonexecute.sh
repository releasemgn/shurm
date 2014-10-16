# Copyright 2011-2014 vsavchik@gmail.com

C_TAG=
C_PGUWARNEXUSGROUPID="com.nvision.pgu.service"

function f_execute_getversionmode_defaulttag() {
	if [ "$GETOPT_TAG" != "" ]; then
		C_TAG=$GETOPT_TAG
	else
		C_TAG=$C_CONFIG_APPVERSION_TAG
	fi
	export C_TAG
}

function f_execute_buildone_core_tags() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4

	if [ "$C_BUILD_OUTDIR" = "" ]; then
		echo f_execute_buildone_core_tags: C_BUILD_OUTDIR is not set
		exit 1
	fi
	if [ "$C_TAG" = "" ]; then
		echo f_execute_buildone_core_tags: C_TAG is not set
		exit 1
	fi

	local BUILD_OPTIONS="$C_CONFIG_MODULE_BUILD_OPTIONS_CORE"
	export MODULE_MAVEN_CMD=$C_SOURCE_PROJECT_MVNCMD
	./buildone-tags.sh $C_BUILD_OUTDIR "$P_EXECUTE_SET" "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $C_TAG "$BUILD_OPTIONS" $C_BUILD_APPVERSION
}

function f_execute_buildone_war_tags() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4

	if [ "$C_BUILD_OUTDIR" = "" ]; then
		echo f_execute_buildone_war_tags: C_BUILD_OUTDIR is not set
		exit 1
	fi
	if [ "$C_TAG" = "" ]; then
		echo f_execute_buildone_war_tags: C_TAG is not set
		exit 1
	fi

	local BUILD_OPTIONS="$C_CONFIG_MODULE_BUILD_OPTIONS_WAR"
	export MODULE_MAVEN_CMD=$C_SOURCE_PROJECT_MVNCMD
	./buildone-tags.sh $C_BUILD_OUTDIR "$P_EXECUTE_SET" "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $C_TAG "$BUILD_OPTIONS" $C_BUILD_APPVERSION
}

function f_execute_download_wardistr() {
	local P_EXECUTE_SET=$1
	local P_PROJECT=$2

	if [ "$C_VERSION" = "" ]; then
		echo f_execute_download_wardistr: C_VERSION is not set
		exit 1
	fi

	f_source_readproject war $P_PROJECT
	local F_PROJECT_DISTITEM=$C_SOURCE_PROJECT_DISTITEM

	# get dist item details
	f_distr_readitem $F_PROJECT_DISTITEM
	local F_ISOBSOLETE=$C_DISTR_OBSOLETE

	# compare with release information
	if [ "$C_RELEASE_PROPERTY_OBSOLETE" = "false" ] && [ "$F_ISOBSOLETE" = "true" ]; then
		return 1
	fi
	if [ "$C_RELEASE_PROPERTY_OBSOLETE" = "true" ] && [ "$F_ISOBSOLETE" = "false" ]; then
		return 1
	fi

	local WAR_FILENAME=$C_DISTR_DISTBASENAME-$C_VERSION.war
	f_downloadnexus $P_PROJECT $C_CONFIG_NEXUS_REPO $C_PGUWARNEXUSGROUPID $C_DISTR_DISTBASENAME $C_VERSION "war"
	if [ $? -ne 0 ]; then
		return 1
	fi

	local STATIC_FILENAME=$C_DISTR_DISTBASENAME-$C_VERSION-webstatic.tar.gz
	f_downloadnexus $P_PROJECT $C_CONFIG_NEXUS_REPO $C_PGUWARNEXUSGROUPID $C_DISTR_DISTBASENAME $C_VERSION "tar.gz" "webstatic"
	if [ $? -ne 0 ]; then
		return 1
	fi

	# download versioninfo
	local VERSION_FILENAME=$P_PROJECT-$C_CONFIG_APPVERSION-version.txt
	f_downloadnexus $P_PROJECT $C_CONFIG_NEXUS_REPO release $P_PROJECT $C_VERSION "txt" "version"
	local VERSION_TAGNAME=`cat $VERSION_FILENAME`

	f_copy_distr $WAR_FILENAME
	f_repackage_staticdistr $P_PROJECT $C_VERSION $WAR_FILENAME $STATIC_FILENAME $VERSION_TAGNAME

	return 0
}

function f_execute_download_lib() {
	local P_EXECUTE_SET=$1
	local P_PROJECT=$2

	if [ "$C_VERSION" = "" ]; then
		echo f_execute_download_lib: C_VERSION is not set
		exit 1
	fi

	f_source_readproject war $P_PROJECT
	local F_PROJECT_DISTITEM=$C_SOURCE_PROJECT_DISTITEM

	# get dist item details
	f_distr_readitem $F_PROJECT_DISTITEM
	local F_ISOBSOLETE=$C_DISTR_OBSOLETE

	# compare with release information
	if [ "$C_RELEASE_PROPERTY_OBSOLETE" = "false" ] && [ "$F_ISOBSOLETE" = "true" ]; then
		return 1
	fi
	if [ "$C_RELEASE_PROPERTY_OBSOLETE" = "true" ] && [ "$F_ISOBSOLETE" = "false" ]; then
		return 1
	fi

	local F_LIB=$C_SOURCE_PROJECT_DISTLIBITEM
	f_downloadnexus $P_PROJECT $C_CONFIG_NEXUS_REPO $C_PGUWARNEXUSGROUPID $F_LIB $C_VERSION "jar"
}

function f_execute_copy_release_to_release() {
	local P_EXECUTE_SET=$1
	local P_PROJECT=$2

	./copy-releaseproject.sh $P_EXECUTE_SET $P_PROJECT
}

function f_execute_vcssetbranchtag() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4
	local P_PROD_BRANCH=$5

	if [ "$C_TAG" = "" ]; then
		echo f_execute_vcssetbranchtag: C_TAG is not set
		exit 1
	fi

	local F_BRANCHNAME=$C_CONFIG_BRANCHNAME
	if [ "$F_BRANCHNAME" = "" ]; then
		F_BRANCHNAME=$P_PROD_BRANCH
	fi

	if [ "$F_BRANCHNAME" != "trunk" ]; then
		F_BRANCHNAME=branches/$F_BRANCHNAME
	fi

	./vcssettag.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $F_BRANCHNAME $C_TAG "$GETOPT_DATE"
}

function f_execute_vcscopytag() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4

	if [ "$C_TAG1" = "" ]; then
		echo f_execute_vcscopytag: C_TAG1 is not set
		exit 1
	fi
	if [ "$C_TAG2" = "" ]; then
		echo f_execute_vcscopytag: C_TAG2 is not set
		exit 1
	fi
	./vcscopytag.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $C_TAG1 "tags/$C_TAG2"
}

function f_execute_vcscopytagtobranch() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4

	if [ "$C_TAG1" = "" ]; then
		echo f_execute_vcscopytagtobranch: C_TAG1 is not set
		exit 1
	fi
	if [ "$C_BRANCH2" = "" ]; then
		echo f_execute_vcscopytagtobranch: C_BRANCH2 is not set
		exit 1
	fi
	./vcscopytag.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $C_TAG1 "branches/$C_BRANCH2"
}

function f_execute_vcscopynewtag() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4

	if [ "$C_TAG1" = "" ]; then
		echo f_execute_vcscopynewtag: C_TAG1 is not set
		exit 1
	fi
	if [ "$C_TAG2" = "" ]; then
		echo f_execute_vcscopynewtag: C_TAG2 is not set
		exit 1
	fi
	./vcscopynewtag.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $C_TAG1 $C_TAG2
}

function f_execute_vcsdroptag() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4

	if [ "$C_TAG" = "" ]; then
		echo f_execute_vcsdroptag: C_TAG is not set
		exit 1
	fi
	./vcsdroptag.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $C_TAG
}

function f_execute_vcsrenametag() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4

	if [ "$C_TAG1" = "" ]; then
		echo f_execute_vcsrenametag: C_TAG1 is not set
		exit 1
	fi
	if [ "$C_TAG2" = "" ]; then
		echo f_execute_vcsrenametag: C_TAG2 is not set
		exit 1
	fi

	./vcsrenametag.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $C_TAG1 $C_TAG2
}

function f_execute_vcscopybranch() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4
	local P_PROD_BRANCH=$5

	if [ "$C_BRANCH1" = "" ] || [ "$C_BRANCH2" = "" ]; then
		echo "f_execute_vcscopybranch: C_BRANCH1, C_BRANCH2 not set"
		exit 1
	fi

	local X_BRANCH1=$C_BRANCH1
	local X_BRANCH2=$C_BRANCH2
	if [ "$X_BRANCH1" = "prod" ]; then
		X_BRANCH1=$P_PROD_BRANCH
	fi
	if [ "$X_BRANCH2" = "prod" ]; then
		X_BRANCH2=$P_PROD_BRANCH
	fi

	./vcscopybranch.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $X_BRANCH1 $X_BRANCH2
}

function f_execute_vcsrenamebranch() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4
	local P_PROD_BRANCH=$5

	if [ "$C_BRANCH1" = "" ] || [ "$C_BRANCH2" = "" ]; then
		echo "f_execute_vcsrenamebranch: C_BRANCH1, C_BRANCH2 not set"
		exit 1
	fi

	local X_BRANCH1=$C_BRANCH1
	local X_BRANCH2=$C_BRANCH2
	if [ "$X_BRANCH1" = "prod" ]; then
		X_BRANCH1=$P_PROD_BRANCH
	fi
	if [ "$X_BRANCH2" = "prod" ]; then
		X_BRANCH2=$P_PROD_BRANCH
	fi

	./vcsrenamebranch.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $X_BRANCH1 $X_BRANCH2
}

function f_execute_start_settag() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4

	local CANDIDATETAG=$C_CONFIG_APPVERSION_TAG
	./vcssettag.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $C_CONFIG_BRANCHNAME $CANDIDATETAG
}

function f_execute_update_settag() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4
	local P_PROD_BRANCH=$5

	F_BRANCH=$P_PROD_BRANCH
	if [ "$C_CONFIG_BRANCHNAME" != "" ]; then
		F_BRANCH=$C_CONFIG_BRANCHNAME
	fi

	if [ "$F_BRANCH" != "trunk" ]; then
		F_BRANCH=branches/$F_BRANCH
	fi

	if [ "$C_TAG" = "" ]; then
		f_execute_getversionmode_defaulttag
	fi

	local F_TAG=$C_TAG
	./vcssettag.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $F_BRANCH $F_TAG
}

function f_execute_setversion() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4
	local P_PROD_BRANCH=$5

	F_BRANCH=$P_PROD_BRANCH
	if [ "$C_CONFIG_BRANCHNAME" != "" ]; then
		F_BRANCH=$C_CONFIG_BRANCHNAME
	fi

	./setversion.sh "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" "$F_BRANCH" "$C_VERSION"
}

function f_execute_checkout() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4
	local P_PROD_BRANCH=$5

	F_BRANCH=$P_PROD_BRANCH
	if [ "$C_CONFIG_BRANCHNAME" != "" ]; then
		F_BRANCH=$C_CONFIG_BRANCHNAME
	fi

	local F_PATH=$C_TARGETDIR/$P_PROJECT
	mkdir -p $F_PATH
	if [ $? != 0 ]; then
		echo unable to create $F_PATH. Exiting
		exit 1
	fi

	./vcscheckout.sh $F_PATH "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" "$F_BRANCH"
}

function f_execute_export() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4
	local P_PROD_BRANCH=$5

	F_BRANCH=$P_PROD_BRANCH
	if [ "$C_CONFIG_BRANCHNAME" != "" ]; then
		F_BRANCH=$C_CONFIG_BRANCHNAME
	fi

	local F_PATH=$C_TARGETDIR/$P_PROJECT
	rm -rf $F_PATH
	mkdir -p $C_TARGETDIR
	if [ $? != 0 ]; then
		echo unable to create $F_PATH. Exiting
		exit 1
	fi

	./vcsexport.sh $F_PATH "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" "$F_BRANCH" "$GETOPT_TAG"
}

function f_execute_commit() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4
	local P_PROD_BRANCH=$5

	local F_PATH=$C_TARGETDIR/$P_PROJECT
	mkdir -p $F_PATH
	if [ $? != 0 ]; then
		echo unable to create $F_PATH. Exiting
		exit 1
	fi

	if [ "$C_COMMITMSG" = "" ]; then
		C_COMMITMSG="default commit message"
	fi

	./vcscommit.sh $F_PATH "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" "$C_COMMITMSG"
}

function f_execute_diffbranchtag() {
	local P_GROUP=$1
	local P_VCSTYPE=$2
	local P_EXECUTE_SET=$3
	local P_PROJECT=$4
	local P_VCSPATH=$5
	local P_PROD_BRANCH=$6

	if [ "$C_DIFF_SINCE" = "" ]; then
		echo f_execute_diffbranchtag: C_DIFF_SINCE is not set
		exit 1
	fi
	if [ "$C_DIFF_TILL" = "" ]; then
		echo f_execute_diffbranchtag: C_DIFF_TILL is not set
		exit 1
	fi
	if [ "$C_FINFO" = "" ]; then
		echo f_execute_diffbranchtag: C_FINFO is not set
		exit 1
	fi
	if [ "$C_FDIFF" = "" ]; then
		echo f_execute_diffbranchtag: C_FDIFF is not set
		exit 1
	fi

	./vcsdiff.sh MARKER $C_FINFO $C_FDIFF "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $C_DIFF_TILL $C_DIFF_SINCE
}

function f_execute_diffbranchsinceone() {
	local P_VCSTYPE=$1
	local P_EXECUTE_SET=$2
	local P_PROJECT=$3
	local P_VCSPATH=$4
	local P_JIRA=$5
	local P_PROD_BRANCH=$6

	if [ "$C_BUILD_OUTDIR" = "" ]; then
		echo f_diffbranchsinceone: C_BUILD_OUTDIR is not set
		exit 1
	fi
	./diffbranchsinceone.sh prod-$C_CONFIG_VERSION_LAST_FULL $C_BUILD_OUTDIR "$P_PROJECT" "$P_VCSTYPE:$P_VCSPATH" $P_PROD_BRANCH $P_JIRA
}

function f_execute_custom() {
	local P_EXECUTE_SET=$1
	local P_PROJECT=$2

	if [ ! -f "$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/custom/$C_CUSTOM_SCRIPT" ]; then
		echo unknown custom script: $C_CUSTOM_SCRIPT. Exiting
		exit 1
	fi

	local F_CUSTOMEXECUTE_SAVEDIR=`pwd`

	if [ "$GETOPT_SHOWONLY" = "yes" ]; then
		echo "(showonly) $C_CUSTOM_SCRIPT $P_EXECUTE_SET $P_PROJECT"
	else
		echo "(execute) $C_CUSTOM_SCRIPT $P_EXECUTE_SET $P_PROJECT"
		(
			source $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/custom/$C_CUSTOM_SCRIPT
			f_custom_execute $P_EXECUTE_SET $P_PROJECT
		)
	fi

	cd $F_CUSTOMEXECUTE_SAVEDIR
}

function f_execute_one() {
	local P_EXECUTE_SET=$1
	local P_EXECUTE_LIST="$2"
	local P_FUNCTION=$3
	local P_PROJECT=$4

	f_source_readproject $P_EXECUTE_SET $project
	local P_EXECUTE_MODE=$C_SOURCE_VERSION
	local P_GROUP=$C_SOURCE_GROUP
	local P_VCSTYPE=$C_SOURCE_VCS
	local P_VCSPATH=$C_SOURCE_PATH
	local P_JIRA=$C_SOURCE_JIRA
	local P_PROD_BRANCH=$C_SOURCE_BRANCH

	if [ "$P_PROD_BRANCH" = "" ]; then
		P_PROD_BRANCH=${P_VCSDIR}-prod
	fi

	if [ "$VERSION_MODE" = "branch" ] && [ "$P_EXECUTE_MODE" = "trunk" ]; then
		# ignore trunk for branch
		return 0
	fi

	if [ "$P_EXECUTE_LIST" = "all" ] || [[ " $P_EXECUTE_LIST " =~ " $P_PROJECT " ]] || [ "$P_EXECUTE_LIST" = "$P_GROUP" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo execute: $P_FUNCTION for $P_PROJECT, VERSION_MODE=$VERSION_MODE...
		fi
	else
		return 0
	fi

	case "$P_FUNCTION" in
# build operations
		CUSTOM)
			f_execute_custom $P_EXECUTE_SET $P_PROJECT
			;;
		BUILDCORE)
			f_execute_buildone_core_tags $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH
			;;
		BUILDWAR)
			f_execute_buildone_war_tags $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH
			;;
		DOWNLOADWAR)
			f_execute_download_wardistr $P_EXECUTE_SET $P_PROJECT
			;;
		DOWNLOADLIB)
			f_execute_download_lib $P_EXECUTE_SET $P_PROJECT
			;;
		COPYRELEASETORELEASE)
			f_execute_copy_release_to_release $P_EXECUTE_SET $P_PROJECT
			;;
# vcs operations
		VCSSETBRANCHTAG)
			f_execute_vcssetbranchtag $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH $P_PROD_BRANCH
			;;
		VCSCOPYTAG)
			f_execute_vcscopytag $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH
			;;
		VCSCOPYTAGTOBRANCH)
			f_execute_vcscopytagtobranch $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH
			;;
		VCSCOPYNEWTAG)
			f_execute_vcscopynewtag $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH
			;;
		VCSDROPTAG)
			f_execute_vcsdroptag $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH
			;;
		VCSRENAMETAG)
			f_execute_vcsrenametag $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH
			;;
		VCSCOPYBRANCH)
			f_execute_vcscopybranch $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH $P_PROD_BRANCH
			;;
		VCSRENAMEBRANCH)
			f_execute_vcsrenamebranch $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH $P_PROD_BRANCH
			;;
		VCSCHECKOUT)
			f_execute_checkout $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH $P_PROD_BRANCH
			;;
		VCSEXPORT)
			f_execute_export $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH $P_PROD_BRANCH
			;;
		VCSCOMMIT)
			f_execute_commit $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH $P_PROD_BRANCH
			;;
		STARTCANDIDATETAGS)
			f_execute_start_settag $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH
			;;
		UPDATETAGS)
			f_execute_update_settag $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH $P_PROD_BRANCH
			;;
		SETVERSION)
			f_execute_setversion $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH $P_PROD_BRANCH
			;;
		DIFFBRANCHTAG)
			f_execute_diffbranchtag $P_GROUP $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH $P_PROD_BRANCH
			;;
		DIFFBRANCHSINCEONE)
			f_execute_diffbranchsinceone $P_VCSTYPE $P_EXECUTE_SET $P_PROJECT $P_VCSPATH $P_JIRA $P_PROD_BRANCH
			;;
	esac
}

function f_execute_core() {
	local P_EXECUTE_LIST="$1"
	local P_FUNCTION=$2

	if [ "$P_EXECUTE_LIST" = "" ]; then
		return 0
	fi

	if [ "$P_FUNCTION" = "" ]; then
		echo f_execute_core: P_FUNCTION is empty
		exit 1
	fi

	# get full core project list
	f_source_projectlist core
	local F_FULLLIST=$C_SOURCE_PROJECTLIST

	if [ "$GETOPT_RELEASE" != "" ]; then
		local F_FNAME_REL=$C_CONFIG_DISTR_PATH/$GETOPT_RELEASE/release.xml
		f_release_setfile $F_FNAME_REL
		f_release_getprojects core

		if [ "$C_RELEASE_TARGETS" != "all" ]; then
			f_getsubsetexact "$F_FULLLIST" "$C_RELEASE_TARGETS"
			F_FULLLIST=$C_COMMON_SUBSET
		fi
	fi

	echo commonexecute.sh: execute function=$P_FUNCTION for core projects=$P_EXECUTE_LIST ...
	local project
	for project in $F_FULLLIST; do
		f_execute_one core "$P_EXECUTE_LIST" $P_FUNCTION $project
	done
}

function f_execute_wars() {
	local P_EXECUTE_LIST="$1"
	local P_FUNCTION=$2

	if [ "$P_EXECUTE_LIST" = "" ]; then
		return 0
	fi

	if [ "$P_FUNCTION" = "" ]; then
		echo f_execute_wars: P_FUNCTION is empty
		exit 1
	fi

	# get full war project list
	f_source_projectlist war
	local F_FULLLIST=$C_SOURCE_PROJECTLIST

	if [ "$GETOPT_RELEASE" != "" ]; then
		local F_FNAME_REL=$C_CONFIG_DISTR_PATH/$GETOPT_RELEASE/release.xml
		f_release_setfile $F_FNAME_REL
		f_release_getprojects war

		if [ "$C_RELEASE_TARGETS" != "all" ]; then
			f_getsubsetexact "$F_FULLLIST" "$C_RELEASE_TARGETS"
			F_FULLLIST=$C_COMMON_SUBSET
		fi
	fi

	echo commonexecute.sh: execute function=$P_FUNCTION for war projects=$P_EXECUTE_LIST ...
	local project
	for project in $F_FULLLIST; do
		f_execute_one war "$P_EXECUTE_LIST" $P_FUNCTION $project
	done
}

function f_execute_all() {
	local P_LOCAL_EXECUTE_LIST="$1"
	local P_FUNCTION=$2

	if [ "$P_LOCAL_EXECUTE_LIST" = "" ]; then
		return 0
	fi

	if [ "$P_FUNCTION" = "" ]; then
		echo f_execute_all: P_FUNCTION is empty
		exit 1
	fi

	# handle types
	local DONE=0

	if [ "$P_LOCAL_EXECUTE_LIST" = "core" ] || [ "$P_LOCAL_EXECUTE_LIST" = "all" ]; then
		f_execute_core all $P_FUNCTION
		DONE=1
	fi

	if [ "$P_LOCAL_EXECUTE_LIST" = "war" ] || [ "$P_LOCAL_EXECUTE_LIST" = "all" ]; then
		f_execute_wars all $P_FUNCTION
		DONE=1
	fi

	if [ "$DONE" = "1" ]; then
		return 0
	fi

	# handle specific subsets
	if [[ "$P_LOCAL_EXECUTE_LIST" =~ "^core " ]]; then
		P_LOCAL_EXECUTE_LIST=${P_LOCAL_EXECUTE_LIST#core }
		f_execute_core "$P_LOCAL_EXECUTE_LIST" $P_FUNCTION
	elif [[ "$P_LOCAL_EXECUTE_LIST" =~ "^war " ]]; then
		P_LOCAL_EXECUTE_LIST=${P_LOCAL_EXECUTE_LIST#war }
		f_execute_wars "$P_LOCAL_EXECUTE_LIST" $P_FUNCTION
	else
		f_execute_core "$P_LOCAL_EXECUTE_LIST" $P_FUNCTION
		f_execute_wars "$P_LOCAL_EXECUTE_LIST" $P_FUNCTION
	fi
}

function f_execute_set() {
	local P_PROJECTSET=$1
	local P_EXECUTE_LIST="$2"
	local P_FUNCTION=$3

	if [ "$P_PROJECTSET" = "core" ]; then
		f_execute_core "$P_EXECUTE_LIST" $P_FUNCTION
	elif [ "$P_PROJECTSET" = "war" ]; then
		f_execute_wars "$P_EXECUTE_LIST" $P_FUNCTION
	fi
}
