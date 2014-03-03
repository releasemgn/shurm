#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

# save backup
function f_redist_savebackup() {
	local P_SERVER=$1
	local P_DEPLOYTYPE=$2
	local P_DST_HOSTLOGIN=$3
	local P_ROOTDIR=$4
	local P_DISTITEM=$5
	local P_RELEASENAME=$6
	local P_LOCATION=$7
	local P_LINKFROM_DIR=$8

	if [ "$P_SERVER" = "" ] || [ "$P_DEPLOYTYPE" = "" ] || [ "$P_DST_HOSTLOGIN" = "" ]; then
		echo f_redist_savebackup: invalid call
		exit 1
	fi
	if [ "$P_ROOTDIR" = "" ] || [ "$P_RELEASENAME" = "" ] || [ "$P_LOCATION" = "" ]; then
		echo f_redist_savebackup: invalid call
		exit 1
	fi

	if [ "$C_REDIST_NOBACKUP" = "true" ]; then
		return 1
	fi		

	f_distr_readitem $P_DISTITEM

	local F_REDISTTYPE_BACKUP="deploy.backup"
	if [ "$P_DEPLOYTYPE" = "hotdeploy" ]; then
		F_REDISTTYPE_BACKUP="hotdeploy.backup"
	fi

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE_BACKUP
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	# backup binary file - default or replaced link
	if [[ ! "$C_DISTR_TYPE" =~ ^archive ]] && [ "$C_DISTR_DEPLOYBASENAME" != "" ]; then
		if [ "$P_DEPLOYTYPE" = "default" ] || [ "$P_DEPLOYTYPE" = "hotdeploy" ] || [ "$P_DEPLOYTYPE" = "links-singledir" ]; then
			f_find_file $F_RUNTIMEDIR $C_DISTR_DEPLOYBASENAME $C_DISTR_EXT $P_DST_HOSTLOGIN
			local F_REDIST_BFILE=$C_COMMON_FINDFILE_NAME
			if [ "$F_REDIST_BFILE" = "" ]; then
				echo $P_DST_HOSTLOGIN: $C_DISTR_DEPLOYBASENAME$C_DISTR_EXT $C_DISTR_TYPE not found in $F_RUNTIMEDIR. Backup skipped.
				return 0
			fi

			local BACKUP_SRCBASE=`basename $F_REDIST_BFILE`

			f_run_cmdcheck $P_DST_HOSTLOGIN "mkdir -p $F_DSTDIR_BACKUP; cp -p $F_RUNTIMEDIR/$BACKUP_SRCBASE $F_DSTDIR_BACKUP"
			echo $P_DST_HOSTLOGIN: $C_DISTR_TYPE backup created - $F_DSTDIR_BACKUP/$BACKUP_SRCBASE

		# backup binary file - link only
		elif [ "$P_DEPLOYTYPE" = "links-multidir" ]; then
			f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LINKFROM_DIR
			local F_LINKDIR=$C_COMMON_DIRPATH

			local F_LINKNAME=$C_DISTR_DEPLOYBASENAME$C_DISTR_EXT
			f_run_cmd $P_DST_HOSTLOGIN "if [ -f $F_LINKDIR/$F_LINKNAME ]; then readlink $F_LINKDIR/$F_LINKNAME; fi"
			local F_LINKTARGETPATH=$RUN_CMD_RES
			if [ "$F_LINKTARGETPATH" = "" ]; then
				echo $P_DST_HOSTLOGIN: $F_LINKNAME $C_DISTR_TYPE not found in $F_LINKDIR. Backup skipped.
				return 0
			fi

			f_run_cmdcheck $P_DST_HOSTLOGIN "mkdir -p $F_DSTDIR_BACKUP; echo $F_LINKPATH > $F_DSTDIR_BACKUP/$F_LINKNAME.link"
			echo $P_DST_HOSTLOGIN: link backup created - $F_LINKNAME.link references $F_LINKTARGETPATH

		# backup static
		elif [ "$P_DEPLOYTYPE" = "static" ]; then
			local F_ARCHIVE_DIR="$F_RUNTIMEDIR"
			local F_ARCHIVE_NAME=$C_DISTR_WAR_CONTEXT
			local F_ARCHIVE_SAVENAME="archive.$S_REDIST_ARCHIVE_TYPE_CHILD.$C_DISTR_WAR_CONTEXT.tar.gz"

			# create archive and copy to backup
			f_run_cmd $P_DST_HOSTLOGIN "if [ -d $F_ARCHIVE_DIR/$F_ARCHIVE_NAME ]; then echo ok; fi"
			if [ "$RUN_CMD_RES" != "ok" ]; then
				echo $P_DST_HOSTLOGIN: $F_ARCHIVE_DIR/$F_ARCHIVE_NAME static not found. Backup skipped.
				return 0
			fi

			f_run_cmdcheck $P_DST_HOSTLOGIN "mkdir -p $F_DSTDIR_BACKUP; cd $F_ARCHIVE_DIR; tar zcf $F_DSTDIR_BACKUP/$F_ARCHIVE_SAVENAME $F_ARCHIVE_NAME; if [ \$? -ne 0 ]; then echo failed; fi"

			echo $P_DST_HOSTLOGIN: static backup of $F_ARCHIVE_DIR/$F_ARCHIVE_NAME created in $F_DSTDIR_BACKUP/$F_ARCHIVE_SAVENAME
		fi
	fi

	# backup archive - by content
	if [[ "$C_DISTR_TYPE" =~ ^archive ]]; then
		local F_ARCHIVE_DIR
		local F_ARCHIVE_SAVENAME
		if [ "$C_DISTR_TYPE" = "archive.direct" ]; then
			F_ARCHIVE_DIR="$F_RUNTIMEDIR"
			F_ARCHIVE_SAVENAME="archive.$S_REDIST_ARCHIVE_TYPE_DIRECT.$C_DISTR_KEY.tar.gz"
		elif [ "$C_DISTR_TYPE" = "archive.child" ] || [ "$C_DISTR_TYPE" = "archive.subdir" ]; then
			F_ARCHIVE_DIR="$F_RUNTIMEDIR/$C_DISTR_DEPLOYBASENAME"
			F_ARCHIVE_SAVENAME="archive.$S_REDIST_ARCHIVE_TYPE_SUBDIR.$C_DISTR_DEPLOYBASENAME.tar.gz"
		fi

		# create archive and copy to backup
		f_run_cmd $P_DST_HOSTLOGIN "if [ -d $F_ARCHIVE_DIR ]; then echo ok; fi"
		if [ "$RUN_CMD_RES" != "ok" ]; then
			echo $P_DST_HOSTLOGIN: $F_ARCHIVE_DIR $C_DISTR_TYPE not found. Backup skipped.
			return 0
		fi

		f_run_cmdcheck $P_DST_HOSTLOGIN "mkdir -p $F_DSTDIR_BACKUP; cd $F_ARCHIVE_DIR; tar zcf $F_DSTDIR_BACKUP/$F_ARCHIVE_SAVENAME *; if [ \$? -ne 0 ]; then echo failed; fi"

		echo $P_DST_HOSTLOGIN: archive backup of $F_ARCHIVE_DIR created in $F_DSTDIR_BACKUP/$F_ARCHIVE_SAVENAME
	fi
}

