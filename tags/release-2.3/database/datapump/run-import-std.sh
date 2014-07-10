#!/bin/sh

P_CMD=$1
P_SINGLE_SCHEMA=$2

# load common and env params
. ./common.sh

F_DBCONN_MAIN=$C_ENV_CONFIG_DB
F_LOGDIR_MAIN="import-log"
F_LOGDIR_POSTREFRESH="import-postrefresh"

P_ENV=$C_ENV_CONFIG_ENV
P_DB=$C_ENV_CONFIG_DB
P_POSTREFRESH=$C_ENV_CONFIG_POSTREFRESH

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

	local F_DATADIR=`echo $C_ENV_CONFIG_LOCAL_DATADIR | tr " " "\n" | grep "$P_DB=" | cut -d "=" -f2 | tr -d "\n"`
	for schema in $F_SCHEMALIST; do
		if [[ ! " $C_ENV_CONFIG_METAONLYSCHEMALIST " =~ " $schema " ]]; then
			if [ -f $F_DATADIR/$schema.dmp ]; then
				echo "verified dump file exists: schema=$schema"
			else
				echo "missing dump file=$F_DATADIR/$schema.dmp. Exiting"
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
		./run-postrefresh.sh $P_ENV $P_DB $P_POSTREFRESH $F_DBCONN_MAIN $F_LOGDIR_POSTREFRESH
		if [ "$?" != "0" ]; then
			echo unsuccessfull call run-postrefresh.sh. Exiting
			exit 1
		fi
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
