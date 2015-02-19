# Oracle-specific implementations

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

