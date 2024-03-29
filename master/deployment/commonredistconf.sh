#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

S_COMMONREDISTCONF_RELADM_TMPDIR=/tmp/$HOSTNAME.$USER.commonredistconf.p$$

function f_redist_rollout_config() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_NODE=$3
	local P_ROOTDIR=$4
	local P_RELEASENAME=$5
	local P_LOCATION=$6

	if [ "$P_RELEASENAME" = "" ] || [ "$P_SERVER" = "" ] || [ "$P_NODE" = "" ] || [ "$P_ENV_HOSTLOGIN" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_LOCATION" = "" ]; then
		echo f_redist_rollout_config: invalid call
		exit 1
	fi

	f_getpath_statelocation $P_SERVER $P_LOCATION "config"
	local F_DSTDIR_STATE=$C_COMMON_DIRPATH

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION "config"
	local F_DSTDIR_DEPLOY=$C_COMMON_DIRPATH

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	f_redist_getlocationinfo $P_SERVER $P_ENV_HOSTLOGIN $P_RELEASENAME $P_LOCATION "config"
	local F_REDIST_CONFIG_TARS="$C_REDIST_DEPLOY_CONTENT_CONFIG"
	local F_REDIST_CONFIG_VER="$C_REDIST_DEPLOY_CONTENT_VER"

	if [ "$F_REDIST_CONFIG_TARS" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo "$P_ENV_HOSTLOGIN: $F_DSTDIR_DEPLOY is empty. Skipped"
		fi
		return 1
	fi

	echo $P_ENV_HOSTLOGIN: ============================================ rollout configuration app=$P_SERVER node=$P_NODE, location=$P_LOCATION ...

	# remove old
	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo $P_ENV_HOSTLOGIN: run $F_DSTDIR_DEPLOY/prepare.sh before deploy ...
	fi
	f_redist_execute $P_ENV_HOSTLOGIN "mkdir -p $F_RUNTIMEDIR; $F_DSTDIR_DEPLOY/prepare.sh; mkdir -p $F_DSTDIR_STATE; cd $F_DSTDIR_STATE; rm -rf $F_REDIST_CONFIG_VER"

	# deploy new
	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo $P_ENV_HOSTLOGIN: deploy new from $F_DSTDIR_DEPLOY to $F_RUNTIMEDIR ...
	fi
	local F_LOGIN=${P_ENV_HOSTLOGIN%%@*}
	f_redist_execute $P_ENV_HOSTLOGIN "cd $F_RUNTIMEDIR; for tf in $F_REDIST_CONFIG_TARS; do tar xmf $F_DSTDIR_DEPLOY/\$tf.config.tar -o --owner=$F_LOGIN > /dev/null; done"

	if [ "$F_REDIST_CONFIG_VER" != "" ]; then
		f_redist_execute $P_ENV_HOSTLOGIN "cd $F_DSTDIR_DEPLOY; cp -t $F_DSTDIR_STATE $F_REDIST_CONFIG_VER"
	fi

	return 0
}

function f_redist_rollback_config() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_NODE=$3
	local P_ROOTDIR=$4
	local P_RELEASENAME=$5
	local P_LOCATION=$6

	if [ "$P_RELEASENAME" = "" ] || [ "$P_SERVER" = "" ] || [ "$P_NODE" = "" ] || [ "$P_ENV_HOSTLOGIN" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_LOCATION" = "" ]; then
		echo f_redist_rollout_config: invalid call
		exit 1
	fi

	f_getpath_statelocation $P_SERVER $P_LOCATION "config.backup"
	local F_DSTDIR_STATE=$C_COMMON_DIRPATH

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION "config.backup"
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	f_redist_getlocationinfo $P_SERVER $P_ENV_HOSTLOGIN $P_RELEASENAME $P_LOCATION "config"
	local F_REDIST_CONFIG_TARS="$C_REDIST_DEPLOY_BACKUP_CONTENT_CONFIG"
	local F_REDIST_CONFIG_VER="$C_REDIST_DEPLOY_BACKUP_CONTENT_VER"

	if [ "$F_REDIST_CONFIG_TARS" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo "$P_ENV_HOSTLOGIN: $F_DSTDIR_BACKUP is empty. Skipped"
		fi
		return 1
	fi

	echo $P_ENV_HOSTLOGIN: ============================================ rollback configuration app=$P_SERVER node=$P_NODE, location=$P_LOCATION ...

	# remove current
	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo $P_ENV_HOSTLOGIN: run $F_DSTDIR_BACKUP/prepare.sh before rollback ...
	fi
	f_redist_execute $P_ENV_HOSTLOGIN "mkdir -p $F_RUNTIMEDIR; $F_DSTDIR_BACKUP/prepare.sh; mkdir -p $F_DSTDIR_STATE; cd $F_DSTDIR_STATE; rm -rf $F_REDIST_CONFIG_VER"

	# restore from backup
	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo $P_ENV_HOSTLOGIN: restore from backup $F_DSTDIR_BACKUP to $F_RUNTIMEDIR ...
	fi
	local F_LOGIN=${P_ENV_HOSTLOGIN%%@*}
	f_redist_execute $P_ENV_HOSTLOGIN "cd $F_RUNTIMEDIR; for tf in $F_REDIST_CONFIG_TARS; do tar xmf $F_DSTDIR_BACKUP/\$tf.config.tar -o --owner=$F_LOGIN > /dev/null; done"

	if [ "$F_REDIST_CONFIG_VER" != "" ]; then
		f_redist_execute $P_ENV_HOSTLOGIN "cd $F_DSTDIR_BACKUP; cp -t $F_DSTDIR_STATE $F_REDIST_CONFIG_VER"
	fi

	return 0
}

function f_redist_fillconfpreparescript_content() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_ROOTDIR=$3
	local P_RELEASENAME=$4
	local P_LOCATION=$5
	local P_FILEMASK="$6"
	local P_DIRTYPE=$7
	local P_REDIST_CONFTYPE=$8
	local P_REDIST_FILES="$9"
	local P_PARTIAL=${10}

	if [ "$P_PARTIAL" = "true" ]; then
		return 0
	fi

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	local F_REDISTTYPE_DEPLOY=$P_DIRTYPE
	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE_DEPLOY
	local F_DSTDIR_DEPLOY=$C_COMMON_DIRPATH
	local F_DSTDIR_DEPLOY_PREPAREFILE=$F_DSTDIR_DEPLOY/prepare.sh

	local F_REDISTTYPE_BACKUP=$P_DIRTYPE.backup
	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE_BACKUP
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH
	local F_DSTDIR_BACKUP_PREPAREFILE=$F_DSTDIR_BACKUP/prepare.sh

	# create pre-deploy/restore delete instruction
	if [ "$P_REDIST_CONFTYPE" = "dir" ]; then
		# use all files
		f_run_cmdcheck $P_ENV_HOSTLOGIN "echo \"rm -rf $F_RUNTIMEDIR/*\" >> $F_DSTDIR_DEPLOY_PREPAREFILE"
		f_run_cmdcheck $P_ENV_HOSTLOGIN "echo \"rm -rf $F_RUNTIMEDIR/*\" >> $F_DSTDIR_BACKUP_PREPAREFILE"

	elif [ "$P_REDIST_CONFTYPE" = "files" ] || [ "$P_REDIST_CONFTYPE" = "mixed-dir" ]; then
		if [ "$P_REDIST_FILES" = "" ]; then
			echo f_redist_fillconfpreparescript_content: unexpected empty P_REDIST_FILES. Exiting
			exit 1
		fi

		# use selected files only
		local F_DEPTHMODIFIER
		if [ "$P_REDIST_CONFTYPE" = "files" ]; then
			F_DEPTHMODIFIER="-maxdepth 1"
		else
			F_DEPTHMODIFIER=
		fi

		f_run_cmdcheck $P_ENV_HOSTLOGIN "echo \"cd $F_RUNTIMEDIR; find . $F_DEPTHMODIFIER \\( $P_FILEMASK \\) -exec rm -rf {} \\;\" >> $F_DSTDIR_DEPLOY_PREPAREFILE"
		f_run_cmdcheck $P_ENV_HOSTLOGIN "echo \"cd $F_RUNTIMEDIR; find . $F_DEPTHMODIFIER \\( $P_FILEMASK \\) -exec rm -rf {} \\;\" >> $F_DSTDIR_BACKUP_PREPAREFILE"
	else
		echo f_redist_fillconfpreparescript_content: unknown P_REDIST_CONFTYPE=$P_REDIST_CONFTYPE. Exiting
		exit 1
	fi
}

function f_redist_fillconfpreparescript_andbackup() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_ROOTDIR=$3
	local P_RELEASENAME=$4
	local P_LOCATION=$5
	local P_CONFCOMP=$6
	local P_DIRTYPE=$7
	local P_REDIST_CONFTYPE=$8
	local P_REDIST_FILES="$9"
	local P_PARTIAL=${10}

	# calculate file mask
	local F_FILEMASK=
	if [ "$P_REDIST_CONFTYPE" = "files" ] || [ "$P_REDIST_CONFTYPE" = "mixed-dir" ]; then
		local mitem
		for mitem in $P_REDIST_FILES; do
			if [ "$F_FILEMASK" != "" ]; then
				F_FILEMASK="$F_FILEMASK -o"
			fi
			F_FILEMASK="$F_FILEMASK -name '$mitem'"
		done
	fi

	# fill and deploy delete script
	f_redist_fillconfpreparescript_content $P_SERVER $P_ENV_HOSTLOGIN $P_ROOTDIR $P_RELEASENAME $P_LOCATION "$F_FILEMASK" $P_DIRTYPE $P_REDIST_CONFTYPE "$P_REDIST_FILES" $P_PARTIAL

	# backup logic
	if [ "$C_REDIST_NOBACKUP" = "true" ]; then
		return 1
	fi		

	f_getredisttypes_bydeploytype $P_DEPLOYTYPE
	local F_REDISTTYPE=$C_ROLLOUT_REDISTTYPE
	local F_REDISTTYPE_BACKUP=$C_ROLLBACK_REDISTTYPE

	f_getpath_statelocation $P_SERVER $P_LOCATION $F_REDISTTYPE
	local F_DSTDIR_STATE=$C_COMMON_DIRPATH

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $F_REDISTTYPE_BACKUP
	local F_DSTDIR_BACKUP=$C_COMMON_DIRPATH

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	local F_CONFIGTARFILE=$P_CONFCOMP.config.tar

	# full backup even if partial deploy
	if [ "$P_REDIST_FILES" = "" ]; then
		# use all files
		f_run_cmdcheck $P_ENV_HOSTLOGIN "mkdir -p $F_DSTDIR_BACKUP; cd $F_RUNTIMEDIR; tar cf $F_DSTDIR_BACKUP/$F_CONFIGTARFILE ."
	else
		# use selected files only
		f_run_cmd $P_ENV_HOSTLOGIN "cd $F_RUNTIMEDIR; find . \\( $F_FILEMASK \\) | tr '\n' ' '"
		local F_FILES="$RUN_CMD_RES"

		if [ "$F_FILES" = "" ]; then
			f_run_cmdcheck $P_ENV_HOSTLOGIN "mkdir -p $F_DSTDIR_BACKUP; cd $F_RUNTIMEDIR; tar cfT $F_DSTDIR_BACKUP/$F_CONFIGTARFILE /dev/null"
		else
			f_run_cmdcheck $P_ENV_HOSTLOGIN "mkdir -p $F_DSTDIR_BACKUP; cd $F_RUNTIMEDIR; tar cf $F_DSTDIR_BACKUP/$F_CONFIGTARFILE $F_FILES"
		fi
	fi

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo $P_ENV_HOSTLOGIN: backup created - $F_DSTDIR_BACKUP/$F_CONFIGTARFILE
	fi

	local F_STATEFILE=$F_DSTDIR_STATE/$P_CONFCOMP.ver
	f_run_cmdcheck $P_ENV_HOSTLOGIN "if [ -f $F_STATEFILE ]; then cp $F_STATEFILE $F_DSTDIR_BACKUP; fi"
}

