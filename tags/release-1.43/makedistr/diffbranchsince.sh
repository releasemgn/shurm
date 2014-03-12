#!/bin/bash 
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`
. ./getopts.sh

SINCE_SUB=$1
TILL_SUB=$2
OUTDIR=$3
PROJECT=$4

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

FINFO=$OUTDIR/diff-info-$PROJECT
FDIFF=$OUTDIR/diff-since-$PROJECT

BRANCHVER=$C_CONFIG_VERSIONBRANCH

echo VERSION CONTROL - `date`: > $FINFO
echo COMMITS DONE: > $FINFO.commits
echo differerence list: > $FDIFF

# core and wars
if [ "$PROJECT" = "" ]; then
	PROJECT=all
fi

export C_DIFF_SINCE=$SINCE_SUB
export C_DIFF_TILL=$TILL_SUB
export C_FINFO=$FINFO
export C_FDIFF=$FDIFF
f_execute_all $PROJECT DIFFBRANCHTAG

echo JIRA LIST: > $FINFO.jira

for jira in $C_CONFIG_COMMIT_TRACKERLIST; do
	grep "$jira-" $FINFO.commits | cut -d":" -f1,2 | sort --unique >> $FINFO.jira
done

echo JIRA COMMENTS: >> $FINFO.jira

for jira in $C_CONFIG_COMMIT_TRACKERLIST; do
	grep "$jira-" $FINFO.commits | sort --unique >> $FINFO.jira
done

