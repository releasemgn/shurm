#!/bin/sh
# Copyright 2011-2013 vsavchik@gmail.com

cd `dirname $0`

P_LIMITTIME=$1
P_REPORT_SCRIPT=$2

if [ "$P_LIMITTIME" = "" ]; then
	echo P_LIMITTIME not set. Exiting
	exit 1
fi
if [ "$P_REPORT_SCRIPT" = "" ]; then
	echo P_REPORT_SCRIPT not set. Exiting
	exit 1
fi

shift 2

# execute specific report script
if [ ! -f "./report-scripts/$P_REPORT_SCRIPT" ]; then
	echo "`date`: unable to execute missing `pwd`/report-scripts/$P_REPORT_SCRIPT. Exiting" >> report.log
	exit 1
fi

# load profiles settings
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

if [ -f ~/.bash_profile ]; then
	. ~/.bash_profile
fi

. $C_CONFIG_PRODUCT_DEPLOYMENT_HOME/etc/monitoring.sh

F_DIR_DATA=$C_MONITORING_DIR_DATA
F_DIR_REPORTS=$C_MONITORING_DIR_REPORTS
F_DIR_RES=$C_MONITORING_DIR_RES
F_RESOURCE_CONTEXT=$C_MONITORING_REPORT_URL

echo "`date`: execute `pwd`/report-scripts/$P_REPORT_SCRIPT $F_DIR_DATA $F_DIR_REPORTS $F_DIR_RES $F_RESOURCE_CONTEXT $@ ..." >> report.log
if [ "$P_LIMITTIME" = "0" ]; then
	./report-scripts/$P_REPORT_SCRIPT $F_DIR_DATA $F_DIR_REPORTS $F_DIR_RES $F_RESOURCE_CONTEXT "$@" >> report.log 2>&1
else
	./limittime.sh $P_LIMITTIME ./report-scripts/$P_REPORT_SCRIPT $F_DIR_DATA $F_DIR_REPORTS $F_DIR_RES $F_RESOURCE_CONTEXT "$@" >> report.log 2>&1
fi
