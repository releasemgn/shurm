#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

. ../../etc/config.sh

if [ "$C_CONFIG_PRODUCT_DEPLOYMENT_HOME" = "" ]; then
	echo C_CONFIG_PRODUCT_DEPLOYMENT_HOME is not defined. Exiting
	exit 1
fi

#################################################################### non-specific function

S_DBMS_TYPE=
function f_get_dbmstype() {
	local P_CONFIGPATH=$1

	. $P_CONFIGPATH

	if [ "$C_ENV_CONFIG_ENV" = "" ] || [ "$C_ENV_CONFIG_DC" = "" ] || [ "$C_ENV_CONFIG_DB" = "" ]; then
		echo "C_ENV_CONFIG_ENV, C_ENV_CONFIG_DC, C_ENV_CONFIG_DB should be set in export configuration file to define database server affected. Exiting"
		exit 1
	fi

	C_ENV_FILE=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/env/$C_ENV_CONFIG_ENV.xml

	# set environment file
	f_env_setpath $C_ENV_FILE

	# get server info
	f_env_getxmlserverinfo $C_ENV_CONFIG_DC $C_ENV_CONFIG_DB

	if [ "$C_ENV_SERVER_DBMSTYPE" = "" ]; then
		echo "C_ENV_SERVER_DBMSTYPE is not defined. Exiting"
		exit 1
	fi

	if [ ! -f "specific/$C_ENV_SERVER_DBMSTYPE.sh" ]; then
		echo "unable to find dbms specific code file specific/$C_ENV_SERVER_DBMSTYPE.sh. Exiting"
		exit 1
	fi

	S_DBMS_TYPE=$C_ENV_SERVER_DBMSTYPE
}

function f_common_watchcmd() {
	local P_TIMEOUT=$1
	local P_MARKER=$2

	sleep 5

	local K=0
	local F_PSVALUE_STARTED
	while [ "$K" -lt $P_TIMEOUT ]; do
		sleep 1
		K=$(expr $K + 1)

		# check process exists
		F_PSVALUE_STARTED=`pgrep -f "MARKER=$P_MARKER"`
		if [ "$F_PSVALUE_STARTED" = "" ]; then
			return 0
		fi
	done

	# kill process
	kill -9 $F_PSVALUE_STARTED
	return 1
}

S_EXEC_LIMITED_OUTPUT=
function f_exec_limited() {
	P_LIMITSECS=$1
	P_CMD="$2"
	P_RESFILE="$3"
	P_INFILE="$4"

	# execute command
	if [ "$P_RESFILE" != "" ]; then
		rm -rf $P_RESFILE
	fi

	local F_MARKER=`mktemp urm.XXXXXXXXXX`
	f_common_watchcmd $P_LIMITSECS $F_MARKER > /dev/null 2>&1 &

	if [ "$P_INFILE" = "" ]; then
		P_INFILE=/dev/null
	fi

	local F_STATUS
	echo "$P_CMD" > ./$F_MARKER
	chmod 700 ./$F_MARKER
	S_EXEC_LIMITED_OUTPUT=
	if [ "$P_RESFILE" != "" ]; then
		sh -c "MARKER=$F_MARKER; ./$F_MARKER < $P_INFILE > $P_RESFILE 2>&1"
		F_STATUS=$?
	else
		S_EXEC_LIMITED_OUTPUT=`sh -c "MARKER=$F_MARKER; ./$F_MARKER < $P_INFILE"`
		F_STATUS=$?
	fi

	rm -rf ./$F_MARKER

	if [ "$F_STATUS" = "137" ]; then
		S_EXEC_LIMITED_OUTPUT="KILLED"
	fi

	return $F_STATUS
}

S_ORG_FOLDERID=
S_ORG_ERROR_MSG=
function f_sqlidx_getorginfo() {
	local P_ORGID=$1

	S_ORG_FOLDERID=
	S_ORG_ERROR_MSG=

	# read org item mapping
	local F_ORGFILE=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/orginfo.txt
	if [ ! -f "$F_ORGFILE" ]; then
		S_ORG_ERROR_MSG="Organizational mapping file $F_ORGFILE not found"
		return 1 # error
	fi

	S_ORG_FOLDERID=`grep "^$P_ORGID=" $F_ORGFILE | cut -d "=" -f2`
	if [ "$S_ORG_FOLDERID" = "" ]; then
		S_ORG_ERROR_MSG="Organizational item $P_ORGID not found in orginfo.txt"
		return 1 # error
	fi

	return 0
}

