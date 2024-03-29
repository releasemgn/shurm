#!/bin/sh

P_ENV=$1
P_DC=$2
P_DB=$3
P_REFRESHDIR=$4
P_DBCONN="$5"
P_LOGDIR=$6

. ../../../etc/config.sh

# load common and env params
. ./common.sh

S_REMOTE_HOSTLOGIN=
S_REMOTE_ROOT=
S_LOGDIR=
S_RUNDIR=

function f_execute_preparepostrefresh() {
	local P_SQLDIR=$1
	local P_LIVEDIR=$2

	local F_PWD=`pwd`
	local F_ENVDIR=$C_CONFIG_PRODUCT_DEPLOYMENT_HOME/master/deployment
	cd $F_ENVDIR
	. ./setenv.sh $P_ENV.xml

	rm -rf $P_LIVEDIR
	mkdir -p $P_LIVEDIR

	# generate configuration files using environment parameters
	./configure.sh -raw -dc $P_DC templates $P_SQLDIR $P_LIVEDIR $P_DB
	if [ "$?" != "0" ]; then
		echo error executing configure.sh. Exiting
		exit 1
	fi

	S_RUNDIR=$P_LIVEDIR/$P_DC/$P_DB
	echo S_RUNDIR=$S_RUNDIR

	cd $F_PWD
}

function f_execute_preparefile() {
	local P_FILE=$1

	(
		echo -- standard script header
		echo set define off
		echo set echo on
		echo spool `basename $P_FILE`.spool append
		echo select sysdate from dual\;
		echo ""
		cat $P_FILE
	) > $P_FILE.copy

	rm -rf $P_FILE
	mv $P_FILE.copy $P_FILE
}

function f_execute_getpostrefresh() {
	local P_SQLDIR=$1
	local P_LIVEDIR=$2

	# cleanup
	rm -rf ./$P_SQLDIR

	# copy scripts and helper
	local F_SVNPATH=$C_CONFIG_SVNPATH/releases/$C_CONFIG_PRODUCT/database/refresh/$P_REFRESHDIR
	echo download postrefresh files from $F_SVNPATH ...
	svn export $C_CONFIG_SVNAUTH --no-auth-cache $F_SVNPATH $P_SQLDIR
	if [ "$?" != "0" ]; then
		echo "svn export $F_SVNPATH - unable to export. Exiting"
		exit 1
	fi

	local fname
	for fname in `find $P_SQLDIR -name "*.sql"`; do
		f_execute_preparefile $fname
	done

	mkdir -p $P_LIVEDIR
	f_execute_preparepostrefresh $P_SQLDIR $P_LIVEDIR
}

function f_wait_finishpostrefresh() {
	echo waiting for finish post-refresh process ...
	sleep 5
	while [ "1" = "1" ]; do
		F_STATUS=`ssh $S_REMOTE_HOSTLOGIN "cat $S_REMOTE_ROOT/postrefresh.status.log | grep FINISHED"`
		if [[ "$F_STATUS" =~ "FINISHED" ]]; then
			echo post-refresh process successfully finished
			return 0
		fi

		sleep 10
	done
}

function f_execute_runpostrefresh() {
	local P_SQLDIR=$1

	f_execute_cmdres $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "if [ -d $S_REMOTE_ROOT ]; then date > laststartdate.txt; echo ok; fi"
	if [ "$S_RUNCMDRES" != "ok" ]; then
		echo unable to access remote root - $S_REMOTE_ROOT. Exiting
		exit 1
	fi

	local F_SQLDIR_REMOTE=postrefresh
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "rm -rf $F_SQLDIR_REMOTE"

	scp -r $P_SQLDIR $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$F_SQLDIR_REMOTE
	scp datapump-config.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp common.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp specific.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	scp import_helper.sh $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "chmod 744 *.sh"

	# execute remotedly
	echo execute post-refresh scripts ...
	f_execute_cmd $S_REMOTE_HOSTLOGIN $S_REMOTE_ROOT "/usr/bin/nohup ./import_helper.sh $P_ENV $P_DB $P_DBCONN postrefresh > import.postrefresh.log 2>&1&"

	# wait postrefresh to finish
	f_wait_finishpostrefresh

	# copy log files
	echo download log files to $S_LOGDIR/$P_REFRESHDIR ...
	mkdir -p ./$S_LOGDIR
	rm -rf ./$S_LOGDIR/$P_REFRESHDIR
	scp -r $S_REMOTE_HOSTLOGIN:$S_REMOTE_ROOT/$F_SQLDIR_REMOTE ./$S_LOGDIR/$P_REFRESHDIR
}

function f_execute_all() {
	S_REMOTE_HOSTLOGIN=$C_ENV_CONFIG_REMOTE_HOSTLOGIN
	S_REMOTE_ROOT=$C_ENV_CONFIG_REMOTE_ROOT
	S_LOGDIR=$P_LOGDIR

	local F_PWD=`pwd`
	local F_SQLDIR=$F_PWD/postrefresh-sql-$P_DB
	mkdir -p $F_SQLDIR

	# copy, setup params, upload and apply
	f_execute_getpostrefresh $F_SQLDIR/templates $F_SQLDIR/live
	f_execute_runpostrefresh $S_RUNDIR

	rm -rf $F_SQLDIR
}

f_execute_all

echo run-postrefresh.sh: successfully finished.
exit 0
