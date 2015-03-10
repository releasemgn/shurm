# Oracle-specific implementations

S_SPECIFIC_VALUE=
S_SPECIFIC_OUTPUT=
S_SPECIFIC_MASK=

function f_oracle_sqlidx_getmask() {
	local P_FIELD=$1
	local P_EXECUTE_LIST="$2"
	local P_ALIGNEDID=$3

	local F_GREP="1 = 2"
	for index in $EXECUTE_LIST; do
		if [[ "$index" =~ ^[0-9] ]]; then
			F_GREP="$F_GREP OR $P_FIELD like '$index-%'"
		else
			# treat index as source folder name
			f_sqlidx_getmask $index $P_ALIGNEDID
			F_GREP="$F_GREP OR regexp_count( $P_FIELD , '^$S_SQL_DIRMASK' ) = 1"
		fi
	done

	S_SPECIFIC_MASK="$F_GREP"
}

###########################################

function f_specific_validate_content() {
	local P_SCRIPT=$1

	local WRONG_END=`sed '/^$/d' $P_SCRIPT | tail -2 | tr -d "\\n\\r" | tr -d " " | tr '[a-z]' '[A-Z]' | grep -ce "END;\$"`
	if [[ "$WRONG_END" != "0" ]]; then
		S_CHECK_SQL_MSG="no trailing slash on BEGIN-END block, sqlplus may hang - $script (END;)"
		return 1
	fi

	return 0
}

S_SPECIFIC_COMMENT=
function f_specific_getcomments() {
	local P_SCRIPT=$1
	local P_COMMENTMASK="$2"

	S_SPECIFIC_COMMENT=`grep "^\-\- $P_COMMENTMASK" $P_SCRIPT`
}

function f_specific_grepcomments() {
	local P_PATTERN=$1
	local P_SRCFILE=$2

	grep -he "-- $P_PATTERN" $P_SRCFILE
}

function f_specific_addcomment() {
	local P_COMMENT=$1

	echo -- $P_COMMENT
}

function f_specific_uddi_begin() {
	local P_FNAME=$1

	(
		echo -- register endpoints
		echo begin
	) >> $P_FNAME
}

function f_specific_uddi_addendpoint() {
	local P_KEY=$1
	local P_UDDI=$2
	local P_FNAME=$3

	echo 	juddi.j3_setup.set_endpoint\( \'$P_KEY\' , \'$P_UDDI\' \)\; >> $P_FNAME
}

function f_specific_uddi_end() {
	local P_FNAME=$1

	(
		echo commit\;
		echo end\;
		echo /
		echo --
	) >> $P_FNAME
}

function f_specific_smevattr_begin() {
	local P_FNAME=$1

	(
		echo -- register smev attributes
		echo begin
	) >> $P_FNAME
}

function f_specific_smevattr_addvalue() {
	local P_UDDI_ATTR_ID=$1
	local P_UDDI_ATTR_NAME=$2
	local P_UDDI_ATTR_CODE=$3
	local P_UDDI_ATTR_REGION=$4
	local P_UDDI_ATTR_ACCESSPOINT=$5
	local P_FNAME=$6

	echo 	juddi.j3_setup.set_endpoint_smev_attributes\( \'$P_UDDI_ATTR_ID\' , \'$P_UDDI_ATTR_NAME\' , \'$P_UDDI_ATTR_CODE\' , \'$P_UDDI_ATTR_REGION\' , \'$P_UDDI_ATTR_ACCESSPOINT\' \)\; >> $P_FNAME
}

function f_specific_smevattr_end() {
	local P_FNAME=$1

	(
		echo commit\;
		echo end\;
		echo /
		echo --
	) >> $P_FNAME
}

########################

function f_specific_check_connect() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"

	S_SPECIFIC_VALUE=""

	f_exec_limited 30 "(echo select 1 from dual\;) | sqlplus $P_SCHEMA/\"$P_DB_USE_SCHEMA_PASSWORD\"@$P_DB_TNS_NAME | egrep \"ORA-\""

	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ]; then
		S_SPECIFIC_VALUE="KILLED"
	else
		S_SPECIFIC_VALUE=`echo $S_EXEC_LIMITED_OUTPUT | egrep "ORA-"`
	fi
}