S_WAR_MRID=
S_WAR_ERROR_MSG=
function f_sqlidx_getwarinfo() {
	local P_WAR=$1

	# get war from distributive info
	f_distr_readitem $P_WAR 'P_RETURN_IF_NOT_FOUND'

	if [ "$?" = "1" ]; then
		S_WAR_ERROR_MSG="distribution item $P_WAR not found in distr.xml"
		return 1 # error
	fi

	# check pguwar
	if [ "$C_DISTR_TYPE" != "pguwar" ]; then
		S_WAR_ERROR_MSG="distribution item $P_WAR is of type $C_DISTR_TYPE, permitted only \"pguwar\""
		return 1 # error
	fi

	S_WAR_MRID=$C_DISTR_WAR_MRID
	if [ "$S_WAR_MRID" = "" ]; then
		S_WAR_MRID="00"
	fi
}

S_SQL_DIRID=

S_ORG_EXTID=
S_ORG_REGIONID=
S_ORG_FULLID=
S_ORG_SUBDIRID=

S_WAR_REGIONID=
S_WAR_NAME=
S_WAR_SUBDIRNAME=
S_WAR_SUBDIRID=

function f_sqlidx_getprefix() {
	local P_FORLDERNAME=$1
	local P_ALIGNEDID=$2

	P_FORLDERNAME=${P_FORLDERNAME//\//.}
	local F_FOLDERBASE=`echo $P_FORLDERNAME | cut -d "." -f1`	

	S_SQL_DIRID=

	S_ORG_EXTID=
	S_ORG_REGIONID=
	S_ORG_FULLID=
	S_ORG_SUBDIRID=

	S_WAR_REGIONID=
	S_WAR_NAME=
	S_WAR_SUBDIRNAME=
	S_WAR_SUBDIRID=

	if [ "$F_FOLDERBASE" = "coreddl" ]; then
		S_SQL_DIRID=0$P_ALIGNEDID

	elif [ "$F_FOLDERBASE" = "coredml" ]; then
		S_SQL_DIRID=1$P_ALIGNEDID

	elif [ "$F_FOLDERBASE" = "coreprodonly" ] || [ "$F_FOLDERBASE" = "coreuatonly" ]; then
		S_SQL_DIRID=2$P_ALIGNEDID

	elif [ "$F_FOLDERBASE" = "coresvc" ]; then
		S_SQL_DIRID=3$P_ALIGNEDID

	elif [ "$F_FOLDERBASE" = "war" ]; then
		S_WAR_REGIONID=`echo $P_FORLDERNAME | cut -d "." -f2`
		S_WAR_NAME=`echo $P_FORLDERNAME | cut -d "." -f3`
		S_WAR_SUBDIRNAME=`echo $P_FORLDERNAME | cut -d "." -f4`

		if [ "$S_WAR_SUBDIRNAME" = "juddi" ]; then
			S_WAR_SUBDIRID=4$P_ALIGNEDID

		elif [ "$S_WAR_SUBDIRNAME" = "svcdic" ]; then
			S_WAR_SUBDIRID=5$P_ALIGNEDID

		elif [ "$S_WAR_SUBDIRNAME" = "svcspec" ]; then
			S_WAR_SUBDIRID=6$P_ALIGNEDID

		else
			echo f_sqlidx_getprefix: invalid folder=$P_FORLDERNAME. Exiting
			exit 1
		fi

		f_sqlidx_getwarinfo $S_WAR_NAME

		S_SQL_DIRID=$S_WAR_SUBDIRID$S_WAR_REGIONID$S_WAR_MRID

	elif [ "$F_FOLDERBASE" = "forms" ]; then
		S_ORG_REGIONID=`echo $P_FORLDERNAME | cut -d "." -f2`
		S_ORG_EXTID=`echo $P_FORLDERNAME | cut -d "." -f3`
		S_ORG_SUBDIRNAME=`echo $P_FORLDERNAME | cut -d "." -f4`

		# get ORGID info
		f_sqlidx_getorginfo $S_ORG_EXTID
		
		if [ "$S_ORG_SUBDIRNAME" = "juddi" ]; then
			S_ORG_SUBDIRID=4$P_ALIGNEDID

		elif [ "$S_ORG_SUBDIRNAME" = "svcdic" ]; then
			S_ORG_SUBDIRID=5$P_ALIGNEDID

		elif [ "$S_ORG_SUBDIRNAME" = "svcspec" ]; then
			S_ORG_SUBDIRID=6$P_ALIGNEDID

		elif [ "$S_ORG_SUBDIRNAME" = "svcform" ]; then
			S_ORG_SUBDIRID=7$P_ALIGNEDID

		else
			echo f_sqlidx_getprefix: invalid folder=$P_FORLDERNAME. Exiting
			exit 1
		fi

		S_SQL_DIRID=$S_ORG_SUBDIRID${S_ORG_REGIONID}99$S_ORG_FOLDERID

	else
		echo f_sqlidx_getprefix: invalid folder=$P_FORLDERNAME. Exiting
		exit 1
	fi
}

S_SQL_DIRMASK=

function f_sqlidx_getmask() {
	local P_FORLDERNAME=$1
	local P_ALIGNEDID=$2

	S_SQL_DIRMASK=

	S_ORG_EXTID=
	S_ORG_REGIONID=
	S_ORG_FULLID=

	S_WAR_REGIONID=
	S_WAR_NAME=
	S_WAR_SUBDIRNAME=

	P_FORLDERNAME=${P_FORLDERNAME//\//.}
	local F_FOLDERBASE=`echo $P_FORLDERNAME | cut -d "." -f1`

	if [ "$F_FOLDERBASE" = "war" ]; then
		S_WAR_REGIONID=`echo $P_FORLDERNAME | cut -d "." -f2`
		S_WAR_NAME=`echo $P_FORLDERNAME | cut -d "." -f3`
		S_WAR_SUBDIRNAME=`echo $P_FORLDERNAME | cut -d "." -f4`

		if [ "$S_WAR_SUBDIRNAME" = "" ]; then
			f_sqlidx_getwarinfo $S_WAR_NAME
			S_SQL_DIRMASK="[4-6]$P_ALIGNEDID$S_WAR_REGIONID$S_WAR_MRID.*"
			return 0
		fi

	elif [ "$F_FOLDERBASE" = "forms" ]; then
		S_ORG_REGIONID=`echo $P_FORLDERNAME | cut -d "." -f2`
		S_ORG_EXTID=`echo $P_FORLDERNAME | cut -d "." -f3`
		S_ORG_SUBDIRNAME=`echo $P_FORLDERNAME | cut -d "." -f4`

		if [ "$S_ORG_SUBDIRNAME" = "" ]; then
			f_sqlidx_getorginfo $S_ORG_EXTID
			S_SQL_DIRMASK="[4-7]$P_ALIGNEDID${S_ORG_REGIONID}99$S_ORG_FOLDERID.*"
			return 0
		fi

	elif [ "$F_FOLDERBASE" = "dataload" ]; then
		S_SQL_DIRMASK="[8-9]$P_ALIGNEDID.*"
		return 0
	fi

	# use by default
	f_sqlidx_getprefix $P_FORLDERNAME $P_ALIGNEDID
	S_SQL_DIRMASK="$S_SQL_DIRID.*"
}

S_SQL_LISTMASK=

function f_sqlidx_getegrepmask() {
	local P_EXECUTE_LIST="$1"
	local P_ALIGNEDID=$2

	local F_GREP="(IGNORE"
	for index in $EXECUTE_LIST; do
		if [[ "$index" =~ ^[0-9] ]]; then
			if [[ "$index" =~ ^8 ]]; then
				# dataload case - ctl file + related data files
				local F_BASEINDEX=${index#8}
				F_GREP="$F_GREP|dataload/$index-|^dataload/$F_BASEINDEX-|/dataload/$F_BASEINDEX-"
			else
				F_GREP="$F_GREP|^$index-|/$index-"
			fi
		else
			# treat index as source folder name
			if [ "$index" = "dataload" ]; then
				F_GREP="$F_GREP|dataload/"
			else
				f_sqlidx_getmask $index $P_ALIGNEDID
				F_GREP="$F_GREP|^$S_SQL_DIRMASK|/$S_SQL_DIRMASK"
			fi
		fi
	done

	F_GREP="$F_GREP)"
	S_SQL_LISTMASK="$F_GREP"
}

function f_sqlidx_getegrepexecmask() {
	local P_EXECUTE_LIST="$1"
	local P_ALIGNEDID=$2

	local F_GREP="(IGNORE"
	for index in $EXECUTE_LIST; do
		if [[ "$index" =~ ^[0-9] ]]; then
			F_GREP="$F_GREP|^$index-"
		else
			f_sqlidx_getmask $index $P_ALIGNEDID
			F_GREP="$F_GREP|^$S_SQL_DIRMASK"
		fi
	done

	F_GREP="$F_GREP)"
	S_SQL_LISTMASK="$F_GREP"
}

function f_sqlidx_getoraclemask() {
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

	S_SQL_LISTMASK="$F_GREP"
}

S_DB_ALLSCHEMALIST=
function f_getregionaldbschemalist() {
	local P_TNSLIST="$1"
	local P_REGIONS="$2"

	S_DB_ALLSCHEMALIST=

	if [ "$P_REGIONS" = "" ]; then
		S_DB_ALLSCHEMALIST="$P_TNSLIST"
		return 0
	fi

	local schema
	local region
	local F_REGION_SCHEMAS
	for schema in $P_TNSLIST; do
		if [[ "$schema" =~ "RR" ]]; then
			F_REGION_SCHEMAS=
			for region in $P_REGIONS; do
				F_REGION_SCHEMAS="$F_REGION_SCHEMAS ${schema/RR/$region}"
			done
			S_DB_ALLSCHEMALIST="$S_DB_ALLSCHEMALIST $F_REGION_SCHEMAS"
		else
			S_DB_ALLSCHEMALIST="$S_DB_ALLSCHEMALIST $schema"
		fi
	done
}

function f_getalldbschemalist() {
	local P_REGIONS="$1"

	f_getregionaldbschemalist "$C_CONFIG_SCHEMAALLLIST" "$P_REGIONS"
}

S_DBMS_VALUE=
function f_getdbms_srcfolders() {
	local P_LIST="$1"

	f_getsubsetexact "$P_LIST" "sql pgsql"
	S_DBMS_VALUE="$C_COMMON_SUBSET"
}

function f_getdbms_typebysrcfolder() {
	local P_FOLDER=$1

	if [ "$P_FOLDER" = "sql" ]; then
		S_DBMS_VALUE=oracle

	elif [ "$P_FOLDER" = "pgsql" ]; then
		S_DBMS_VALUE=postgres

	else
		echo unknown source folder $P_FOLDER. Exiting
		exit 1
	fi
}

#################################################################### specific functions


function f_getdbms_relfolderbytype() {
	local P_DBMSTYPE=$1

	if [ "$P_DBMSTYPE" = "oracle" ]; then
		S_DBMS_VALUE=SQL

	elif [ "$P_DBMSTYPE" = "postgres" ]; then
		S_DBMS_VALUE=PGSQL

	else
		echo unknown dbmstype $P_DBMSTYPE. Exiting
		exit 1
	fi
}

S_DB_USE_SCHEMA_PASSWORD=
function f_get_db_password() {
	local P_DBMSTYPE=$1
	local P_DB_TNSNAME=$2
	local P_DB_SCHEMA=$3

	if [ "$GETOPT_DBAUTH" != "yes" ]; then
		S_DB_USE_SCHEMA_PASSWORD=$P_DB_SCHEMA

	elif [ "$GETOPT_DBPASSWORD" != "" ]; then
		S_DB_USE_SCHEMA_PASSWORD=$GETOPT_DBPASSWORD

	elif [ "$C_ENV_PROPERTY_DBAUTHFILE" != "" ]; then
		# check file
		local F_FNAME=$C_ENV_PROPERTY_DBAUTHFILE
		if [ ! -f "$F_FNAME" ]; then
			echo f_get_db_password: password file $F_FNAME does not exist. Exiting
			exit 1
		fi

		# get password
		S_DB_USE_SCHEMA_PASSWORD=`cat $F_FNAME | grep "^$P_DB_TNSNAME.$P_DB_SCHEMA=" | cut -d "=" -f2 | tr -d "\n\r"`
		if [ "$S_DB_USE_SCHEMA_PASSWORD" = "" ]; then
			echo f_get_db_password: unable to find password for tnsname=$P_DB_TNSNAME, schema=$P_DB_SCHEMA in $F_FNAME. Exiting
			exit 1
		fi
	else
		echo f_get_db_password: unable to derive auth type. Exiting
		exit 1
	fi
}

function f_check_db_connect() {
	local P_DBMSTYPE=$1
	local P_DB_TNS_NAME=$2
	local P_SCHEMA=$3

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $P_SCHEMA

	f_specific_check_connect $P_DB_TNS_NAME $P_SCHEMA $S_DB_USE_SCHEMA_PASSWORD

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_check_db_connect: Can't connect to $P_SCHEMA@$P_DB_TNS_NAME due to ERROR \"$S_SPECIFIC_VALUE\""
		exit 20
	fi
}

function f_exec_sql() {
	local P_DBMSTYPE=$1
	local P_DB_TNS_NAME=$2
	local P_SCHEMA=$3
	local P_SCRIPTFILE=$4
	local P_OUTDIR=$5
	local P_SKIPERROR=$6
	local P_SPECIAL_CMD=$7
	local P_SPECIAL_PASSWORD=$8

	local F_SCRIPTNAME=`basename $P_SCRIPTFILE`

	if [ "$P_SPECIAL_PASSWORD" = "" ]; then
		f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $P_SCHEMA
	else
		S_DB_USE_SCHEMA_PASSWORD=$P_SPECIAL_PASSWORD
	fi

	if [ "$P_SPECIAL_CMD" != "" ]; then
		f_specific_exec_sqlcmd $P_DB_TNS_NAME $P_SCHEMA $S_DB_USE_SCHEMA_PASSWORD "$P_SPECIAL_CMD" $P_OUTDIR/$F_SCRIPTNAME.out
	else
		f_specific_exec_sqlfile $P_DB_TNS_NAME $P_SCHEMA $S_DB_USE_SCHEMA_PASSWORD "$P_SCRIPTFILE" $P_OUTDIR/$F_SCRIPTNAME.out
	fi

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "$P_DB_TNS_NAME: $F_SCRIPTNAME is applied to $P_SCHEMA with ERRORs \"$S_SPECIFIC_VALUE\""
		echo "$P_DB_TNS_NAME: "Pls, see" $P_OUTDIR/$F_SCRIPTNAME.out"

		if [ "$P_SKIPERROR" = "yes" ]; then
			return 1
		else
			echo f_exec_sql: found error in strict mode, script=$F_SCRIPTNAME. Exiting.
			exit 33
		fi
	else
		echo "$P_DB_TNS_NAME: $F_SCRIPTNAME is applied to $P_SCHEMA"
	fi

	return 0
}

function f_exec_syssql() {
	local P_DBMSTYPE=$1
	local P_DB_TNS_NAME=$2
	local P_SCRIPTFILE=$3
	local P_OUTDIR=$4
	local P_SKIPERROR=$5
	local P_SPECIALPASSWORD=$6

	f_exec_sql $P_DBMSTYPE $P_DB_TNS_NAME sys $P_SCRIPTFILE $P_OUTDIR $P_SKIPERROR "as sysdba" $P_SPECIALPASSWORD
	return $?
}

function f_exec_syssql_private() {
	local P_DBMSTYPE=$1
	local P_DB_TNS_NAME=$2
	local P_PASSWORD=$3
	local P_SKIPERROR=$4

	f_specific_exec_sqlsys $P_DB_TNS_NAME $P_PASSWORD

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "$P_DB_TNS_NAME: private script is applied to sys with ERRORs"

		if [ "$P_SKIPERROR" = "yes" ]; then
			return 1
		else
			echo f_exec_syssql_private: found error in strict mode in private script. Exiting.
			exit 33
		fi
	else
		echo "$P_DB_TNS_NAME: private script is applied to sys"
	fi
}

function f_add_sqlheader() {
	local P_DBMSTYPE=$1
	local P_SCRIPTNAME=$2
	local P_OUTDIR=$3

	f_specific_add_sqlheader $P_SCRIPTNAME $P_OUTDIR
}

function f_add_sqlfile() {
	local P_DBMSTYPE=$1
	local P_FNAME=$2

	if [ -r $P_FNAME ]; then
		cat $P_FNAME
		f_specific_add_forceexit
	else
		echo "f_add_sqlfile: Can't find sql-script $P_FNAME"
		exit 34
	fi
}

function f_sqlload_ctlfile() {
	local P_DBMSTYPE=$1
	local P_DB_TNS_NAME=$2
	local P_SCHEMA=$3
	local P_FILE_NAME=$4
	local P_OUTDIR=$5

	local F_CTLNAME=`basename $P_FILE_NAME`
	local F_CTLDIR=`dirname $P_FILE_NAME`

	mkdir -p $P_OUTDIR

	local F_SAVEDIR=`pwd`
	cd $F_CTLDIR

	echo "load data file to $P_SCHEMA@$P_DB_TNS_NAME control=$P_FILE_NAME log=$P_OUTDIR/$F_CTLNAME.out ..." > $P_OUTDIR/$F_CTLNAME.out

	f_get_db_password $P_DBMSTYPE $P_DB_TNS_NAME $P_SCHEMA
	f_specific_loadfile $P_DB_TNS_NAME $P_SCHEMA $S_DB_USE_SCHEMA_PASSWORD $P_FILE_NAME $P_OUTDIR

	if [ "$S_SPECIFIC_VALUE" != "" ]; then
		echo "f_specific_loadfile failed - $S_SPECIFIC_VALUE. Exiting"
		cd $F_SAVEDIR
		exit 1
	fi

	cd $F_SAVEDIR
	echo "$P_DB_TNS_NAME: $P_FILE_NAME is loaded into $P_SCHEMA"
}

# load configuration xml helpers

. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/common.sh
. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/commonenv.sh
. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/commondistr.sh
. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/common/commonrelease.sh
