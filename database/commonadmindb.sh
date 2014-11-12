#!/bin/bash
# Copyright 2011-2013 vsavchik@gmail.com

C_ADMINDB_REL_P1=
C_ADMINDB_REL_P2=
C_ADMINDB_REL_P3=
C_ADMINDB_REL_P4=
C_ADMINDB_REL_FULL=
function f_admindb_parsereleasenumber() {
	local P_RELEASE=$1

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
	local P_RELEASE=$1
	local P_SCHEMA=$2
	local P_SCRIPTNAME=$3
	local P_SCRIPTNUM=$4

	f_admindb_parsereleasenumber $P_RELEASE

	local F_SCHEMA=`echo $P_SCHEMA | tr '[a-z]' '[A-Z]'`

	echo "INSERT INTO $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS (RELEASE, SCHEMA, ID, FILENAME, UPDATETIME, UPDATEUSERID, SCRIPT_STATUS)"
	echo "VALUES ('$C_ADMINDB_REL_FULL', '$F_SCHEMA', $P_SCRIPTNUM, '$P_SCRIPTNAME', SYSDATE, sys_context('USERENV','OS_USER') , 'S');"
	echo "COMMIT;"
}

function f_admindb_add_updatescripttime() {
	local P_RELEASE=$1
	local P_SCHEMA=$2
	local P_SCRIPTNUM=$3

	f_admindb_parsereleasenumber $P_RELEASE

	local F_SCHEMA=`echo $P_SCHEMA | awk '{print toupper($0)}'`

	echo "update $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS set UPDATETIME=SYSDATE where RELEASE='$C_ADMINDB_REL_FULL' and ID=$P_SCRIPTNUM;"
	echo "commit;"
}

function f_admindb_beginscriptstatus() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2
	local P_SCHEMA=$3
	local P_SCRIPTNAME=$4
	local P_SCRIPTNUM=$5

	f_admindb_parsereleasenumber $P_RELEASE

	local F_CTLSQL="`f_admindb_add_beginscriptstatus $P_RELEASE $P_SCHEMA $P_SCRIPTNAME $P_SCRIPTNUM`"

	f_get_db_password $P_DB_TNS_NAME $P_SCHEMA
	f_exec_limited 60 "(
		$F_CTLSQL
	) | sqlplus -S $P_SCHEMA/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME | egrep \"(ORA-|PLS-)\""

	local F_UPD_A=$S_EXEC_LIMITED_OUTPUT
	if [ "$F_UPD_A" != "" ]; then
		echo "$P_DB_TNS_NAME: $P_SCRIPTNAME script_status is not finalized due to ERRORs \"$F_UPD_A\""
		exit 37
	fi
}

function f_admindb_updatescriptstatus() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2
	local P_SCHEMA=$3
	local P_SCRIPTNAME=$4
	local P_SCRIPTNUM=$5
	local P_STATUS=$6

	f_admindb_parsereleasenumber $P_RELEASE

	local F_SCHEMA=`echo $P_SCHEMA | awk '{print toupper($0)}'`

	f_get_db_password $P_DB_TNS_NAME $P_SCHEMA
	f_exec_limited 60 "(
		echo \"update $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS set SCRIPT_STATUS='$P_STATUS' where RELEASE='$C_ADMINDB_REL_FULL' and ID=$P_SCRIPTNUM;\"
		echo commit;
	) | sqlplus -S $P_SCHEMA/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME | egrep \"(ORA-|PLS-)\""

	local F_UPD_A=$S_EXEC_LIMITED_OUTPUT
	if [ "$F_UPD_A" != "" ]; then
		echo "$P_DB_TNS_NAME: $P_SCRIPTNAME script_status is not finalized due to ERRORs \"$F_UPD_A\""
		exit 37
	fi
}

