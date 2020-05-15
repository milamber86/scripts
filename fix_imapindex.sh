#!/bin/bash

#  fix_imapindex.sh
#  icewarp tools
#
#  Created by Otto Beranek on 12/05/2020.
#
#  Tests all imap folders for given username/password for broken index
#  and restores indexes from backup if the index is broken.
#  Tests webclient cache item count against imap folder, if not equal,
#  triggers webclient cache update or clear and full folder refresh.

# global vars
myDate="$(date +%m%d%y-%H%M)";
ctimeout=30; # connection and idle timeout for netcat
iwserver="127.0.0.1";
toolSh="/opt/icewarp/tool.sh";
icewarpdSh="/opt/icewarp/icewarpd.sh";
tmpFile="/root/imapindextmp.txt";
iwArchivePattern='^"Archive';
indexFileName="imapindex.bin";
backupPrefixPath="/.zfs/snapshot/20200512-0024";
mntPrefixPath="/mnt/data-nfs";
tmpPrefix="_restore_";
bckPrefix="_backup_${myDate}_";
excludePattern='^"Public Folders|^"Archive|"Notes';
re='^[0-9]+$'; # "number" regex for results comparison
dbName="$(cat /opt/icewarp/config/_webmail/server.xml | egrep -o "dbname=.*<" | sed -r 's|dbname=(.*)<|\1|')";

function imapFolderList # ( 1: login email, 2: password -> imap folders list excluding archive folders )
{
local cmdResult="$(timeout -k ${ctimeout} ${ctimeout} echo -e ". login \"${1}\" \"${2}\"\n. xlist \"\" \"*\"\n. logout\n" | nc -w 30 127.0.0.1 143 | egrep XLIST | egrep -o '\"(.*?)\"|Completed' | sed -r 's|"/" ||' | egrep -v "${iwArchivePattern}")"
echo "${cmdResult}" | tail -1 | egrep "Completed" > /dev/null
if [[ ${?} -ne 0 ]] ; then
  echo "Failed getting list of imap folders for account ${1}. Error: ${cmdResult}";return 1;
    else
  echo "${cmdResult}" | egrep -v "Completed" | egrep -v "${excludePattern}";
  return 0;
fi
}

function getFullMailboxPath # ( 1: user@email -> full mailbox path )
{
local cmdResult="$(${toolSh} export account ${1} u_fullmailboxpath | awk -F ',' '{print $2}')"
if [[ ! -d "${cmdResult}" ]] ; then
    echo "Failed to get full mailbox path for account ${1}, error: ${cmdResult}";return 1;
    else
    echo "${cmdResult}"
fi
}

function testImapFolder # ( 1: login email, 2: password, 3: imap folder path -> OK: number of messages in folder, NOK - full folder path )
{
local fmPath="$(getFullMailboxPath ${1})";
tmpImapFolder="$(echo "${3}" | tr -dc [:print:] |sed -r 's|"||g')";
if [[ "${tmpImapFolder}" =~ ^INBOX ]] ; then
local imapFolder="$(echo "${tmpImapFolder}" | sed -r s'|INBOX|inbox|')";
  else
  if [[ "${tmpImapFolder}" =~ \.$ ]] ; then
  local hexImapFolder="$(echo "${tmpImapFolder}" | tr -d '\n' | xxd -ps -c 200)";
  local imapFolder="enc~${hexImapFolder}";
    else
    if [[ "${tmpImapFolder}" =~ ^Spam ]] ; then
    local imapFolder="$(echo "${tmpImapFolder}" | sed -r s'|Spam|~spam|')";
      else
      imapFolder="${tmpImapFolder}"
    fi
  fi
fi
# get number of messages in given imap folder
local imapCmd=". login ${1} ${2}\n. select \"${imapFolder}\"\n. logout\n"
local cmdResult="$(timeout -k ${ctimeout} ${ctimeout} echo -e "${imapCmd}" | nc -w ${ctimeout} 127.0.0.1 143 | egrep -o "\* (.*) EXISTS" | awk '{print $2}')"
# test imap returned integer in number of messages in folder test, if not, plan index restore
if ! [[ $cmdResult =~ $re ]] ; then
    echo "${fmPath}${imapFolder}/";return 1;
    else
  declare -i imapResult=${cmdResult};
fi
# get number of messages on the filesystem for given folder
if [[ ! -d "${fmPath}${imapFolder}" ]] ; then
  echo "Folder ${imapFolder} not found on filesystem, error: ${cmdResult}";return 1;
    else
  local cmdResult="$(find "${fmPath}${imapFolder}/" -maxdepth 1 -type f -name "*.imap" | wc -l)"
  if ! [[ $cmdResult =~ $re ]] ; then
    echo "${fmPath}${imapFolder}/";return 1;
      else
    declare -i fsResult=${cmdResult};
  fi
fi
if [[ ${imapResult} -ne ${fsResult} ]] ; then
    echo "${fmPath}${imapFolder}/";return 1;
        else
    echo "${imapResult}";return 0;
fi
}

