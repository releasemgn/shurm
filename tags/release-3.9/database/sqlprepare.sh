#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

# Usage example: ./sqlprepare.sh prod-patch-2.1.3.1 prod-patch-2.1.3.1.run

SCRIPTDIR=`dirname $0`
cd $SCRIPTDIR
SCRIPTDIR=`pwd`

. ./getopts.sh

DBMSTYPE=$1
SQL_VERSION_ORIGINAL=$2
SQL_VERSION_PREPARED=$3
SQL_SVNRELEASEURL=$4

# check params

if [ "$SQL_VERSION_ORIGINAL" = "" ]; then
	echo sqlprepare.sh: SQL_VERSION_PREPARED not set
	exit 1
fi

if [ "$SQL_VERSION_PREPARED" = "" ]; then
	SQL_VERSION_PREPARED=$SQL_VERSION_ORIGINAL.run
fi

# execute

. ./specific/$DBMSTYPE.sh
. ./common.sh

S_CHECK_FAILED=no

S_CHECK_SQL_MSG=
function f_local_check_sql() {
	local P_ALIGNEDNAME=$1
	local P_SCRIPT=$2

	f_specific_validate_content $P_SCRIPT
	if [ "$?" != 0 ]; then
		return 1
	fi

	# check if regional
	if [ "$P_ALIGNEDNAME" = "regional" ]; then
		f_specific_getcomments $P_SCRIPT "REGIONS " 
		if [ "$S_SPECIFIC_COMMENT" = "" ]; then
			S_CHECK_SQL_MSG="script should have REGIONS header property - $P_SCRIPT"
			return 1
		fi
	fi		

	return 0
}

function f_local_cp_sql() {
	local script=$1
	local dest=$2

	cp $script $dest
}

function f_local_move_errors() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local P_PATH="$3"
	local P_COMMENT=$4
	
	if [ "$GETOPT_MOVE_ERRORS" != "yes" ] || [ "$SQL_SVNRELEASEURL" = "" ]; then
		echo "errors in $P_PATH: $P_COMMENT"
		return 0
	fi

	echo "moving $P_PATH to errors folder ..."

	local F_ITEMBASE=`basename "$P_PATH"`
	local F_ITEMDIR=`dirname "$P_PATH"`

	local F_SVNPATH=$P_PATH
	if [ "$P_ALIGNEDNAME" != "common" ]; then
		F_SVNPATH="$P_ALIGNEDNAME/$P_PATH"
	fi

	# drop old in svn if any
	F_SVNSTATUS=`svn info $C_CONFIG_SVNOLD_AUTH "$SQL_SVNRELEASEURL/errors/$F_SVNPATH" 2>&1 | grep -c 'Not a valid URL'`
	if [ "$F_SVNSTATUS" = "0" ]; then
		svn delete $C_CONFIG_SVNOLD_AUTH -m "delete before adding the same" "$SQL_SVNRELEASEURL/errors/$F_SVNPATH" > /dev/null
	fi

	# ensure dir created
	F_SVNSTATUS=`svn info $C_CONFIG_SVNOLD_AUTH "$SQL_SVNRELEASEURL/errors/$F_ITEMDIR" 2>&1 | grep -c 'Not a valid URL'`
	if [ "$F_SVNSTATUS" != "0" ]; then
		svn mkdir $C_CONFIG_SVNOLD_AUTH -m "create parent dir before move" --parents "$SQL_SVNRELEASEURL/errors/$F_ITEMDIR" > /dev/null
	fi

	# move item
	svn rename $C_CONFIG_SVNOLD_AUTH -m "$P_COMMENT" "$SQL_SVNRELEASEURL/sql/$F_SVNPATH" "$SQL_SVNRELEASEURL/errors/$F_SVNPATH" > /dev/null
}

