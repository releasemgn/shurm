#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SINCE_SUB=$1
TILL_SUB=$2
OUTDIR=$3
MODULE=$4
MODULE_PATH=$5
JIRA_PROJECT=$6

. ./common.sh

# check params
if [ "$SINCE_SUB" = "" ]; then
	echo SINCE_SUB not set
	exit 1
fi
if [ "$TILL_SUB" = "" ]; then
	echo TILL_SUB not set
	exit 1
fi
if [ "$OUTDIR" = "" ]; then
	echo OUTDIR not set
	exit 1
fi

# execute

FINFO=$OUTDIR/$MODULE-diff-info
FDIFF=$OUTDIR/$MODULE-diff-since

BRANCHVER=$C_CONFIG_VERSIONBRANCH

echo VERSION CONTROL - `date`: > $FINFO
echo COMMITS DONE: > $FINFO.commits
echo differerence list: > $FDIFF

./vcsdiff.sh MARKER $FINFO $FDIFF $MODULE $MODULE_PATH $TILL_SUB $SINCE_SUB

echo JIRA LIST: > $FINFO.jira
grep "$JIRA_PROJECT-" $FINFO.commits | cut -d":" -f1,2 | sort --unique >> $FINFO.jira
echo JIRA COMMENTS: >> $FINFO.jira
grep "$JIRA_PROJECT-" $FINFO.commits | sort --unique >> $FINFO.jira