function f_specific_check_output() {
	local P_FILE=$1

	S_SPECIFIC_VALUE=""

	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ]; then
		S_SPECIFIC_VALUE="KILLED"
	else
		S_SPECIFIC_VALUE=$(egrep "(ORA-|PLS-|SP2-)" $P_FILE)
	fi
}

function f_specific_exec_sqlcmd() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_CMD="$4"
	local P_LIMIT=$5
	local P_OUTFILE="$6"

	S_SPECIFIC_VALUE=""

	if [ "$P_LIMIT" = "" ]; then
		P_LIMIT=600
	fi

	export NLS_LANG=AMERICAN_AMERICA.CL8MSWIN1251
	f_exec_limited $P_LIMIT "echo \"$P_CMD\" | sqlplus -S $P_SCHEMA/\"$P_DB_USE_SCHEMA_PASSWORD\"@$P_DB_TNS_NAME" $P_OUTFILE

	if [ "$P_OUTFILE" != "" ]; then
		f_specific_check_output $P_OUTFILE
	else
		S_SPECIFIC_OUTPUT="$S_EXEC_LIMITED_OUTPUT"
		S_SPECIFIC_VALUE=$(echo $S_EXEC_LIMITED_OUTPUT | egrep "(ORA-|PLS-|SP2-)")
	fi		
}

function f_specific_exec_sqlfile() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_SCRIPTFILE="$4"
	local P_LIMIT=$5
	local P_OUTFILE="$6"

	if [ "$P_LIMIT" = "" ]; then
		P_LIMIT=600
	fi

	export NLS_LANG=AMERICAN_AMERICA.CL8MSWIN1251
	f_exec_limited $P_LIMIT "sqlplus $P_SCHEMA/\"$P_DB_USE_SCHEMA_PASSWORD\"@$P_DB_TNS_NAME" $P_OUTFILE $P_SCRIPTFILE
	f_specific_check_output $P_OUTFILE
}

function f_specific_exec_sqlsys() {
	local P_DB_TNS_NAME=$1
	local P_PASSWORD="$2"

	S_SPECIFIC_VALUE=""

	export NLS_LANG=AMERICAN_AMERICA.CL8MSWIN1251
	F_CHECK_OUT=`sqlplus sys/"$P_PASSWORD"@$P_DB_TNS_NAME "as sysdba" 2>&1`

	S_SPECIFIC_VALUE=`echo $F_CHECK_OUT | egrep "(ORA-|PLS-|SP2-)"`
}

function f_specific_add_sqlheader() {
	local P_SCRIPTNAME=$1
	local P_OUTDIR=$2

	echo -- standard script header
	echo set define off
	echo set echo on
	echo spool $P_OUTDIR/$P_SCRIPTNAME.spool append
	echo select sysdate from dual\;
}

function f_specific_add_forceexit() {
	echo ''
	echo exit
	echo ''
}

function f_specific_loadfile() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_FILE_NAME=$4
	local P_OUTDIR=$5

	S_SPECIFIC_VALUE=""

	local F_CTLNAME=`basename $P_FILE_NAME`

	export NLS_LANG=AMERICAN_AMERICA.CL8MSWIN1251
	sqlldr $P_SCHEMA/"$P_DB_USE_SCHEMA_PASSWORD"@$P_DB_TNS_NAME control=$P_FILE_NAME log=$P_OUTDIR/$F_CTLNAME.log bad=$P_OUTDIR/$F_CTLNAME.bad >> $P_OUTDIR/$F_CTLNAME.out

	if [ $? -ne 0 ]; then
		S_SPECIFIC_VALUE="sqlldr failed - see $P_OUTDIR/$F_CTLNAME.log"
	fi
}

#################################

function f_specific_admin_add_insert_script() {
	local P_RELEASE=$1
	local P_SCHEMA=$2
	local P_SCRIPTNUM=$3
	local P_SCRIPTNAME=$4

	echo "INSERT INTO $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS (RELEASE, SCHEMA, ID, FILENAME, UPDATETIME, UPDATEUSERID, SCRIPT_STATUS)"
	echo "VALUES ('$P_RELEASE', '$P_SCHEMA', $P_SCRIPTNUM, '$P_SCRIPTNAME', SYSDATE, sys_context('USERENV','OS_USER') , 'S');"
	echo "COMMIT;"
}

