#!/bin/sh

P_ENV=$1
P_DB=$2
P_DC=$3
P_REFRESHDIR=$4
P_DBCONN="$5"
P_LOGDIR=$6

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

	# generate configuration files using environment parameters
	./configure.sh -raw -dc $P_DC $F_PWD/$P_SQLDIR $F_PWD/$P_LIVEDIR $P_DB
	if [ "$?" != "0" ]; then
		echo error executing configure.sh. Exiting
		exit 1
	fi

	S_RUNDIR=$F_PWD/$P_LIVEDIR/$P_DC/$P_DB

	cd $F_PWD
}

function f_execute_getpostrefresh() {
	local P_SQLDIR=$1
	local P_LIVEDIR=$2

	# cleanup
	rm -rf ./$S_LOGDIR
	mkdir -p ./$S_LOGDIR

	# copy scripts and helper
	local F_SVNPATH=$C_CONFIG_SVNPATH/releases/$C_CONFIG_PRODUCT/database/refresh/$P_REFRESHDIR
	echo download postrefresh files from $F_SVNPATH ...
	svn export $C_CONFIG_SVNAUTH --no-auth-cache $F_SVNPATH $P_SQLDIR

	mkdir -p $P_LIVEDIR
	f_execute_preparepostrefresh $P_SQLDIR $P_LIVEDIR
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

function f_execute_all() {
	S_REMOTE_HOSTLOGIN=$C_ENV_CONFIG_REMOTE_HOSTLOGIN
	S_REMOTE_ROOT=$C_ENV_CONFIG_REMOTE_ROOT
	S_LOGDIR=$P_LOGDIR

	F_SQLDIR=postrefresh-sql-$P_DB
	rm -rf $F_SQLDIR
	mkdir -p $F_SQLDIR

	# copy, setup params, upload and apply
	f_execute_getpostrefresh $F_SQLDIR/templates $F_SQLDIR/live
	f_execute_runpostrefresh $S_RUNDIR
}

f_execute_all

echo run-postrefresh.sh: successfully finished.
exit 0
