#!/bin/bash

P_ENV=$1
P_DB=$2
P_DBCONN="$3"
P_CMD=$4

if [ "$P_CMD" = "" ]; then
	echo P_CMD is not set. Exiting
	exit 1
fi
shift 4

P_SCHEMALIST="$*"

# load common and env params
. ./common.sh

. $C_ENV_CONFIG_REMOTE_SETORAENV $P_ENV $P_DB

S_CONNECTION=
S_LOAD_ORACLEDIR=

function f_execute_all_dropold() {
	# clean datapump directory
	rm -rf $S_LOAD_ORACLEDIR/*.dmp $S_LOAD_ORACLEDIR/*.log

	# perform scheme mapping
	f_get_finalschemalist "$P_SCHEMALIST"

	# create uppercase comma-separated quoted schemalist
	local F_SCHEMA_LIST_COMMA_UPPER=`echo $S_FINAL_SCHEMALIST | tr '[a-z]' '[A-Z]' | sed "s/^/'/;s/$/'/;s/ /','/g"`

	# process sql script
	cat $C_CONFIG_SCRIPT_DROPUSERS | sed "s/@SCHEMA_LIST@/$F_SCHEMA_LIST_COMMA_UPPER/g;s/@DROPTBS@/$C_ENV_CONFIG_RECREATETABLESPACES/g" > $C_CONFIG_SCRIPT_DROPUSERS.run
	echo "exit" >> $C_CONFIG_SCRIPT_DROPUSERS.run

	# execute script
	echo "execute kill session/drop user script..."
	f_sqlexec $S_CONNECTION $C_CONFIG_SCRIPT_DROPUSERS.run $C_CONFIG_SCRIPT_DROPUSERS.out
}

function f_execute_all_preparedata() {
	# fill tables - will be used by prepare sql script
	f_sqlexec $S_CONNECTION $C_CONFIG_CREATEDATA_SQLFILE $C_CONFIG_CREATEDATA_SQLFILE.out

	local F_SCHEMAONE
	local F_SCHEMAONE_FINAL
	if [ "$P_SCHEMALIST" != "" ]; then
		# get final schema
		f_get_finalschema $P_SCHEMALIST
		F_SCHEMAONE_FINAL=$S_FINAL_SCHEMA

		local F_SCHEMA_UPPER=`echo $F_SCHEMAONE_FINAL | tr '[a-z]' '[A-Z]'`
		F_SCHEMAONE="$F_SCHEMA_UPPER"
	else
		F_SCHEMAONE=all
		F_SCHEMAONE_FINAL=all
	fi

	# run prepare data script
	cat $C_CONFIG_PREPAREDATA_SQLFILE | sed "s/@SCHEMAONE@/$F_SCHEMAONE/g;s/@SCHEMAONEFINAL@/$F_SCHEMAONE_FINAL/g;s/@C_ENV_CONFIG_TABLESET@/$C_ENV_CONFIG_TABLESET/g" > $C_CONFIG_PREPAREDATA_SQLFILE.run
	f_sqlexec $S_CONNECTION $C_CONFIG_PREPAREDATA_SQLFILE.run $C_CONFIG_PREPAREDATA_SQLFILE.out

	# ensure no data
	cat $C_CONFIG_TRUNCATEDATA_SQLFILE | sed "s/@SCHEMAONE@/$F_SCHEMAONE/g;s/@SCHEMAONEFINAL@/$F_SCHEMAONE_FINAL/g;s/@C_ENV_CONFIG_TABLESET@/$C_ENV_CONFIG_TABLESET/g" > $C_CONFIG_TRUNCATEDATA_SQLFILE.run
	f_sqlexec $S_CONNECTION $C_CONFIG_TRUNCATEDATA_SQLFILE.run $C_CONFIG_TRUNCATEDATA_SQLFILE.out
}

function f_execute_all_finishdata() {
	local F_SCHEMAONE
	local F_SCHEMAONE_FINAL
	if [ "$P_SCHEMALIST" != "" ]; then
		# get final schema
		f_get_finalschema $P_SCHEMALIST
		F_SCHEMAONE_FINAL=$S_FINAL_SCHEMA

		local F_SCHEMA_UPPER=`echo $F_SCHEMAONE_FINAL | tr '[a-z]' '[A-Z]'`
		F_SCHEMAONE="$F_SCHEMA_UPPER"
	else
		F_SCHEMAONE=all
		F_SCHEMAONE_FINAL=all
	fi

	# run finish data script
	cat $C_CONFIG_FINISHDATA_SQLFILE | sed "s/@SCHEMAONE@/$F_SCHEMAONE/g;s/@SCHEMAONEFINAL@/$F_SCHEMAONE_FINAL/g;s/@C_ENV_CONFIG_TABLESET@/$C_ENV_CONFIG_TABLESET/g" > $C_CONFIG_FINISHDATA_SQLFILE.run
	f_sqlexec $S_CONNECTION $C_CONFIG_FINISHDATA_SQLFILE.run $C_CONFIG_FINISHDATA_SQLFILE.out
}

function f_execute_all_importmeta() {
	f_common_getschemadump "role"
	f_impdp $S_CONNECTION "DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$C_DUMP_NAME LOGFILE=role.log" ignoreerrors

	# collect remap - only for different
	F_REMAP_SCHEMALIST=
	for pair in $C_ENV_CONFIG_SCHMAPPING; do
		schema_from=${pair%%=*}
		schema_to=${pair##*=}
		if [ "$schema_from" != "$schema_to" ]; then
			F_REMAP_SCHEMALIST="$F_REMAP_SCHEMALIST $schema_from:$schema_to"
		fi
	done
	F_REMAP_SCHEMALIST=${F_REMAP_SCHEMALIST# }

	if [ "$F_REMAP_SCHEMALIST" != "" ]; then
		F_REMAP_SCHEMALIST=`echo $F_REMAP_SCHEMALIST | sed "s/ /,/g"`
		F_REMAP_SCHEMALIST="REMAP_SCHEMA=$F_REMAP_SCHEMALIST"
	fi

	if [ "$P_SCHEMALIST" != "" ]; then
		local F_SCHEMALIST_UPPER=`echo $P_SCHEMALIST | tr '[a-z]' '[A-Z]' | tr ' ' ','`
	else
		local F_SCHEMALIST_UPPER=`echo $C_ENV_CONFIG_FULLSCHEMALIST | tr '[a-z]' '[A-Z]' | tr ' ' ','`
	fi

	local F_TRANSFORM="transform=segment_attributes:n:table"
	if [ "$C_ENV_CONFIG_USETRANSFORM" = "no" ]; then
		F_TRANSFORM=
	fi

	if [ "$C_ENV_CONFIG_ADDTRANSFORM" != "" ]; then
		F_TRANSFORM="$F_TRANSFORM $C_ENV_CONFIG_ADDTRANSFORM"
	fi

	f_common_getschemadump "meta"
	f_impdp $S_CONNECTION "CONTENT=METADATA_ONLY SCHEMAS=$F_SCHEMALIST_UPPER DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$C_DUMP_NAME LOGFILE=meta.log $F_TRANSFORM $F_REMAP_SCHEMALIST" ignoreerrors
}

function f_execute_all_importdatafull() {
	echo "STARTED: `date`" > import.status.log

	local F_TRANSFORM="transform=segment_attributes:n:table"
	if [ "$C_ENV_CONFIG_USETRANSFORM" = "no" ]; then
		F_TRANSFORM=
	fi

	if [ "$C_ENV_CONFIG_ADDTRANSFORM" != "" ]; then
		F_TRANSFORM="$F_TRANSFORM $C_ENV_CONFIG_ADDTRANSFORM"
	fi

	local schema
	local F_SCHEMA_UPPER
	local F_SCHEMAONE_FINAL
	local F_SCHEMA_FINAL_UPPER
	local F_REMAP
	local F_DUMP
	for schema in $P_SCHEMALIST; do
		f_common_getschemadump $schema
		F_DUMP=$C_DUMP_NAME

		if [ ! -f "$S_LOAD_ORACLEDIR/$F_DUMP" ]; then
			echo dump for schema=$schema not found in $S_LOAD_ORACLEDIR. Skipped.
		else
			# get final schema
			f_get_finalschema $schema
			F_SCHEMAONE_FINAL=$S_FINAL_SCHEMA

			echo execute impdp for schema=$schema, target schema=$F_SCHEMAONE_FINAL - full dump ...
			
			F_SCHEMA_UPPER=`echo $schema | tr '[a-z]' '[A-Z]'`
			F_SCHEMA_FINAL_UPPER=`echo $F_SCHEMAONE_FINAL | tr '[a-z]' '[A-Z]'`

			if [ "$F_SCHEMA_UPPER" != "$F_SCHEMA_FINAL_UPPER" ]; then
				F_REMAP="REMAP_SCHEMA=$F_SCHEMA_UPPER:$F_SCHEMA_FINAL_UPPER"
			else
				F_REMAP=""
			fi

			f_impdp $S_CONNECTION "DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR SCHEMAS=$F_SCHEMA_UPPER DUMPFILE=$F_DUMP LOGFILE=$schema.log $F_REMAP $F_TRANSFORM" ignoreerrors
		fi
	done

	echo "FINISHED: `date`" >> import.status.log
}

function f_execute_all_importdatatables() {
	echo "STARTED: `date`" > import.status.log

	local schema
	local F_SCHEMA_UPPER
	local F_SCHEMAONE_FINAL
	local F_SCHEMA_FINAL_UPPER
	local F_REMAP
	local F_DUMP
	for schema in $P_SCHEMALIST; do
		f_common_getschemadump $schema
		F_DUMP=$C_DUMP_NAME

		if [ -f "$S_LOAD_ORACLEDIR/$F_DUMP" ]; then
			# get final schema
			f_get_finalschema $schema
			F_SCHEMAONE_FINAL=$S_FINAL_SCHEMA

			echo execute impdp for schema=$schema, target schema=$F_SCHEMAONE_FINAL - table data only ...

			F_SCHEMA_UPPER=`echo $schema | tr '[a-z]' '[A-Z]'`
			F_SCHEMA_FINAL_UPPER=`echo $F_SCHEMAONE_FINAL | tr '[a-z]' '[A-Z]'`

			if [ "$F_SCHEMA_UPPER" != "$F_SCHEMA_FINAL_UPPER" ]; then
				F_REMAP="REMAP_SCHEMA=$F_SCHEMA_UPPER:$F_SCHEMA_FINAL_UPPER"
			else
				F_REMAP=""
			fi

			local F_TRANSFORM="transform=segment_attributes:n:table"
			if [ "$C_ENV_CONFIG_USETRANSFORM" = "no" ]; then
				F_TRANSFORM=
			fi

			f_impdp $S_CONNECTION "DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR SCHEMAS=$schema DUMPFILE=$F_DUMP LOGFILE=$schema.log INCLUDE=TABLE_DATA TABLE_EXISTS_ACTION=TRUNCATE $F_REMAP $F_TRANSFORM" ignoreerrors
		fi
	done

	echo "FINISHED: `date`" >> import.status.log
}

function f_execute_all_postrefresh() {
	local script
	for script in `find postrefresh -name "*.sql" | sort`; do
		echo apply script $script ...
		f_sqlexec $S_CONNECTION $script $script.out
	done
}

function f_execute_all_executesql() {
	f_sqlexec $S_CONNECTION executesql.sql executesql.out
}

function f_execute_all_exportdata() {
	local schema
	local F_SCHEMAONE_FINAL
	local F_SCHEMA_FINAL_UPPER
	local F_DUMP
	for schema in $P_SCHEMALIST; do
		f_common_getschemadump $schema
		F_DUMP=$C_DUMP_NAME

		# get final schema
		f_get_finalschema $schema
		F_SCHEMAONE_FINAL=$S_FINAL_SCHEMA

		echo export schema=$schema, target schema=$F_SCHEMAONE_FINAL ...
		F_SCHEMA_FINAL_UPPER=`echo $F_SCHEMAONE_FINAL | tr '[a-z]' '[A-Z]'`
		f_expdp $S_CONNECTION "DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_DUMP LOGFILE=$schema.log schemas=$F_SCHEMA_FINAL_UPPER"
	done
}

function f_execute_all_exportdatasimple() {
	local schema=$P_SCHEMALIST
	local F_DATANAME=data
	rm -rf $S_LOAD_ORACLEDIR/$F_DATANAME.dmp $S_LOAD_ORACLEDIR/$F_DATANAME.log

	echo export schema=$schema ...
	F_SCHEMA_FINAL_UPPER=`echo $schema | tr '[a-z]' '[A-Z]'`
	f_expdp $S_CONNECTION "DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_DATANAME.dmp LOGFILE=$F_DATANAME.log schemas=$F_SCHEMA_FINAL_UPPER"
}

function f_execute_all_importdatasimple() {
	local P_SCHEMA_DST=$1
	local P_SCHEMA_SRC=$2

	F_REMAP=
	F_DMP_SCHEMA=$P_SCHEMA_DST
	if [ "$P_SCHEMA_SRC" != "" ]; then
		F_REMAP="REMAP_SCHEMA=$P_SCHEMA_SRC:$P_SCHEMA_DST"
		F_DMP_SCHEMA=$P_SCHEMA_SRC
	fi

	local schema=$P_SCHEMA_DST
	local F_DATANAME=data
	rm -rf $S_LOAD_ORACLEDIR/$F_DATANAME.log

	# drop old
	(
		echo "drop user $P_SCHEMA_DST cascade;"
	) | sqlplus -S / "as sysdba"

	echo import schema=$schema $F_REMAP...
	F_SCHEMA_UPPER=`echo $F_DMP_SCHEMA | tr '[a-z]' '[A-Z]'`
	f_impdp $S_CONNECTION "DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$F_DATANAME.dmp LOGFILE=$F_DATANAME.log schemas=$F_SCHEMA_UPPER $F_REMAP"

	# simplify pwd
	(
		echo "alter user $P_SCHEMA_DST identified by $P_SCHEMA_DST account unlock;"
	) | sqlplus -S / "as sysdba"
}

function f_execute_all() {
	S_CONNECTION=`echo $C_ENV_CONFIG_CONNECTION | tr " " "\n" | grep "$P_DBCONN=" | cut -d "=" -f2`
	S_LOAD_ORACLEDIR=`echo $C_ENV_CONFIG_LOADDIR | tr " " "\n" | grep "$P_DBCONN=" | cut -d "=" -f2`

	echo "import_helper.sh: execute P_DBCONN=$P_DBCONN, cmd=$P_CMD, P_SCHEMALIST=$P_SCHEMALIST using connection=$S_CONNECTION, S_LOAD_ORACLEDIR=$S_LOAD_ORACLEDIR ..."

	#----------------- import ORACLE METADATA
	if [ "$P_CMD" = "importmeta" ]; then
		f_execute_all_importmeta
	elif [ "$P_CMD" = "dropold" ]; then
		f_execute_all_dropold
	elif [ "$P_CMD" = "preparedata" ]; then
		f_execute_all_preparedata
	elif [ "$P_CMD" = "importdatafull" ]; then
		f_execute_all_importdatafull
	elif [ "$P_CMD" = "importdatatables" ]; then
		f_execute_all_importdatatables
	elif [ "$P_CMD" = "finishdata" ]; then
		f_execute_all_finishdata
	elif [ "$P_CMD" = "postrefresh" ]; then
		f_execute_all_postrefresh
	elif [ "$P_CMD" = "executesql" ]; then
		f_execute_all_executesql
	elif [ "$P_CMD" = "exportdata" ]; then
		f_execute_all_exportdata
	elif [ "$P_CMD" = "exportdatasimple" ]; then
		f_execute_all_exportdatasimple
	elif [ "$P_CMD" = "importdatasimple" ]; then
		f_execute_all_importdatasimple $P_SCHEMALIST
	fi
}

f_execute_all

echo import_helper.sh: successfully finished