function f_specific_admin_add_update_script() {
	local P_RELEASE=$1
	local P_SCRIPTNUM=$2

	echo "update $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS set UPDATETIME=SYSDATE where RELEASE='$P_RELEASE' and ID=$P_SCRIPTNUM;"
	echo "commit;"
}

function f_specific_admin_update_scriptstatus() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_SCRIPTNUM=$5
	local P_STATUS=$6
	
	local F_CTLSQL="
		update $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS set SCRIPT_STATUS='$P_STATUS' where RELEASE='$P_RELEASE' and ID=$P_SCRIPTNUM;
		commit;"
	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_get_scriptstatus() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_SCRIPTNUM=$5

	local F_CTLSQL="select 'VALUE=' || SCRIPT_STATUS || '=' as x from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE' and ID=$P_SCRIPTNUM;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "$P_DB_TNS_NAME: cannot get script id=$P_SCRIPTNUM status. Exiting"    
		echo "$S_SPECIFIC_VALUE"
		exit 38
	fi 

	S_SPECIFIC_VALUE=`echo "$S_SPECIFIC_OUTPUT" | grep VALUE | cut -d "=" -f2`
}

function f_specific_admin_get_releasestatuses() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_FILE=$5

	local F_CTLSQL="
		set pagesize 0
		select ID || '=' || SCRIPT_STATUS || '=' as x from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE' order by ID;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 300 $P_FILE
}

function f_specific_admin_delete_scriptstatus() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_SCRIPTNUM=$5

	local F_CTLSQL="
		delete from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where RELEASE = '$P_RELEASE' and ID = $P_SCRIPTNUM;
		echo commit;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_get_releasestatus() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="select 'VALUE=' || rel_status || '=' as x from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES where release='$P_RELEASE';"
	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60

	if [ "$S_SPECIFIC_VALUE" = "" ]; then
		S_SPECIFIC_OUTPUT=`echo "$S_SPECIFIC_OUTPUT" | grep VALUE | cut -d "=" -f2`
	fi
}

function f_specific_admin_get_releasescriptcount() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="select 'VALUE=' || count(*) || '=' as x from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE';"
	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60

	if [ "$S_SPECIFIC_VALUE" = "" ]; then
		S_SPECIFIC_OUTPUT=`echo "$S_SPECIFIC_OUTPUT" | grep VALUE | cut -d "=" -f2`
	fi
}

function f_specific_admin_get_releasescriptfailedcount() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="select 'VALUE=' || count(*) || '=' as x from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE' and script_status='S';"
	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60

	if [ "$S_SPECIFIC_VALUE" = "" ]; then
		S_SPECIFIC_OUTPUT=`echo "$S_SPECIFIC_OUTPUT" | grep VALUE | cut -d "=" -f2`
	fi
}

function f_specific_admin_create_release() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_REL_P1=$5
	local P_REL_P2=$6
	local P_REL_P3=$7
	local P_REL_P4=$8

	local F_CTLSQL="
		INSERT INTO $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES (release, rel_p1, rel_p2, rel_p3, rel_p4, begin_apply_time, end_apply_time, rel_status )
		VALUES ( '$P_RELEASE', $P_REL_P1, $P_REL_P2, $P_REL_P3, $P_REL_P4, SYSDATE, NULL, 'S' );
		COMMIT;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_finish_release() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="
		UPDATE $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES set end_apply_time=sysdate, rel_status='A' where release='$P_RELEASE';
		COMMIT;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_drop_release() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="
		delete from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE';
		delete from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_RELEASES where release='$P_RELEASE';"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_deletescripts() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_IDLIST="$5"
	local P_ALIGNEDID=$6

	f_oracle_sqlidx_getmask "FILENAME" "$P_IDLIST" $P_ALIGNEDID
	local F_ORACLEMASK="$S_SPECIFIC_MASK"

	local F_CTLSQL="delete from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE' and ( $F_ORACLEMASK );"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_fixall_release() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="update $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS set script_status = 'A' where release='$P_RELEASE' and script_status <> 'A';"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_fix_releaseitems() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_IDLIST="$5"
	local P_ALIGNEDID=$6

	f_oracle_sqlidx_getmask "FILENAME" "$P_IDLIST" $P_ALIGNEDID
	local F_ORACLEMASK="$S_SPECIFIC_MASK"

	local F_CTLSQL="update $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS set script_status = 'A' where release='$P_RELEASE' and script_status <> 'A' and ( $F_ORACLEMASK );"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_get_failedscripts() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="select 'SCRIPT=' || ID as script from $C_CONFIG_SCHEMAADMIN.$C_CONFIG_SCHEMAADMIN_SCRIPTS where script_status <> 'A' and release='$P_RELEASE' order by 1;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60

	if [ "$S_SPECIFIC_VALUE" = "" ]; then
		S_SPECIFIC_OUTPUT=`echo "$S_SPECIFIC_OUTPUT" | grep "SCRIPT=" | cut -d "=" -f2 | tr "\n" " "`
	fi
}