function f_redist_prepare_deleteobsolete() {
	local P_SERVER=$1
	local P_DEPLOYTYPE=$2
	local P_DST_HOSTLOGIN=$3
	local P_ROOTDIR=$4
	local P_RELEASENAME=$5
	local P_LOCATION=$6
	local P_LINKFROM_DIR="$7"
	local P_OBSOLETE_LIST="$8"

	if [ "$P_SERVER" = "" ] || [ "$P_DEPLOYTYPE" = "" ] || [ "$P_DST_HOSTLOGIN" = "" ] || [ "$P_OBSOLETE_LIST" = "" ]; then
		echo f_redist_prepare_deleteobsolete: invalid call
		exit 1
	fi
	if [ "$P_ROOTDIR" = "" ] || [ "$P_RELEASENAME" = "" ] || [ "$P_LOCATION" = "" ]; then
		echo f_redist_prepare_deleteobsolete: invalid call
		exit 1
	fi

	local F_REDISTTYPE_DEPLOY="deploy"
	local F_REDISTTYPE_BACKUP="deploy.backup"
	if [ "$P_DEPLOYTYPE" = "hotdeploy" ]; then
		F_REDISTTYPE_DEPLOY="hotdeploy"
		F_REDISTTYPE_BACKUP="hotdeploy.backup"
	fi

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE_DEPLOY
	local F_DSTDIR_DEPLOY=$C_COMMON_DIRPATH

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE_BACKUP
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	# find obsolete if any
	local F_REDIST_OBSOLETELIST=
	for oname in $P_OBSOLETE_LIST; do	
		f_distr_readitem $oname

		# backup binary file
		if [ "$C_DISTR_DEPLOYBASENAME" != "" ]; then
			f_find_file $F_RUNTIMEDIR $C_DISTR_DEPLOYBASENAME $C_DISTR_EXT $P_DST_HOSTLOGIN
			if [ "$C_COMMON_FINDFILE_NAME" != "" ]; then
				local F_BASENAME=$(basename $C_COMMON_FINDFILE_NAME)
				F_REDIST_OBSOLETELIST="$F_REDIST_OBSOLETELIST $F_RUNTIMEDIR/$F_BASENAME"
			fi
		fi
	done	

	# save obsolete list in obsolete.txt
	if [ "$F_REDIST_OBSOLETELIST" != "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo create obsolete.txt to delete obsolete files: $F_REDIST_OBSOLETELIST
		fi
		f_run_cmd $P_DST_HOSTLOGIN "echo $F_REDIST_OBSOLETELIST | tr \" \" \"\n\" > $F_DSTDIR_DEPLOY/obsolete.txt"
	else
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo obsolete files are not found, ignored.
		fi
		return 0
	fi

	# backup obsolete files if required
	if [ "$C_REDIST_NOBACKUP" = "true" ]; then
		return 0
	fi

	for oname in $P_OBSOLETE_LIST; do
		f_redist_savebackup $P_SERVER $P_DEPLOYTYPE $P_DST_HOSTLOGIN $P_ROOTDIR $oname $P_RELEASENAME $P_LOCATION $P_LINKFROM_DIR
	done		
}

function f_redist_transfer_fileset() {
	local P_SERVER=$1
	local P_DEPLOYTYPE=$2
	local P_DST_HOSTLOGIN=$3
	local P_ROOTDIR=$4
	local P_DIST_ITEMS="$5"
	local P_RELEASENAME=$6
	local P_LOCATION=$7
	local P_LINKFROM_DIR="$8"
	local P_REDIST_SRCPATH=$9
	local P_REDIST_DISTR_REMOTEHOST=${10}

	if [ "$P_SERVER" = "" ] || [ "$P_DEPLOYTYPE" = "" ] || [ "$P_RELEASENAME" = "" ] || [ "$P_DST_HOSTLOGIN" = "" ]; then
		echo f_redist_transfer_fileset: invalid call
		exit 1
	fi
	if [ "$P_LOCATION" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_DIST_ITEMS" = "" ] || [ "$P_REDIST_SRCPATH" = "" ]; then
		echo f_redist_transfer_fileset: invalid call
		exit 1
	fi

	local F_REDISTTYPE_DEPLOY="deploy"
	local F_REDISTTYPE_BACKUP="deploy.backup"
	if [ "$P_DEPLOYTYPE" = "hotdeploy" ]; then
		F_REDISTTYPE_DEPLOY="hotdeploy"
		F_REDISTTYPE_BACKUP="hotdeploy.backup"
	fi

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE_DEPLOY
	local F_DSTDIR_DEPLOY=$C_COMMON_DIRPATH

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE_BACKUP
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH

	# ensure redist created
	f_run_cmd $P_DST_HOSTLOGIN "mkdir -p $F_DSTDIR_DEPLOY; mkdir -p $F_DSTDIR_BACKUP"

	echo "$P_DST_HOSTLOGIN: redist path=$F_DSTDIR_DEPLOY: items - $P_DIST_ITEMS..."
	local F_RELEASE=${P_RELEASENAME%%-*}
	local item
	for item in $P_DIST_ITEMS; do
		f_redist_transfer_file $P_DEPLOYTYPE $F_RELEASE $P_DST_HOSTLOGIN $item $P_REDIST_SRCPATH $F_DSTDIR_DEPLOY $P_REDIST_DISTR_REMOTEHOST
		if [ "$?" -eq 0 ]; then
			f_redist_savebackup $P_SERVER $P_DEPLOYTYPE $P_DST_HOSTLOGIN $P_ROOTDIR $item $P_RELEASENAME $P_LOCATION $P_LINKFROM_DIR
		fi
	done
}

function f_redist_transfer_staticset() {
	local P_SERVER=$1
	local P_DST_HOSTLOGIN=$2
	local P_ROOTDIR=$3
	local P_DIST_ITEMS="$4"
	local P_RELEASENAME=$5
	local P_LOCATION=$6
	local P_REDIST_SRCPATH=$7
	local P_REDIST_DISTR_REMOTEHOST=$8

	if [ "$P_SERVER" = "" ] || [ "$P_RELEASENAME" = "" ] || [ "$P_DST_HOSTLOGIN" = "" ] || [ "$P_REDIST_SRCPATH" = "" ]; then
		echo f_redist_transfer_staticset: invalid call
		exit 1
	fi
	if [ "$P_ROOTDIR" = "" ] || [ "$P_LOCATION" = "" ] || [ "$P_DIST_ITEMS" = "" ]; then
		echo f_redist_transfer_staticset: invalid call
		exit 1
	fi

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION "deploy"
	local F_DSTDIR_DEPLOY=$C_COMMON_DIRPATH

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION "deploy.backup"
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH

	# ensure redist created
	f_run_cmd $P_DST_HOSTLOGIN "mkdir -p $F_DSTDIR_DEPLOY; mkdir -p $F_DSTDIR_BACKUP"

	echo "$P_DST_HOSTLOGIN: redist path=$F_DSTDIR_DEPLOY: static items - $P_DIST_ITEMS..."

	local F_RELEASE=${P_RELEASENAME%%-*}
	local item
	for item in $P_DIST_ITEMS; do
		f_redist_transfer_file static $F_RELEASE $P_DST_HOSTLOGIN $item $P_REDIST_SRCDIR $P_REDIST_SRCPATH $F_DSTDIR_DEPLOY $P_REDIST_DISTR_REMOTEHOST
		if [ "$?" -eq 0 ]; then
			f_redist_savebackup $P_SERVER static $P_DST_HOSTLOGIN $P_ROOTDIR $item $P_RELEASENAME $P_LOCATION
		fi
	done
}

function f_redist_rollout_archives() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_ROOTDIR=$3
	local P_RELEASENAME=$4
	local P_LOCATION=$5
	local P_DEPLOY_ARCHIVE_LIST="$6"

	if [ "$P_DEPLOY_ARCHIVE_LIST" = "" ]; then
		return 0
	fi

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION "deploy"
	local F_DSTDIR=$C_COMMON_DIRPATH

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	# rollout - by content
	local x
	for x in $P_DEPLOY_ARCHIVE_LIST; do
		f_redist_deploy_archiveitem $P_HOSTLOGIN $F_DSTDIR $F_RUNTIMEDIR $x
	done
}

function f_redist_rollout_generic() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_NODE=$3
	local P_ROOTDIR=$4
	local P_RELEASENAME=$5
	local P_LOCATION=$6
	local P_DEPLOYTYPE=$7
	local P_HOTDEPLOYDIR="$8"
	local P_LINKFROMDIR="$9"

	if [ "$P_RELEASENAME" = "" ] || [ "$P_SERVER" = "" ] || [ "$P_NODE" = "" ] || [ "$P_ENV_HOSTLOGIN" = "" ]; then
		echo f_redist_rollout_generic: invalid call
		exit 1
	fi
	if [ "$P_DEPLOYTYPE" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_LOCATION" = "" ]; then
		echo f_redist_rollout_generic: invalid call
		exit 1
	fi
	if [ "$P_DEPLOYTYPE" = "hotdeploy" ] && [ "$P_HOTDEPLOYDIR" = "" ]; then
		echo f_redist_rollout_generic: invalid call - hotdeploypath is required for hot deploy
		exit 1
	fi

	local F_REDISTTYPE="deploy"
	local F_REDISTTYPE_BACKUP="deploy.backup"
	if [ "$P_DEPLOYTYPE" = "hotdeploy" ]; then
		F_REDISTTYPE="hotdeploy"
		F_REDISTTYPE_BACKUP="hotdeploy.backup"
	fi

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE
	local F_DSTDIR_DEPLOY=$C_COMMON_DIRPATH

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE_BACKUP
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	if [ "$P_DEPLOYTYPE" = "links-multidir" ]; then
		F_RUNTIMEDIR="$F_RUNTIMEDIR/release-$P_RELEASENAME"
	fi

	# get content
	f_redist_getdiritems $P_ENV_HOSTLOGIN $F_DSTDIR_DEPLOY
	local F_DEPLOY_BINARY_LIST="$C_REDIST_DIRITEMS_BINARY"
	C_REDIST_UPDATED_ITEMS="$F_DEPLOY_BINARY_LIST"

	local F_DEPLOY_MASKEDBINARY_LIST="$C_REDIST_DIRITEMS_MASKEDBINARY"
	local F_DEPLOY_ARCHIVE_LIST="$C_REDIST_DIRITEMS_ARCHIVE"
	local F_DEPLOY_OBSOLETE_LIST="$C_REDIST_DIRITEMS_OBSOLETE"
	local F_REDIST_DIRITEMS_ISPGUSTATIC=$C_REDIST_DIRITEMS_ISPGUSTATIC

	if [ "$C_REDIST_DIRITEMS_ISEMPTY" = "true" ]; then
		echo $P_ENV_HOSTLOGIN: nothing to roll out
		return 1
	fi

	f_redist_getdiritems $P_ENV_HOSTLOGIN $F_DSTDIR_BACKUP
	local F_DELETE_BINARY_LIST="$C_REDIST_DIRITEMS_BINARY"

	echo $P_ENV_HOSTLOGIN: ============================================ rollout app=$P_SERVER node=$P_NODE location=$P_LOCATION deploytype=$P_DEPLOYTYPE ...

	# execute prepare
	f_redist_execute $P_ENV_HOSTLOGIN "cd $F_DSTDIR_DEPLOY; ./prepare.sh"

	if [ "$P_DEPLOYTYPE" = "default" ] || [ "$P_DEPLOYTYPE" = "hotdeploy" ]; then
		# remove old
		if [ "$F_DEPLOY_MASKEDBINARY_LIST" != "" ] || [ "$F_DELETE_BINARY_LIST" != "" ] || [ "$F_DEPLOY_OBSOLETE_LIST" != "" ]; then
			f_redist_execute $P_ENV_HOSTLOGIN "cd $F_RUNTIMEDIR; rm -rf $F_DEPLOY_MASKEDBINARY_LIST $F_DELETE_BINARY_LIST $F_DEPLOY_OBSOLETE_LIST"
		fi

		# deploy new
		if [ "$F_DEPLOY_BINARY_LIST" != "" ]; then
			f_redist_execute $P_ENV_HOSTLOGIN "cd $F_DSTDIR_DEPLOY; cp -t $F_RUNTIMEDIR $F_DEPLOY_BINARY_LIST"

			# hotdeploy mode - additional copy to upload dir
			if [ "$P_DEPLOYTYPE" = "hotdeploy" ]; then
				f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_HOTDEPLOYDIR
				local F_HOTUPLOADDIR=$C_COMMON_DIRPATH

				f_redist_execute $P_ENV_HOSTLOGIN "cd $F_DSTDIR_DEPLOY; cp -t $F_HOTUPLOADDIR $F_DEPLOY_BINARY_LIST"
			fi
		fi

	elif [ "$P_DEPLOYTYPE" = "links-multidir" ] || [ "$P_DEPLOYTYPE" = "links-singledir" ]; then
		f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LINKFROMDIR
		local F_RUNTIMELINKDIR=$C_COMMON_DIRPATH

		# deploy and create links
		f_redist_execute $P_ENV_HOSTLOGIN "mkdir -p $F_RUNTIMEDIR"

		# remove old
		if [ "$F_DEPLOY_MASKEDBINARY_LIST" != "" ] || [ "$F_DELETE_BINARY_LIST" != "" ] || [ "$F_DEPLOY_OBSOLETE_LIST" != "" ]; then
			f_redist_execute $P_ENV_HOSTLOGIN "cd $F_RUNTIMEDIR; rm -rf $F_DEPLOY_MASKEDBINARY_LIST $F_DELETE_BINARY_LIST $F_DEPLOY_OBSOLETE_LIST"
		fi

		for x in $F_DEPLOY_BINARY_LIST; do
			f_redist_execute $P_ENV_HOSTLOGIN "cp $F_DSTDIR_DEPLOY/$x $F_RUNTIMEDIR; cd $F_RUNTIMELINKDIR; rm -rf $x; ln -s $F_RUNTIMEDIR/$x $x"
		done
	fi

	# deploy archives
	# rollout first pgu static if any
	if [ "$F_REDIST_DIRITEMS_ISPGUSTATIC" = "true" ]; then
		f_redist_rollout_archives $P_SERVER $P_ENV_HOSTLOGIN $P_ROOTDIR $P_RELEASENAME $P_LOCATION "$S_REDIST_PGU_STATIC_FILENAME"
	fi

	if [ "$F_DEPLOY_ARCHIVE_LIST" != "" ]; then
		f_redist_rollout_archives $P_SERVER $P_ENV_HOSTLOGIN $P_ROOTDIR $P_RELEASENAME $P_LOCATION "$F_DEPLOY_ARCHIVE_LIST"
	fi

	return 0
}

function f_redist_rollback_archives() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_ROOTDIR=$3
	local P_RELEASENAME=$4
	local P_LOCATION=$5
	local P_DEPLOY_ARCHIVE_LIST="$6"

	if [ "$P_DEPLOY_ARCHIVE_LIST" = "" ]; then
		return 0
	fi

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION "deploy.backup"
	local F_DSTDIR=$C_COMMON_DIRPATH

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	# rollout - by content
	local x
	for x in $P_DEPLOY_ARCHIVE_LIST; do
		f_redist_deploy_archiveitem $P_HOSTLOGIN $F_DSTDIR $F_RUNTIMEDIR $x
	done
}

