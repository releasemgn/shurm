# Copyright 2011-2013 vsavchik@gmail.com

C_GIT_REPONAME=
C_GIT_REPOVERSION=

function f_git_getreponame() {
	local P_MODULEPATH=$1
	local P_MODULENAME=$2

	# check required
	if [ "$C_CONFIG_GITMIRRORPATH" = "" ]; then
		echo C_CONFIG_GITMIRRORPATH is not set. Exiting
		exit 1
	fi

	if [ "$P_MODULEPATH" = "" ] || [ "$P_MODULEPATH" = "/" ]; then
		C_GIT_REPONAME=$P_MODULENAME.git
	else
		local F_MODULEPATH=`echo $P_MODULEPATH | sed "s/\//./g"`
		C_GIT_REPONAME=$F_MODULEPATH-$P_MODULENAME.git
	fi

	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$C_GIT_REPONAME
	if [ ! -d "$F_MIRRORPATH" ]; then
		echo $F_MIRRORPATH should be created using $C_CONFIG_GITMIRRORPATH/mirror.sh. Exiting
		exit 1
	fi
}

function f_git_refreshmirror() {
	local P_GITREPONAME=$1

	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	git fetch origin
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_refreshmirror: git pull error. Exiting"
		exit 1
	fi
}

function f_git_createlocal_frombranch() {
	local P_GITREPONAME=$1
	local P_LOCAL_PATH=$2
	local P_BRANCH=$3

	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	if [ ! -d "$F_MIRRORPATH" ]; then
		echo f_git_createlocal: mirror directory $F_MIRRORPATH does not exist. Exiting
		exit 1
	fi
	
	git clone $F_MIRRORPATH --shared -b branch-$P_BRANCH $P_LOCAL_PATH
	local RES=$?

	if [ "$RES" != "0" ]; then
		echo "f_git_createlocal_frombranch: git clone error. Exiting"
		exit 1
	fi
}

function f_git_createlocal_fromtag() {
	local P_GITREPONAME=$1
	local P_LOCAL_PATH=$2
	local P_TAG=$3

	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	if [ ! -d "$F_MIRRORPATH" ]; then
		echo f_git_createlocal: mirror directory $F_MIRRORPATH does not exist. Exiting
		exit 1
	fi
	
	git clone $F_MIRRORPATH --shared -b tag-$P_TAG $P_LOCAL_PATH
	local RES=$?

	if [ "$RES" != "0" ]; then
		echo "f_git_createlocal: git clone error. Exiting"
		exit 1
	fi
}

function f_git_export_frompath() {
	local P_GITREPONAME=$1
	local P_LOCAL_PATH=$2
	local P_PATH=$3
	local P_FILE=$4

	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME

	if [ ! -d "$F_MIRRORPATH" ]; then
		echo "f_git_export_frompath: mirror directory $F_MIRRORPATH does not exist. Exiting"
		exit 1
	fi

	local F_BASEDIR=`dirname $P_LOCAL_PATH`
	local F_BASENAME=`basename $P_LOCAL_PATH`
	if [ ! -d "$F_BASEDIR" ]; then
		echo "f_git_export_frompath: local directory $F_BASEDIR does not exist. Exiting"
		exit 1
	fi

	if [ -f "$P_LOCAL_PATH" ] || [ -d "$P_LOCAL_PATH" ]; then
		echo "f_git_export_frompath: local file or directory $P_LOCAL_PATH should not exist. Exiting"
		exit 1
	fi

	cd $F_BASEDIR
	F_BASEDIR=`pwd`

	cd $F_MIRRORPATH

	F_STRIPOPTION=
	if [ "$P_FILE" = "" ]; then
		mkdir -p $F_BASEDIR/$F_BASENAME
		git archive $P_PATH . | ( cd $F_BASEDIR/$F_BASENAME; tar x $F_STRIPOPTION )
	else
		# export file or subdir
		F_COMPS=`echo ${P_FILE%/} | tr "/" "\n" | grep -c "$"`
		F_COMPS=$(expr $F_COMPS - 1)
		F_STRIPOPTION="--strip-components=$F_COMPS"

		F_FILEBASENAME=`basename $P_FILE`
		if [ "$F_FILEBASENAME" != "$F_BASENAME" ] && ( [ -f "$F_BASEDIR/$F_FILEBASENAME" ] || [ -d "$F_BASEDIR/$F_FILEBASENAME" ] ); then
			echo "f_git_export_frompath: local file or directory $F_BASEDIR/$F_FILEBASENAME should not exist. Exiting"
			exit 1
		fi

		git archive branch-$P_BRANCH $P_FILE | ( cd $F_BASEDIR; tar x $F_STRIPOPTION )
		if [ "$F_FILEBASENAME" != "$F_BASENAME" ]; then
			mv $F_BASEDIR/$F_FILEBASENAME $F_BASEDIR/$F_BASENAME
		fi
	fi

	cd $F_SAVEPATH	
}

function f_git_export_frombranch() {
	local P_GITREPONAME=$1
	local P_LOCAL_PATH=$2
	local P_BRANCH=$3
	local P_FILE=$4

	f_git_export_frompath $P_GITREPONAME $P_LOCAL_PATH branch-$P_BRANCH $P_FILE
}

function f_git_export_fromtag() {
	local P_GITREPONAME=$1
	local P_LOCAL_PATH=$2
	local P_TAG=$3
	local P_FILE=$4

	f_git_export_frompath $P_GITREPONAME $P_LOCAL_PATH tag-$P_TAG $P_FILE
}

