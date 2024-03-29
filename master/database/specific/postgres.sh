# PostgreSQL-specific implementations

S_SPECIFIC_CONNECT=
S_SPECIFIC_MASK=

function f_postgres_getconnect() {
	local P_DB_TNS_NAME=$1
	
	local DBNAME=${P_DB_TNS_NAME%%@*}
	local DBHOST=${P_DB_TNS_NAME#*@}

	S_SPECIFIC_CONNECT="-d $DBNAME -h $DBHOST"
}

function f_postgres_sqlidx_getmask() {
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
			F_GREP="$F_GREP OR $P_FIELD ~ '^$S_SQL_DIRMASK'"
		fi
	done

	S_SPECIFIC_MASK="$F_GREP"
}

###########################################

function f_specific_validate_content() {
	local P_SCRIPT=$1

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

	echo f_specific_smevattr_addvalue - NOT SUPPORTED. Exiting
	exit 1
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

	f_postgres_getconnect $P_DB_TNS_NAME
	export PGPASSWORD=$P_DB_USE_SCHEMA_PASSWORD
	f_exec_limited 30 "(echo select \'value=ok\' as x\;) | psql $S_SPECIFIC_CONNECT -U $P_SCHEMA | egrep \"ORA-\""

	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ]; then
		S_SPECIFIC_VALUE="KILLED"
	else
		if [[ ! "$S_EXEC_LIMITED_OUTPUT" =~ "value=ok" ]]; then
			S_SPECIFIC_VALUE="$S_EXEC_LIMITED_OUTPUT"
		fi
	fi
}

function f_specific_check_output() {
	local P_FILE=$1

	S_SPECIFIC_VALUE=""

	if [ "$S_EXEC_LIMITED_OUTPUT" = "KILLED" ]; then
		S_SPECIFIC_VALUE="KILLED"
	else
		S_SPECIFIC_VALUE=$(grep "^ERROR:" $P_FILE)
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

	export PGCLIENTENCODING=WIN1251
	export PGPASSWORD=$P_DB_USE_SCHEMA_PASSWORD
	f_postgres_getconnect $P_DB_TNS_NAME
	f_exec_limited $P_LIMIT "echo \"$P_CMD\" | psql $S_SPECIFIC_CONNECT -U $P_SCHEMA" $P_OUTFILE

	if [ "$P_OUTFILE" != "" ]; then
		f_specific_check_output $P_OUTFILE
	else
		S_SPECIFIC_OUTPUT="$S_EXEC_LIMITED_OUTPUT"
		S_SPECIFIC_VALUE=$(echo $S_EXEC_LIMITED_OUTPUT | grep "^ERROR:")
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

	export PGCLIENTENCODING=WIN1251
	export PGPASSWORD=$P_DB_USE_SCHEMA_PASSWORD
	f_postgres_getconnect $P_DB_TNS_NAME
	f_exec_limited $P_LIMIT "psql $S_SPECIFIC_CONNECT -U $P_SCHEMA -e" $P_OUTFILE $P_SCRIPTFILE
	f_specific_check_output $P_OUTFILE
}

function f_specific_exec_sqlsys() {
	local P_DB_TNS_NAME=$1
	local P_PASSWORD="$2"

	echo NOT IMPLEMENTED. Exiting
	exit 1
}

function f_specific_add_sqlheader() {
	local P_SCRIPTNAME=$1
	local P_OUTDIR=$2

	echo -- standard script header
	echo "select now();"
}

function f_specific_add_forceexit() {
	return 0
}

function f_specific_loadfile() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_FILE_NAME=$4
	local P_OUTDIR=$5

	echo NOT IMPLEMENTED. Exiting
	exit 1
}

#################################

function f_specific_admin_add_insert_script() {
	local P_RELEASE=$1
	local P_SCHEMA=$2
	local P_SCRIPTNUM=$3
	local P_SCRIPTNAME=$4

	echo "INSERT INTO $C_CONFIG_SCHEMAADMIN_SCRIPTS (RELEASE, SCHEMA, ID, FILENAME, UPDATETIME, UPDATEUSERID, SCRIPT_STATUS)"
	echo "VALUES ('$P_RELEASE', '$P_SCHEMA', $P_SCRIPTNUM, '$P_SCRIPTNAME', now(), current_user , 'S');"
	echo "COMMIT;"
}

