#!/bin/bash

#  fix_imapindex.sh
#  icewarp tools
#
#  Created by Otto Beranek on 12/05/2020.
#
#  Tests all imap folders for given username/password for broken index
#  and prepares restore from backup if the index is broken.

# global vars
ctimeout=30 # connection and idle timeout for netcat
toolSh="/opt/icewarp/tool.sh"
tmpFile=/root/imaptmp.txt
iwArchivePattern='^"Archive'

function imapFolderList # ( 1: login email, 2: password -> imap folders list excluding archive folders )
{
local cmdResult="$(timeout -k ${ctimeout} ${ctimeout} echo -e ". login \"${1}\" \"${2}\"\n. xlist \"\" \"*\"\n. logout\n" | nc -w 30 127.0.0.1 143 | egrep XLIST | awk '{print $NF}' | egrep -v "${iwArchivePattern}")"
echo "${cmdResult}" | tail -1 | egrep "Completed" > /dev/null
if [[ ${?} -ne 0 ]] ; then
  echo "Failed getting list of imap folders for account ${1}. Error: ${cmdResult}";return 1;
    else
  echo "${cmdResult}" | egrep -v "Completed";
  return 0;
fi
}

function testImapFolder # ( 1: login email, 2: password, 3: imap folder path -> folder index status )
{
tmpImapFolder="$(echo "${3}" | tr -dc [:print:] |sed -r 's|"||g')";
if [[ "${tmpImapFolder}" == "INBOX" ]] ; then
  local imapFolder="$(echo "${tmpImapFolder}" | tr '[:upper:]' '[:lower:]')";
   else
  imapFolder="${tmpImapFolder}"
fi
# get full mailbox path for tested user
local cmdResult="$(${toolSh} export account ${1} u_fullmailboxpath | awk -F ',' '{print $2}')"
if [[ ! -d "${cmdResult}" ]] ; then
    echo "Failed to get full mailbox path for account ${1}, error: ${cmdResult}";return 1;
    else
  local fmPath="${cmdResult}";
fi
# get number of messages in given imap folder
local imapCmd=". login ${1} ${2}\n. select "${imapFolder}"\n. logout\n"
local cmdResult="$(timeout -k ${ctimeout} ${ctimeout} echo -e "${imapCmd}" | nc -w ${ctimeout} 127.0.0.1 143 | egrep -o "\* (.*) EXISTS" | awk '{print $2}')"
# "number" regex for results comparison
re='^[0-9]+$'
# test imap returned integer in number of messages in folder test, if not, plan index restore
if ! [[ $cmdResult =~ $re ]] ; then
  echo -e "${fmPath}${imapFolder}/\n" >> ${tmpFile}
  echo "Failed to get number of messages for folder ${imapFolder} from imap, error: ${cmdResult}";return 1;
    else
  declare -i imapResult=${cmdResult};
fi
# get number of messages on the filesystem for given folder
if [[ ! -d "${fmPath}${imapFolder}" ]] ; then
  echo "Folder ${imapFolder} not found on filesystem, error: ${cmdResult}";return 1;
    else
  local cmdResult="$(find "${fmPath}${imapFolder}/" -maxdepth 1 -type f -name "*.imap" | wc -l)"
  if ! [[ $cmdResult =~ $re ]] ; then
    echo "Failed to get number of messages for folder ${imapFolder} from filesystem, error: ${cmdResult}";return 1;
      else
    declare -i fsResult=${cmdResult};
  fi
fi
if [[ ${imapResult} -ne ${fsResult} ]] ; then
  echo -e "${fmPath}${imapFolder}/\n" >> ${tmpFile}
  echo "Imap and filesystem counts not equal ( account: ${1}, folder: ${imapFolder}, imapCnt: ${imapResult}, fsCnt: ${fsResult} ). Index restore scheduled.";return 1;
    else
  echo "No problem detected.";return 0;
fi
}

# main
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
    echo "User ${1}, folder ${i} FAIL, ${cmdResult}"
          else
    echo "User ${1}, folder ${i} OK"
  fi
done