function f_redist_transfer_configset() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_ROOTDIR=$3
	local P_RELEASENAME=$4
	local P_LOCATION=$5
	local P_CONFCOMP=$6
	local P_DIRTYPE=$7
	local P_PARTIAL=$8
	local P_REDIST_SRCPATH=$9
	local P_REDIST_DISTR_REMOTEHOST=${10}

	if [ "$P_SERVER" = "" ] || [ "$P_ENV_HOSTLOGIN" = "" ] || [ "$P_RELEASENAME" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_LOCATION" = "" ]; then
		echo f_redist_transfer_configset: invalid call
		exit 1
	fi
	if [ "$P_PARTIAL" = "" ] || [ "$P_DIRTYPE" = "" ] || [ "$P_CONFCOMP" = "" ] || [ "$P_REDIST_SRCPATH" = "" ]; then
		echo f_redist_transfer_configset: invalid call
		exit 1
	fi

	# get component information
	f_distr_getconfcompinfo $P_CONFCOMP
	local F_REDIST_CONFTYPE=$C_DISTR_CONF_TYPE
	local F_REDIST_FILES="$C_DISTR_CONF_FILES"

	f_getpath_redistlocation $P_SERVER $P_RELEASENAME $P_LOCATION $P_DIRTYPE
	local F_DSTDIR_DEPLOY=$C_COMMON_DIRPATH

	local F_CONFIGTARFILE=$P_CONFCOMP.config.tar
	local F_CONFIGTARMD5NAME=$P_CONFCOMP.ver

	local F_TMPDIR=$S_COMMONREDISTCONF_RELADM_TMPDIR
	rm -rf $F_TMPDIR
	mkdir -p $F_TMPDIR

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo $P_ENV_HOSTLOGIN: copy $P_REDIST_SRCPATH to $F_DSTDIR_DEPLOY ...
	fi

	local F_COPYSET
	if [ "$P_REDIST_DISTR_REMOTEHOST" = "release" ]; then
		F_COPYSET=$F_TMPDIR/config

		# copy from release box to tmpdir
		f_release_downloaddir $P_REDIST_SRCPATH $F_COPYSET
		if [ $? != 0 ]; then
			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo "f_redist_transfer_configset: not found configuration files at release host in $P_REDIST_SRCPATH. Skipped."
			fi
			return 1
		fi
	else
		if [ ! -d $P_REDIST_SRCPATH ]; then
			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo "f_redist_transfer_configset: not found configuration at $P_REDIST_SRCPATH. Skipped."
			fi
			return 1
		fi

		F_COPYSET=$P_REDIST_SRCPATH
	fi

	# pack files at source to simplify copy
	local F_SAVEDIR=`pwd`
	cd $F_COPYSET
	tar cf $F_TMPDIR/$F_CONFIGTARFILE . > /dev/null
	cd $F_SAVEDIR

	if [ ! -f "$F_TMPDIR/$F_CONFIGTARFILE" ]; then
		echo f_redist_transfer_configset: unable to create $F_TMPDIR/$F_CONFIGTARFILE. Exiting
		exit 1
	fi

	# transfer files
	f_run_cmdcheck $P_ENV_HOSTLOGIN "mkdir -p $F_DSTDIR_DEPLOY"
	f_upload_file $P_ENV_HOSTLOGIN $F_TMPDIR/$F_CONFIGTARFILE $F_DSTDIR_DEPLOY/$F_CONFIGTARFILE $F_CONFIGTARMD5NAME

	# cleanup
	rm -rf $F_TMPDIR

	# add delete old configuration files to prepare script
	f_redist_fillconfpreparescript_andbackup $P_SERVER $P_ENV_HOSTLOGIN $P_ROOTDIR $P_RELEASENAME $P_LOCATION $P_CONFCOMP $P_DIRTYPE $F_REDIST_CONFTYPE "$F_REDIST_FILES" $P_PARTIAL
	return 0
}

