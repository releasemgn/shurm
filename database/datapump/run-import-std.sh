#!/bin/sh

P_CMD=$1
P_SINGLE_SCHEMA=$2

# load common and env params
. ./common.sh

F_DBCONN_MAIN=$C_ENV_CONFIG_DB
F_LOGDIR_MAIN="import-log"
F_LOGDIR_POSTREFRESH="import-postrefresh"

if [ "$C_ENV_CONFIG_ENV" = "" ]; then
	echo C_ENV_CONFIG_ENV is not set. Exiting
	exit 1
fi
if [ "$C_ENV_CONFIG_DC" = "" ]; then
	echo P_DC=$C_ENV_CONFIG_DC is not set. Exiting
	exit 1
fi
if [ "$C_ENV_CONFIG_DB" = "" ]; then
	echo C_ENV_CONFIG_DB is not set. Exiting
	exit 1
fi
if [ "$C_ENV_CONFIG_POSTREFRESH" = "" ]; then
	echo C_ENV_CONFIG_POSTREFRESH is not set. Exiting
	exit 1
fi

P_ENV=$C_ENV_CONFIG_ENV
P_DC=$C_ENV_CONFIG_DC
P_DB=$C_ENV_CONFIG_DB
P_POSTREFRESH="$C_ENV_CONFIG_POSTREFRESH"

function f_local_checkdata() {
	# check data available
	if [ "$P_SINGLE_SCHEMA" = "" ]; then
		F_SCHEMALIST=$C_ENV_CONFIG_FULLSCHEMALIST
	else
		F_SCHEMALIST=$P_SINGLE_SCHEMA
	fi

	if [ "$GETOPT_SHOWALL" = "yes" ]; then
		echo using schema list: $F_SCHEMALIST
	fi

	local F_DATADIR=`echo $C_ENV_CONFIG_DATADIR | tr " " "\n" | grep "$P_DB=" | cut -d "=" -f2 | tr -d "\n"`
	local F_DUMP
	for schema in $F_SCHEMALIST; do
		if [[ ! " $C_ENV_CONFIG_METAONLYSCHEMALIST " =~ " $schema " ]]; then
			f_common_getschemadump $schema
			F_DUMP=$C_DUMP_NAME

			if [ -f "$F_DATADIR/$F_DUMP" ]; then
				echo "verified dump file exists: schema=$schema"
			else
				echo "schema=$schema - missing dump file=$F_DATADIR/$F_DUMP. Exiting"
				exit 1
			fi
		fi
	done
}

function f_local_main_load() {
	# main db - load meta from core dir
	if [ "$P_CMD" = "all" ] || [ "$P_CMD" = "meta" ]; then
		echo execute - load meta from core dir ...
		echo running ./run-import-meta.sh $P_ENV $P_DB $F_DBCONN_MAIN $F_LOGDIR_MAIN $P_SINGLE_SCHEMA ...
		./run-import-meta.sh $P_ENV $P_DB $F_DBCONN_MAIN $F_LOGDIR_MAIN $P_SINGLE_SCHEMA
		if [ "$?" != "0" ]; then
			echo unsuccessfull call run-import-meta.sh. Exiting
			exit 1
		fi
	fi

	# main db - load data from core dir
	if [ "$P_CMD" = "all" ] || [ "$P_CMD" = "data" ]; then
		echo execute - load data from core dir ...
		echo running ./run-import-data.sh $P_ENV $P_DB $F_DBCONN_MAIN $F_LOGDIR_MAIN $P_SINGLE_SCHEMA ...
		./run-import-data.sh $P_ENV $P_DB $F_DBCONN_MAIN $F_LOGDIR_MAIN $P_SINGLE_SCHEMA
		if [ "$?" != "0" ]; then
			echo unsuccessfull call run-import-data.sh. Exiting
			exit 1
		fi
	fi
}

function f_local_postrefresh() {
	# main db - post-refresh
	if [ "$P_CMD" = "all" ] || [ "$P_CMD" = "post-refresh" ]; then
		echo execute - post-refresh ...
		for pr in $P_POSTREFRESH; do
			if [ "$GETOPT_SCRIPTFOLDER" = "" ] || [ "$GETOPT_SCRIPTFOLDER" = "$pr" ]; then
				./run-postrefresh.sh $P_ENV $P_DC $P_DB $pr $F_DBCONN_MAIN $F_LOGDIR_POSTREFRESH
				if [ "$?" != "0" ]; then
					echo refresh folder $pr - unsuccessfull call run-postrefresh.sh. Exiting
					exit 1
				fi
			fi
		done
	fi
}

function f_local_executeall() {
	if [ "$P_CMD" = "data" ] || [ "$P_CMD" = "all" ]; then
		f_local_checkdata
	fi

	f_local_main_load
	f_local_postrefresh
}

f_local_executeall

echo run-import-std.sh: successfully finished
exit 0
