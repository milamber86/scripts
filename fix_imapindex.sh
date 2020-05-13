#!/bin/bash

#  fix_imapindex.sh
#  icewarp tools
#
#  Created by Otto Beranek on 12/05/2020.
#
#  Tests all imap folders for given username/password for broken index
#  and restores indexes from backup if the index is broken.
#

# global vars
myDate="$(date +%m%d%y-%H%M)";
ctimeout=30; # connection and idle timeout for netcat
toolSh="/opt/icewarp/tool.sh";
icewarpdSh="/opt/icewarp/icewarpd.sh";
tmpFile="/root/imapindextmp.txt";
iwArchivePattern='^"Archive';
indexFileName="imapindex.bin";
backupPrefixPath="/.zfs/snapshot/20200512-0024";
mntPrefixPath="/mnt/data-nfs";
tmpPrefix="_restore_";
bckPrefix="_backup_${myDate}_";

function imapFolderList # ( 1: login email, 2: password -> imap folders list excluding archive folders )
{
local cmdResult="$(timeout -k ${ctimeout} ${ctimeout} echo -e ". login \"${1}\" \"${2}\"\n. xlist \"\" \"*\"\n. logout\n" | nc -w 30 127.0.0.1 143 | egrep XLIST | egrep -o '\"(.*?)\"|Completed' | sed -r 's|"/" ||' | egrep -v "${iwArchivePattern}")"
echo "${cmdResult}" | tail -1 | egrep "Completed" > /dev/null
if [[ ${?} -ne 0 ]] ; then
  echo "Failed getting list of imap folders for account ${1}. Error: ${cmdResult}";return 1;
    else
  echo "${cmdResult}" | egrep -v "Completed";
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
# "number" regex for results comparison
re='^[0-9]+$'
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
  echo "Error copying files, src: ${srcPath} or dst: ${dstPath} does not exist."
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

function indexRestore # ()
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
    echo "FAIL - User: ${1}, folder: ${i}, fullpath: ${cmdResult}."
    prepFolderRestore "${1}" "${cmdResult}"
          else
    echo "OK - User: ${1}, ${cmdResult} msgs, folder: ${i}."
  fi
done
if [[ -f "${tmpFile}" ]]; then
  indexRestore
fi
exit 0