function testWcFolder # ( 1: user@email, 2: imap folder name -> number of messages in wc cache )
{
local folderEncName="$(echo ${2} | sed -r 's|"||g')";
local folderName="$(python imapcode.py "${folderEncName}")";
local dbQuery="$(echo -e "select folder_id from folder where account_id = \x27${1}\x27 and name = \x27${folderName}\x27;")";
local folderDbId="$(echo "${dbQuery}" | mysql ${dbName} | egrep -v folder_id | tr -dc [:print:])";
local dbQuery="$(echo -e "select count(*) from item where folder_id = ${folderDbId};")";
local dbResult="$(echo "${dbQuery}" | mysql ${dbName} | egrep -v count | tr -dc [:print:])";
if ! [[ $dbResult =~ $re ]] ; then
echo "Failed to get number of messages for ${1}, folder ${2} from the webclient database.";return 1;
  else
  echo "${dbResult}";return 0;
fi
}

function fixWcFolder # ( 1: user@email, 2: imap folder name )
{
local folderEncName="$(echo ${2} | sed -r 's|"||g')";
local folderName="$(python imapcode.py "${folderEncName}")";
local dbQuery="$(echo -e "select folder_id from folder where account_id = \x27${1}\x27 and name = \x27${folderName}\x27;")";
local folderDbId="$(echo "${dbQuery}" | mysql ${dbName} | egrep -v folder_id | tr -dc [:print:])";
local dbQuery="$(echo -e "update folder set sync_update=0 where folder_id = ${folderDbId};")";
#local dbQuery="$(echo -e "update folder set uid_validity=NULL, sync_update=0 where folder_id = ${folderDbId};")";
local dbResult="$(echo "${dbQuery}" | mysql "${dbName}")";
# todo test db result
}

function resetWcFolder # ( 1: user@email, 2: imap folder name )
{
local folderEncName="$(echo ${2} | sed -r 's|"||g')";
local folderName="$(python imapcode.py "${folderEncName}")";
local dbQuery="$(echo -e "select folder_id from folder where account_id = \x27${1}\x27 and name = \x27${folderName}\x27;")";
local folderDbId="$(echo "${dbQuery}" | mysql ${dbName} | egrep -v folder_id | tr -dc [:print:])";
local dbQuery="$(echo -e "delete from item where folder_id = ${folderDbId};")";
local dbResult="$(echo "${dbQuery}" | mysql "${dbName}")";
# todo test db result
local dbQuery="$(echo -e "update folder set uid_validity=NULL, sync_update=0 where folder_id = ${folderDbId};")";
local dbResult="$(echo "${dbQuery}" | mysql "${dbName}")";
# todo test db result
}

