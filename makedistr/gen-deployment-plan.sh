#!/bin/bash

# Get release page from Confluence and process it to clarify release status
# Usage example: ./gen-deployment-plan.sh PGU-release-2012-03-30
# Copy to Excel and split by ':'

REL_PAGE=$1

. ../../common/makedistr/common-confluence.sh
. ../../common/makedistr/common-hashes.sh

f_confluence_get_page $REL_PAGE
f_confluence_count_chgroups

CHGROUPS=$C_CONFLUENCE_CHGROUP_COUNT
echo Found change groups: $CHGROUPS

CHGROUP_START=1
# CHGROUP_START=8 # DEBUG (keep this line)

# DEBUG (keep this line commented) - 
rm gen-deployment-plan.txt 2>/dev/null

# DEBUG - for CHGROUP in $(); do # DEBUG
for CHGROUP in $(seq $CHGROUP_START $CHGROUPS); do 

	f_confluence_parse_chgroup $CHGROUP
	f_confluence_count_changes $CHGROUP
	CHANGES=$C_CONFLUENCE_CHANGES_COUNT

	init_hash_subsystem
	hash_lock

	for CHANGE in $(seq 1 $CHANGES); do 
		f_confluence_parse_change $CHGROUP $CHANGE
		# echo "  change: $C_CONFLUENCE_CHANGE_NUM test result: [$C_CONFLUENCE_CHANGE_TEST]" # DEBUG

		# Use assoc array to keep distinct TestRes
		if [ -z "$C_CONFLUENCE_CHANGE_TEST" ]; then
			C_CONFLUENCE_CHANGE_TEST=N/A
		fi

		set_hash_elem $C_CONFLUENCE_CHANGE_TEST specified
	done

	TEST_RESULTS=`get_hash_keys`
	TEST_RESULTS=`echo $TEST_RESULTS` # newlines to spaces

	hash_unlock
	destroy_hash_subsystem

	CH_MODULES=`echo $C_CONFLUENCE_CHGROUP_COMPONENT | cut -d: -f2`
	CH_REGIONS=`echo $C_CONFLUENCE_CHGROUP_COMPONENT | cut -d: -f3-`

	REG_NN=`echo $CH_REGIONS | sed -e 's/.*(\([0-9]*\)).*/\1/'`
 	REGION=`echo $CH_REGIONS | sed -e 's/\(.*\)(\([0-9]*\))\(.*\)/\2 (\1) \3/'`

 	CH_MODULES=`echo $CH_MODULES       \
 		| sed -e 's/ Регионы//'    \
 		| sed -e 's/ Регион//'     \
 		| sed -e 's/Изменяется//'  \
 	`

 	GRP=`xmlstarlet sel -t -m //component -i "@name='pguweb.reg.$REG_NN'" -v @unit -n ../etc/distr.xml 2>/dev/null`

	echo "$CHGROUP ($CHANGES): $GRP: $REGION: $CH_MODULES: TestRes: $TEST_RESULTS" | tee -a gen-deployment-plan.txt
	# exit -1005 # DEBUG (keep this line)
done

echo
echo "Changes and detailed test results ==================================="
echo

cat gen-deployment-plan.txt | while read line
do
	words=`echo "$line" | cut -d: -f3-4 | sed -e 's/[+():,]/ /g'`

	echo -n "$line"
	for word in $words; do

		# echo # DEBUG (keep this line commented)

    		if [[ "$word" =~ ^[0-9] ]]  || 
    		   [ ! -z `echo "SQL для сервера форм - Ведомство Республика область край автономный округ Red Green team Инфраструктура АСИ" | grep -i -o $word` ]
    		then
    			continue
    		fi

    		testres=`grep $word gen-deployment-plan.txt | cut -d: -f6-`

		init_hash_subsystem
		hash_lock

    		for testresult in $testres; do
			set_hash_elem $testresult specified
    		done

		TEST_RESULTS=`get_hash_keys`
		TEST_RESULTS=`echo $TEST_RESULTS` # newlines to spaces

		hash_unlock
		destroy_hash_subsystem

		echo -n ": $word: $TEST_RESULTS"
	done
	echo # newline
done
