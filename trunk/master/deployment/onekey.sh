#!/bin/bash
# Copyright 2011-2014 vsavchik@gmail.com

P_CMD=$1
P_HOSTLOGIN=$2
P_KEYFILENEXT=$3
P_KEYACCESS=$4

if [ "$P_CMD" != "set" ] && [ "$P_CMD" != "add" ] && [ "$P_CMD" != "change" ] && [ "$P_CMD" != "delete" ]; then
	echo "onekey.sh: invalid command $P_CMD. Exiting"
	exit 1
fi

if [ "$P_KEYFILENEXT" = "" ]; then
	P_KEYFILENEXT=~/.ssh/id_dsa
fi

# replace with public key data
if [[ ! "$P_KEYFILENEXT" =~ \.pub$ ]]; then
	P_KEYFILENEXTPUB=$P_KEYFILENEXT.pub
	P_KEYFILENEXTPRV=$P_KEYFILENEXT
else
	P_KEYFILENEXTPUB=$P_KEYFILENEXT
	P_KEYFILENEXTPRV=${P_KEYACCESS%.pub}
fi

if [ ! -f "$P_KEYFILENEXTPUB" ]; then
	echo "onekey.sh: cannot find public key file $P_KEYFILENEXTPUB. Exiting"
	exit 1
fi

S_HASNEXTPRIVATEKEY=no
if [ -f "$P_KEYFILENEXTPRV" ]; then
	S_HASNEXTPRIVATEKEY=yes
fi

function f_execute_all() {
	# access using private key
	F_ACCESSOPTION=
	F_ACCESSMSG=
	if [ "$P_KEYACCESS" != "" ]; then
		if [[ "$P_KEYACCESS" =~ \.pub$ ]]; then
			P_KEYACCESS=${P_KEYACCESS%.pub}
		fi
	
		if [ ! -f "$P_KEYACCESS" ]; then
			echo "onekey.sh: invalid private key file $P_KEYACCESS. Exiting"
			exit 1
		fi

		F_ACCESSOPTION="-i $P_KEYACCESS"
		F_ACCESSMSG=" using access key $P_KEYACCESS"
	fi

	F_KEYOWNER=`cat $P_KEYFILENEXTPUB | cut -d " " -f3`
	F_KEYDATA=`cat $P_KEYFILENEXTPUB`

	# change
	F_AUTHFILE=.ssh/authorized_keys

	# check new key is already placed and access using old key is not avalable
	if [ "$P_CMD" != "delete" ]; then
		local F_CHECK=`ssh -n $F_ACCESSOPTION -o PasswordAuthentication=no $P_HOSTLOGIN "echo ok"`
		if [ "$?" != "0" ]; then
			if [ "$S_HASNEXTPRIVATEKEY" = "yes" ]; then
				F_CHECK=`ssh -n -i $P_KEYFILENEXTPRV -o PasswordAuthentication=no $P_HOSTLOGIN "echo ok"`
				if [ "$?" = "0" ]; then
					F_ACCESSOPTION="-i $P_KEYFILENEXTPRV"
				fi
			fi
		fi
	fi

	if [ "$P_CMD" = "change" ] || [ "$P_CMD" = "add" ]; then
		echo "$P_HOSTLOGIN: change key to $P_KEYFILENEXTPUB ($F_KEYOWNER) on $P_HOSTLOGIN$F_ACCESSMSG ..."
		ssh -n $F_ACCESSOPTION $P_HOSTLOGIN "if [ ! -f $F_AUTHFILE ]; then mkdir -p .ssh; chmod 700 .ssh; echo \"\" > $F_AUTHFILE; chmod 600 $F_AUTHFILE; fi; cat $F_AUTHFILE | grep -v $F_KEYOWNER\$ > $F_AUTHFILE.2; echo \"$F_KEYDATA\" >> $F_AUTHFILE.2; cp $F_AUTHFILE.2 $F_AUTHFILE; rm -rf $F_AUTHFILE.2;"
		if [ "$?" != "0" ]; then
			echo "onekey.sh: error executing key replacement. Exiting"
			exit 1
		fi

	elif [ "$P_CMD" = "set" ]; then
		echo "$P_HOSTLOGIN: set the only key to $P_KEYFILENEXTPUB ($F_KEYOWNER) on $P_HOSTLOGIN$F_ACCESSMSG ..."
		ssh -n $F_ACCESSOPTION $P_HOSTLOGIN "if [ ! -f $F_AUTHFILE ]; then mkdir -p .ssh; chmod 700 .ssh; echo \"\" > $F_AUTHFILE; chmod 600 $F_AUTHFILE; fi; echo \"$F_KEYDATA\" > $F_AUTHFILE"
		if [ "$?" != "0" ]; then
			echo "onekey.sh: error executing key set. Exiting"
			exit 1
		fi

	elif [ "$P_CMD" = "delete" ]; then
		echo "$P_HOSTLOGIN: delete key $P_KEYFILENEXTPUB ($F_KEYOWNER) on $P_HOSTLOGIN$F_ACCESSMSG ..."
		ssh -n $F_ACCESSOPTION $P_HOSTLOGIN "if [ ! -f $F_AUTHFILE ]; then mkdir -p .ssh; chmod 700 .ssh; echo \"\" > $F_AUTHFILE; chmod 600 $F_AUTHFILE; fi; cat $F_AUTHFILE | grep -v $F_KEYOWNER\$ > $F_AUTHFILE.2; cp $F_AUTHFILE.2 $F_AUTHFILE; rm -rf $F_AUTHFILE.2;"
		if [ "$?" != "0" ]; then
			echo "onekey.sh: error executing key delete. Exiting"
			exit 1
		fi
	fi

	if [ "$P_CMD" = "change" ] || [ "$P_CMD" = "set" ]; then
		# check - if there is next key
		if [ "$S_HASNEXTPRIVATEKEY" = "yes" ]; then
			ssh -n -i $P_KEYFILENEXTPRV -o PasswordAuthentication=no $P_HOSTLOGIN "echo change successfully completed"
			if [ "$?" != "0" ]; then
				echo "onekey.sh: error executing new key check. Exiting"
				exit 1
			fi
			echo "$P_HOSTLOGIN: new key successfully verified."
		fi
	fi
}

f_execute_all
