#!/bin/bash
iwserver="127.0.0.1";                               # IceWarp server IP/host
ctimeout="500";                                     # curl connection timeout in seconds
resetFolder=1;                                      # TODO: 0: if folder already exists, import data without deleting existing data, 1: delete data in folder before import

function rawurlencode # urlencode string function
{
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

function sessionLogin # ( 1: user@email, 2: password -> wcSid - webclient session ID )
{
email="${1}";
pass="${2}";
atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>getauthtoken</commandname><commandparams><email>${email}</email><password>${pass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
wcatoken="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL --data-binary "${atoken_request}" "http://${iwserver}/icewarpapi/" | egrep -o "<authtoken>(.*)</authtoken>" | sed -r s'|<authtoken>(.*)</authtoken>|\1|')"
# get phpsessid
wcphpsessid="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL "http://${iwserver}/webmail/?atoken=$( rawurlencode "${wcatoken}" )" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"
# auth wc session
auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
wcSid="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL --data-binary "${auth_request}" "http://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";
echo "${wcSid}";
}

function sessionLogout # ( 1: wcSid )
{
wcSid="${1}";
logout_request="<iq sid=\"wm-"${wcSid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
logout="$(curl --connect-timeout 30 -m 30 -kL --data-binary "${logout_request}" "http://${iwserver}/webmail/server/webmail.php")";
}

function createGWFolder # ( 1: wcSid, 2: email, 3: folderTypeCode, 4: folderName -> 0: created OK, 1: already exists, 2: error )
{
wcSid="${1}";
email="${2}";
folderTypeCode="${3}";
folderName="${4}";
folder_create_request="<iq sid=\"wm-"${wcSid}"\" uid=\""${email}"\" type=\"set\"><query xmlns=\"webmail:iq:folders\"><account uid=\""${email}"\"><folder action=\"add\"><type>${folderTypeCode}</type><name>"${folderName}"</name></folder></account></query></iq>"
folder_create="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL --data-binary "${folder_create_request}" "http://${iwserver}/webmail/server/webmail.php")"
if [[ "${folder_create}" =~ "folder_already_exists" ]]
  then
  echo 1;return 1;
fi
if [[ "${folder_create}" =~ "webmail:iq:folders" ]]
  then
  echo 0;return 0;
  else
  echo 2;return 2;
fi
echo 2;return 2;
}

function importData # ( 1:wcSid, 2: email, 3: fileName, 4: fileType, 5: folderName )
{
wcSid="${1}";
email="${2}";
fileName="${3}";
fileType="${4}";
folderName="${5}";
case ${fileType} in
     vcard) importAction="vcard" ;;
  calendar) importAction="vcalendar" ;;
esac
tmpuuid="$(cat /proc/sys/kernel/random/uuid | tr -d '-')";
postUid="$(echo "${tmpuuid::-10}")";
dateDay="$(date --rfc-3339='date')";
data_upload_temp="$(curl -k -F "folder=${dateDay}-${postUid}" -F "sid=wm-${wcSid}" -F "swf=1" -F "folder=${dateDay}-${postUid}" -F "file=@${fileName};type=text/${fileType}" "http://${iwserver}/webmail/server/upload.php")";
fileId="$(echo "${data_upload_temp}" | sed -r 's|.*,id:"(.*)",size.*|\1|')";
data_upload_request="<iq sid=\"wm-"${wcSid}"\" type=\"set\"><query xmlns=\"webmail:iq:import\"><import action=\"${importAction}\"><account uid=\""${email}"\"><folder uid=\""${folderName}"\"/></account><fullpath>${dateDay}-${postUid}/${fileId}</fullpath></import></query></iq>";
data_upload="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL --data-binary "${data_upload_request}" "http://${iwserver}/webmail/server/webmail.php")";
echo "${data_upload}";
}

# main ( 1: email, 2: password, 3: folderTypeCode C|E|T, 4: folderName, 5: fileName )
sid="$(sessionLogin "${1}" "${2}")";
createGWFolder "${sid}" "${1}" "${3}" "${4}";
case ${3} in
     "C") type="vcard" ;;
     "E") type="calendar" ;;
     "T") type="calendar" ;;
esac
importData "${sid}" "${1}" "${5}" "${type}" "${4}"
echo "$(sessionLogout "${sid}")";
exit 0