function f_redist_get_configset() {
	local P_SERVER=$1
	local P_ENV_HOSTLOGIN=$2
	local P_ROOTDIR=$3
	local P_LOCATION=$4
	local P_CONFCOMP=$5
	local P_DSTPATH=$6

	if [ "$P_ENV_HOSTLOGIN" = "" ] || [ "$P_SERVER" = "" ] || [ "$P_ROOTDIR" = "" ] || [ "$P_DSTPATH" = "" ] || [ "$P_CONFCOMP" = "" ] || [ "$P_LOCATION" = "" ]; then
		echo f_redist_get_configset: invalid call. Exiting
		exit 1
	fi

	# get source directory information
	f_distr_getconfcompinfo $P_CONFCOMP
	local F_REDIST_CONFTYPE=$C_DISTR_CONF_TYPE
	local F_REDIST_FILES="$C_DISTR_CONF_FILES"
	local F_REDIST_EXCLUDE="$C_DISTR_CONF_EXCLUDE"

	f_getpath_runtimelocation $P_SERVER $P_ROOTDIR $P_LOCATION
	local F_RUNTIMEDIR=$C_COMMON_DIRPATH

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo $P_ENV_HOSTLOGIN: copy configuration from $F_RUNTIMEDIR ...
	fi

	local F_FILEMASK=
	local F_FILES
	if [ "$F_REDIST_CONFTYPE" = "dir" ]; then
		F_FILEMASK="*"
		f_run_cmd $P_ENV_HOSTLOGIN "if [ -d $F_RUNTIMEDIR ]; then cd $F_RUNTIMEDIR; find . -maxdepth 1 | grep -v \"^.$\" | tr '\n' ' '; fi"
		F_FILES="$RUN_CMD_RES"

	elif [ "$F_REDIST_CONFTYPE" = "mixed-dir" ] || [ "$F_REDIST_CONFTYPE" = "files" ]; then
		if [ "$F_REDIST_FILES" = "" ]; then
			echo f_redist_get_configset: unexpected empty F_REDIST_FILES. Exiting
			exit 1
		fi

		# use selected files only
		F_FILEMASK=
		local mitem
		for mitem in $F_REDIST_FILES; do
			if [ "$F_FILEMASK" != "" ]; then
				F_FILEMASK="$F_FILEMASK -o"
			fi
			F_FILEMASK="$F_FILEMASK -name '$mitem'"
		done

		local F_DEPTHMODIFIER
		if [ "$F_REDIST_CONFTYPE" = "files" ]; then
			F_DEPTHMODIFIER="-maxdepth 1"
		else
			F_DEPTHMODIFIER=
		fi
		
		f_run_cmd $P_ENV_HOSTLOGIN "if [ -d $F_RUNTIMEDIR ]; then cd $F_RUNTIMEDIR; find . $F_DEPTHMODIFIER \\( $F_FILEMASK \\) | tr '\n' ' '; fi"
		F_FILES="$RUN_CMD_RES"
	else
		echo f_redist_get_configset: unknown F_REDIST_CONFTYPE. Exiting
		exit 1
	fi

	if [ "$F_FILES" = "" ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo "$P_ENV_HOSTLOGIN: $F_RUNTIMEDIR is empty (mask=$F_FILEMASK). Skipped."
		fi
		return 1
	fi

	if [ "$F_REDIST_EXCLUDE" != "" ]; then
		local emask
		for emask in $F_REDIST_EXCLUDE; do
			F_FILES="--exclude=\"$emask\" $F_FILES"
		done
	fi

	local F_TMPDIR=$S_COMMONREDISTCONF_RELADM_TMPDIR
	local F_CONFIGTARFILE=$P_CONFCOMP.config.tar

	f_run_cmd $P_ENV_HOSTLOGIN "rm -rf $F_TMPDIR/$F_CONFIGTARFILE; mkdir -p $F_TMPDIR; if [ -d $F_RUNTIMEDIR ]; then cd $F_RUNTIMEDIR; tar cf $F_TMPDIR/$F_CONFIGTARFILE $F_FILES > /dev/null; echo ok; else echo nodir; fi"
	if [ "$RUN_CMD_RES" != "ok" ]; then
		if [ "$RUN_CMD_RES" = "nodir" ]; then
			if [ "$GETOPT_SHOWALL" = "yes" ]; then
				echo "$P_ENV_HOSTLOGIN: $F_RUNTIMEDIR does not exist. Skipped."
			fi
			return 1
		fi

		echo $P_ENV_HOSTLOGIN: error create tar - $RUN_CMD_RES. Exiting
		exit 1
	fi

	# create destination directory and download files
	# upload to destination
	mkdir -p $P_DSTPATH
	f_download_file $P_ENV_HOSTLOGIN $F_TMPDIR/$F_CONFIGTARFILE $P_DSTPATH/$F_CONFIGTARFILE

	if [ ! -f "$P_DSTPATH/$F_CONFIGTARFILE" ]; then
		echo unable to create $P_DSTPATH/$F_CONFIGTARFILE. Exiting
		exit 1
	fi

	local F_SAVEDIR=`pwd`
	cd $P_DSTPATH
	tar xmf $F_CONFIGTARFILE > /dev/null
	rm -rf $F_CONFIGTARFILE
	cd $F_SAVEDIR

	f_run_cmdcheck $P_ENV_HOSTLOGIN "rm -rf $F_TMPDIR/$F_CONFIGTARFILE"

	return 0
}

function f_redistr_droptmp() {
	local P_SERVER=$1
	local P_HOSTLOGIN=$2
	local P_NODE=$3

	f_run_cmdcheck $P_HOSTLOGIN "rm -rf $S_COMMONREDISTCONF_RELADM_TMPDIR"
}
