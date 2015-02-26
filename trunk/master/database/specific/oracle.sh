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

function f_specific_check_connect() {
	local P_DB_TNS_NAME=$1
	local P_SCHEMA=$2
	local P_DB_USE_SCHEMA_PASSWORD=$3

	f_exec_limited 30 "(echo select 1 from dual\;) | sqlplus $P_SCHEMA/$S_DB_USE_SCHEMA_PASSWORD@$P_DB_TNS_NAME | egrep \"ORA-\""
	local F_CHECK_OUTPUT=$S_EXEC_LIMITED_OUTPUT
	local F_CHECK=`echo $F_CHECK_OUTPUT | egrep "ORA-"`

	if [ "$F_CHECK_OUTPUT" = "KILLED" ] || [ "$F_CHECK" != "" ]; then
		S_SPECIFIC_VALUE="$F_CHECK_OUTPUT"
	else
		S_SPECIFIC_VALUE=""
	fi
}
