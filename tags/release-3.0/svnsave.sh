#!/bin/bash

cd `dirname $0`

P_MASTERAUTH="$*"

if [ "$P_MASTERAUTH" = "" ]; then
	if [ -f ~/.auth/svnold.auth.txt ]; then
		P_MASTERAUTH="`cat ~/.auth/svnold.auth.txt`"
	fi
fi

if [ "$P_MASTERAUTH" = "" ]; then
	echo "P_MASTERAUTH is empty. Exiting"
	exit 1
fi

function f_execute_addnew() {
	local P_LISTING_FILE=$1

	local F_FNAME
	local F_SVNSTATUS
	cat $P_LISTING_FILE | cut -d ":" -f2 | while read line; do
		F_FNAME=$line
		if [ ! -f "$F_FNAME" ]; then
			echo "svnsave.sh: unexpected - missing file $F_FNAME. Exiting"
			exit 1
		fi

		F_SVNSTATUS="?"
		if [ -d "`dirname $F_FNAME`/.svn" ]; then
			F_SVNSTATUS="`svn status $F_FNAME`"
			F_SVNSTATUS=${F_SVNSTATUS:0:1}
		fi

		if [ "$F_SVNSTATUS" = "?" ]; then
			svn --parents add $F_FNAME
		fi
	done
}

function f_execute_deleteunknown() {
	local P_LISTING_FILE=$1

	local F_NAME
	local F_STATUS
	local F_DIR
	find . | egrep -v "(^\.$|^\.svn/|/\.svn$|/\.svn/)" | sed "s/^\.\///" | sort | while read line; do
		F_NAME=$line
		F_DIR=`dirname $F_NAME`

		if [ -d "$F_NAME" ]; then
			# check unknown directory
			F_STATUS=`grep ":$F_NAME/" $P_LISTING_FILE | head -1`
			if [ "$F_STATUS" = "" ]; then
				if [ -d "$F_NAME/.svn" ]; then
					svn delete $F_NAME
				else
					rm -rf $F_NAME
				fi
			fi
		elif [ -f "$F_NAME" ]; then
			# check unknown file
			F_STATUS=`grep ":$F_NAME$" $P_LISTING_FILE | head -1`

			if [ "$F_STATUS" = "" ]; then
				if [ -d "$F_DIR/.svn" ]; then
					F_STATUS=`svn status $F_NAME`
					if [[ "$F_STATUS" =~ "^\?" ]]; then
						rm -rf $F_NAME
					else
						svn delete $F_NAME
					fi
				else
					rm -rf $F_NAME
				fi
			fi
		fi
	done
}

function f_execute_all() {
	# check listing file
	local F_LISTING_FILE=master.files.info
	if [ ! -f "$F_LISTING_FILE" ]; then
		echo "svnsave.sh: unable to find listing file $F_LISTING_FILE. Exiting"
		exit 1
	fi

	# issue svn commands
	echo "svnsave.sh: check added..."
	f_execute_addnew $F_LISTING_FILE
	local F_STAT=$?
	if [ "$F_STAT" != "0" ]; then
		echo "svnsave.sh: f_execute_addnew failed. Exiting"
		exit 1
	fi

	echo "svnsave.sh: check deleted..."
	f_execute_deleteunknown $F_LISTING_FILE
	F_STAT=$?
	if [ "$F_STAT" != "0" ]; then
		echo "svnsave.sh: f_execute_deleteunknown failed. Exiting"
		exit 1
	fi

	# commit
	local F_CHANGES=`svn status 2>/dev/null | head -1`
	if [ "$F_CHANGES" != "" ]; then
		echo "svnsave.sh: commit..."
		svn commit $P_MASTERAUTH -m "upgrade URM product codebase"
		local F_CHECK=$?
		if [ "$F_CHECK" != "0" ]; then
			echo "svnsave.sh: unable to commit changes. Exiting"
			exit 1
		fi
	else
		echo "svnsave.sh: no changes."
	fi
}

f_execute_all

echo "svnsave.sh: successfully finished."
