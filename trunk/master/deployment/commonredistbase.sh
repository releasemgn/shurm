#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

C_REDIST_EXECUTE_ECHO_ONLY=true
C_REDIST_NOBACKUP=
C_REDIST_SRCDIR=
C_REDIST_SRCVER=

C_SOURCE_FILE=
C_SOURCE_FILE_STATIC=

C_DISTR_DEPLOYFINALNAME=
C_DISTR_STATICPREFIX=

C_REDIST_LOCATIONLIST=
C_REDIST_LOCATION_COMPONENTS=

C_REDIST_DIRITEMS=
C_REDIST_DIRITEMS_PREPARE=
C_REDIST_DIRITEMS_BINARY=
C_REDIST_DIRITEMS_MASKEDBINARY=
C_REDIST_DIRITEMS_ISPGUSTATIC=false
C_REDIST_DIRITEMS_ARCHIVE=
C_REDIST_DIRITEMS_LINK=
C_REDIST_DIRITEMS_OBSOLETE=
C_REDIST_DIRITEMS_ISEMPTY=
C_REDIST_DIRITEMS_CONFIG=
C_REDIST_DIRITEMS_VER=

C_REDIST_DEPLOY_CONTENT=
C_REDIST_DEPLOY_BACKUP_CONTENT=

S_REDIST_PGU_STATIC_FILENAME="archive.child.pgu.tar.gz"
S_REDIST_PGU_STATIC_DISTNAME="gu-web"
S_REDIST_ARCHIVE_TYPE_DIRECT="direct"
S_REDIST_ARCHIVE_TYPE_CHILD="child"
S_REDIST_ARCHIVE_TYPE_SUBDIR="subdir"
S_REDIST_ARCHIVE_TYPE_PGUSTATIC="pgustatic"

C_REDIST_UPDATED_ITEMS=

S_REDIST_DIRTYPE=

function f_redist_execute() {
	local P_EXEC_HOSTLOGIN=$1
	local P_EXEC_CMD="$2"

	if [ "$C_REDIST_EXECUTE_ECHO_ONLY" = "true" ]; then
		echo $P_EXEC_HOSTLOGIN: showonly "$P_EXEC_CMD"
		RUN_CMD_RES=
	else
		echo $P_EXEC_HOSTLOGIN: execute "$P_EXEC_CMD"
		f_run_cmdcheck $P_EXEC_HOSTLOGIN "echo `date` \"(SSH_CLIENT=$SSH_CLIENT): $P_EXEC_CMD\" >> ~/execute.log"
		f_run_cmdcheck $P_EXEC_HOSTLOGIN "$P_EXEC_CMD"
	fi
}

# redist file
function f_redist_copy_file() {
	local P_DISTITEM=$1
	local P_SRCFILENAME=$2
	local P_SRCDIR=$3
	local P_DST_HOSTLOGIN=$4
	local P_DSTDIR=$5
	local P_DSTFILENAME=$6
	local P_SRC_HOSTLOGIN=$7

	if [ "$P_DISTITEM" = "" ] || [ "$P_SRCFILENAME" = "" ] || [ "$P_SRCDIR" = "" ] || [ "$P_DST_HOSTLOGIN" = "" ] || [ "$P_DSTDIR" = "" ] || [ "$P_DSTFILENAME" = "" ]; then
		echo f_redist_copy_file: invalid call. Exiting
		exit 1
	fi

	local F_REDIST_SRCFILE=$P_SRCDIR/$P_SRCFILENAME
	local F_REDIST_DSTFILE=$P_DSTDIR/$P_DSTFILENAME
	local L_MD5NAME=$P_DISTITEM.ver

	# copy file
	if [ "$P_SRC_HOSTLOGIN" != "" ]; then
		f_upload_remotefile $P_SRC_HOSTLOGIN $P_DST_HOSTLOGIN $F_REDIST_SRCFILE $F_REDIST_DSTFILE $L_MD5NAME
	else
		f_upload_file $P_DST_HOSTLOGIN $F_REDIST_SRCFILE $F_REDIST_DSTFILE $L_MD5NAME
	fi

	return 0		
}