function f_specific_admin_add_update_script() {
	local P_RELEASE=$1
	local P_SCRIPTNUM=$2

	echo "update $C_CONFIG_SCHEMAADMIN_SCRIPTS set UPDATETIME=now() where RELEASE='$P_RELEASE' and ID=$P_SCRIPTNUM;"
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
		update $C_CONFIG_SCHEMAADMIN_SCRIPTS set SCRIPT_STATUS='$P_STATUS' where RELEASE='$P_RELEASE' and ID=$P_SCRIPTNUM;
		commit;"
	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_get_scriptstatus() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_SCRIPTNUM=$5

	local F_CTLSQL="select 'VALUE=' || SCRIPT_STATUS || '=' as x from $C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE' and ID=$P_SCRIPTNUM;"

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
		select ID || '=' || SCRIPT_STATUS || '=' as x from $C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE' order by ID;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 300 $P_FILE
	sed -i "s/^ *//" $P_FILE
}

function f_specific_admin_delete_scriptstatus() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_SCRIPTNUM=$5

	local F_CTLSQL="
		delete from $C_CONFIG_SCHEMAADMIN_SCRIPTS where RELEASE = '$P_RELEASE' and ID = $P_SCRIPTNUM;
		echo commit;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_get_releasestatus() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="select 'VALUE=' || rel_status || '=' as x from $C_CONFIG_SCHEMAADMIN_RELEASES where release='$P_RELEASE';"
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

	local F_CTLSQL="select 'VALUE=' || count(*) || '=' as x from $C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE';"
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

	local F_CTLSQL="select 'VALUE=' || count(*) || '=' as x from $C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE' and script_status='S';"
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
		INSERT INTO $C_CONFIG_SCHEMAADMIN_RELEASES (release, rel_p1, rel_p2, rel_p3, rel_p4, begin_apply_time, end_apply_time, rel_status )
		VALUES ( '$P_RELEASE', $P_REL_P1, $P_REL_P2, $P_REL_P3, $P_REL_P4, now(), NULL, 'S' );
		COMMIT;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_finish_release() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="
		UPDATE $C_CONFIG_SCHEMAADMIN_RELEASES set end_apply_time=now(), rel_status='A' where release='$P_RELEASE';
		COMMIT;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_drop_release() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="
		delete from $C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE';
		delete from $C_CONFIG_SCHEMAADMIN_RELEASES where release='$P_RELEASE';"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_deletescripts() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_IDLIST="$5"
	local P_ALIGNEDID=$6

	f_postgres_sqlidx_getmask "FILENAME" "$P_IDLIST" $P_ALIGNEDID
	local F_POSTGRESMASK="$S_SPECIFIC_MASK"

	local F_CTLSQL="delete from $C_CONFIG_SCHEMAADMIN_SCRIPTS where release='$P_RELEASE' and ( $F_POSTGRESMASK );"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_fixall_release() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="update $C_CONFIG_SCHEMAADMIN_SCRIPTS set script_status = 'A' where release='$P_RELEASE' and script_status <> 'A';"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_fix_releaseitems() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4
	local P_IDLIST="$5"
	local P_ALIGNEDID=$6

	f_postgres_sqlidx_getmask "FILENAME" "$P_IDLIST" $P_ALIGNEDID
	local F_POSTGRESMASK="$S_SPECIFIC_MASK"

	local F_CTLSQL="update $C_CONFIG_SCHEMAADMIN_SCRIPTS set script_status = 'A' where release='$P_RELEASE' and script_status <> 'A' and ( $F_POSTGRESMASK );"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60
}

function f_specific_admin_get_failedscripts() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD="$3"
	local P_RELEASE=$4

	local F_CTLSQL="select 'SCRIPT=' || ID as script from $C_CONFIG_SCHEMAADMIN_SCRIPTS where script_status <> 'A' and release='$P_RELEASE' order by 1;"

	f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA "$P_DB_USE_SCHEMA_PASSWORD" "$F_CTLSQL" 60

	if [ "$S_SPECIFIC_VALUE" = "" ]; then
		S_SPECIFIC_OUTPUT=`echo "$S_SPECIFIC_OUTPUT" | grep "SCRIPT=" | cut -d "=" -f2 | tr "\n" " "`
	fi
}

function f_specific_check_dbms_available() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2

	# check tnsname is sql client is available
	local F_FINDSQLPLUS=`which psql 2>&1`
	if [ "$F_FINDSQLPLUS" = "" ] || [[ "$F_FINDSQLPLUS" =~ "no psql" ]]; then
		return 0
	fi

	echo check schema=$P_SCHEMA ...
	f_check_db_connect "oracle" $P_DB_TNS_NAME $P_SCHEMA
	local RES=$?

	return $RES
}
