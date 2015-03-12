#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

C_ADMINDB_REL_P1=
C_ADMINDB_REL_P2=
C_ADMINDB_REL_P3=
C_ADMINDB_REL_P4=
C_ADMINDB_REL_FULL=
function f_admindb_parsereleasenumber() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2

	C_ADMINDB_REL_P1=`echo $P_RELEASE | cut -d "." -f1`
	C_ADMINDB_REL_P2=`echo $P_RELEASE | cut -d "." -f2`
	C_ADMINDB_REL_P3=`echo $P_RELEASE | cut -d "." -f3`
	C_ADMINDB_REL_P4=`echo $P_RELEASE | cut -d "." -f4`

	if [ "$C_ADMINDB_REL_P1" = "" ] || [ "$C_ADMINDB_REL_P2" = "" ]; then
		echo f_admindb_parsereleasenumber: invalid release version=$P_RELEASE. Exiting.
		exit 1
	fi

	if [ "$C_ADMINDB_REL_P3" = "" ]; then
		C_ADMINDB_REL_P3=0
	fi
	if [ "$C_ADMINDB_REL_P4" = "" ]; then
		C_ADMINDB_REL_P4=0
	fi

	C_ADMINDB_REL_FULL=$C_ADMINDB_REL_P1.$C_ADMINDB_REL_P2.$C_ADMINDB_REL_P3.$C_ADMINDB_REL_P4
}

function f_admindb_add_beginscriptstatus() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_SCHEMA=$3
	local P_SCRIPTNAME=$4
	local P_SCRIPTNUM=$5

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	local F_SCHEMA=`echo $P_SCHEMA | tr '[a-z]' '[A-Z]'`

	f_specific_admin_add_insert_script $C_ADMINDB_REL_FULL $F_SCHEMA $P_SCRIPTNUM $P_SCRIPTNAME
}

function f_admindb_add_updatescripttime() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_SCHEMA=$3
	local P_SCRIPTNUM=$4

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE
	f_specific_admin_add_update_script $C_ADMINDB_REL_FULL $P_SCRIPTNUM
}

function f_admindb_beginscriptstatus() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3
	local P_SCHEMA=$4
	local P_SCRIPTNAME=$5
	local P_SCRIPTNUM=$6

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	local F_CTLSQL="`f_admindb_add_beginscriptstatus $P_DBMSTYPE $P_RELEASE $P_SCHEMA $P_SCRIPTNAME $P_SCRIPTNUM`"

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $P_SCHEMA
	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$S_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "$P_DB_TNS_NAME: $P_SCRIPTNAME script_status is not finalized due to ERRORs \"$S_SPECIFIC_VALUE\""
		exit 37
	fi
}

function f_admindb_updatescriptstatus() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3
	local P_SCHEMA=$4
	local P_SCRIPTNAME=$5
	local P_SCRIPTNUM=$6
	local P_STATUS=$7

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	local F_SCHEMA=`echo $P_SCHEMA | awk '{print toupper($0)}'`

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $P_SCHEMA
	f_specific_admin_update_scriptstatus $P_DB_TNS_NAME $P_SCHEMA "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL $P_SCRIPTNUM $P_STATUS

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "$P_DB_TNS_NAME: $P_SCRIPTNAME script_status is not finalized due to ERRORs \"$S_SPECIFIC_VALUE\""
		exit 37
	fi
}

C_ADMINDB_SCRIPT_STATUS=
C_ADMINDB_SCRIPT_ERRORS=
function f_admindb_check_scriptstatus() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3
	local P_SCHEMA=$4
	local P_SCRIPTNAME=$5
	local P_SCRIPTNUM=$6

	C_ADMINDB_SCRIPT_STATUS=
	C_ADMINDB_SCRIPT_ERRORS=

	local X_STATUS
	if [ "$GETOPT_STATUSFILE" != "" ]; then
		# use status file if defined
		local F_NOZERO=`echo $P_SCRIPTNUM | sed "s/^0*//"`
		X_STATUS=`cat $GETOPT_STATUSFILE | grep "^$F_NOZERO=" | cut -d "=" -f2`
	else
		f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

		local F_SCHEMA=`echo $P_SCHEMA | awk '{print toupper($0)}'`

		f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $P_SCHEMA
		f_specific_admin_get_scriptstatus $P_DB_TNS_NAME $P_SCHEMA "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL $P_SCRIPTNUM
		X_STATUS=$S_SPECIFIC_VALUE
	fi

	if [ "$X_STATUS" = "" ]; then
		C_ADMINDB_SCRIPT_STATUS=new
	else
		C_ADMINDB_SCRIPT_STATUS=applied
		if [ "$X_STATUS" = "A" ]; then
			C_ADMINDB_SCRIPT_ERRORS=no
		else
			C_ADMINDB_SCRIPT_ERRORS=yes
		fi
	fi
}

function f_admindb_get_scriptstatusall() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3
	local P_STATUSFILE=$4

	echo $P_DB_TNS_NAME: create status file $P_STATUSFILE ...
	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN 

	rm -rf $P_STATUSFILE
	rm -rf $P_STATUSFILE.tmp
	f_specific_admin_get_releasestatuses $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL $P_STATUSFILE.tmp

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "$P_DB_TNS_NAME: Can't get status of scripts execution. Exiting."    
		echo "$S_SPECIFIC_VALUE"
		exit 38
	fi

	mv $P_STATUSFILE.tmp $P_STATUSFILE
}