function f_specific_check_dbms_available() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2

	# check tnsname is sql client is available
	local F_FINDSQLPLUS=`which sqlplus 2>&1`
	if [ "$F_FINDSQLPLUS" = "" ] || [[ "$F_FINDSQLPLUS" =~ "no sqlplus" ]]; then
		return 0
	fi

	echo check schema=$P_SCHEMA ...
	f_check_db_connect "oracle" $P_DB_TNS_NAME $P_SCHEMA
	local RES=$?

	return $RES
}

###########################################

function f_specific_expdp() {
	local P_LOADCONNECTION=$1
	local P_PARAMS="$2"

	if [[ "$P_LOADCONNECTION" =~ "sys/" ]] || [ "$P_LOADCONNECTION" = "/" ]; then
		echo execute expdp \"$P_LOADCONNECTION as sysdba\" $P_PARAMS ...
		expdp \"$P_LOADCONNECTION as sysdba\" $P_PARAMS
		if [ "$?" != "0" ]; then
			return 1
		fi
	else
		echo execute expdp $P_LOADCONNECTION $P_PARAMS ...
		expdp $P_LOADCONNECTION $P_PARAMS
		if [ "$?" != "0" ]; then
			return 1
		fi
	fi

	return 0
}

function f_specific_impdp() {
	local P_LOADCONNECTION=$1
	local P_PARAMS="$2"

	if [[ "$P_LOADCONNECTION" =~ "sys/" ]] || [ "$P_LOADCONNECTION" = "/" ]; then
		echo execute impdp \"$P_LOADCONNECTION as sysdba\" $P_PARAMS ...
		impdp \"$P_LOADCONNECTION as sysdba\" $P_PARAMS
		if [ "$?" != "0" ]; then
			return 1
		fi
	else
		echo execute impdp $P_LOADCONNECTION $P_PARAMS ...
		impdp $P_LOADCONNECTION $P_PARAMS
		if [ "$?" != "0" ]; then
			return 1
		fi
	fi

	return 0
}

function f_specific_sqlexec() {
	local P_CONNECTION=$1
	local P_SCRIPT_RUN=$2
	local P_SCRIPT_OUT=$3

	if [[ "$P_CONNECTION" =~ "sys/" ]] || [ "$P_CONNECTION" = "/" ]; then
		sqlplus $P_CONNECTION "as sysdba" < $P_SCRIPT_RUN > $P_SCRIPT_OUT
	else
		sqlplus $P_CONNECTION < $P_SCRIPT_RUN > $P_SCRIPT_OUT
	fi
}

function f_specific_remote_sqlexec() {
	local P_CONNECTION=$1
	local P_SCRIPT_RUN=$2
	local P_SCRIPT_OUT=$3

	if [[ "$P_CONNECTION" =~ "sys/" ]] || [ "$P_CONNECTION" = "/" ]; then
		ssh $C_ENV_CONFIG_REMOTE_HOSTLOGIN "cd $C_ENV_CONFIG_REMOTE_ROOT; rm -rf $P_SCRIPT_OUT; . $C_ENV_CONFIG_REMOTE_SETORAENV $C_ENV_CONFIG_ENV $C_ENV_CONFIG_DB; sqlplus $P_CONNECTION "as sysdba" < $P_SCRIPT_RUN > $P_SCRIPT_OUT 2>&1"
	else
		ssh $C_ENV_CONFIG_REMOTE_HOSTLOGIN "cd $C_ENV_CONFIG_REMOTE_ROOT; rm -rf $P_SCRIPT_OUT; . $C_ENV_CONFIG_REMOTE_SETORAENV $C_ENV_CONFIG_ENV $C_ENV_CONFIG_DB; sqlplus $P_CONNECTION < $P_SCRIPT_RUN > $P_SCRIPT_OUT 2>&1"
	fi

}

