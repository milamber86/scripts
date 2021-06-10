#!/bin/bash
#VARS
HOST="127.0.0.1";
ctimeout=15;
scriptdir="$(cd $(dirname $0) && pwd)"
toolSh="/opt/icewarp/tool.sh";
icewarpdSh="/opt/icewarp/icewarpd.sh";
excludePattern="Public";
admin="tester12@test1.loc";
adminpass="awg3545ser6t3h45esg";

function wctoken() # ( user@email -> auth wc URL for the user )
{
if [[ ! -z ${2} ]];
  then
  admpass="${2}"
  else
  local admpass="$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system 'c_accounts_policies_globaladminpassword' | awk '{print $2}')";
fi
if [[ ! -z ${3} ]];
  then
  HOST="${3}"
fi
local iwserver="${HOST}"
local start=`date +%s%N | cut -b1-13`
local email="${1}";
local admemail="globaladmin";
# get admin auth token
local atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>authenticate</commandname><commandparams><email>${admemail}</email><password>${admpass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
local wcatoken="$(curl -s --connect-timeout 8 -m 8 -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o 'sid="(.*)"' | sed -r 's|sid="(.*)"|\1|')"
if [ -z "${wcatoken}" ];
  then
    echo "ERROR" "Webclient Stage 1 fail - Error getting webclient auth token from control!";
    return 1;
fi
# impersonate webclient user
local imp_request="<iq sid=\"${wcatoken}\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>impersonatewebclient</commandname><commandparams><email>${email}</email></commandparams></query></iq>"
local wclogintmp="$(curl -s --connect-timeout 8 -m 8 -ikL --data-binary "${imp_request}" "https://${iwserver}/icewarpapi/" | egrep -o '<result>(.*)</result>' | sed -r 's|<result>(.*)</result>|\1|')"
wclogin="${wclogintmp}"
if [ -z "${wclogin}" ];
  then
  local freturn="FAIL";echo "FAIL"
  echo "ERROR" "Webclient Stage 2 fail - Error impersonating webclient user!";
  return 1;
  else
  echo "${wclogin}"
  return 0;
fi
}

function getImapFolders() # ( user email -> user imap folders list  )
{
local user="${1}";
local login="$(echo -ne "${user}\0${admin}\0${adminpass}" | base64 | tr -d '\n')";
local response="$(echo -e ". AUTHENTICATE PLAIN\n${login}\n. XLIST \"\" \"*\"\n. logout\n" | nc -w 30 127.0.0.1 143 | egrep XLIST | egrep -o '\"(.*?)\"|Completed' | sed -r 's|"/" ||' | egrep -v "${excludePattern}")";
if echo "${response}" | grep Completed;
  then
    echo "${response}" | grep -v Completed | tr -d '"';return 0;
  else
    echo "Error: ${response}";return 1;
fi
}
function wclogin() # ( wctoken -> user webclient login )
{
local email="${2}";
local iwserver="127.0.0.1";
# get user phpsessid
local wcphpsessid="$(curl -s --connect-timeout 8 -m 8 -ikL "https://127.0.0.1/webmail/${1}" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"
if [ -z "${wcphpsessid}" ];
  then
  local freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
  echo "ERROR" "Webclient Stage 3 fail - Error getting php session ID";
  return 1;
fi
# auth user webclient session
local auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
local wcsid="$(curl -s --connect-timeout 8 -m 8 -ikL --data-binary "${auth_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";
if [ -z "${wcsid}" ];
  then
  local freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
  echo "ERROR" "Webclient Stage 4 fail - Error logging to the webclient ( check PHP session store is available if Redis/KeyDB used )";
  return 1;
fi
# get settings
get_settings_request="<iq sid=\"wm-"${wcsid}"\" type=\"get\" format=\"json\"><query xmlns=\"webmail:iq:private\"><resources><skins/><banner_options/><im/><sip/><chat/><mail_settings_default/><mail_settings_general/><login_settings/><layout_settings/><homepage_settings/><calendar_settings/><default_calendar_settings/><cookie_settings/><default_reminder_settings/><event_settings/><spellchecker_languages/><signature/><groups/><restrictions/><aliases/><read_confirmation/><global_settings/><paths/><streamhost/><password_policy/><fonts/><certificate/><timezones/><external_settings/><gw_mygroup/><default_folders/><documents/></resources></query></iq>";
get_settings_response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${get_settings_request}" "https://${iwserver}/webmail/server/webmail.php")";
if [[ "${get_settings_response}" =~ "result" ]];
  then
   local freturn=OK;
  else
   local freturn=FAIL;echo "ERROR" "Stage 5 fail - Error getting settings, possible API problem";
   return 1;
fi
# refresh folders and look for INBOX
local refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${email}\" type=\"set\" format=\"xml\"><query xmlns=\"webmail:iq:accounts\"><account action=\"refresh\" uid=\"${email}\"/></query></iq>"
local response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o "folder uid=\"INBOX\"")"
if [[ "${response}" =~ "INBOX" ]];
  then
   local freturn=OK;
  else
   local freturn=FAIL;echo "ERROR" "Webclient Stage 6 fail - No INBOX in folder sync response";
   return 1;
fi
for FOLDER in $(getImapFolders "${email}" | grep -v Completed);
  do
  local response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o "folder uid=\"${FOLDER}\"")"
  if [[ "${response}" =~ "${FOLDER}" ]];
  then
   local freturn=OK;echo -n "OK - ${FOLDER};";
  else
   local freturn=FAIL;echo "ERROR" "Webclient Stage 6 fail - ${FOLDER}";
   #return 1;
fi
done
# session logout
local logout_request="<iq sid=\"wm-"${wcsid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${logout_request}" "https://${iwserver}/webmail/server/webmail.php" > /dev/null 2>&1
echo "OK - INBOX"
return 0
}

#MAIN
if [[ -z $@ ]];
  then
  echo "Requires user email as a mandatory 1st parameter. 2nd param: globaladminpass, 3rd param: server host/IP are optional."
  exit 1
fi
token=$(wctoken "${@}");
if [ ! -z "${token}" ];
  then
    start=`date +%s%N | cut -b1-13`
    login=$(wclogin "${token}" "${1}");
    end=`date +%s%N | cut -b1-13`
    runtime=$((end-start))
  else
    echo "Failed to get webclient auth token."
    exit 1
fi
echo "${1};${login};${runtime};";
exit 0
