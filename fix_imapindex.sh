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
ctimeout=60; # connection and idle timeout for netcat
iwserver="127.0.0.1";
toolSh="/opt/icewarp/tool.sh";
icewarpdSh="/opt/icewarp/icewarpd.sh";
tmpFile="$(mktemp /tmp/folderrepair.XXXXXXXXX)";
iwArchivePattern='^"Archive';
indexFileName="imapindex.bin";
backupPrefixPath=".zfs/snapshot/20220808-0000";
mntPrefixPath="/mnt/data";
tmpPrefix="_restore_";
bckPrefix="_backup_${myDate}_";
wcCacheRetry=100;
excludePattern='^"~|^"Soubory|^"Public Folders|^"Archive|"Notes|^Informa&AQ0-n&AO0- kan&AOE-ly RSS';
pubFolderPattern=' \\Public| \\Virtual| \\Shared| \\Noselect';
re='^[0-9]+$'; # "number" regex for results comparison
dbName="$(cat /opt/icewarp/config/_webmail/server.xml | egrep -o "dbname=.*<" | sed -r 's|dbname=(.*)<|\1|')";
logFailed="/root/logFailed_fix";
dbgLvl=1;
resetInbox=0;
admin="admin@domain.loc";
adminpass="adminpassword";
email="${1}";
imapLogin="$(echo -ne "${email}\0${admin}\0${adminpass}" | base64 | tr -d '\n')";

function wctoken() # ( user@email -> auth wc URL for the user )
{
local start=`date +%s%N | cut -b1-13`
local email="${1}";
# get admin auth token
local atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>authenticate</commandname><commandparams><email>${admin}</email><password>${adminpass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
local wcatoken="$(curl -s --connect-timeout 8 -m 8 -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o 'sid="(.*)"' | sed -r 's|sid="(.*)"|\1|')"
if [ -z "${wcatoken}" ];
  then
    echo "ERROR" "Webclient Stage 1 fail - Error getting webclient auth token from control!";
    return 1;
fi
# impersonate webclient user
local imp_request="<iq sid=\"${wcatoken}\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>impersonatewebclient</commandname><commandparams><email>${email}</email></commandparams></query></iq>"
local wclogintmp="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${imp_request}" "https://${iwserver}/icewarpapi/" | egrep -o '<result>(.*)</result>' | sed -r 's|<result>(.*)</result>|\1|')"
wclogin="$(echo ${wclogintmp} | awk -F'=' '{print $2}')";
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

function imapFolderList # ( 1: login email -> imap folders list ) get user imap folders
{
local cmdResult="$(timeout -k ${ctimeout} ${ctimeout} echo -e ". AUTHENTICATE PLAIN\n${imapLogin}\n. xlist \"\" \"*\"\n. logout\n" | nc -w 30 127.0.0.1 143 | egrep XLIST | egrep -v "${pubFolderPattern}" | egrep -o '\"(.*?)\"|Completed' | sed -r 's|"/" ||' | egrep -v "${excludePattern}")"
echo "${cmdResult}" | tail -1 | egrep "Completed" > /dev/null
if [[ ${?} -ne 0 ]] ; then
  echo "Failed getting list of imap folders for account ${1}. Error: ${cmdResult} Could not auth.";return 1;
    else
  echo "${cmdResult}" | egrep -v "Completed" | egrep -v "${excludePattern}";
  return 0;
fi
}

function getFullMailboxPath # ( 1: user@email -> full mailbox path ) get user full mailbox path prefix from IW api
{
local cmdResult="$(${toolSh} export account ${1} u_fullmailboxpath | awk -F ',' '{print $2}')"
if [[ ! -d "${cmdResult}" ]] ; then
    echo "Failed to get full mailbox path for account ${1}, error: ${cmdResult}";return 1;
    else
    echo "${cmdResult}"
fi
}

