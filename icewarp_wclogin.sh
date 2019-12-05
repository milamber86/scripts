#!/bin/bash
# IceWarp server IP/host
iwserver="127.0.0.1"
# email address
email="user@example.loc"
# password
pass="password"

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


atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>getauthtoken</commandname><commandparams><email>${email}</email><password>${pass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"

# get auth token
wcatoken="$(curl -ik --data-binary "${atoken_request}" "http://${iwserver}/icewarpapi/" |egrep -o "<authtoken>(.*)</authtoken>" | sed -r s'|<authtoken>(.*)</authtoken>|\1|')"

# get phpsessid
wcphpsessid="$(curl -ik "http://${iwserver}/webmail/?atoken=$( rawurlencode "${wcatoken}" )" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"

# auth wc session
wcsid="$(curl -ik --data-binary "<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>" "http://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";

# refresh folders
curl -ik --data-binary "<iq sid=\"wm-"${wcsid}"\" uid=\"${email}\" type=\"set\" format=\"xml\"><query xmlns=\"webmail:iq:accounts\"><account action=\"refresh\" uid=\"${email}\"/></query></iq>" "http://${iwserver}/webmail/server/webmail.php"

# session logout
curl -ik --data-binary "<iq sid=\"wm-"${wcsid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>" "http://${iwserver}/webmail/server/webmail.php"
