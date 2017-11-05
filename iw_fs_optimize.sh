#!/bin/bash
# build fs tree, count number of files in each folder
# if there is more than N files in folder, runs optimize
# optimize does these steps:
# 	- deduplicates messages using fdupes
#	- moves NDRs and other garbage mail to subdirectory
#	- moves older mail to subfolders on folder per year basis
#
#   - REQUIRES: fdupes
#
### ### variables ###
#
# ( script options are -d: starting directory, -s: max allowed files count for directory )
#
#
declare FDUPES="$(which fdupes)"
if [ "${FDUPES}" == "" ];
then
  echo "fdupes util missing, please install fdupes, exiting here"
  exit 1
fi
#
# option defaults
declare START_DIR="/mnt/data/mail/";
declare -i MAX_SIZE=10000;
#
# get command line options
while getopts d:s: option
do
  case "${option}"
  in
  d) START_DIR=${OPTARG};; # where to start, full path ended with slash "/"
  s) MAX_SIZE=${OPTARG};; # where to start, full path ended with slash "/"
  esac
done
#
### ### functions ###
#
## returns domain paths
get_domain_path()
{
echo "$(find "${START_DIR}" -maxdepth 1 -type d | tail -n +2)"
return 0
}
#
#
## returns user paths for all records from DOMAINS  
get_user_path()
{
for element in $(seq 0 $((${#DOMAINS[@]} -1))) 
do
  echo "$(find "${DOMAINS[element]}" -maxdepth 1 -type d | tail -n +2)"
done
return 0
}
#
#
## returns file count for given path, input is full path ending with /
get_folder_stats()
{
echo "$(find "${1}" -maxdepth 1 -type f | wc -l)"
return 0
}
#
#
## returns subfolder paths over file limit, input is full path ending with /
get_user_stats()
{
IFS=$'\n'
for path in $(find "${1}" -type d | tail -n +2 | xargs -I '{}' bash -c 'echo -e "$(find "{}" -maxdepth 1 -type f | wc -l)" "{}"')
do
  declare -i dirsize=$(echo "${path}" | sed -r s'|^([[:digit:]]+) (\/.*)$|\1|')
  if [ "${dirsize}" -ge "${MAX_SIZE}" ]
    then
    echo "${path}"
  fi
done
return 0
}
#
#
## deduplicate files in given path using fdupes, input is full path ending with /, returns new number of messages
optimize_dupes()
{
(>&2 ${FDUPES} -fNI "${1}");
get_folder_stats "${1}"
return 0
}
#
#
## search for NDR and other garbage mail, move it to ${GARBAGE_FOLDER}, input is full path ending with /, returns new number of messages
# TODO optimize search string
optimize_garbage()
{
>&2 find "${1}" -maxdepth 1 -type f -name "*.imap" | xargs egrep -l "^Subject: Returned mail" | xargs -I {} mv -v "{}" "${1}""${GARBAGE_FOLDER}"
get_folder_stats "${1}"
return 0
}
#
#
## move older mail to subfolders, input is full path ending with /, returns new number of messages
optimize_old()
{
for year in {2016 2015 2014 2013 2012 2011 2010 2009 2008 2007 2006 2005 2004 2003 2002 2001 2000}
do
  mkdir -p "${1}"${year}
  cp "${1}"imapindex.dat "${1}"${year}/imapindex.dat
  cp "${1}"imapindex.bin "${1}"${year}/imapindex.bin
  echo "*" > "${1}"${year}/flagsext.dat
  >&2 find "${1}" -maxdepth 1 -type f -name "${year}*.imap" | xargs -I {} mv -v "{}" "${1}"${year}
done
mkdir -p "${1}"1999_older
cp "${1}"imapindex.dat "${1}"1999_older/imapindex.dat
cp "${1}"imapindex.bin "${1}"1999_older/imapindex.bin
echo "*" > "${1}"1999_older/flagsext.dat
>&2 find "${1}" -maxdepth 1 -type f -name "${19}*.imap" | xargs -I {} mv -v "{}" "${1}"1999_older
get_folder_stats "${1}"
return 0
}
#
#
### ### MAIN ### ( fill DOMAINS, USERS, OPTIMIZE arrays and performe optimize on paths in OTPIMIZE )
for element in $(get_domain_path)
do
  declare -a DOMAINS=( "${DOMAINS[@]}" "${element}" )
done
echo "DOMAINS all - ${DOMAINS[@]}" # debug
echo "DOMAINS last added - ${DOMAINS[-1]}" # debug
echo "DOMAINS elements count - ${#DOMAINS[@]}" # debug
read -n 1 -s -r -p "Press any key to continue" # debug
for element in $(get_user_path)
do
  declare -a USERS=( "${USERS[@]}" "${element}" )
done
echo "USERS all - ${USERS[@]}" # debug
echo "USERS last added - ${USERS[-1]}" # debug
echo "USERS elements count - ${#USERS[@]}" # debug
read -n 1 -s -r -p "Press any key to continue" # debug
for element in $(seq 0 $((${#USERS[@]} -1))) 
do
  unset tmparr
  readarray tmparr <<< "$(get_user_stats "${USERS[element]}")"
  if [ "${tmparr[@]}" != "" ] 
   then 
   declare -a OPTIMIZE=( "${OPTIMIZE[@]}" "${tmparr[@]}" )
  fi
done
  echo "OPTIMIZE all - ${OPTIMIZE[@]}" # debug
  echo "OPTIMIZE last added - ${OPTIMIZE[-1]}" # debug
  echo "OPTIMIZE elements count - ${#OPTIMIZE[@]}" # debug
  read -n 1 -s -r -p "Press any key to continue" # debug
for element in $(seq 0 $((${#OPTIMIZE[@]} - 1)))
do
  echo "Running optimize for path: ${OPTIMIZE[element]}"
  declare -i nodupes=$(echo $(optimize_dupes ${OPTIMIZE[element]}))
  echo "${nodupes} files left in the folder after dedup ..."
  declare -i nogarbage=$(echo $(optimize_garbage ${OPTIMIZE[element]}))
  echo "${nogarbage} files left in the folder after garbage cleanup ..."
  declare -i noold=$(echo $(optimize_old ${OPTIMIZE[element]}))
  echo "${noold} files left in the folder after old mail cleanup ..."
  echo "Work done for ${OPTIMIZE[element]}"
done
exit 0