# read source dir
function f_redist_findsourcefile() {
	local P_SRCDIR=$1
	local P_DISTR_HOSTLOGIN=$2

	C_SOURCE_FILE=
	C_SOURCE_FILE_STATIC=

	f_find_file $P_SRCDIR $C_DISTR_DISTBASENAME $C_DISTR_EXT $P_DISTR_HOSTLOGIN
	C_SOURCE_FILE=$C_COMMON_FINDFILE_NAME

	# ensure correct file
	if [ "$C_SOURCE_FILE" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo f_redist_findsourcefile: file $C_DISTR_DISTBASENAME$C_DISTR_EXT not found in $P_SRCDIR. Skipped.
		fi
		return 1
	fi

	C_SOURCE_FILE=`basename $C_SOURCE_FILE`
	
	# find static for war
	if [ "$C_DISTR_TYPE" = "war" ] || [ "$C_DISTR_TYPE" = "pguwar" ]; then
		f_find_file $P_SRCDIR $C_DISTR_DISTBASENAME $C_DISTR_WAR_STATICEXT $P_DISTR_HOSTLOGIN
		C_SOURCE_FILE_STATIC=$C_COMMON_FINDFILE_NAME

		if [ "$C_SOURCE_FILE_STATIC" != "" ]; then
			C_SOURCE_FILE_STATIC=`basename $C_SOURCE_FILE_STATIC`
		fi
	fi
		
	return 0
}

function f_redist_getdiritems() {
	local P_ENV_HOSTLOGIN=$1
	local P_DIR=$2

	f_run_cmd $P_ENV_HOSTLOGIN "if [ -d $P_DIR ]; then cd $P_DIR; find . -maxdepth 1 -type f -name '*.*' | sed 's/\.\///g' | sort | tr '\n' ' '; fi"
	C_REDIST_DIRITEMS=$RUN_CMD_RES

	C_REDIST_DIRITEMS_ISEMPTY=true
	C_REDIST_DIRITEMS_PREPARE=
	C_REDIST_DIRITEMS_BINARY=
	C_REDIST_DIRITEMS_MASKEDBINARY=
	C_REDIST_DIRITEMS_ISPGUSTATIC=false
	C_REDIST_DIRITEMS_ARCHIVE=
	C_REDIST_DIRITEMS_LINK=
	C_REDIST_DIRITEMS_OBSOLETE=
	C_REDIST_DIRITEMS_CONFIG=
	C_REDIST_DIRITEMS_VER=

	if [ "$C_REDIST_DIRITEMS" = "" ]; then
		return 0
	fi

	local x
	for x in $C_REDIST_DIRITEMS; do
		if [[ "$x" =~ .ver$ ]]; then
			C_REDIST_DIRITEMS_VER="$C_REDIST_DIRITEMS_VER $x"

		elif [ "$x" = "$S_REDIST_PGU_STATIC_FILENAME" ]; then
			C_REDIST_DIRITEMS_ISPGUSTATIC=true
			C_REDIST_DIRITEMS_ISEMPTY=false

		elif [ "$x" = "prepare.sh" ]; then
			C_REDIST_DIRITEMS_PREPARE=true

		elif [[ "$x" =~ ^archive ]]; then
			C_REDIST_DIRITEMS_ARCHIVE="$C_REDIST_DIRITEMS_ARCHIVE $x"
			C_REDIST_DIRITEMS_ISEMPTY=false

		elif [[ "$x" =~ ".link" ]]; then
			C_REDIST_DIRITEMS_LINK="$C_REDIST_DIRITEMS_LINK $x"
			C_REDIST_DIRITEMS_ISEMPTY=false

		elif [[ "$x" =~ ".config.tar" ]]; then
			x=${x%.config.tar}
			C_REDIST_DIRITEMS_CONFIG="$C_REDIST_DIRITEMS_CONFIG $x"
			C_REDIST_DIRITEMS_ISEMPTY=false

		elif [ "$x" = "obsolete.txt" ]; then
			f_run_cmd $P_ENV_HOSTLOGIN "cat $P_DIR/$x | tr \"\n\" \" \" "
			C_REDIST_DIRITEMS_OBSOLETE=$RUN_CMD_RES
			C_REDIST_DIRITEMS_ISEMPTY=false

		else
			C_REDIST_DIRITEMS_BINARY="$C_REDIST_DIRITEMS_BINARY $x"
			if [[ "$x" =~ ^[0-9] ]]; then
				x=`echo $x | sed "s/^[0-9.]*-//"`
				y=`echo $x | sed -r "s/([^.]*)/\\1-[0-9]*[0-9]/"`
			fi
			C_REDIST_DIRITEMS_MASKEDBINARY="$C_REDIST_DIRITEMS_MASKEDBINARY $x *[0-9]-$x $y"
			C_REDIST_DIRITEMS_ISEMPTY=false
		fi
	done

	C_REDIST_DIRITEMS_ARCHIVE=${C_REDIST_DIRITEMS_ARCHIVE# }
	C_REDIST_DIRITEMS_LINK=${C_REDIST_DIRITEMS_LINK# }
	C_REDIST_DIRITEMS_CONFIG=${C_REDIST_DIRITEMS_CONFIG# }
	C_REDIST_DIRITEMS_BINARY=${C_REDIST_DIRITEMS_BINARY# }
	C_REDIST_DIRITEMS_MASKEDBINARY=${C_REDIST_DIRITEMS_MASKEDBINARY# }
	C_REDIST_DIRITEMS_VER=${C_REDIST_DIRITEMS_VER# }
}

function f_redist_getdeployfilename() {
	local P_RELEASE=$1
	local P_DEPLOYTYPE=$2

	if [ "$C_DISTR_TYPE" = "archive.direct" ]; then
		C_DISTR_DEPLOYFINALNAME="archive.$S_REDIST_ARCHIVE_TYPE_DIRECT.$C_DISTR_KEY.tar.gz"

	elif [ "$C_DISTR_TYPE" = "archive.subdir" ]; then
		C_DISTR_DEPLOYFINALNAME="archive.$S_REDIST_ARCHIVE_TYPE_SUBDIR.$C_DISTR_DEPLOYBASENAME.tar.gz"

	elif [ "$C_DISTR_TYPE" = "archive.child" ]; then
		C_DISTR_DEPLOYFINALNAME="archive.$S_REDIST_ARCHIVE_TYPE_CHILD.$C_DISTR_DEPLOYBASENAME.tar.gz"

	elif [ "$C_DISTR_TYPE" = "war" ]; then
		if [ "$P_DEPLOYTYPE" = "links-multidir" ]; then
			C_DISTR_DEPLOYFINALNAME="$C_DISTR_DEPLOYBASENAME.war"
		else
			C_DISTR_DEPLOYFINALNAME="$P_RELEASE-$C_DISTR_DEPLOYBASENAME.war"
		fi
		C_DISTR_STATICPREFIX=$S_REDIST_ARCHIVE_TYPE_CHILD

	elif [ "$C_DISTR_TYPE" = "pguwar" ]; then
		C_DISTR_DEPLOYFINALNAME="$P_RELEASE-$C_DISTR_DEPLOYBASENAME.war"
		C_DISTR_STATICPREFIX=$S_REDIST_ARCHIVE_TYPE_PGUSTATIC

	elif [ "$C_DISTR_TYPE" = "binary" ]; then
		C_DISTR_DEPLOYFINALNAME="$C_DISTR_DEPLOYBASENAME$C_DISTR_EXT"

		if [ "$P_DEPLOYTYPE" = "links-multidir" ]; then
			C_DISTR_DEPLOYFINALNAME="$C_DISTR_DEPLOYFINALNAME"
		else
			if [[ ! "$C_DISTR_OPTIONS" =~ "N" ]]; then
				C_DISTR_DEPLOYFINALNAME=$P_RELEASE-$C_DISTR_DEPLOYFINALNAME
			fi
		fi
	else
		echo f_redist_getdeployfilename: unknown C_DISTR_TYPE=$C_DISTR_TYPE. Exiting
		exit 1
	fi
}

function f_redist_getitems() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_RELEASENAME=$3
	local P_LOCATION=$4
	local P_REDISTTYPE=$5

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $P_REDISTTYPE
	local F_DSTDIR=$C_COMMON_DIRPATH

	# get content
	f_redist_getdiritems $P_ENV_HOSTLOGIN $F_DSTDIR
}

function f_redist_getlocations() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_RELEASENAME=$3
	local P_REDISTTYPE=$4

	f_getpath_redistroot $P_SERVER $P_RELEASENAME $P_REDISTTYPE
	local F_DSTDIR=$C_COMMON_DIRPATH

	f_run_cmd $P_ENV_HOSTLOGIN "if [ -d "$F_DSTDIR" ]; then cd $F_DSTDIR; find . -type f -exec dirname {} \; | sort -u | tr \"\n\" \" \" | sed 's/\.\///g'; fi"
	C_REDIST_LOCATIONLIST="$RUN_CMD_RES"
}

function f_redist_getlocationinfo() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_RELEASENAME=$3
	local P_LOCATION=$4
	local P_CONTENTTYPE=$5

	local F_ROLLOUT_REDISTTYPE
	local F_ROLLBACK_REDISTTYPE
	if [ "$P_CONTENTTYPE" = "deploy" ]; then
		F_ROLLOUT_REDISTTYPE="deploy"
		F_ROLLBACK_REDISTTYPE="deploy.backup"

	elif [ "$P_CONTENTTYPE" = "config" ]; then
		F_ROLLOUT_REDISTTYPE="config"
		F_ROLLBACK_REDISTTYPE="config.backup"

	elif [ "$P_CONTENTTYPE" = "hotdeploy" ]; then
		F_ROLLOUT_REDISTTYPE="hotdeploy"
		F_ROLLBACK_REDISTTYPE="hotdeploy.backup"

	else
		echo f_redist_getlocationinfo: invalid content type=$P_CONTENTTYPE. Exiting
		exit 1
	fi

	# get content
	f_redist_getitems $P_SERVER $P_ENV_HOSTLOGIN $P_RELEASENAME $P_LOCATION $F_ROLLOUT_REDISTTYPE
	C_REDIST_DEPLOY_CONTENT=$C_REDIST_DIRITEMS

	f_redist_getitems $P_SERVER $P_ENV_HOSTLOGIN $P_RELEASENAME $P_LOCATION $F_ROLLBACK_REDISTTYPE
	C_REDIST_DEPLOY_BACKUP_CONTENT=$C_REDIST_DIRITEMS

	if [ "$C_REDIST_DEPLOY_CONTENT" = "" ] && [ "$C_REDIST_DEPLOY_BACKUP_CONTENT" = "" ]; then
		return 1
	fi

	return 0
}

# redist remote file
function f_redist_transfer_file() {
	local P_DEPLOYTYPE=$1
	local P_RELEASE=$2
	local P_ENV_HOSTLOGIN=$3
	local P_DISTITEM=$4
	local P_SRCDIR=$5
	local P_DSTDIR=$6
	local P_DIST_HOSTLOGIN=$7

	if [ "$P_RELEASE" = "" ] || [ "$P_ENV_HOSTLOGIN" = "" ] || [ "$P_DISTITEM" = "" ]; then
		echo f_redist_transfer_remotefile: invalid call
		exit 1
	fi
	if [ "$P_SRCDIR" = "" ] || [ "$P_DSTDIR" = "" ] || [ "$P_DEPLOYTYPE" = "" ]; then
		echo f_redist_transfer_remotefile: invalid call
		exit 1
	fi

	# read distr
	f_distr_readitem $P_DISTITEM

	local F_SRCDIR=$P_SRCDIR
	if [ "$C_DISTR_DISTFOLDER" != "" ]; then
		F_SRCDIR=$F_SRCDIR/$C_DISTR_DISTFOLDER
	fi

	f_redist_findsourcefile $F_SRCDIR $P_DIST_HOSTLOGIN
	if [ $? -ne 0 ]; then
		return 1
	fi

	if [ "$P_DEPLOYTYPE" = "static" ] && [ "$C_DISTR_WAR_CONTEXT" = "" ]; then
		echo f_redist_transfer_file: binary is not static. Exiting
		exit 1
	fi

	f_redist_getdeployfilename $P_RELEASE $P_DEPLOYTYPE

	if [ "$P_DEPLOYTYPE" != "static" ]; then
		f_redist_copy_file $P_DISTITEM "$C_SOURCE_FILE" $F_SRCDIR $P_ENV_HOSTLOGIN $P_DSTDIR "$C_DISTR_DEPLOYFINALNAME" $P_DIST_HOSTLOGIN
		if [ $? -ne 0 ]; then
			return 1
		fi

	elif [ "$P_DEPLOYTYPE" = "static" ] && [ "$C_SOURCE_FILE_STATIC" != "" ]; then
		local F_REDIST_SAVEAS
		if [ "$C_DISTR_DISTBASENAME" = "$S_REDIST_PGU_STATIC_DISTNAME" ]; then
			F_REDIST_SAVEAS=$S_REDIST_PGU_STATIC_FILENAME
		else
			F_REDIST_SAVEAS="archive.$C_DISTR_STATICPREFIX.$C_DISTR_WAR_CONTEXT.tar.gz"
		fi
			
		f_redist_copy_file $P_DISTITEM "$C_SOURCE_FILE_STATIC" $F_SRCDIR $P_ENV_HOSTLOGIN $P_DSTDIR "$F_REDIST_SAVEAS" $P_DIST_HOSTLOGIN
		if [ $? -ne 0 ]; then
			return 1
		fi
	fi

	return 0
}

function f_redist_deploy_archiveitem() {
	local P_HOSTLOGIN=$1
	local P_SRC_ARCHIVE_DIR=$2
	local P_DST_ARCHIVE_DIR=$3
	local P_ARCHIVEFILE=$4

	# get archive type
	local F_ARC_TYPE=`echo $P_ARCHIVEFILE | cut -d "." -f2`

	local F_LOGIN=${P_HOSTLOGIN%%@*}
	if [ "$F_ARC_TYPE" = "$S_REDIST_ARCHIVE_TYPE_CHILD" ]; then
		local F_ARC_DIR=`echo $P_ARCHIVEFILE | cut -d "." -f3`
		local F_FINALPATH=$P_DST_ARCHIVE_DIR/$F_ARC_DIR
		echo $P_ENV_HOSTLOGIN: rollout $P_SRC_ARCHIVE_DIR/$P_ARCHIVEFILE to $F_FINALPATH...
		f_redist_execute $P_ENV_HOSTLOGIN "rm -rf $F_FINALPATH; mkdir -p $P_DST_ARCHIVE_DIR; cd $P_DST_ARCHIVE_DIR; tar zxmf $P_SRC_ARCHIVE_DIR/$P_ARCHIVEFILE -o --owner=$F_LOGIN > /dev/null"

	elif [ "$F_ARC_TYPE" = "$S_REDIST_ARCHIVE_TYPE_DIRECT" ]; then
		local F_FINALPATH=$P_DST_ARCHIVE_DIR
		echo $P_ENV_HOSTLOGIN: rollout $P_SRC_ARCHIVE_DIR/$P_ARCHIVEFILE to $F_FINALPATH...
		f_redist_execute $P_ENV_HOSTLOGIN "rm -rf $F_FINALPATH; mkdir -p $F_FINALPATH; cd $F_FINALPATH; tar zxmf $P_SRC_ARCHIVE_DIR/$P_ARCHIVEFILE -o --owner=$F_LOGIN > /dev/null"

	elif [ "$F_ARC_TYPE" = "$S_REDIST_ARCHIVE_TYPE_SUBDIR" ]; then
		local F_ARC_DIR=`echo $P_ARCHIVEFILE | cut -d "." -f3`
		local F_FINALPATH=$P_DST_ARCHIVE_DIR/$F_ARC_DIR
		echo $P_ENV_HOSTLOGIN: rollout $P_SRC_ARCHIVE_DIR/$P_ARCHIVEFILE to $F_FINALPATH...
		f_redist_execute $P_ENV_HOSTLOGIN "rm -rf $F_FINALPATH; mkdir -p $F_FINALPATH; cd $F_FINALPATH; tar zxmf $P_SRC_ARCHIVE_DIR/$P_ARCHIVEFILE -o --owner=$F_LOGIN > /dev/null"

	elif [ "$F_ARC_TYPE" = "$S_REDIST_ARCHIVE_TYPE_PGUSTATIC" ]; then
		local F_ARC_DIR=`echo $P_ARCHIVEFILE | cut -d "." -f3`
		local F_BASEPATH=$P_DST_ARCHIVE_DIR
		local F_FINALPATH=$F_BASEPATH/$F_ARC_DIR
		echo $P_ENV_HOSTLOGIN: rollout pgu static $P_SRC_ARCHIVE_DIR/$P_ARCHIVEFILE to $F_FINALPATH...
		f_redist_execute $P_ENV_HOSTLOGIN "rm -rf $F_FINALPATH; mkdir -p $F_BASEPATH; cd $F_BASEPATH; cp -R pgu $F_ARC_DIR; cd $F_ARC_DIR; tar zxmf $P_SRC_ARCHIVE_DIR/$P_ARCHIVEFILE -o --owner=$F_LOGIN > /dev/null"
	else
		echo f_redist_rollout_archiveitem: unknown archive type=$F_ARC_TYPE in archive file $P_SRC_ARCHIVE_DIR/$P_ARCHIVEFILE. Exiting
		exit 1
	fi
}

function f_redist_createlocation() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_RELEASENAME=$3
	local P_ROOTDIR=$4
	local P_LOCATION=$5
	local P_CONTENTTYPE=$6

	local F_ROLLOUT_REDISTTYPE
	local F_ROLLBACK_REDISTTYPE
	if [ "$P_CONTENTTYPE" = "deploy" ]; then
		F_ROLLOUT_REDISTTYPE="deploy"
		F_ROLLBACK_REDISTTYPE="deploy.backup"

	elif [ "$P_CONTENTTYPE" = "config" ]; then
		F_ROLLOUT_REDISTTYPE="config"
		F_ROLLBACK_REDISTTYPE="config.backup"

	elif [ "$P_CONTENTTYPE" = "hotdeploy" ]; then
		F_ROLLOUT_REDISTTYPE="hotdeploy"
		F_ROLLBACK_REDISTTYPE="hotdeploy.backup"

	else
		echo f_redist_createlocation: invalid content type=$P_CONTENTTYPE. Exiting
		exit 1
	fi

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_ROLLOUT_REDISTTYPE
	local F_DSTDIR_DEPLOY=$C_COMMON_DIRPATH

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_ROLLBACK_REDISTTYPE
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	# create empty initial script
	echo $P_ENV_HOSTLOGIN: create redist location=$P_LOCATION contenttype=$P_CONTENTTYPE ...
	f_run_cmdcheck $P_ENV_HOSTLOGIN "
		mkdir -p $F_DSTDIR_DEPLOY
		mkdir -p $F_DSTDIR_BACKUP
		if [ ! -f $F_DSTDIR_DEPLOY/prepare.sh ]; then
			echo \"#!/bin/bash\" > $F_DSTDIR_DEPLOY/prepare.sh
			echo \"# location deployment preparation\" >> $F_DSTDIR_DEPLOY/prepare.sh
			chmod 777 $F_DSTDIR_DEPLOY/prepare.sh
		fi
		if [ ! -f $F_DSTDIR_BACKUP/prepare.sh ]; then
			echo \"#!/bin/bash\" > $F_DSTDIR_BACKUP/prepare.sh
			echo \"# location rollback preparation\" >> $F_DSTDIR_BACKUP/prepare.sh
			chmod 777 $F_DSTDIR_BACKUP/prepare.sh
		fi
		echo \"mkdir -p $F_RUNTIMEDIR\" >> $F_DSTDIR_DEPLOY/prepare.sh
		echo \"mkdir -p $F_RUNTIMEDIR\" >> $F_DSTDIR_BACKUP/prepare.sh
		echo \"cd $F_RUNTIMEDIR\" >> $F_DSTDIR_DEPLOY/prepare.sh
		echo \"cd $F_RUNTIMEDIR\" >> $F_DSTDIR_BACKUP/prepare.sh
		"
}

function f_redist_recreatedir() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_RELEASENAME=$3

	if [ "$P_ENV_HOSTLOGIN" = "" ] || [ "$P_SERVER" = "" ] || [ "$P_RELEASENAME" = "" ]; then
		echo f_redist_recreatedir: invalid call. Exiting
		exit 1
	fi

	f_getpath_redistserverreleaseroot $P_SERVER $P_RELEASENAME
	local F_DSTDIR_DEPLOY=$C_COMMON_DIRPATH

	f_getpath_redistserverbackuproot $P_SERVER $P_RELEASENAME
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH

	f_run_cmd $P_ENV_HOSTLOGIN "rm -rf $F_DSTDIR_DEPLOY $F_DSTDIR_BACKUP; mkdir -p $F_DSTDIR_DEPLOY; mkdir -p $F_DSTDIR_BACKUP; if [ -d $F_DSTDIR_DEPLOY ] && [ -d $F_DSTDIR_BACKUP ]; then echo ok; fi"

	if [ "$RUN_CMD_RES" != "ok" ]; then
		echo $P_ENV_HOSTLOGIN: unable to create redist $F_DSTDIR_DEPLOY, $F_DSTDIR_BACKUP. Exiting
		exit 1
	fi

	echo $P_ENV_HOSTLOGIN: ============================================ redist $F_DSTDIR_DEPLOY, $F_DSTDIR_BACKUP recreated.
}

function f_redist_drop() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2

	f_getpath_redistserverroot $P_SERVER
	local F_DSTDIR_REDIST=$C_COMMON_DIRPATH

	f_run_cmd $P_ENV_HOSTLOGIN "if [ -d "$F_DSTDIR_REDIST" ]; then echo ok; fi"
	if [ "$RUN_CMD_RES" = "ok" ]; then
		echo "$P_ENV_HOSTLOGIN: ============================================ drop redist $F_DSTDIR_REDIST ..."
		f_run_cmdcheck $P_ENV_HOSTLOGIN "rm -rf $F_DSTDIR_REDIST/*"
	else
		echo $P_ENV_HOSTLOGIN: empty, nothing to drop.
	fi
}

function f_redist_getdirtype() {
	local P_CLUSTER_MODE=$1
	local P_NODE=$2
	local P_DEPLOYTYPE=$3
	local P_COMPTYPE=$4

	# deploy to admin node only hotdeploy and in cluster mode
	if ( [ "$P_CLUSTER_MODE" != "yes" ] || [ "$P_DEPLOYTYPE" != "hotdeploy" ] ) && [ "$P_NODE" = "admin" ]; then
		S_REDIST_DIRTYPE=none
		return 1
	fi

	# in cluster mode deploy hotdeploy to admin node only, not to other nodes
	if [ "$P_CLUSTER_MODE" = "yes" ] && [ "$P_DEPLOYTYPE" = "hotdeploy" ] && [ "$P_NODE" != "admin" ]; then
		S_REDIST_DIRTYPE=none
		return 1
	fi

	# hotdeploy case
	if [ "$P_DEPLOYTYPE" = "hotdeploy" ]; then
		S_REDIST_DIRTYPE=hotdeploy
		return 0
	fi
		
	# other case
	S_REDIST_DIRTYPE=$P_COMPTYPE
	return 0
}
