#!/bin/bash

. ./common.sh

S_WORK=work

function f_addend() {
	FNAME=$1

	cat $FNAME | sed "s/$/@/" > $FNAME.new
	rm -rf $FNAME
	mv $FNAME.new $FNAME
}

function f_delete() {
	FNAME=$1

	rm -rf $FNAME.delete
	for x in $(cat $FNAME); do
		if [ "`grep $x $S_WORK/prod.txt`" = "" ]; then
			echo $x >> $FNAME.delete
		else
			echo $x >> $FNAME.new
		fi
	done
}

function f_new() {
	rm -rf $S_WORK/prod.txt.new
	for x in $(cat $S_WORK/prod.txt); do
		if [ "`cat $S_WORK/uat.copy.txt $S_WORK/uat.skip.txt | grep $x`" = "" ]; then
			echo $x >> $S_WORK/prod.txt.new
		fi
	done
}

function f_execute_all() {
	rm -rf $S_WORK
	mkdir -p $S_WORK
	local F_CURDIR=`pwd`
	
	svn export $C_CONFIG_SVNAUTH $C_CONFIG_SVNPATH/releases/$C_CONFIG_PRODUCT/database/prod/schema $S_WORK/schema
	cd $S_WORK/schema
	find . -iwholename "*/TABLE/*" | cut -d "/" -f2,4 | sed "s/.sql/@/" | sort > $F_CURDIR/$S_WORK/prod.txt
	cd $F_CURDIR

	grep "#" $C_CONFIG_TABLE_FILE | sed "s/#//;s/\/TABLE\//\//" > $S_WORK/uat.skip.txt
	grep -v "#" $C_CONFIG_TABLE_FILE | sed "s/\/TABLE\//\//" > $S_WORK/uat.copy.txt

	f_addend $S_WORK/uat.copy.txt
	f_addend $S_WORK/uat.skip.txt

	f_delete $S_WORK/uat.copy.txt
	f_delete $S_WORK/uat.skip.txt
	f_new

	# process prod.new
	sed -i "s/^/#/;s/\//\/TABLE\//;s/@//" $S_WORK/prod.txt.new
}

f_execute_all

echo checkfiles.sh: successfully finished
