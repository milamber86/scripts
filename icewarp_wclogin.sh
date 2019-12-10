#!/bin/bash
iwserver="10.1.1.10";				# IceWarp server IP/host
email="wczabbixmon@icewarp.loc";    		# email address, standard user must exist, guest user will be created by this script if it does not exist
pass="r4g53eR-4g54se6";	        		# password
declare -i guest=1;				# test account type, 0 - standard user account, 1 - teamchat guest account
ctimeout="10";          			# curl connection timeout in seconds

# urlencode string function
rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"
}

if [[ ${guest} != 0 ]] # generate guestaccount email, test if guest account exists, if not, create one
	then
	 guestaccemail="$(echo ${email} | sed -r s'|(.*)\@(.*)|\1_\2\@##internalservicedomain.icewarp.com##|')"  # generate teamchat guest account email
	 guestacclogin="$(echo ${email} | sed -r s'|(.*)\@(.*)|\1|')"
	 /opt/icewarp/tool.sh export account "${guestaccemail}" u_name | grep -o ",${guestacclogin},"
	 result=$?
	 if [[ ${result} != 0 ]]
	 	then
		 /opt/icewarp/tool.sh create account "${guestaccemail}" u_name "${guestacclogin}" u_mailbox "${email}" u_password "${pass}"
	 fi
fi

# get auth token
atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>getauthtoken</commandname><commandparams><email>${email}</email><password>${pass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
wcatoken="$(curl --connect-timeout ${ctimeout} -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | tee wcatoken.res | egrep -o "<authtoken>(.*)</authtoken>" | sed -r s'|<authtoken>(.*)</authtoken>|\1|')"

# get phpsessid
wcphpsessid="$(curl --connect-timeout ${ctimeout} -ikL "https://${iwserver}/webmail/?atoken=$( rawurlencode "${wcatoken}" )" | tee wcphpsessid.res | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"

# auth wc session
auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
wcsid="$(curl --connect-timeout ${ctimeout} -ikL --data-binary "${auth_request}" "https://${iwserver}/webmail/server/webmail.php" | tee wcsid.res | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";

if [[ ${guest} == 0 ]] # test response for standard or teamchat guest account
	then
	 # refresh folders standard account start
	 refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${email}\" type=\"set\" format=\"xml\"><query xmlns=\"webmail:iq:accounts\"><account action=\"refresh\" uid=\"${email}\"/></query></iq>"
	 response="$(curl --connect-timeout ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | tee refreshfolder.res | egrep -o "folder uid=\"INBOX\"")"
	 if [[ "${response}" =~ "INBOX" ]];
         	then
         	 echo "INBOX folder found, OK"
        	else
         	 echo "Alert! INBOX not found in folder refresh response."
	 fi
	 # refresh folders standard account end
	else
	 # refresh folders teamchat guest account start
	 refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${guestaccemail}\" type=\"get\" format=\"json\"><query xmlns=\"webmail:iq:folders\"><account uid=\"${guestaccemail}\"/></query></iq>"
	 response="$(curl --connect-timeout ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | tee refreshfolder.res | egrep -o "INHERITED_ACL")"
	 if [[ "${response}" =~ "INHERITED_ACL" ]];
         	then
         	 echo "Test pattern found in response, OK"
        	else
         	 echo "Alert! Test pattern not found in response."
	 fi
	 # refresh folders teamchat guest account end
fi

# session logout
logout_request="<iq sid=\"wm-"${wcsid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
curl --connect-timeout ${ctimeout} -ikL --data-binary "${logout_request}" "https://${iwserver}/webmail/server/webmail.php"