C_ADMINDB_SCRIPT_STATUS=
C_ADMINDB_SCRIPT_ERRORS=
function f_admindb_check_scriptstatus() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2
	local P_SCHEMA=$3
	local P_SCRIPTNAME=$4
	local P_SCRIPTNUM=$5

	C_ADMINDB_SCRIPT_STATUS=
	C_ADMINDB_SCRIPT_ERRORS=

	local X_STATUS
	if [ "$GETOPT_STATUSFILE" != "" ]; then
		# use status file if defined
		local F_NOZERO=`echo $P_SCRIPTNUM | sed "s/^0*//"`
		X_STATUS=`cat $GETOPT_STATUSFILE | grep "^$F_NOZERO=" | cut -d "=" -f2`
	else
		f_admindb_parsereleasenumber $P_RELEASE

		local F_SCHEMA=`echo $P_SCHEMA | awk '{print toupper($0)}'`

		f_get_db_password $P_DB_TNS_NAME $P_SCHEMA
		f_exec_limited 60 "(
			echo \"select 'VALUE=' || SCRIPT_STATUS || '=' as x from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$C_ADMINDB_REL_FULL' and ID=$P_SCRIPTNUM;\"
		) | sqlplus -S $P_SCHEMA/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME"

		local F_COUNT_OUTPUT=$S_EXEC_LIMITED_OUTPUT
		local F_COUNT_ERR=`echo $F_COUNT_OUTPUT| egrep "(ORA-|PLS-)"`
		if [ "$F_COUNT_OUTPUT" = "KILLED" ] || [ "$F_COUNT_ERR" != "" ]; then
			echo "$P_DB_TNS_NAME: can't apply $P_SCRIPTNAME. Skipped."    
			echo "$P_DB_TNS_NAME: maybe grants not present on $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS, $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES were not given to application schemas"
			echo "$F_COUNT_OUTPUT"
			exit 38
		fi 

		X_STATUS=`echo $F_COUNT_OUTPUT | grep VALUE | cut -d "=" -f2`
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
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2
	local P_STATUSFILE=$3

	echo $P_DB_TNS_NAME: create status file $P_STATUSFILE ...
	f_admindb_parsereleasenumber $P_RELEASE

	f_get_db_password $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN

	rm -rf $P_STATUSFILE
	rm -rf $P_STATUSFILE.tmp
	f_exec_limited 300 "(
		echo set pagesize 0
		echo \"select ID || '=' || SCRIPT_STATUS || '=' as x from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$C_ADMINDB_REL_FULL' order by ID;\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME" $P_STATUSFILE.tmp

	local F_COUNT_ERR=`cat $P_STATUSFILE.tmp | egrep "(ORA-|PLS-)"`
	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ] || [ "$F_COUNT_ERR" != "" ]; then
		echo "$P_DB_TNS_NAME: Can't get status of scripts execution. Exiting."    
		echo "$F_COUNT_ERR"
		exit 38
	fi

	mv $P_STATUSFILE.tmp $P_STATUSFILE
}

function f_admindb_delete_scriptstatus() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2
	local P_SCRIPTNUM=$3
	local P_SCHEMA=$4

	f_admindb_parsereleasenumber $P_RELEASE

	f_get_db_password $P_DB_TNS_NAME $P_SCHEMA
	f_exec_limited 60 "(
		echo \"delete from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where RELEASE = '$C_ADMINDB_REL_FULL' and ID = $P_SCRIPTNUM;\"
		echo commit\; 
	) | sqlplus -S $P_SCHEMA/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME | egrep \"(ORA-|PLS-)\""

	local F_RUN="$S_EXEC_LIMITED_OUTPUT"
	if [ "$F_RUN" != "" ]; then
		echo "f_admindb_delete_scriptstatus: $P_SCRIPTNUM script_status is not finalized due to ERRORs \"$F_RUN\""
		exit 37
	fi
}

C_ADMINDB_RELEASESTATUS=
C_ADMINDB_ALL_SCIPTS_COUNT=
C_ADMINDB_NOT_APPLIED_SCIPTS_COUNT=
function f_admindb_getreleasestatus() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2

	f_admindb_parsereleasenumber $P_RELEASE

	f_get_db_password $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN

	echo $P_DB_TNS_NAME: get release $P_RELEASE status ...
	f_exec_limited 60 "(
		echo \"select 'VALUE=' || rel_status || '=' as x from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES where release='$C_ADMINDB_REL_FULL';\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME | grep VALUE | cut -d \"=\" -f2"

	C_ADMINDB_RELEASESTATUS="$S_EXEC_LIMITED_OUTPUT"
	local F_CHECK=`echo "$C_ADMINDB_RELEASESTATUS" | egrep "(ORA-|PLS-)"`
	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ] || [ "$F_CHECK" != "" ]; then
		echo "f_admindb_getreleasestatus: error executing query: $F_CHECK. Exiting"
		exit 1
	fi

	f_exec_limited 60 "(
		echo \"select 'VALUE=' || count(*) || '=' as x from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$C_ADMINDB_REL_FULL';\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME | grep VALUE | cut -d \"=\" -f2"

	C_ADMINDB_ALL_SCIPTS_COUNT="$S_EXEC_LIMITED_OUTPUT"
	local F_CHECK=`echo "$C_ADMINDB_ALL_SCIPTS_COUNT" | egrep "(ORA-|PLS-)"`
	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ] || [ "$F_CHECK" != "" ]; then
		echo "f_admindb_getreleasestatus: error executing query: $F_CHECK. Exiting"
		exit 1
	fi

	f_exec_limited 60 "(
		echo \"select 'VALUE=' || count(*) || '=' as x from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$C_ADMINDB_REL_FULL' and script_status='S';\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME | grep VALUE | cut -d \"=\" -f2"

	C_ADMINDB_NOT_APPLIED_SCIPTS_COUNT="$S_EXEC_LIMITED_OUTPUT"
	local F_CHECK=`echo "$C_ADMINDB_NOT_APPLIED_SCIPTS_COUNT" | egrep "(ORA-|PLS-)"`
	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ] || [ "$F_CHECK" != "" ]; then
		echo "f_admindb_getreleasestatus: error executing query: $F_CHECK. Exiting"
		exit 1
	fi
}