function f_redist_rollback_generic() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_NODE=$3
	local P_ROOTDIR=$4
	local P_RELEASENAME=$5
	local P_LOCATION=$6
	local P_DEPLOYTYPE=$7
	local P_HOTDEPLOYDIR="$8"
	local P_LINKFROMDIR="$9"

	if [ "$P_RELEASENAME" = "" ] || [ "$P_SERVER" = "" ] || [ "$P_NODE" = "" ] || [ "$P_ENV_HOSTLOGIN" = "" ]; then
		echo f_redist_rollback_generic: invalid call
		exit 1
	fi
	if [ "$P_DEPLOYTYPE" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_LOCATION" = "" ]; then
		echo f_redist_rollback_generic: invalid call
		exit 1
	fi
	if [ "$P_DEPLOYTYPE" = "hotdeploy" ] && [ "$P_HOTDEPLOYDIR" = "" ]; then
		echo f_redist_rollback_generic: invalid call
		exit 1
	fi

	local F_REDISTTYPE="deploy"
	local F_REDISTTYPE_BACKUP="deploy.backup"
	if [ "$P_DEPLOYTYPE" = "hotdeploy" ]; then
		F_REDISTTYPE="hotdeploy"
		F_REDISTTYPE_BACKUP="hotdeploy.backup"
	fi

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE
	local F_DSTDIR_DEPLOY=$C_COMMON_DIRPATH

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE_BACKUP
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	# get content
	f_redist_getdiritems $P_ENV_HOSTLOGIN $F_DSTDIR_DEPLOY
	local F_DEPLOY_BINARY_LIST="$C_REDIST_DIRITEMS_BINARY"
	C_REDIST_UPDATED_ITEMS="$F_DEPLOY_BINARY_LIST"

	local F_DEPLOY_ARCHIVE_LIST=$C_REDIST_DIRITEMS_ARCHIVE

	f_redist_getdiritems $P_ENV_HOSTLOGIN $F_DSTDIR_BACKUP
	local F_DELETE_BINARY_LIST=$C_REDIST_DIRITEMS_BINARY
	local F_DELETE_LINK_LIST=$C_REDIST_DIRITEMS_LINK
	local F_DELETE_ARCHIVE_LIST=$C_REDIST_DIRITEMS_ARCHIVE
	local F_REDIST_DIRITEMS_ISPGUSTATIC=$C_REDIST_DIRITEMS_ISPGUSTATIC

	if [ "$C_REDIST_DIRITEMS_ISEMPTY" = "true" ]; then
		echo $P_ENV_HOSTLOGIN: nothing to rollback
		return 1
	fi

	echo $P_ENV_HOSTLOGIN: ============================================ rollback app=$P_SERVER node=$P_NODE location=$P_LOCATION deploytype=$P_DEPLOYTYPE ...

	# execute prepare
	f_redist_execute $P_ENV_HOSTLOGIN "cd $F_DSTDIR_BACKUP; ./prepare.sh"

	if [ "$P_DEPLOYTYPE" = "default" ] || [ "$P_DEPLOYTYPE" = "hotdeploy" ]; then
		# remove old and new
		f_redist_execute $P_ENV_HOSTLOGIN "cd $F_RUNTIMEDIR; rm -rf $F_DELETE_BINARY_LIST $F_DEPLOY_BINARY_LIST"

		# deploy old
		if [ "$F_DELETE_BINARY_LIST" != "" ]; then
			f_redist_execute $P_ENV_HOSTLOGIN "cd $F_DSTDIR_BACKUP; cp -t $F_RUNTIMEDIR $F_DELETE_BINARY_LIST"

			# hotdeploy mode - additional copy to upload dir
			if [ "$P_DEPLOYTYPE" = "hotdeploy" ]; then
				f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_HOTDEPLOYDIR
				local F_HOTUPLOADDIR=$C_COMMON_DIRPATH

				f_redist_execute $P_ENV_HOSTLOGIN "cd $F_DSTDIR_BACKUP; cp -t $F_HOTUPLOADDIR $F_DELETE_BINARY_LIST"
			fi
		fi
	elif [ "$P_DEPLOYTYPE" = "links-multidir" ]; then
		f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LINKFROMDIR
		local F_RUNTIMELINKDIR=$C_COMMON_DIRPATH

		# restore links
		for x in $F_DELETE_LINK_LIST; do
			F_BASENAME=`echo $x | sed "s/\.link//g"`

			f_run_cmd $P_ENV_HOSTLOGIN "cat $F_DSTDIR_BACKUP/$x"
			F_OLDLINK=$RUN_CMD_RES
 
			f_redist_execute $P_ENV_HOSTLOGIN "cd $F_RUNTIMELINKDIR; rm -rf $F_BASENAME; ln -s $F_OLDLINK $F_BASENAME"
		done		

	elif [ "$P_DEPLOYTYPE" = "links-singledir" ]; then
		f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LINKFROMDIR
		local F_RUNTIMELINKDIR=$C_COMMON_DIRPATH

		# deploy and create links
		f_redist_execute $P_ENV_HOSTLOGIN "mkdir -p $F_RUNTIMEDIR"

		# remove old
		if [ "$F_DEPLOY_MASKEDBINARY_LIST" != "" ] || [ "$F_DELETE_BINARY_LIST" != "" ] || [ "$F_DEPLOY_OBSOLETE_LIST" != "" ]; then
			f_redist_execute $P_ENV_HOSTLOGIN "cd $F_RUNTIMEDIR; rm -rf $F_DEPLOY_MASKEDBINARY_LIST $F_DELETE_BINARY_LIST $F_DEPLOY_OBSOLETE_LIST"
		fi

		for x in $F_DEPLOY_BINARY_LIST; do
			f_redist_execute $P_ENV_HOSTLOGIN "cp $F_DSTDIR_BACKUP/$x $F_RUNTIMEDIR; cd $F_RUNTIMELINKDIR; rm -rf $x; ln -s $F_RUNTIMEDIR/$x $x"
		done
	fi

	# deploy archives
	# rollback first pgu static if any
	if [ "$F_REDIST_DIRITEMS_ISPGUSTATIC" = "true" ]; then
		f_redist_rollback_archives $P_SERVER $P_ENV_HOSTLOGIN $P_ROOTDIR $P_RELEASENAME $P_LOCATION "$S_REDIST_PGU_STATIC_FILENAME"
	fi

	if [ "$F_DEPLOY_ARCHIVE_LIST" != "" ]; then
		f_redist_rollback_archives $P_SERVER $P_ENV_HOSTLOGIN $P_ROOTDIR $P_RELEASENAME $P_LOCATION "$F_DELETE_ARCHIVE_LIST"
	fi

	return 0
}