function f_admindb_delete_scriptstatus() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3
	local P_SCRIPTNUM=$4
	local P_SCHEMA=$5

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $P_SCHEMA
	f_specific_admin_delete_scriptstatus $P_DB_TNS_NAME $P_SCHEMA "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL $P_SCRIPTNUM

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_admindb_delete_scriptstatus: $P_SCRIPTNUM script_status is not finalized due to ERRORs \"$S_SPECIFIC_VALUE\""
		exit 37
	fi
}

C_ADMINDB_RELEASESTATUS=
C_ADMINDB_ALL_SCIPTS_COUNT=
C_ADMINDB_NOT_APPLIED_SCIPTS_COUNT=
function f_admindb_getreleasestatus() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN

	echo $P_DB_TNS_NAME: get release $P_RELEASE status ...
	f_specific_admin_get_releasestatus $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL 
	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_admindb_getreleasestatus: error executing f_specific_admin_get_releasestatus - $S_SPECIFIC_VALUE. Exiting"
		exit 1
	fi

	C_ADMINDB_RELEASESTATUS="$S_SPECIFIC_OUTPUT"

	f_specific_admin_get_releasescriptcount $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL
	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_admindb_getreleasestatus: error executing f_specific_admin_get_releasescriptcount - $S_SPECIFIC_VALUE. Exiting"
		exit 1
	fi

	C_ADMINDB_ALL_SCIPTS_COUNT="$S_SPECIFIC_OUTPUT"

	f_specific_admin_get_releasescriptfailedcount $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL
	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_admindb_getreleasestatus: error executing f_specific_admin_get_releasescriptfailedcount - $S_SPECIFIC_VALUE. Exiting"
		exit 1
	fi

	C_ADMINDB_NOT_APPLIED_SCIPTS_COUNT="$S_SPECIFIC_OUTPUT"
}

function f_admindb_beginrelease() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3

	# check release is new
	echo check release status...
	f_admindb_getreleasestatus $P_DBMSTYPE $P_RELEASE $P_DB_TNS_NAME
	if [ "$C_ADMINDB_RELEASESTATUS" != "" ]; then
		return 1
	fi

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	echo add release...
	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_specific_admin_create_release $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL $C_ADMINDB_REL_P1 $C_ADMINDB_REL_P2 $C_ADMINDB_REL_P3 $C_ADMINDB_REL_P4

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_admindb_beginrelease: can't insert $C_ADMINDB_REL_FULL value into $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES due to ERROR \"$S_SPECIFIC_VALUE\""
		exit 2
	fi
}

function f_admindb_finishrelease() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_specific_admin_finish_release $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "$f_admindb_finishrelease: can't update rel_status field for $C_ADMINDB_REL_FULL in $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES due to ERROR \"$S_SPECIFIC_VALUE\""
		exit 3
	fi
}

function f_admindb_droprelease() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_specific_admin_drop_release $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_admindb_droprelease: error - $S_SPECIFIC_VALUE. Exiting"
		exit 1
	fi

	echo "$P_DB_TNS_NAME: delete release $P_RELEASE - $S_SPECIFIC_OUTPUT"
}

function f_admindb_dropreleaseitems() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3
	local P_IDLIST="$4"
	local P_ALIGNEDID=$5

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE "$P_IDLIST"

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_specific_admin_deletescripts $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL "$P_IDLIST" $P_ALIGNEDID

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_admindb_dropreleaseitems: error - $S_SPECIFIC_VALUE. Exiting"
		exit 1
	fi

	echo "$P_DB_TNS_NAME: delete release $P_RELEASE items - $S_SPECIFIC_OUTPUT"
}

function f_admindb_checkandfinishrelease() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3

	# finish release status
	f_admindb_getreleasestatus $P_DBMSTYPE $P_RELEASE $P_DB_TNS_NAME

	if [ "$C_ADMINDB_NOT_APPLIED_SCIPTS_COUNT" = "0" ] || [ "$GETOPT_SKIPERRORS" = "yes" ]; then
		f_admindb_finishrelease $P_DBMSTYPE $P_RELEASE $P_DB_TNS_NAME
		echo "$P_DB_TNS_NAME: release $P_RELEASE is finalized." 
	else
		echo ""
		echo "$P_DB_TNS_NAME: release $P_RELEASE is not finalized. There are unapplied sql scripts." 
	fi
}

function f_admindb_fixreleaseall() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_specific_admin_fixall_release $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_admindb_fixreleaseall: error - $S_SPECIFIC_VALUE. Exiting"
		exit 1
	fi

	echo "$P_DB_TNS_NAME: fix release $P_RELEASE - $S_SPECIFIC_OUTPUT"
}

function f_admindb_fixreleaseitems() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3
	local P_IDLIST="$4"
	local P_ALIGNEDID=$5

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_specific_admin_fix_releaseitems $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL "$P_IDLIST" $P_ALIGNEDID

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_admindb_fixreleaseitems: error - $S_SPECIFIC_VALUE. Exiting"
		exit 1
	fi

	echo "$P_DB_TNS_NAME: delete release $P_RELEASE items - $S_SPECIFIC_OUTPUT"
}

function f_admindb_getreleasefailed() {
	local P_DBMSTYPE=$1
	local P_RELEASE=$2
	local P_DB_TNS_NAME=$3

	f_admindb_parsereleasenumber $P_DBMSTYPE $P_RELEASE

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_specific_admin_get_failedscripts $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN "$S_DB_USE_SCHEMA_PASSWORD" $C_ADMINDB_REL_FULL

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_admindb_getreleasefailed: error - $S_SPECIFIC_VALUE. Exiting"
		exit 1
	fi

	C_ADMINDB_SQLRES="$S_SPECIFIC_OUTPUT"
}
