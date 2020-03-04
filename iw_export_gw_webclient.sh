#!/bin/bash
iwserver="127.0.0.1";				 							# IceWarp server IP/host
email="beranek@icewarp.cz"; 							# email address, standard user must exist, guest user will be created by this script if it does not exist
pass="4R6waeg"; 	        	  						# password
declare -i guest=0;						    				# test account type, 0 - standard user account, 1 - teamchat guest account
ctimeout="50";          			    				# curl connection timeout in seconds

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

# todo: list all grupware folders for the account

start=`date +%s%N | cut -b1-13`
# get auth token
atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>getauthtoken</commandname><commandparams><email>${email}</email><password>${pass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
wcatoken="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o "<authtoken>(.*)</authtoken>" | sed -r s'|<authtoken>(.*)</authtoken>|\1|')"

# get phpsessid
wcphpsessid="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL "https://${iwserver}/webmail/?atoken=$( rawurlencode "${wcatoken}" )" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"

# auth wc session
auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
wcsid="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${auth_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";

# export Contacts folder to vcf format
encemail="$(rawurlencode "${email}")"
curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL "https://${iwserver}/webmail/server/download.php?sid=wm-${wcsid}&class=exportvcard&fullpath=${encemail}%2FContacts" > "${email}.Contacts.vcf"

# export Calendar folder to ics format
calexport_request="<iq sid=\"wm-${wcsid}\" type=\"set\"><query xmlns=\"webmail:iq:folders\"><account uid=\"${email}\"><folder uid=\"Calendar\" action=\"save_items\"/></account></query></iq>"
calexport="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL --data-binary "${calexport_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o "<fullpath>(.*)</fullpath>" | perl -pe 's|<fullpath>(.*)</fullpath>|\1|')"
curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL "https://${iwserver}/webmail/server/download.php?class=file&fullpath=${calexport}&sid=wm-${wcsid}" > "${email}.Calendar.vcf"

# todo: export Tasks, Notes, Documents

# session logout
logout_request="<iq sid=\"wm-"${wcsid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${logout_request}" "https://${iwserver}/webmail/server/webmail.php"

end=`date +%s%N | cut -b1-13`
runtime=$((end-start))
exit 0
