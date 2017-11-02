#!/bin/bash
# build fs tree, count number of files in each folder
# if there is more than N files in folder, runs optimize
# optimize does these steps:
# 	- deduplicates messages using fdupes
#	- moves NDRs and other garbage mail to subdirectory
#	- moves older mail to subfolders on folder per year basis
#
### ### variables ###
#
# ( script options are -d: starting directory, -s: max allowed files count for directory )
#
# option defaults
declare START_DIR="";
declare MAX_SIZE="";
#
# get command line options
while getopts d:s option
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
## returns user paths for DOMAINS and load them into USERS array  
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
FPATH="${1}";
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
optimize_garbage()
{

get_folder_stats "${1}"
return 0
}
#
#
## move older mail to subfolders, input is full path ending with /, returns new number of messages
optimize_old()
{

get_folder_stats "${1}"
return 0
}
#
#
### ### MAIN ###