# urlencode string
function rawurlencode() {
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

function refreshWcFolder # ( 1: user@email, 2: password, 3: imap folder name )
{
local folderEncName="$(echo ${3} | sed -r 's|"||g')";
local folderName="$(python imapcode.py "${folderEncName}")";
local email="${1}";
local pass="${2}";
# get auth token
local atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>getauthtoken</commandname><commandparams><email>${email}</email><password>${pass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
local wcatoken="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o "<authtoken>(.*)</authtoken>" | sed -r s'|<authtoken>(.*)</authtoken>|\1|')"
 ## echo "1: ${wcatoken}"
# get phpsessid
local wcphpsessid="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL "https://${iwserver}/webmail/?atoken=$( rawurlencode "${wcatoken}" )" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"
 ## echo "2: ${wcphpsessid}"
# auth wc session
local auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
local wcsid="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${auth_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";
## echo "3: ${wcsid}"

# refresh folders standard account start
local refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${email}\" type=\"set\" format=\"xml\"><query xmlns=\"webmail:iq:accounts\"><account action=\"refresh\" uid=\"${email}\"/></query></iq>"
local response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php")"
 ## echo "4: ${response}"
# folder refresh
local refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"734012818541404900158955161135\" type=\"get\" format=\"xml\"><query xmlns=\"webmail:iq:items\"><account uid=\"${email}\"><folder uid=\"${folderName}\"><item><values><subject/><to/><sms/><from/><date/><size/><flags/><has_attachment/><color/><priority/><smime_status/><item_moved/><tags/><ctz>120</ctz></values><filter><limit>68</limit><offset>0</offset><sort><date>desc</date><item_id>desc</item_id></sort></filter></item></folder></account></query></iq>"
local response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php")"
 ## echo "5: ${response}"
# session logout
local logout_request="<iq sid=\"wm-"${wcsid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${logout_request}" "https://${iwserver}/webmail/server/webmail.php" > /dev/null 2>&1
}

function prepFolderRestore # ( 1: user@email, 2: full path to folder )
{
local dstPath="${2}";
local fmPath="$(getFullMailboxPath ${1})";
local iwmPath="$(echo ${dstPath} | sed -r "s|${mntPrefixPath}||")";
local srcPath="${mntPrefixPath}${backupPrefixPath}/${iwmPath}";
if [[ (-f "${dstPath}") && (-f "${srcPath}") ]]; then
echo "Restoring ${indexFileName}, src: ${srcPath}${indexFileName} -> dst: ${dstPath}${tmpPrefix}${indexFileName}"
/usr/bin/cp -fv "${srcPath}/${indexFileName}" "${dstPath}/${tmpPrefix}${indexFileName}"
echo "${dstPath}" >> "${tmpFile}"
  else
  echo "Error copying files, either src: ${srcPath} or dst: ${dstPath} does not exist."
fi
}

function indexRename # ( 1: full path to folder )
{
local srcName="${1}${tmpPrefix}${indexFileName}";
local dstName="${1}${indexFileName}";
local bckName="${1}${bckPrefix}${indexFileName}";
echo "Moving ${dstName} -> ${bckName} and ${srcName} -> ${dstName}";
/usr/bin/mv -v "${dstName}" "${bckName}" && /usr/bin/mv -v "${srcName}" "${dstName}";
return ${?}
}

function indexFix # ()
{
${toolSh} set system C_System_Tools_WatchDog_POP3 0
${icewarpdSh} --stop pop3
sleep 1
${icewarpdSh} --stop pop3
pkill -9 -f pop3
for I in $(cat "${tmpFile}")
do
  indexRename "${I}"
done
${icewarpdSh} --restart pop3
${toolSh} set system C_System_Tools_WatchDog_POP3 1
${toolSh} set system C_Accounts_Global_Accounts_DirectoryCache_RefreshNow 1
}

# main
if [[ ! -f imapcode.py ]]; then
yum -y install python python-six
wget https://mail.icewarp.cz/imapcode.py
chmod u+x imapcode.py
fi
rm -fv "${tmpFile}"
cmdResult=$(imapFolderList "${1}" "${2}");
if [[ ${?} -ne 0 ]] ; then
  echo "${cmdResult}";exit 1;
    else
  readarray -t imapFolders < <(echo "${cmdResult}")
fi
for i in "${imapFolders[@]}"
do
  cmdResult=$(testImapFolder "${1}" "${2}" "${i}");
  if [[ ${?} -ne 0 ]] ; then
    echo "FAIL IMAP - User: ${1}, folder: ${i}, fullpath: ${cmdResult}. Trying to repair."
    prepFolderRestore "${1}" "${cmdResult}"
          else
           ##   echo "   OK IMAP - User: ${1}, ${cmdResult} msgs, folder: ${i}."
          continue;
  fi
done
if [[ -f "${tmpFile}" ]]; then
  indexFix
fi
for i in "${imapFolders[@]}"
do
  cmdResult=$(testImapFolder "${1}" "${2}" "${i}");
  if [[ ${?} -ne 0 ]] ; then
  echo "FAIL IMAP 2nd time - User: ${1}, folder: ${i}, fullpath: ${cmdResult}. Giving up."
  continue
          else
          imapCnt=${cmdResult};
          cmdResult="$(testWcFolder "${1}" "${i}")";
          if [[ $cmdResult -ne ${imapCnt} ]] ; then
          echo "FAIL WC - User: ${1}, folder: ${i}, wc cache/imap have: ${cmdResult} / ${imapCnt} msgs.";
          fixWcFolder "${1}" "${i}";
          refreshWcFolder "${1}" "${2}" "${i}";
          cmdResult=$(testWcFolder "${1}" "${i}");
          echo "Status after repair: folder: ${i}, wc cache have: ${cmdResult} msgs.";
                      else
                       ##      echo "   OK WC - User: ${1}, ${cmdResult} msgs, folder: ${i}."
                      continue;
          fi
   fi
done
exit 0