function f_local_cp_dir() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local SQL_SRC_DIR=$3
	local SQL_DST_DIR=$4

	f_sqlidx_getprefix $SQL_SRC_DIR $P_ALIGNEDID
	local SQL_PREFIX=$S_SQL_DIRID

	# regional tail
	local F_REGIONALINDEX

	if [ ! -d $SQL_SRC_DIR ]; then
		if [ "$GETOPT_SHOWALL" = "yes" ]; then
			echo $SQL_SRC_DIR is not found. Skipped.
		fi
		return 1
	fi

	local F_XSAVEDIR=`pwd`

	mkdir -p $SQL_DST_DIR
	echo prepare/copy $SQL_SRC_DIR...
	cd $SQL_SRC_DIR

	# process apply scripts
	local x
	local xr
	local xrindex
	local xrnoindex
	local xrschema
	for x in $(find . -maxdepth 1 -name "*.sql"); do
		xr=${x#./}
		xrindex=${xr%%-*}
		xrtail=${xr#*-}
		xrschema=${xrtail%%-*}
		xrtail=${xrtail#*-}
		
		if [ "$P_ALIGNEDNAME" = "regional" ] || [[ "$xrschema" =~ "RR" ]]; then
			F_REGIONALINDEX="RR"
		else
			F_REGIONALINDEX=
		fi

		f_local_cp_sql $x $SQL_DST_DIR/$SQL_PREFIX$xrindex$F_REGIONALINDEX-$xrschema-$xrtail
	done

	# process rollback scripts
	if [ -d "rollback" ]; then
		mkdir -p $SQL_DST_DIR/rollback
		cd rollback

		for x in $(find . -maxdepth 1 -name "*.sql"); do
			xr=${x#./}
			xrindex=${xr%%-*}
			xrtail=${xr#*-}
			xrschema=${xrtail%%-*}
			xrtail=${xrtail#*-}
		
			if [ "$P_ALIGNEDNAME" = "regional" ] || [[ "$xrschema" =~ "RR" ]]; then
				F_REGIONALINDEX="RR"
			else
				F_REGIONALINDEX=
			fi

			f_local_cp_sql $x $SQL_DST_DIR/rollback/$SQL_PREFIX$xrindex$F_REGIONALINDEX-$xrschema-$xrtail
		done
		cd ..
	fi			

	cd $F_XSAVEDIR
}

function f_local_check_schema() {
	local P_ALIGNEDNAME=$1
	local P_SCHEMA=$2
	local P_SCHEMALIST="$3"

	if [ "$P_SCHEMA" = "" ]; then
		return 1
	fi

	# exact if regional or common
	if [ "$P_ALIGNEDNAME" = "common" ] || [ "$P_ALIGNEDNAME" = "regional" ]; then
		if [[ " $P_SCHEMALIST " =~ " $P_SCHEMA " ]]; then
			return 0
		fi
		return 1
	fi

	# in aligned can be both masked and direct
	local schema
	local F_MASK
	for schema in $P_SCHEMALIST; do
		F_MASK=${schema/RR/[0-9][0-9]}
		if [ "$P_SCHEMA" = "$schema" ] || [[ "$P_SCHEMA" =~ $F_MASK ]]; then
			return 0
		fi
	done

	return 1
}

function f_local_check_dir() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local P_DIR=$3
	local P_TYPE=$4
	local P_SCHEMALIST="$5"

	if [ ! -d $P_DIR ]; then
		return 0
	fi

	local xbase
	local xlist=`find $P_DIR -maxdepth 1 -type f -printf '"%f" '`
	while [ "1" = "1" ]; do
		if [[ "$xlist" =~ ^\" ]]; then
			xbase=`echo $xlist | cut -d "\"" -f2`
			xlist=${xlist#\"$xbase\"}
			xlist=${xlist# }
		else
			xbase=`echo $xlist | cut -d " " -f1`
			xlist=${xlist#$xbase}
			xlist=${xlist# }
		fi

		if [ "$xbase" = "" ]; then
			return 0
		fi

		local x="$P_DIR/$xbase"
		local F_ONEFAILED=no
		local F_ONEFAILED_MSG=""

		# check well-formed name
		if [ `echo $xbase | grep -c "[^0-9a-zA-Z_.-]"` -eq 1 ]; then
			F_ONEFAILED_MSG="$F_ONEFAILED_MSG; invalid filename characters - '$x'"
			F_ONEFAILED=yes
		fi

		# get extension
		local F_EXT=${xbase##*.}

		# for sql type it should be the ONLY extension
		if [ "$F_ONEFAILED" = "no" ] && [ "$P_TYPE" = "sql" ] && [ "$F_EXT" != "sql" ]; then
			F_ONEFAILED_MSG="$F_ONEFAILED_MSG; invalid filename extension - $x"
			F_ONEFAILED=yes
		fi

		if [ "$P_TYPE" = "sql" ]; then
			# for sql type files should have NNN-SCHEMA-zzz format
			local F_SCRIPTNUM=`echo $xbase | cut -d "-" -f1`
			local F_SCRIPTSCHEMA=`echo $xbase | cut -d "-" -f2`

			if [ "$F_ONEFAILED" = "no" ] && ([ "$F_SCRIPTNUM" = "" ] || [ `echo "$F_SCRIPTNUM" | grep -c "^[0-9][0-9][0-9]$"` -ne 1 ]); then
				F_ONEFAILED_MSG="$F_ONEFAILED_MSG; invalid script number - $x"
				F_ONEFAILED=yes
			fi

			# check scriptnum is unique
			if [ "$F_ONEFAILED" = "no" ] && ([ "$F_SCRIPTNUM" != "" ] && [ `find $P_DIR -maxdepth 1 -type f -name "$F_SCRIPTNUM*.$F_EXT" | grep -c "."` != "1" ]); then
				F_ONEFAILED_MSG="$F_ONEFAILED_MSG; not unique script number - $x"
				F_ONEFAILED=yes
			fi

			if [ "$F_ONEFAILED" = "no" ]; then
				f_local_check_schema $P_ALIGNEDNAME $F_SCRIPTSCHEMA "$P_SCHEMALIST"
				local F_STATUS=$?
				if [ "$F_STATUS" != "0" ]; then
					F_ONEFAILED_MSG="$F_ONEFAILED_MSG; invalid schema for $x, permitted schema list - $P_SCHEMALIST"
					F_ONEFAILED=yes
				fi
			fi

		elif [ "$P_TYPE" = "ctl" ]; then
			# for ctl type .sql and .ctl files should have NNN-SCHEMA-zzz format, other files should be NNN-xxx format
			local F_SCRIPTNUM=`echo $xbase | cut -d "-" -f1`
			if [ "$F_ONEFAILED" = "no" ] && ([ "$F_SCRIPTNUM" = "" ] || [ `echo "$F_SCRIPTNUM" | grep -c "^[0-9][0-9][0-9]$"` -ne 1 ]); then
				F_ONEFAILED_MSG="$F_ONEFAILED_MSG; invalid dataload file number - $x"
				F_ONEFAILED=yes
			fi

			if [ "$F_EXT" = "ctl" ] || [ "$F_EXT" = "sql" ]; then
				# check scriptnum is unique across the same extension
				if [ "$F_ONEFAILED" = "no" ] && ([ "$F_SCRIPTNUM" != "" ] && [ `find $P_DIR -maxdepth 1 -type f -name "$F_SCRIPTNUM*.$F_EXT" | grep -c "."` != "1" ]); then
					F_ONEFAILED_MSG="$F_ONEFAILED_MSG; not unique dataload file number - $x"
					F_ONEFAILED=yes
				fi

				local F_SCRIPTSCHEMA=`echo $xbase | cut -d "-" -f2`

				if [ "$F_ONEFAILED" = "no" ]; then
					f_local_check_schema $P_ALIGNEDNAME $F_SCRIPTSCHEMA "$P_SCHEMALIST"
					local F_STATUS=$?
					if [ "$F_STATUS" != "0" ]; then
						F_ONEFAILED_MSG="$F_ONEFAILED_MSG; invalid schema for $x, permitted schema list - $P_SCHEMALIST"
						F_ONEFAILED=yes
					fi
				fi
			fi

		elif [ "$P_TYPE" = "form" ]; then
			# for form script file should have ESERVICEID-FORMTYPE-form format, formtype=order
			local F_SERVICEID=`echo $xbase | cut -d "-" -f1`

			if [ "$F_SERVICEID-pguforms-orderform.sql" != "$xbase" ]; then
				F_ONEFAILED_MSG="$F_ONEFAILED_MSG; invalid script name=$xbase, expected - ESERVICEID-pguforms-orderform.sql"
				F_ONEFAILED=yes
			fi
		fi

		# check sql file content
		if [ "$F_ONEFAILED" = "no" ] && [ "$F_EXT" = "sql" ]; then
			f_local_check_sql $P_ALIGNEDNAME "$x"
			if [ $? -ne 0 ]; then
				F_ONEFAILED_MSG="$F_ONEFAILED_MSG; $S_CHECK_SQL_MSG"
				F_ONEFAILED=yes
			fi
		fi

		if [ "$F_ONEFAILED" = "yes" ]; then
			F_ONEFAILED_MSG="${F_ONEFAILED_MSG#; }"
			f_local_move_errors $P_ALIGNEDNAME $P_ALIGNEDID "$x" "$F_ONEFAILED_MSG"
			S_CHECK_FAILED=yes
		fi
	done
}

function f_local_check_one_war() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local P_MPNAME=$3

	local F_REGION=`echo $P_MPNAME | cut -d "." -f2`
	local F_WAR=`echo $P_MPNAME | cut -d "." -f3`

	local F_DIR_FAILED=no
	if [ "$F_REGION" = "" ] || [ "$F_WAR" = "" ]; then
		echo sqlprepare.sh: invalid regional war folder name=$P_MPNAME, expected format is war.regnum.warname
		F_DIR_FAILED="yes"
	fi

	# check region is NN
	if [ `echo "$F_REGION" | grep -c "^[0-9][0-9]$"` -ne 1 ]; then
		echo "sqlprepare.sh: invalid regional war folder name=$P_MPNAME, region=$F_REGION, expected NN"
		F_DIR_FAILED="yes"
	fi

	if [ "$F_DIR_FAILED" = "yes" ]; then
		S_CHECK_FAILED=yes
		f_local_move_errors $P_ALIGNEDNAME $P_ALIGNEDID $P_MPNAME "invalid regional war folder name=$P_MPNAME, expected format is war.regnum.warname"
		return 1
	fi

	f_sqlidx_getwarinfo $F_WAR
	if [ "$?" = "1" ]; then
		echo "ERROR: $S_WAR_ERROR_MSG"
		S_CHECK_FAILED=yes
		f_local_move_errors $P_ALIGNEDNAME $P_ALIGNEDID $P_MPNAME "$S_WAR_ERROR_MSG"
	fi

	echo check war region=$F_REGION, mpname=$P_MPNAME ...
	f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID $P_MPNAME/svcdic sql "nsi"
	f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID $P_MPNAME/svcspec sql "pguapi"
}

function f_local_check_one_forms() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local P_ORGNAME=$3

	local F_REGION=`echo $P_ORGNAME | cut -d "." -f2`
	local F_ORGID=`echo $P_ORGNAME | cut -d "." -f3`

	local F_DIR_FAILED=no
	if [ "$F_REGION" = "" ] || [ "$F_ORGID" = "" ]; then
		echo sqlprepare.sh: invalid regional forms folder name=$P_ORGNAME, expected format is forms.regnum.orgcode
		F_DIR_FAILED="yes"
	fi

	# check region is NN
	if [ `echo "$F_REGION" | grep -c "^[0-9][0-9]$"` -ne 1 ]; then
		echo "sqlprepare.sh: invalid regional folder name=$P_ORGNAME, region=$F_REGION, expected NN"
		F_DIR_FAILED="yes"
	fi

	if [ "$F_DIR_FAILED" = "yes" ]; then
		S_CHECK_FAILED=yes
		f_local_move_errors $P_ALIGNEDNAME $P_ALIGNEDID $P_ORGNAME "invalid regional forms folder name=$P_ORGNAME, expected format is forms.regnum.orgcode"
		return 1
	fi

	# check ORGID
	f_sqlidx_getorginfo $F_ORGID
	if [ "$?" = "1" ]; then
		echo "ERROR: $S_ORG_ERROR_MSG"
		S_CHECK_FAILED=yes
		f_local_move_errors $P_ALIGNEDNAME $P_ALIGNEDID $P_ORGNAME "$S_ORG_ERROR_MSG"
	fi

	echo check forms region=$F_REGION, orgname=$P_ORGNAME ...
	f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID $P_ORGNAME/svcdic sql "nsi"
	f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID $P_ORGNAME/svcspec sql "pgu pguapi"
	f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID $P_ORGNAME/svcform form
}

function f_local_execute_check() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2

	S_CHECK_FAILED=no

	# check folders
	local F_COREMASK="coreddl|coredml|coresvc|coreprodonly|coreuatonly|dataload|manual"
	if [ "$P_ALIGNEDNAME" = "common" ]; then
		F_COREMASK="aligned|$F_COREMASK"
	fi

	local F_SVCMASK="forms\\..*|war\\..*"
	local F_UNKNOWNFOLDERS=`ls | egrep -v "($F_COREMASK|$F_SVCMASK)" | tr "\n" " " | sed "s/ $//"`

	if [ "$F_UNKNOWNFOLDERS" != "" ]; then
		echo "sqlprepare.sh: aligned=$P_ALIGNEDNAME - invalid release folders (files): $F_UNKNOWNFOLDERS, expected: $F_COREMASK|$F_SVCMASK"

		for entry in $F_UNKNOWNFOLDERS; do
			f_local_move_errors $P_ALIGNEDNAME $P_ALIGNEDID $entry "invalid release folder (file): $entry, expected: $F_COREMASK|$F_SVCMASK"
		done

		if [ "$GETOPT_SKIPERRORS" != "yes" ]; then
			exit 1
		fi

		S_CHECK_FAILED=yes
	fi

	# check by folder
	if [ -d coreddl ] || [ -d coredml ] || [ -d coresvc ] || [ -d coreprodonly ] || [ -d coreuatonly ] || [ -d dataload ]; then
		echo check core ...
		f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID coreddl sql "$C_CONFIG_SCHEMAALLLIST"
		f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID coredml sql "$C_CONFIG_SCHEMAALLLIST"
		f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID coresvc sql "$C_CONFIG_SCHEMAALLLIST"
		f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID coreprodonly sql "$C_CONFIG_SCHEMAALLLIST"
		f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID coreuatonly sql "$C_CONFIG_SCHEMAALLLIST"
		f_local_check_dir $P_ALIGNEDNAME $P_ALIGNEDID dataload ctl "$C_CONFIG_SCHEMAALLLIST"
	fi

	# check wars
	local mpname
	for mpname in $(find . -maxdepth 1 -type d -name "war.*" | sort | sed "s/\.\///g" ); do
		f_local_check_one_war $P_ALIGNEDNAME $P_ALIGNEDID $mpname
	done			

	# check forms
	local orgname
	for orgname in $(find . -maxdepth 1 -type d -name "forms.*" | sort | sed "s/\.\///g" ); do
		f_local_check_one_forms $P_ALIGNEDNAME $P_ALIGNEDID $orgname
	done			

	if [ "$S_CHECK_FAILED" = "yes" ]; then
		echo sqlprepare.sh: errors in script set. Exiting
		if [ "$GETOPT_SKIPERRORS" != "yes" ]; then
			exit 1
		fi
	fi
}

S_DIC_CONTENT=no
S_SVC_CONTENT=no
S_SMEVATTR_CONTENT=no

function f_local_check_uddi() {
	local P_DICFILE_EP=$1
	local P_SVCFILE_EP=$2
	local P_SMEVATTRFILE=$3

	# check files have content
	S_DIC_CONTENT=no
	S_SVC_CONTENT=no
	S_SMEVATTR_CONTENT=no

	local CHECK_CONTENT=N
	if [ -f $P_DICFILE_EP ]; then
		if [ "`cat $P_DICFILE_EP | wc -l`" != "0" ]; then
			S_DIC_CONTENT=yes
			CHECK_CONTENT=Y
		fi
	fi

	if [ -f $P_SVCFILE_EP ]; then
		if [ "`cat $P_SVCFILE_EP | wc -l`" != "0" ]; then
			S_SVC_CONTENT=yes
			CHECK_CONTENT=Y
		fi
	fi

	if [ -f $P_SMEVATTRFILE ]; then
		if [ "`cat $P_SMEVATTRFILE | wc -l`" != "0" ]; then
			S_SMEVATTR_CONTENT=yes
			CHECK_CONTENT=Y
		fi
	fi

	if [ "$CHECK_CONTENT" != "Y" ]; then
		return 1
	fi

	return 0
}

function f_local_split_uddi_comment() {
	local line=$1

	line=`echo $line | sed "s/\r//;s/\n//"`

	UDDI_MARK=`echo $line | cut -d" " -f2`
	UDDI_KEY=`echo $line | cut -d" " -f3`
	UDDI_UAT=`echo $line | cut -d" " -f4`
	UDDI_PROD=`echo $line | cut -d" " -f5`

	# echo UDDI_KEY=$UDDI_KEY, UDDI_UAT=$UDDI_UAT, UDDI_PROD=$UDDI_PROD
}

# Check if endpoints are specified
function f_local_check_uddi_endpoints() {
	if [ "$UDDI_UAT" = "" ] || ([ "$UDDI_PROD" = "" ] && [ "$GETOPT_SCRIPTFOLDER" = "" ]); then
		return 1 # error
	fi
	return 0
}

function f_local_process_uddi_endpoints() {
	local P_SVCNUM=$1
	local FNAME_UAT=$2
	local FNAME_PROD=$3
	local DICFILE=$4
	local SVCFILE=$5

	# process content for endpoints
	local LOCAL_UDDI_FNAME=uddi.txt
	rm -rf $LOCAL_UDDI_FNAME

	if [ "$S_DIC_CONTENT" = "yes" ]; then
		cat $DICFILE >> $LOCAL_UDDI_FNAME
	fi

	if [ "$S_SVC_CONTENT" = "yes" ]; then
		cat $SVCFILE >> $LOCAL_UDDI_FNAME
	fi

	f_specific_uddi_begin $FNAME_UAT
	f_specific_uddi_begin $FNAME_PROD

	cat $LOCAL_UDDI_FNAME | while read line; do
		f_local_split_uddi_comment "$line"

		if [ "$UDDI_MARK" = "UDDI" ]; then
			f_local_check_uddi_endpoints
			if [ $? = 1 ]; then
				echo "sqlprepare.sh: invalid UDDI data: key=$UDDI_KEY, UDDI_UAT=$UDDI_UAT, UDDI_PROD=$UDDI_PROD"
			fi

			if [ "$UDDI_UAT" != "" ] || [ "$GETOPT_SCRIPTFOLDER" = "" ]; then
				f_specific_uddi_addendpoint $UDDI_KEY $UDDI_UAT $FNAME_UAT
			fi

			if [ "$UDDI_PROD" != "" ] || [ "$GETOPT_SCRIPTFOLDER" = "" ]; then
				f_specific_uddi_addendpoint $UDDI_KEY $UDDI_PROD $FNAME_PROD
			fi
		fi

	done

	if [ `cat $FNAME_UAT | grep -c "''" ` -ne 0 ]; then
		echo $FNAME_UAT: not all UAT endpoints are filled in...
		S_CHECK_FAILED=yes
		return 1
	fi

	if [ `cat $FNAME_PROD | grep -c "''"` -ne 0 ] && [ "$GETOPT_SCRIPTFOLDER" = "" ]; then
		echo $FNAME_PROD: not all PROD endpoints are filled in...
		S_CHECK_FAILED=yes
		return 1
	fi

	f_specific_uddi_end $FNAME_UAT
	f_specific_uddi_end $FNAME_PROD

	echo sqlprepare.sh: SVCNUM=$P_SVCNUM - UDDI content has been created for endpoints.
}

function f_local_process_uddi_smevattrs() {
	local P_SVCNUM=$1
	local FNAME_UAT=$2
	local FNAME_PROD=$3
	local SMEVATTRFILE=$4

	# process content for endpoints
	local LOCAL_UDDI_FNAME=uddi.txt
	rm -rf $LOCAL_UDDI_FNAME

	cat $SMEVATTRFILE >> $LOCAL_UDDI_FNAME

	f_specific_smevattr_begin $FNAME_UAT
	f_specific_smevattr_begin $FNAME_PROD

	cat $LOCAL_UDDI_FNAME | while read line; do
		local line=`echo $line | sed "s/\"/@/g;s/\n//"`
		local UDDI_ATTR_ID=`echo $line | cut -d " " -f3`
		local UDDI_ATTR_NAME=`echo $line | sed "s/.*name=@\([^@]*\)@.*/\1/g;s/'/''/g"`
		local UDDI_ATTR_CODE=`echo $line | sed "s/.*code=@\([^@]*\)@.*/\1/g"`
		local UDDI_ATTR_REGION=`echo $line | sed "s/.*region=@\([^@]*\)@.*/\1/g"`
		local UDDI_ATTR_ACCESSPOINT=`echo $line | sed "s/.*accesspoint=@\([^@]*\)@.*/\1/g"`

		if [ "$UDDI_ATTR_ID" = "" ] || [ "$UDDI_ATTR_NAME" = "" ] || [ "$UDDI_ATTR_CODE" = "" ] || [ "$UDDI_ATTR_REGION" = "" ] || [ "$UDDI_ATTR_ACCESSPOINT" = "" ]; then
			echo "sqlprepare.sh: invalid string - line=$line"
		fi

		f_specific_smevattr_addvalue $UDDI_ATTR_ID $UDDI_ATTR_NAME $UDDI_ATTR_CODE $UDDI_ATTR_REGION $UDDI_ATTR_ACCESSPOINT $FNAME_UAT
		f_specific_smevattr_addvalue $UDDI_ATTR_ID $UDDI_ATTR_NAME $UDDI_ATTR_CODE $UDDI_ATTR_REGION $UDDI_ATTR_ACCESSPOINT $FNAME_PROD
	done

	if [ `cat $FNAME_UAT | grep set_endpoint_smev_attributes | grep -c "''" ` -ne 0 ]; then
		echo $FNAME_UAT: not all UAT attrs are filled in...
		S_CHECK_FAILED=yes
		return 1
	fi

	if [ `cat $FNAME_PROD | grep set_endpoint_smev_attributes | grep -c "''"` -ne 0 ] && [ "$GETOPT_SCRIPTFOLDER" = "" ]; then
		echo $FNAME_PROD: not all PROD attrs are filled in...
		S_CHECK_FAILED=yes
		return 1
	fi

	f_specific_smevattr_end $FNAME_UAT
	f_specific_smevattr_end $FNAME_PROD

	echo sqlprepare.sh: SVCNUM=$P_SVCNUM - UDDI content has been created for smev attributes.
}

function f_local_ctlcopy() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local P_CTLFROM=$3
	local P_CTLTO=$4

	mkdir -p $P_CTLTO

	# regional tail
	local F_REGIONALINDEX=
	if [ "$P_ALIGNEDNAME" = "regional" ]; then
		F_REGIONALINDEX="RR"
	fi

	# add registration index
	local x
	for x in $(find $P_CTLFROM -maxdepth 1 -type f -name "*.ctl" | sort ); do
		echo process $x...
		local xbase=`basename $x`
		local F_SCRIPTNUM=${xbase%%-*}
		
		# get filename without extension
		local F_FILEBASE=${xbase%.*}
		local F_FILEBASENOINDEX=${F_FILEBASE#*-}
		
		# rename - all by ctl index
		cp $P_CTLFROM/$F_SCRIPTNUM-* $P_CTLTO/

		# rename
		mv $P_CTLTO/$F_FILEBASE.ctl $P_CTLTO/8$P_ALIGNEDID$F_SCRIPTNUM$F_REGIONALINDEX-$F_FILEBASENOINDEX.ctl

		if [ -f $P_CTLTO/$F_FILEBASE.sql ]; then
			mv $P_CTLTO/$F_FILEBASE.sql $P_CTLTO/9$P_ALIGNEDID$F_SCRIPTNUM$F_REGIONALINDEX-$F_FILEBASENOINDEX.sql
		fi
	done
}

function f_local_execute_core() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local P_TARGETDIR=$3

	echo preparing core scripts dc=$P_ALIGNEDNAME ...
	f_local_cp_dir $P_ALIGNEDNAME $P_ALIGNEDID coreddl $P_TARGETDIR
	f_local_cp_dir $P_ALIGNEDNAME $P_ALIGNEDID coredml $P_TARGETDIR
	f_local_cp_dir $P_ALIGNEDNAME $P_ALIGNEDID coreprodonly $P_TARGETDIR/prodonly
	f_local_cp_dir $P_ALIGNEDNAME $P_ALIGNEDID coreuatonly $P_TARGETDIR/uatonly
	f_local_cp_dir $P_ALIGNEDNAME $P_ALIGNEDID coresvc $P_TARGETDIR/svcrun

	# copy dataload part
	if [ -d dataload ]; then
		f_local_ctlcopy $P_ALIGNEDNAME $P_ALIGNEDID dataload $P_TARGETDIR/dataload
	fi

	# copy manual part
	if [ -d manual ]; then
		cp -rf manual $P_TARGETDIR/manual
	fi
}

function f_local_execute_uddi() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local P_TARGETDIR=$3
	local P_UDDIDIR=$4

	f_sqlidx_getprefix $P_UDDIDIR.juddi $P_ALIGNEDID
	local F_UDDINUM=$S_SQL_DIRID

	# regional tail
	local F_REGIONALINDEX=
	if [ "$P_ALIGNEDNAME" = "regional" ]; then
		F_REGIONALINDEX="RR"
	fi

	# process UDDI
	local SRC_DICFILE_EP=$P_TARGETDIR/svcrun/uddidic.$F_UDDINUM$F_REGIONALINDEX.ep.txt
	local SRC_SVCFILE_EP=$P_TARGETDIR/svcrun/uddisvc.$F_UDDINUM$F_REGIONALINDEX.ep.txt
	local SRC_SMEVATTRFILE=$P_TARGETDIR/svcrun/uddisvc.$F_UDDINUM$F_REGIONALINDEX.smevattr.txt

	if [ -d $P_UDDIDIR/svcdic ]; then
		mkdir -p $P_TARGETDIR/svcrun
		echo $P_UDDIDIR/svcdic...
		if [ -f $P_UDDIDIR/svcdic/extdicuddi.txt ]; then
			f_specific_grepcomments "UDDI" $P_UDDIDIR/svcdic/extdicuddi.txt > $SRC_DICFILE_EP
		fi
	fi

	if [ -d $P_UDDIDIR/svcspec ] && [ "`find $P_UDDIDIR/svcspec -name \"*.sql\"`" != "" ]; then

		mkdir -p $P_TARGETDIR/svcrun
		echo $P_UDDIDIR/svcspec...

		# empty resulting files
		rm $SRC_SVCFILE_EP   2>/dev/null
		rm $SRC_SMEVATTRFILE 2>/dev/null

		for script in $( find $P_UDDIDIR/svcspec -name *.sql | sort ); do

			# extract required smev attributes
			f_specific_grepcomments "SMEVATTR" $script >> $SRC_SMEVATTRFILE

			# extract required uddi endpoints
			F_CHECK_FAILED_KEYS=""
			f_specific_grepcomments "UDDI" $script | (
				while read line; do
					f_local_split_uddi_comment "$line"
					f_local_check_uddi_endpoints
					if [ $? = 1 ]; then
						F_CHECK_FAILED_KEYS="$F_CHECK_FAILED_KEYS, $UDDI_KEY"
					fi
				done
	
				if [ ! -z "$F_CHECK_FAILED_KEYS" ]; then
					F_CHECK_FAILED_KEYS=${F_CHECK_FAILED_KEYS:2} # trim leading ', '
					F_ONEFAILED_MSG="invalid UDDI comment: missing PROD or UAT endpoint for keys: $F_CHECK_FAILED_KEYS"
					f_local_move_errors $P_ALIGNEDNAME $P_ALIGNEDID $script "$F_ONEFAILED_MSG"
				fi
			)

			f_specific_grepcomments "UDDI" $script >> $SRC_SVCFILE_EP # may output "No such file" message if script moved to errors
		done
	fi

	f_local_check_uddi $SRC_DICFILE_EP $SRC_SVCFILE_EP $SRC_SMEVATTRFILE
	if [ $? -ne 0 ]; then
		echo sqlprepare.sh: no UDDI content.
		return 1
	fi

	local DST_FNAME_UAT=$P_TARGETDIR/svcrun/uatonly/${F_UDDINUM}000$F_REGIONALINDEX-juddi-uat.sql
	local DST_FNAME_PROD=$P_TARGETDIR/svcrun/prodonly/${F_UDDINUM}000$F_REGIONALINDEX-juddi-prod.sql

	# process content
	mkdir -p `dirname $DST_FNAME_UAT`
	mkdir -p `dirname $DST_FNAME_PROD`

	f_specific_addcomment "UAT UDDI setup script" > $DST_FNAME_UAT
	f_specific_addcomment "PROD UDDI setup script" > $DST_FNAME_PROD

	# process endpoints
	if [ "$S_DIC_CONTENT" = "yes" ] || [ "$S_SVC_CONTENT" = "yes" ]; then
		f_local_process_uddi_endpoints $F_UDDINUM $DST_FNAME_UAT $DST_FNAME_PROD $SRC_DICFILE_EP $SRC_SVCFILE_EP
	fi

	# process smev attrs
	if [ "$S_SMEVATTR_CONTENT" = "yes" ]; then
		f_local_process_uddi_smevattrs $F_UDDINUM $DST_FNAME_UAT $DST_FNAME_PROD $SRC_SMEVATTRFILE
	fi
}

function f_execute_one_war() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local P_TARGETDIR=$3
	local P_MPNAME=$4

	echo process war regional folder: $P_MPNAME ...
	f_local_cp_dir $P_ALIGNEDNAME $P_ALIGNEDID $P_MPNAME/svcdic $P_TARGETDIR/svcrun
	f_local_cp_dir $P_ALIGNEDNAME $P_ALIGNEDID $P_MPNAME/svcspec $P_TARGETDIR/svcrun
	f_local_execute_uddi $P_ALIGNEDNAME $P_ALIGNEDID $P_TARGETDIR $P_MPNAME
}

function f_execute_one_forms() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local P_TARGETDIR=$3
	local P_ORGNAME=$4

	echo process forms regional folder: $P_ORGNAME ...
	f_local_cp_dir $P_ALIGNEDNAME $P_ALIGNEDID $P_ORGNAME/svcdic $P_TARGETDIR/svcrun
	f_local_cp_dir $P_ALIGNEDNAME $P_ALIGNEDID $P_ORGNAME/svcspec $P_TARGETDIR/svcrun
	f_local_cp_dir $P_ALIGNEDNAME $P_ALIGNEDID $P_ORGNAME/svcform $P_TARGETDIR/svcrun
	f_local_execute_uddi $P_ALIGNEDNAME $P_ALIGNEDID $P_TARGETDIR $P_ORGNAME
}

function f_local_execute_services() {
	local P_ALIGNEDNAME=$1
	local P_ALIGNEDID=$2
	local P_TARGETDIR=$3

	local mpname
	for mpname in $(find . -maxdepth 1 -type d -name "war.*" | sort | sed "s/\.\///g" ); do
		f_execute_one_war $P_ALIGNEDNAME $P_ALIGNEDID $P_TARGETDIR $mpname
	done

	local orgname
	for orgname in $(find . -maxdepth 1 -type d -name "forms.*" | sort | sed "s/\.\///g" ); do
		f_execute_one_forms $P_ALIGNEDNAME $P_ALIGNEDID $P_TARGETDIR $orgname
	done

	if [ "$S_CHECK_FAILED" = "yes" ]; then
		echo sqlprepare.sh: errors in script set. Exiting
		if [ "$GETOPT_SKIPERRORS" != "yes" ]; then 
			exit 1; 
		fi
	fi
}

function f_local_check_all() {
	local P_ALIGNEDDIRLIST="$1"

	# common
	f_aligned_getidbyname common
	echo sqlprepare.sh: =================================== check common ...
	f_local_execute_check common $S_COMMON_ALIGNEDID

	# aligned
	local aligneddir
	local F_SAVEDIR=`pwd`
	for aligneddir in $P_ALIGNEDDIRLIST; do
		f_aligned_getidbyname $aligneddir

		echo sqlprepare.sh: =================================== check aligned dir=$aligneddir ...
		cd aligned/$aligneddir
		f_local_execute_check $aligneddir $S_COMMON_ALIGNEDID
		cd $F_SAVEDIR
	done
}

function f_local_copy_all() {
	local P_ALIGNEDDIRLIST="$1"

	# common
	f_aligned_getidbyname common
	echo sqlprepare.sh: =================================== copy common id=$S_COMMON_ALIGNEDID ...
	local F_TARGETDIR=$SQL_VERSION_PREPARED
	f_local_execute_core common $S_COMMON_ALIGNEDID $F_TARGETDIR
	f_local_execute_services common $S_COMMON_ALIGNEDID $F_TARGETDIR

	# aligned
	local aligneddir
	local F_SAVEDIR=`pwd`
	for aligneddir in $P_ALIGNEDDIRLIST; do
		f_aligned_getidbyname $aligneddir

		echo sqlprepare.sh: =================================== copy aligned dir=$aligneddir id=$S_COMMON_ALIGNEDID ...
		cd aligned/$aligneddir
		F_TARGETDIR=$SQL_VERSION_PREPARED/aligned/$aligneddir
		f_local_execute_core $aligneddir $S_COMMON_ALIGNEDID $F_TARGETDIR
		f_local_execute_services $aligneddir $S_COMMON_ALIGNEDID $F_TARGETDIR
		cd $F_SAVEDIR
	done
}

function f_local_execute_all() {
	# make absolute path
	rm -rf $SQL_VERSION_PREPARED
	mkdir -p $SQL_VERSION_PREPARED

	local F_PREPARE_SAVEDIR=`pwd`
	cd $SQL_VERSION_PREPARED
	SQL_VERSION_PREPARED=`pwd`
	cd $F_PREPARE_SAVEDIR

	if [ ! -d "$SQL_VERSION_ORIGINAL" ]; then
		echo sql folder does not exist - $SQL_VERSION_ORIGINAL. Exiting
		exit 1
	fi

	cd $SQL_VERSION_ORIGINAL

	# get aligned
	local F_ALIGNEDDIRLIST=
	if [ -d aligned ]; then
		local F_SAVEDIR=`pwd`
		cd aligned
		F_ALIGNEDDIRLIST=`find . -maxdepth 1 -type d | grep -v "^.$" | sed "s/.\///" | sort | tr "\n" " "`
		F_ALIGNEDDIRLIST=${F_ALIGNEDDIRLIST% }
		cd $F_SAVEDIR
	fi

	# check scripts from SVN (exit on errors if no -s option)
	f_local_check_all "$F_ALIGNEDDIRLIST"

	# change script numbers and copy to ../patches.log (exit on errors if no -s option)
	f_local_copy_all "$F_ALIGNEDDIRLIST"

	cd $F_PREPARE_SAVEDIR
}

f_local_execute_all

exit 0

echo sqlprepare.sh: finished.
