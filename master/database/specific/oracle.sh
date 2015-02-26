# Oracle-specific implementations

S_SPECIFIC_VALUE=

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
	local P_DB_USE_SCHEMA_PASSWORD=$3

	S_SPECIFIC_VALUE=""

	f_exec_limited 30 "(echo select 1 from dual\;) | sqlplus $P_SCHEMA/$P_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME | egrep \"ORA-\""

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
	local P_DB_USE_SCHEMA_PASSWORD=$3
	local P_CMD="$4"
	local P_OUTFILE="$5"

	S_SPECIFIC_VALUE=""

	export NLS_LANG=AMERICAN_AMERICA.CL8MSWIN1251
	f_exec_limited 600 "sqlplus $P_SCHEMA/$P_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME \"$P_CMD\"" $P_OUTFILE

	if [ "$P_OUTFILE" != "" ]; then
		f_specific_check_output $P_OUTFILE
	else
		S_SPECIFIC_VALUE=$(echo $S_EXEC_LIMITED_OUTPUT | egrep "(ORA-|PLS-|SP2-)")
	fi		
}

function f_specific_exec_sqlfile() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD=$3
	local P_SCRIPTFILE="$4"
	local P_OUTFILE="$5"

	export NLS_LANG=AMERICAN_AMERICA.CL8MSWIN1251
	f_exec_limited 600 "sqlplus $P_SCHEMA/$P_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME" $P_OUTFILE $P_SCRIPTFILE
	f_specific_check_output $P_OUTFILE
}

function f_specific_exec_sqlsys() {
	local P_DB_TNS_NAME=$1
	local P_PASSWORD=$2

	S_SPECIFIC_VALUE=""

	export NLS_LANG=AMERICAN_AMERICA.CL8MSWIN1251
	F_CHECK_OUT=`sqlplus sys/$P_PASSWORD@$P_DB_TNS_NAME "as sysdba" 2>&1`

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
	local P_DB_USE_SCHEMA_PASSWORD=$3
	local P_FILE_NAME=$4
	local P_OUTDIR=$5

	S_SPECIFIC_VALUE=""

	local F_CTLNAME=`basename $P_FILE_NAME`

	export NLS_LANG=AMERICAN_AMERICA.CL8MSWIN1251
	sqlldr $P_SCHEMA/$P_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME control=$P_FILE_NAME log=$P_OUTDIR/$F_CTLNAME.log bad=$P_OUTDIR/$F_CTLNAME.bad >> $P_OUTDIR/$F_CTLNAME.out

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
