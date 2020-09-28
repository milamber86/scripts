#!/bin/bash
iwserver="127.0.0.1";                             # IceWarp server IP/host
ctimeout="600";                                   # curl connection timeout in seconds
tmpFile="/root/tmpFile";
tmpFolders="/root/tmpFolders";
exportPath="/root/exporttst";
mkdir -p "${exportPath}"
excludePattern='^"TeamChat';
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
wcatoken="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o "<authtoken>(.*)</authtoken>" | sed -r s'|<authtoken>(.*)</authtoken>|\1|')"
# get phpsessid
wcphpsessid="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL "https://${iwserver}/webmail/?atoken=$( rawurlencode "${wcatoken}" )" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"
# auth wc session
auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
wcSid="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL --data-binary "${auth_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";
echo "${wcSid}";
}

function sessionLogout # ( 1: wcSid )
{
wcSid="${1}";
logout_request="<iq sid=\"wm-"${wcSid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
logout="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL --data-binary "${logout_request}" "https://${iwserver}/webmail/server/webmail.php")";
}

function exportFolderVCF # ( 1: wcSid, 2: user@email, 3: folderName, 4: targetPath )
{
wcSid=${1};
email="${2}";
folderName="${3}";
targetPath="${4}";
# export Contacts folder to vcf format
encemail="$(rawurlencode "${email}")"
curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL "https://${iwserver}/webmail/server/download.php?sid=wm-${wcSid}&class=exportvcard&fullpath=${encemail}%2F${folderName}" > "${targetPath}"
# echo "${targetPath}";
}

function exportFolderICS # ( 1: wcSid, 2: user@email, 3: folderName, 4: targetPath )
{
wcSid=${1};
email="${2}";
folderName="${3}";
targetPath="${4}";
# export Calendar, Tasks folder to ics format
calexport_request="<iq sid=\"wm-${wcSid}\" type=\"set\"><query xmlns=\"webmail:iq:folders\"><account uid=\"${email}\"><folder uid=\"${folderName}\" action=\"save_items\"/></account></query></iq>"
calexport_response="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL --data-binary "${calexport_request}" "https://${iwserver}/webmail/server/webmail.php")";
local fullPath="$(echo "${calexport_response}" | egrep -o "<fullpath>(.*)</fullpath>" | perl -pe 's|<fullpath>(.*)</fullpath>|\1|')";
curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL "https://${iwserver}/webmail/server/download.php?class=file&fullpath=${fullPath}&sid=wm-${wcSid}" > "${targetPath}"
# echo "${targetPath}";
}

function getFolders # ( 1: wcSid, 2: user@email -> gw folders list to tmpFile )
{
wcSid="${1}";
email="${2}";
getfolder_request="<iq sid=\"wm-${wcSid}\" uid=\"${email}\" type=\"set\" format=\"json\"><query xmlns=\"webmail:iq:accounts\"><account action=\"refresh\" uid=\"${email}\"/></query></iq>";
getfolder_response="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -kL --data-binary "${getfolder_request}" "https://${iwserver}/webmail/server/webmail.php")";
echo "${getfolder_response}" | json_reformat -u | jq . -c | egrep -o '\"TYPE\":\[\{\"VALUE\":\"[[:alnum:]]\"\}\]|\"RELATIVE_PATH\":\[\{\"VALUE\":\"[[:alnum:]\\ \/]*\"\}\]|\"ATTRIBUTES\":\{\"UID\":\"[[:alnum:]\/\@_]*\"\}\}' | tr -d '[]{}' | sed -r 's|"VALUE":||' | sed -r 's|"UID":||' > "${tmpFile}"
}

function parseFolders # ( tmpFile folder list from getFolders -> folder_name;type to tmpFolders file )
{
local wantType=0;
while IFS=':' read attr value; do
    if [[ ${attr} =~ '"TYPE"' ]]
      then
      folderType=${value}
    fi
    if [[ ( ${attr} =~ '"RELATIVE_PATH"' ) && ( ( ${folderType} =~ '"E"' ) || ( ${folderType} =~ '"C"' ) || ( ${folderType} =~ '"T"' ) ) ]]
      then
      local folderName="${value}";
      folderRecord="${folderName};${folderType};";
      echo "${folderRecord}" >> ${tmpFolders}
    fi
done < "${tmpFile}"
}

# main
rm -f ${tmpFile}
rm -f ${tmpFolders}
echo "--- Logging user ${1} ---"
wcSid="$(sessionLogin "${1}" "${2}")";
echo "--- Exporting folders for ${1} ---"
getFolders "${wcSid}" "${1}";
parseFolders
echo "--- Exported folders for ${1}: ---"
cat ${tmpFolders}
mkdir -p "${exportPath}/${1}";
while IFS=';' read name type; do
  folderName="$(echo "${name}" | tr -d '"')";
  echo "--- Exporting user ${1}, folder ${folderName} ---"
  if [[ ${folderName} =~ '/' ]]; then
    makeDir="$(echo ${folderName} | awk -F'/' '{OFS = "/"; $NF=""; print $0}')";
    mkdir -p "${exportPath}/${1}/${makeDir}";
  fi
  case ${type} in
   '"E"') exportFolderICS "${wcSid}" "${1}" "${folderName}" "${exportPath}/${1}/${folderName}.ics" ;;
   '"C"') exportFolderVCF "${wcSid}" "${1}" "${folderName}" "${exportPath}/${1}/${folderName}.vcf" ;;
   '"T"') exportFolderICS "${wcSid}" "${1}" "${folderName}" "${exportPath}/${1}/${folderName}.ics" ;;
  esac
  echo "--- Finished exporting user ${1}, folder ${folderName} ---"
done < "${tmpFolders}"
sessionLogout "${wcSid}"
exit 0