function f_specific_createloaddir() {
	local P_LOADDIR=$1

	echo "-- create export dir" >> $C_CONFIG_CREATEDATA_SQLFILE
	echo "create or replace directory ORACLE_DYNAMICDATADIR as '$C_ENV_CONFIG_REMOTE_ROOT/$P_LOADDIR';" >> $C_CONFIG_CREATEDATA_SQLFILE
}

function f_specific_createloadinfotable() {
	echo "-- setup table with uat table data" >> $C_CONFIG_CREATEDATA_SQLFILE
	echo "drop table $C_ENV_CONFIG_TABLESET;" >> $C_CONFIG_CREATEDATA_SQLFILE
	echo "create table $C_ENV_CONFIG_TABLESET ( tschema varchar2(128) , rschema varchar2(128), tname varchar2(128) , status char(1) );" >> $C_CONFIG_CREATEDATA_SQLFILE
}

function f_specific_addloadinforecord() {
	local tschema_upper=$1
	local rschema_upper=$2
	local table_upper=$3
	local status=$4

	echo "insert into $C_ENV_CONFIG_TABLESET ( tschema , rschema , tname , status ) values ( '$tschema_upper' , '$rschema_upper' , '$table_upper' , '$status' );" >> $C_CONFIG_CREATEDATA_SQLFILE
}

function f_specific_export_schemadata_all() {
	local P_LOADCONNECTION=$1
	local P_DUMP=$2
	local P_LOG=$3
	local P_SCHEMA=$4

	f_specific_expdp $P_LOADCONNECTION "DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$P_DUMP LOGFILE=$P_LOG schemas=$P_SCHEMA CONTENT=DATA_ONLY"
}

function f_specific_export_schemadata_selected() {
	local P_LOADCONNECTION=$1
	local P_DUMP=$2
	local P_LOG=$3
	local P_SCHEMA=$4

	# impossible to adopt to oracle quotes and shell !
	if [[ "$P_LOADCONNECTION" =~ "sys/" ]] || [ "$P_LOADCONNECTION" = "/" ]; then
		echo "execute expdp \"$P_LOADCONNECTION as sysdba\" DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$P_DUMP LOGFILE=$P_LOG schemas=$P_SCHEMA CONTENT=DATA_ONLY include=TABLE:\"IN \(select tname from $C_ENV_CONFIG_TABLESET where status = \'S\' and tschema = \'$P_SCHEMA\'\)\" ..."
		expdp \"$P_LOADCONNECTION as sysdba\" DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$P_DUMP LOGFILE=$P_LOG schemas=$P_SCHEMA CONTENT=DATA_ONLY include=TABLE:\"IN \(select tname from $C_ENV_CONFIG_TABLESET where status = \'S\' and tschema = \'$P_SCHEMA\'\)\"
	else
		echo "execute expdp $P_LOADCONNECTION DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$P_DUMP LOGFILE=$P_LOG schemas=$P_SCHEMA CONTENT=DATA_ONLY include=TABLE:\"IN \(select tname from $C_ENV_CONFIG_TABLESET where status = \'S\' and tschema = \'$P_SCHEMA\'\)\" ..."
		expdp $P_LOADCONNECTION DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=$P_DUMP LOGFILE=$P_LOG schemas=$P_SCHEMA CONTENT=DATA_ONLY include=TABLE:\"IN \(select tname from $C_ENV_CONFIG_TABLESET where status = \'S\' and tschema = \'$P_SCHEMA\'\)\"
	fi
}

function f_specific_exportmeta() {
	f_expdp $S_LOADCONNECTION "CONTENT=METADATA_ONLY schemas=$P_SCHEMA_SET exclude=STATISTICS DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=meta.dmp LOGFILE=meta.log"

	#----------------- export role data
	f_expdp $S_LOADCONNECTION "full=y INCLUDE=role DIRECTORY=$C_ENV_CONFIG_DATAPUMP_DIR DUMPFILE=role.dmp LOGFILE=role.log"
}