function f_git_refreshlocal() {
	local P_LOCAL_PATH=$1

	local F_SAVEPATH=`pwd`
	cd $P_LOCAL_PATH

	git fetch origin
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_refreshlocal: git fetch error. Exiting"
		exit 1
	fi
}

function f_git_setmirrortag() {
	local P_GITREPONAME=$1
	local P_BRANCH=$2
	local P_TAG=$3
	local P_MESSAGE=$4
	local P_TAGDATE=$5
	
	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	# get revision by date
	local F_REVMARK=
	if [ "$P_TAGDATE" != "" ]; then
		F_REVMARK=`git log --format=oneline -n 1 --before="$P_TAGDATE" refs/heads/branch-$P_BRANCH | tr -d " " -f1`
		if [ "$F_REVMARK" = "" ]; then
			echo "f_git_setmirrortag: unable to find branch revision on given date. Exiting
			exit 1
		fi
	fi

	git tag tag-$P_TAG -a -f -m "$P_MESSAGE" refs/heads/branch-$P_BRANCH $F_REVMARK
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_setmirrortag: git tag error. Exiting"
		exit 1
	fi
}

function f_git_dropmirrortag() {
	local P_GITREPONAME=$1
	local P_TAG=$2
	
	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	git tag -d tag-$P_TAG
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_dropmirrortag: git tag error. Exiting"
		exit 1
	fi
}

function f_git_dropmirrorbranch() {
	local P_GITREPONAME=$1
	local P_BRANCH=$2
	
	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	git branch -D branch-$P_BRANCH
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_dropmirrorbranch: git branch error. Exiting"
		exit 1
	fi
}

function f_git_getmirrortagstatus() {
	local P_GITREPONAME=$1
	local P_TAG=$2

	C_GIT_REPOVERSION=
	
	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	local F_STATUS=`git tag -l tag-$P_TAG`

	if [ "$F_STATUS" = "" ]; then
		cd $F_SAVEPATH
		return 1
	fi

	C_GIT_REPOVERSION=`git show --format=raw tag-$P_TAG | grep "commit " | cut -d " " -f2`
	cd $F_SAVEPATH

	return 0
}

function f_git_getmirrorbranchstatus() {
	local P_GITREPONAME=$1
	local P_BRANCH=$2
	
	C_GIT_REPOVERSION=
	
	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	local F_STATUS=`git branch --list branch-$P_BRANCH`

	if [ "$F_STATUS" = "" ]; then
		cd $F_SAVEPATH
		return 1
	fi

	C_GIT_REPOVERSION=`git show --format=raw branch-$P_BRANCH | grep "commit " | cut -d " " -f2`
	cd $F_SAVEPATH

	return 0
}

function f_git_copymirrortag_fromtag() {
	local P_GITREPONAME=$1
	local P_TAG_FROM=$2
	local P_TAG_TO=$3
	local P_MESSAGE=$4
	
	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	# drop if exists
	git tag -a -f -m "$P_MESSAGE" tag-$P_TAG_TO refs/tags/tag-$P_TAG_FROM
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_copymirrortag_fromtag: git tag error. Exiting"
		exit 1
	fi
}

function f_git_copymirrorbranch_fromtag() {
	local P_GITREPONAME=$1
	local P_TAG_FROM=$2
	local P_BRANCH_TO=$3
	local P_MESSAGE=$4
	
	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	git branch branch-$P_BRANCH_TO refs/tags/tag-$P_TAG_FROM
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_copymirrorbranch_fromtag: git branch error. Exiting"
		exit 1
	fi
}

function f_git_copymirrorbranch_frombranch() {
	local P_GITREPONAME=$1
	local P_BRANCH_FROM=$2
	local P_BRANCH_TO=$3
	local P_MESSAGE=$4
	
	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	git branch branch-$P_BRANCH_TO refs/heads/branch-$P_BRANCH_FROM
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_copymirrorbranch_frombranch: git branch error. Exiting"
		exit 1
	fi
}

function f_git_copymirrortag_frombranch() {
	local P_GITREPONAME=$1
	local P_BRANCH_FROM=$2
	local P_TAG_TO=$3
	local P_MESSAGE=$4
	
	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	# drop if exists
	git tag -a -f -m "$P_MESSAGE" tag-$P_TAG_TO refs/heads/branch-$P_BRANCH_FROM
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_copymirrortag_frombranch: git tag error. Exiting"
		exit 1
	fi
}

function f_git_renamemirrortag() {
	# rename tag
	local P_GITREPONAME=$1
	local P_TAG_FROM=$2
	local P_TAG_TO=$3
	local P_MESSAGE=$4
	
	# copy tag
	f_git_copymirrortag_fromtag $P_GITREPONAME tag-$P_TAG_FROM tag-$P_TAG_TO $P_MESSAGE
	
	# drop old tag
	f_git_dropmirrortag $P_GITREPONAME tag-$P_TAG_FROM
}

function f_git_pushmirror() {
	local P_GITREPONAME=$1

	local F_SAVEPATH=`pwd`
	local F_MIRRORPATH=$C_CONFIG_GITMIRRORPATH/$P_GITREPONAME
	cd $F_MIRRORPATH

	git push origin
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_pushmirror: git tag error. Exiting"
		exit 1
	fi
}

function f_git_pushlocal() {
	local P_LOCAL_PATH=$1

	local F_SAVEPATH=`pwd`
	cd $P_LOCAL_PATH

	git push origin
	local RES=$?
	cd $F_SAVEPATH

	if [ "$RES" != "0" ]; then
		echo "f_git_pushlocal: git tag error. Exiting"
		exit 1
	fi
}