function f_admindb_beginrelease() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2

	# check release is new
	echo check release status...
	f_admindb_getreleasestatus $P_RELEASE $P_DB_TNS_NAME
	if [ "$C_ADMINDB_RELEASESTATUS" != "" ]; then
		return 1
	fi

	f_admindb_parsereleasenumber $P_RELEASE

	# INSERT into $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES
	echo add release...
	f_get_db_password $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_exec_limited 60 "(
		echo \"INSERT INTO $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES (release, rel_p1, rel_p2, rel_p3, rel_p4, begin_apply_time, end_apply_time, rel_status ) \"
		echo \"VALUES ( '$C_ADMINDB_REL_FULL', $C_ADMINDB_REL_P1, $C_ADMINDB_REL_P2, $C_ADMINDB_REL_P3, $C_ADMINDB_REL_P4, SYSDATE, NULL, 'S' );\"
		echo \"COMMIT;\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME | egrep \"(ORA-|PLS-)\""

	local F_RUN="$S_EXEC_LIMITED_OUTPUT"
	if [ "$F_RUN" != "" ]; then
		echo "f_admindb_beginrelease: can't insert $C_ADMINDB_REL_FULL value into $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES due to ERROR \"$F_RUN\""
		exit 2
	fi
}

function f_admindb_finishrelease() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2

	f_admindb_parsereleasenumber $P_RELEASE

	f_get_db_password $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_exec_limited 60 "(
		echo \"UPDATE $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES set end_apply_time=sysdate, rel_status='A' where release='$C_ADMINDB_REL_FULL';\"
		echo \"COMMIT;\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME | egrep \"(ORA-|PLS-)\""

	local F_RUN="$S_EXEC_LIMITED_OUTPUT"
	if [ "$F_RUN" != "" ]; then
		echo "$f_admindb_finishrelease: can't update rel_status field for $C_ADMINDB_REL_FULL in $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES due to ERROR \"$F_RUN\""
		exit 3
	fi
}

function f_admindb_droprelease() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2

	f_admindb_parsereleasenumber $P_RELEASE

	f_get_db_password $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_exec_limited 60 "(
		echo \"delete from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$C_ADMINDB_REL_FULL';\"
		echo \"delete from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES where release='$C_ADMINDB_REL_FULL';\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME"

	C_ADMINDB_SQLRES="$S_EXEC_LIMITED_OUTPUT"
	local F_CHECK=`echo "$C_ADMINDB_SQLRES" | egrep "(ORA-|PLS-)"`
	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ] || [ "$F_CHECK" != "" ]; then
		echo "f_admindb_droprelease: error executing query: $F_CHECK. Exiting"
		exit 1
	fi

	echo $P_DB_TNS_NAME: delete release $P_RELEASE - $C_ADMINDB_SQLRES
}