function imapFolderFsPath # ( 1: user@email, 2: imap mailbox name -> imap mailbox full encoded fs path) get IW full fs path for imap mailbox
{
local fmPath="$(getFullMailboxPath ${1})";
local tmpFolder="$(echo "${2}" | sed -r 's# #|#g')";
IFS='/' read -ra FOLDERS <<< $(echo "${tmpFolder}" | sed -r 's|"||g')
total=${#FOLDERS[*]};
for I in $( seq 0 $(( $total - 1 )) )
  do
  FOLDER="$(echo "${FOLDERS[$I]}" | tr -d '\n')";
  if [[ ( "${FOLDER}" =~ INBOX ) && ( $I -eq 0 ) ]] ; then
    FOLDERS[$I]="$(echo "${FOLDER}" | sed -r s'|INBOX|inbox|')";
      else
      if [[ "${FOLDER}" =~ \.\.\._  ]] ; then continue ; fi;
      if [[ ( "${FOLDER}" =~ \.$ ) || ( "${FOLDER}" =~ \.\.\. ) || ( "${FOLDER}" =~ \* ) ]] ; then
        local hexImapFolder="$(echo "${FOLDER}" | sed -r 's#\|# #g' | tr -d '\n' | xxd -ps -c 200)";
        FOLDERS[$I]="enc~${hexImapFolder}";
          else
          if [[ "${FOLDER}" =~ ^Spam ]] ; then
            FOLDERS[$I]="$(echo "${FOLDER}" | sed -r s'|^Spam$|~spam|')";
          fi
      fi
  fi
  done
total=${#FOLDERS[*]};
for I in $( seq 0 $(( $total - 1 )) )
  do
  FOLDERS[$I]="$(echo ${FOLDERS[$I]})/";
  done
IFS=\/ eval 'lst="${FOLDERS[*]}"'
echo "${fmPath}/${lst}" | sed -r 's#//#/#g' | sed -r 's#\|# #g'
}

# test if imap reports the same number of messages in SELECT <mailbox> EXISTS response as the number of messages in folder on filesystem
function testImapFolder # ( 1: login email, 2: password, 3: imap folder path -> OK: number of messages in folder, NOK - imap mailbox full encoded fs path )
{
# get number of messages on the filesystem for given folder
local fmPath="$(imapFolderFsPath "${1}" "${3}")";
if [[ ! -d "${fmPath}" ]] ; then
  echo "Folder ${fmPath} not found on filesystem, error: ${cmdResult}";return 1;
    else
  local cmdResult="$(find "${fmPath}" -maxdepth 1 -type f -name "*.imap" | wc -l)"
  if ! [[ $cmdResult =~ $re ]] ; then
    echo "${fmPath}";return 1;
      else
    declare -i fsResult=${cmdResult};
  fi
fi
# get number of messages in given imap folder in EXISTS SELECT response
imapFolder="$(echo "${3}" | tr -dc [:print:] |sed -r 's|"||g')";
local imapCmd=". AUTHENTICATE PLAIN\n${imapLogin}\n. select \"${imapFolder}\"\n. logout\n"
local cmdResult="$(timeout -k ${ctimeout} ${ctimeout} echo -e "${imapCmd}" | nc -w ${ctimeout} 127.0.0.1 143 | egrep -o "\* (.*) EXISTS" | awk '{print $2}')"
# test imap returned integer in number of messages in folder test, if not, plan index restore
if ! [[ $cmdResult =~ $re ]] ; then
    echo "${fmPath}";return 1;
    else
  declare -i imapResult=${cmdResult};
fi
if [[ ${imapResult} -ne ${fsResult} ]] ; then
    echo "${fmPath}";return 1;
        else
    echo "${imapResult}";return 0;
fi
}

function getImapSeenCnt # ( 1: login email, 2: password, 3: imap folder path -> OK: number of seen messages in folder, NOK - imap mailbox full encoded fs path )
{
# get number of messages in given imap folder in UID SEARCH seen response
imapFolder="$(echo "${3}" | tr -dc [:print:] |sed -r 's|"||g')";
local imapCmd=". AUTHENTICATE PLAIN\n${imapLogin}\n. select \"${imapFolder}\"\n. uid search seen\n. logout\n"
local cmdResult="$(timeout -k ${ctimeout} ${ctimeout} echo -e "${imapCmd}" | nc -w ${ctimeout} 127.0.0.1 143 | egrep '\* SEARCH' | sed -r 's|\* SEARCH ||' | wc -w)"
if ! [[ $cmdResult =~ $re ]] ; then
    echo "${fmPath}";return 1;
    else
  declare -i seenCnt=${cmdResult};
  echo "${seenCnt}";return 0;
fi
}

function testWcFolder # ( 1: user@email, 2: imap folder name -> number of messages in wc cache ) get number of items from wc db for given folder
{
local tmpFolder="$(echo "${2}" | sed -r 's|"||g')";
local folderEncName="$(echo "${tmpFolder}" | sed -r 's# #|#g')";
local folderName="$(python imapcode.py "$(echo "${folderEncName}" | sed -r s'#\|# #g')")";
local dbQuery="$(echo -e "select folder_id from folder where account_id = \x27${1}\x27 and name = \x27${folderName}\x27 and path like \x27%${tmpFolder}\x27;")";
local dbResult="$(echo "${dbQuery}" | mysql ${dbName} | egrep -v folder_id | tr -dc [:print:])";
if ! [[ $dbResult =~ $re ]] ; then
  local dbQuery="$(echo -e "select folder_id from folder where account_id = \x27${1}\x27 and name = \x27${folderName}\x27 and path like \x27%${tmpFolder}%\x27;")";
  local dbResult="$(echo "${dbQuery}" | mysql ${dbName} | egrep -v folder_id | tr -dc [:print:])";
  if ! [[ $dbResult =~ $re ]] ; then
    local dbQuery="$(echo -e "select folder_id from folder where account_id = \x27${1}\x27 and name = \x27${folderName}\x27;")";
    local dbResult="$(echo "${dbQuery}" | mysql ${dbName} | egrep -v folder_id | tr -dc [:print:])";
    if ! [[ $dbResult =~ $re ]] ; then
      echo "ERROR ${dbResult}"
      return 1;
    fi
  fi
fi
local folderDbId=${dbResult}
local dbQuery="$(echo -e "select count(*) from item where folder_id = ${folderDbId};")";
local dbResult="$(echo "${dbQuery}" | mysql ${dbName} | egrep -v count | tr -dc [:print:])";
if ! [[ $dbResult =~ $re ]] ; then
  echo "Failed to get number of messages for ${1}, folder ${2} from the webclient database.";return 1;
    else
    echo "${dbResult}";return 0;
fi
}

function fixWcFolder # ( 1: user@email, 2: imap folder name ) set folder to refresh in wc db
{
local tmpFolder="$(echo "${2}" | sed -r 's# #|#g')";
local folderEncName="$(echo "${tmpFolder}" | sed -r 's|"||g')";
local folderName="$(python imapcode.py "$(echo "${folderEncName}" | sed -r s'#\|# #g')")";
local dbQuery="$(echo -e "select folder_id from folder where account_id = \x27${1}\x27 and name = \x27${folderName}\x27;")";
local folderDbId="$(echo "${dbQuery}" | mysql ${dbName} | egrep -v folder_id | tr -dc [:print:])";
local dbQuery="$(echo -e "update folder set sync_update=0 where folder_id = ${folderDbId};")";
#local dbQuery="$(echo -e "update folder set uid_validity=NULL, sync_update=0 where folder_id = ${folderDbId};")";
local dbResult="$(echo "${dbQuery}" | mysql "${dbName}")";
# todo test db result
}

function resetWcFolder # ( 1: user@email, 2: imap folder name ) delete items for given folder, reset folder validity in wc db
{
local tmpFolder="$(echo "${2}" | sed -r 's# #|#g')";
local folderEncName="$(echo "${tmpFolder}" | sed -r 's|"||g')";
local folderName="$(python imapcode.py "$(echo "${folderEncName}" | sed -r s'#\|# #g')")";
local dbQuery="$(echo -e "select folder_id from folder where account_id = \x27${1}\x27 and name = \x27${folderName}\x27;")";
local folderDbId="$(echo "${dbQuery}" | mysql ${dbName} | egrep -v folder_id | tr -dc [:print:])";
local dbQuery="$(echo -e "delete from item where folder_id = ${folderDbId};")";
local dbResult="$(echo "${dbQuery}" | mysql "${dbName}")";
# todo test db result
local dbQuery="$(echo -e "update folder set uid_validity=NULL, sync_update=0 where folder_id = ${folderDbId};")";
local dbResult="$(echo "${dbQuery}" | mysql "${dbName}")";
# todo test db result
}

function resetWcUser # ( 1: user@email ) delete whole user wc cache db
{
local dbQuery="$(echo -e "delete from item where folder_id in (select folder_id from folder where account_id = \x27${1}\x27);")";
local dbResult="$(echo "${dbQuery}" | mysql "${dbName}")";
# todo test db result
local dbQuery="$(echo -e "delete from folder where account_id = \x27${1}\x27;")";
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

function refreshWcFolder # ( 1: user@email, 2: password, 3: imap folder name ) simulate user folder select in webclient to trigger wc cache folder refresh
{
local tmpFolder="$(echo "${3}" | sed -r 's# #|#g')";
local folderEncName="$(echo "${tmpFolder}" | sed -r 's|"||g')";
local folderName="$(python imapcode.py "$(echo "${folderEncName}" | sed -r s'#\|# #g')")";
local email="${1}";
wcatoken="$(wctoken "${email}")";
# get phpsessid
local wcphpsessid="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL "https://${iwserver}/webmail/?atoken=${wcatoken}" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"
if [[ "${wcphpsessid}" =~ "500 Internal Server Error" ]] ; then echo "${wcphpsessid}";return 1; fi
 ## echo "2: ${wcphpsessid}"
# auth wc session
local auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
local wcsid="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${auth_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";
if [[ "${wcsid}" =~ "500 Internal Server Error" ]] ; then echo "${wcsid}";return 1; fi
## echo "3: ${wcsid}"

# refresh folders standard account start
local refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${email}\" type=\"set\" format=\"xml\"><query xmlns=\"webmail:iq:accounts\"><account action=\"refresh\" uid=\"${email}\"/></query></iq>"
local response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php")"
if [[ "${response}" =~ "500 Internal Server Error" ]] ; then echo "${response}";return 1; fi
 ## echo "4: ${response}"
# folder refresh
local folderAmpEnc="$(echo "${folderName}" | sed -r 's|&|&amp;|g')";
local refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"734012818541404900158955161135\" type=\"get\" format=\"xml\"><query xmlns=\"webmail:iq:items\"><account uid=\"${email}\"><folder uid=\"${folderAmpEnc}\"><item><values><subject/><to/><sms/><from/><date/><size/><flags/><has_attachment/><color/><priority/><smime_status/><item_moved/><tags/><ctz>120</ctz></values><filter><limit>68</limit><offset>0</offset><sort><date>desc</date><item_id>desc</item_id></sort></filter></item></folder></account></query></iq>"
local response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php")"
if [[ "${response}" =~ "500 Internal Server Error" ]] ; then echo "${response}";return 1; fi
 ## echo "5: ${response}"
# session logout
local logout_request="<iq sid=\"wm-"${wcsid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${logout_request}" "https://${iwserver}/webmail/server/webmail.php" > /dev/null 2>&1
}

function prepFolderRestore # ( 1: user@email, 2: full imap mailbox fs path ) prepares imapindex restore from backup
{
local dstPath="${2}";
local fmPath="$(getFullMailboxPath ${1})";
local iwmPath="$(echo ${dstPath} | sed -r "s|${mntPrefixPath}||")";
local srcPath="${mntPrefixPath}/${backupPrefixPath}${iwmPath}";
if [[ (-f "${dstPath}${indexFileName}") && (-f "${srcPath}${indexFileName}") ]]; then
echo "Restoring ${indexFileName}, src: ${srcPath}${indexFileName} -> dst: ${dstPath}${tmpPrefix}${indexFileName}"
/usr/bin/cp -fv "${srcPath}${indexFileName}" "${dstPath}/${tmpPrefix}${indexFileName}"
#echo "${dstPath}" >> "${tmpFile}"
  else
  echo "Error copying files, either src: ${srcPath}${indexFileName} or dst: ${dstPath}${indexFileName} does not exist."
  return 1
fi
}

function indexRename # ( 1: full path to folder ) rename indexes , called from indexFix
{
local srcName="${1}${tmpPrefix}${indexFileName}";
local dstName="${1}${indexFileName}";
local bckName="${1}${bckPrefix}${indexFileName}";
echo "Moving ${dstName} -> ${bckName} and ${srcName} -> ${dstName}";
/usr/bin/mv -v "${dstName}" "${bckName}" && /usr/bin/mv -v "${srcName}" "${dstName}";
chown icewarp:icewarp "${dstName}"
cacheInvalidate=$(/opt/icewarp/scripts/php.sh -c /opt/icewarp/php/php.ini -f /root/cache_invalidate.php "${dstName}");
echo "*" > "${1}flagsext.dat";
chown icewarp:icewarp "${1}flagsext.dat";
cacheInvalidate=$(/opt/icewarp/scripts/php.sh -c /opt/icewarp/php/php.ini -f /root/cache_invalidate.php "${1}flagsext.dat}");
}

function indexFix # ( 1: user@email ) stop imap, rename restored idx, backup original ones, restart imap
{
${toolSh} set system C_System_Tools_WatchDog_POP3 0
sudo ${icewarpdSh} --stop pop3
sleep 1
sudo ${icewarpdSh} --stop pop3
pkill -9 -f pop3
for I in $(cat "${tmpFile}")
do
  indexRename "${I}"
done
sudo ${icewarpdSh} --restart pop3
${toolSh} set system C_System_Tools_WatchDog_POP3 1
${toolSh} set account "${1}" u_directorycache_refreshnow 1
}

function indexFolderFix # ( 1: user@email. 2: full fs folder path ) stop imap, rename restored idx, backup original ones, restart imap
{
${toolSh} set system C_System_Tools_WatchDog_POP3 0
sudo ${icewarpdSh} --stop pop3
sleep 1
sudo ${icewarpdSh} --stop pop3
pkill -9 -f pop3
indexRename "${2}"
sudo ${icewarpdSh} --restart pop3
${toolSh} set system C_System_Tools_WatchDog_POP3 1
${toolSh} set account "${1}" u_directorycache_refreshnow 1
}


overwrite() { echo -e "\r\033[1A\033[0K$@"; }

# main
if [[ ( ! -f imapcode.py ) || ( ! -f cache_invalidate.php ) ]]; then
yum -y install python python-six
rm -fv imapcode.py
rm -fv cache_invalidate.php
wget https://raw.githubusercontent.com/milamber86/scripts/master/imapcode.py
wget https://raw.githubusercontent.com/milamber86/scripts/master/cache_invalidate.php
chmod u+x imapcode.py
fi
echo "$(date) - ${email} start.";
imapFolders="";
cmdResult=$(imapFolderList "${email}" "${2}"); # get imap folder list
if [[ ${?} -ne 0 ]] ; then
  echo "${cmdResult}";exit 1;
    else
  readarray -t imapFolders < <(echo "${cmdResult}")
fi
for i in "${imapFolders[@]}" # loop through folders in folder list, test fs vs imap count
do
  cmdResult=$(testImapFolder "${email}" "${2}" "${i}");
  if [[ ${?} -ne 0 ]] ; then
    echo "+++ FAIL IMAP - User: ${email}, folder: ${i}, fullpath: ${cmdResult}. Trying to repair."
    if [[ ${dryrun} -eq 0 ]]; then prepFolderRestore "${email}" "${cmdResult}"; fi
      else
      if [[ $dbgLvl -eq 1 ]] ; then echo "*** OK IMAP - User: ${email}, ${cmdResult} msgs, folder: ${i}." ; fi ;
  fi
done
if [[ ( -s "${tmpFile}" ) && ${dryrun} -eq 0 ]] ; then
  indexFix "${email}";
fi
if [[ $resetInbox -eq 1 ]] ; then
  fmPath="$(imapFolderFsPath "${email}" "INBOX")";
  imapSeenCnt=$(getImapSeenCnt "${email}" "${2}" "INBOX");
  echo "INBOX index reset. Pre seen count: ${imapSeenCnt}";
  prepFolderRestore "${email}" "${fmPath}";
  indexFolderFix "${email}" "${fmPath}";
  imapSeenCnt=$(getImapSeenCnt "${email}" "${2}" "INBOX");
  echo "INBOX index reset. Post seen count: ${imapSeenCnt}";
fi
refreshWcFolder "${email}" "${2}" "INBOX"; > /dev/null 2>&1
cmdResult="$(testWcFolder "${email}" "INBOX")";
if [[ ( $? -ne 0 ) && ( ${dryrun} -eq 0 ) ]] ; then resetWcUser "${email}"; fi
for i in "${imapFolders[@]}"
do
  cmdResult=$(testImapFolder "${email}" "${2}" "${i}");
  if [[ ${?} -ne 0 ]] ; then
  echo "+++ FAIL IMAP 2nd time - User: ${email}, folder: ${i}, fullpath: ${cmdResult}. Deleting index, Triggering cache refresh."
  if [[ ${dryrun} -eq 0 ]]; then /usr/bin/rm -fv "${cmdResult}${indexFileName}"; fi
  if [[ ${dryrun} -eq 0 ]]; then cacheInvalidate=$(/opt/icewarp/scripts/php.sh -c /opt/icewarp/php/php.ini -f cache_invalidate.php "${cmdResult}${indexFileName}"); fi
  if [[ ${dryrun} -eq 0 ]]; then /usr/bin/rm -fv "${cmdResult}flags.dat"; fi
  if [[ ${dryrun} -eq 0 ]]; then /usr/bin/rm -fv "${cmdResult}*.timestamp"; fi
  if [[ ${dryrun} -eq 0 ]]; then echo "*" > "${cmdResult}flagsext.dat"; fi
  if [[ ${dryrun} -eq 0 ]]; then chown icewarp:icewarp "${cmdResult}flagsext.dat"; fi
  if [[ ${dryrun} -eq 0 ]]; then sudo ${icewarpdSh} --restart pop3; fi
  if [[ ${dryrun} -eq 0 ]]; then ${toolSh} set account "${email}" u_directorycache_refreshnow 1; fi
  if [[ ${dryrun} -eq 0 ]]; then cmdResult=$(testImapFolder "${email}" "${2}" "${i}"); fi
  cmdResult=$(testImapFolder "${email}" "${2}" "${i}");
    if [[ ${?} -ne 0 ]] ; then
    echo "+++ FAIL IMAP 3rd time - User: ${email}, folder: ${i}, fullpath: ${cmdResult}. Logging, giving up."
    echo "${email};${cmdResult};" >> "${logFailed}"
    fi
          else
          imapCnt=${cmdResult};
          imapSeenCnt=$(getImapSeenCnt "${email}" "${2}" "${i}");
          cmdResult="$(testWcFolder "${email}" "${i}")";
          if [[ ( $? -ne 0) && ( ${dryrun} -eq 0 ) ]] ; then resetWcFolder "${email}" "${i}"; fi
          if [[ ${cmdResult} -ne ${imapCnt} ]] ; then
          echo "+++ FAIL WebC - User: ${email}, folder: ${i}, wc cache / imap / imap seen: ${cmdResult} / ${imapCnt} / ${imapSeenCnt} msgs.";
          for j in $(seq 1 $wcCacheRetry);
            do
            if [[ ${dryrun} -eq 0 ]]; then fixWcFolder "${email}" "${i}"; fi
            refreshWcFolder "${email}" "${2}" "${i}";
            if [[ $? -ne 0 ]] ; then echo "FAIL WebC 2nd time - User: ${email}, folder: ${i}, Internal server error refreshfolder wc. Giving up.";break; fi
            cmdResult=$(testWcFolder "${email}" "${i}");
            if [[ $j -ge 2 ]] ; then
              overwrite "***** Update cycle ${j} / ${wcCacheRetry} ( interval 15s ) - User: ${email}, folder: ${i}, wc cache have: ${cmdResult} of ${imapCnt} msgs.";
                else
                echo "***** Update cycle ${j} / ${wcCacheRetry} ( interval 15s ) - User: ${email}, folder: ${i}, wc cache have: ${cmdResult} of ${imapCnt} msgs.";
            fi
            if [[ $cmdResult -eq ${imapCnt} ]] ; then break ; fi
            sleep 15;
            done
                      else
                      if [[ $dbgLvl -eq 1 ]] ; then echo "*** OK WEBC - User: ${email}, imap: ${imapCnt}, imap seen: ${imapSeenCnt}, web: ${cmdResult} msgs, folder: ${i}." ; fi
                      continue;
          fi
   fi
done
rm -f "${tmpFile}";
echo "$(date) - ${email} end.";
exit 0
