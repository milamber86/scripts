#!/bin/bash
#VARS
HOST="127.0.0.1";
ctimeout=15;
scriptdir="$(cd $(dirname $0) && pwd)"
toolSh="/opt/icewarp/tool.sh";
icewarpdSh="/opt/icewarp/icewarpd.sh";

function wctoken() # ( user@email -> auth wc URL for the user )
{
local iwserver="${HOST}"
local start=`date +%s%N | cut -b1-13`
local email="${1}";
local admemail="globaladmin";
local admpass="$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system 'c_accounts_policies_globaladminpassword' | awk '{print $2}')";
# get admin auth token
local atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>authenticate</commandname><commandparams><email>${admemail}</email><password>${admpass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
local wcatoken="$(curl -s --connect-timeout 8 -m 8 -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o 'sid="(.*)"' | sed -r 's|sid="(.*)"|\1|')"
if [ -z "${wcatoken}" ];
  then
  local testadmpass="$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system 'c_accounts_policies_globaladminpassword')";
  if [[ ${?} -eq 0 ]]
    then
    local newadmpass="$(echo "${testadmpass}" | awk '{print $2}')";
    if [[ "${newadmpass}" != "${admpass}" ]]
      then
      admpass="${newadmpass}";
      local atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>authenticate</commandname><commandparams><email>${admemail}</email><password>${admpass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
      local wcatoken="$(curl -s --connect-timeout 8 -m 8 -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o 'sid="(.*)"' | sed -r 's|sid="(.*)"|\1|')"
      if [ -z "${wcatoken}" ];
        then
        local freturn="FAIL";echo "FAIL"
        echo "ERROR" "Webclient Stage 1 fail - Error getting webclient auth token from control!";
        return 1;
        else
        echo "globaladm pass changed to ${admpass}"
      fi
      else
      local freturn="FAIL";echo "FAIL"
      echo "ERROR" "Webclient Stage 1 fail - Error getting webclient auth token from control!";
      return 1;
    fi
    else
    local freturn="FAIL";echo "FAIL"
    echo "ERROR" "Webclient Stage 1 fail - Error getting webclient auth token from control!";
    return 1;
  fi
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

wctoken "${1}"
exit 0
