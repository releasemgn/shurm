#!/bin/sh

P_ENV=$1
P_DB=$2
P_REFRESHDIR=$3
P_DBCONN="$4"
P_LOGDIR=$5

# load common and env params
. ./common.sh

S_REMOTE_HOSTLOGIN=
S_REMOTE_ROOT=
S_LOGDIR=

function f_execute_all() {
	S_REMOTE_HOSTLOGIN=$C_ENV_CONFIG_REMOTE_HOSTLOGIN
	S_REMOTE_ROOT=$C_ENV_CONFIG_REMOTE_ROOT
	S_LOGDIR=$P_LOGDIR

	f_execute_cmdres $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "if [ -d $S_REMOTE_ROOT ]; then date > laststartdate.txt; echo ok; fi"
	if [ "$S_RUNCMDRES" != "ok" ]; then
		echo unable to access remote root - $S_REMOTE_ROOT. Exiting
		exit 1
	fi

	# cleanup
	rm -rf ./$S_LOGDIR
	mkdir -p ./$S_LOGDIR

	F_SQLDIR=postrefresh-sql-$P_DB
	rm -rf ./$F_SQLDIR

	F_SQLDIR_REMOTE=postrefresh
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "rm -rf $F_SQLDIR_REMOTE"

	# copy scripts and helper
	F_SVNPATH=$C_CONFIG_SVNPATH/releases/$C_CONFIG_PRODUCT/database/refresh/$P_REFRESHDIR
	echo download postrefresh files from $F_SVNPATH ...
	svn export $C_CONFIG_SVNAUTH --no-auth-cache $F_SVNPATH $F_SQLDIR
	scp -r $F_SQLDIR $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$F_SQLDIR_REMOTE
	scp datapump-config.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp common.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp import_helper.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "chmod 744 *.sh"

	# execute remotedly
	echo execute post-refresh scripts ...
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "./import_helper.sh $P_ENV $P_DB $P_DBCONN postrefresh"

	# copy log files
	echo download log files to $F_SQLDIR_REMOTE ...
	mkdir -p ./$S_LOGDIR
	scp -r $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$F_SQLDIR_REMOTE ./$S_LOGDIR
}

f_execute_all

echo run-postrefresh.sh: successfully finished.
exit 0
