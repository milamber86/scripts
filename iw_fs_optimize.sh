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
FDUPES="$(which fdupes)"
if [ "${FDUPES}" != *"fdupes" ]; then
									echo "fdupes util missing, please install fdupes"
									exit 1
fi
#
# option defaults
declare START_DIR="";
declare -i MAX_SIZE=100000;
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
## fill DOMAINS array with domain paths
get_domain_path()
{
declare -a DOMAINS=( $(find "${START_DIR}" -maxdepth 1 -type d | tail -n +2) );
(>&2 echo ${DOMAINS[@]});
(>&2 echo ${#DOMAINS[@]});
return 0
}
#
#
## fill USERS array with user paths for all records from DOMAINS  
get_user_path()
{
declare local element;
for element in $(seq 0 $((${#DOMAINS[@]} - 1)))
do
  declare -a USERS+=(( $(find "${1}" -maxdepth 1 -type d | tail -n +2) );
done
(>&2 echo ${USERS[@]});
(>&2 echo ${#USERS[@]});
return 0
}
#
#
## get file count for given path, input is full path ending with /, returns file count
get_folder_stats()
{
find "${1}" -maxdepth 1 -type f | wc -l
return 0
}
#
#
## get file count for user maildir folders of given path, input is full path ending with /, returns maildir stats
get_user_stats()
{
declare local FPATH="${1}";
for I in $(find "${FPATH}" -maxdepth 1 -type d)
do
  find "${I}" -maxdepth 1 -type d -print | xargs -0 -I {} sh -c 'echo -e $(find "{}" -printf "\n" | wc -l) "{}"' | sort -n | head -n -1;
done
return 0
}
#
#
## append path for optimize to end of OPTIMIZE array, input is full path ending with /
append_to_optimize()
{
declare -a OPTIMIZE+=( ${1} );
(>&2 echo ${OPTIMIZE[@]});
(>&2 echo ${#OPTIMIZE[@]});
return 0
}
#
#
## remove last element of OPTIMIZE array
remove_from_optimize()
{
OPTIMIZE=("${OPTIMIZE[@]::${#OPTIMIZE[@]}-1}");
(>&2 echo ${OPTIMIZE[@]});
(>&2 echo ${#OPTIMIZE[@]});
return 0
} 
#
#
## process all records in USERS, append those over file limit to OPTIMIZE array
search_for_optimize()
{
declare local element;
declare local path;
for element in $(seq 0 $((${#USERS[@]} - 1)))
do
  for path in $(get_user_stats ${USERS[element]})
  do
    declare local -i size=$(echo "${path}" | sed -r s'|^([[:digit:]]+) (\/.*)$|\1|')
    if [ "${size}" -ge "${MAX_SIZE}" ]
    then
      declare local appendpath=$(echo "${path}" | sed -r s'|^([[:digit:]]+) (\/.*)$|\2|')
      append_for_optimize "${appendpath}"
    fi
  done
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
find "${1}" -maxdepth 1 -type f -name "*.imap" | xargs egrep -l "^Subject: Returned mail" | xargs -I {} mv -v "{}" "${1}""${GARBAGE_FOLDER}"
get_folder_stats "${1}"
return 0
}
#
#
## move older mail to subfolders, input is full path ending with /, returns new number of messages
optimize_old()
{
declare local year;
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
### ### MAIN ###
get_domain_path
get_user_path
search_for_optimize
for element in $(seq 0 $((${#OPTIMIZE[@]} - 1)))
do
  echo "Running optimize for path: ${OPTIMIZE[element]}"
  declare -i files=$(echo "${OPTIMIZE[element]}" | sed -r s'|^([[:digit:]]+) (\/.*)$|\1|')
  declare -i nodupes=$(echo $(optimize_dupes ${OPTIMIZE[element]}))
  declare -i dupes=${files}-${nodupes}
  declare -i files=${files}-${dupes}
  echo "fdupes deleted ${dupes} duplicate files, ${files} files left in the folder"
  declare -i nogarbage=$(echo $(optimize_garbage ${OPTIMIZE[element]}))
  declare -i garbage=${files}-${nogarbage}
  declare -i files=${files}-${garbage}
  echo "garbage filter moved ${garbage} files to ${GARBAGE_FOLDER} subfolder, ${files} files left in the folder"
  declare -i noold=$(echo $(optimize_old ${OPTIMIZE[element]}))
  declare -i old=${files}-${noold}
  declare -i files=${files}-${old}
  echo "garbage filter moved ${old} files to subfolders, ${files} files left in the folder"
  echo "Work done for ${OPTIMIZE[element]}"
done
exit 0