function f_admindb_dropreleaseitems() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2
	local P_IDLIST="$3"
	local P_ALIGNEDID=$4

	f_admindb_parsereleasenumber $P_RELEASE "$P_IDLIST"

	f_sqlidx_getoraclemask "FILENAME" "$P_IDLIST" $P_ALIGNEDID
	F_ORACLEMASK="$S_SQL_LISTMASK"

	f_get_db_password $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_exec_limited 60 "(
		echo \"delete from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$C_ADMINDB_REL_FULL' and ( $F_ORACLEMASK );\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME"

	C_ADMINDB_SQLRES="$S_EXEC_LIMITED_OUTPUT"
	local F_CHECK=`echo "$C_ADMINDB_SQLRES" | egrep "(ORA-|PLS-)"`
	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ] || [ "$F_CHECK" != "" ]; then
		echo "f_admindb_dropreleaseitems: error executing query: $F_CHECK. Exiting"
		exit 1
	fi

	echo $P_DB_TNS_NAME: delete release $P_RELEASE items - $C_ADMINDB_SQLRES
}

function f_admindb_checkandfinishrelease() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2

	# finish release status
	f_admindb_getreleasestatus $P_RELEASE $P_DB_TNS_NAME

	if [ "$C_ADMINDB_NOT_APPLIED_SCIPTS_COUNT" = "0" ] || [ "$GETOPT_SKIPERRORS" = "yes" ]; then
		f_admindb_finishrelease $P_RELEASE $P_DB_TNS_NAME
		echo "$P_DB_TNS_NAME: release $P_RELEASE is finalized." 
	else
		echo ""
		echo "$P_DB_TNS_NAME: release $P_RELEASE is not finalized. There are unapplied sql scripts." 
	fi
}

function f_admindb_fixreleaseall() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2

	f_admindb_parsereleasenumber $P_RELEASE

	f_get_db_password $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_exec_limited 60 "(
		echo \"update $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS set script_status = 'A' where release='$C_ADMINDB_REL_FULL' and script_status <> 'A';\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME"

	C_ADMINDB_SQLRES="$S_EXEC_LIMITED_OUTPUT"
	local F_CHECK=`echo "$C_ADMINDB_SQLRES" | egrep "(ORA-|PLS-)"`
	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ] || [ "$F_CHECK" != "" ]; then
		echo "f_admindb_fixreleaseall: error executing query: $F_CHECK. Exiting"
		exit 1
	fi

	echo $P_DB_TNS_NAME: fix release $P_RELEASE - $C_ADMINDB_SQLRES
}

function f_admindb_fixreleaseitems() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2
	local P_IDLIST="$3"
	local P_ALIGNEDID=$4

	f_admindb_parsereleasenumber $P_RELEASE

	f_sqlidx_getoraclemask "FILENAME" "$P_IDLIST" $P_ALIGNEDID
	F_ORACLEMASK="$S_SQL_LISTMASK"

	f_get_db_password $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_exec_limited 60 "(
		echo \"update $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS set script_status = 'A' where release='$C_ADMINDB_REL_FULL' and script_status <> 'A' and ( $F_ORACLEMASK );\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME"

	C_ADMINDB_SQLRES="$S_EXEC_LIMITED_OUTPUT"
	local F_CHECK=`echo "$C_ADMINDB_SQLRES" | egrep "(ORA-|PLS-)"`
	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ] || [ "$F_CHECK" != "" ]; then
		echo "f_admindb_fixreleaseitems: error executing query: $F_CHECK. Exiting"
		exit 1
	fi

	echo $P_DB_TNS_NAME: delete release $P_RELEASE items - $C_ADMINDB_SQLRES
}

function f_admindb_getreleasefailed() {
	local P_RELEASE=$1
	local P_DB_TNS_NAME=$2

	local F_IDLIST=`echo $P_IDLIST | sed "s/ /,/g"`

	f_admindb_parsereleasenumber $P_RELEASE

	f_get_db_password $P_DB_TNS_NAME $C_CONFIG_SCHEMAADMIN
	f_exec_limited 60 "(
		echo \"select 'SCRIPT=' || ID as script from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where script_status <> 'A' and release='$C_ADMINDB_REL_FULL' order by 1;\"
	) | sqlplus -S $C_CONFIG_SCHEMAADMIN/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME"

	C_ADMINDB_SQLRES="$S_EXEC_LIMITED_OUTPUT"
	local F_CHECK=`echo "$C_ADMINDB_SQLRES" | egrep "(ORA-|PLS-)"`
	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ] || [ "$F_CHECK" != "" ]; then
		echo "f_admindb_getreleasefailed: error executing query: $F_CHECK. Exiting"
		exit 1
	fi

	C_ADMINDB_SQLRES=`echo "$C_ADMINDB_SQLRES" | grep "SCRIPT=" | cut -d "=" -f2 | tr "\n" " "`
}
