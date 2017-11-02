#!/bin/bash
# build fs tree, count number of files in each folder
# if there is more than N files in folder, runs optimize
# optimize does these steps:
# 	- deduplicates messages using fdupes
#	- moves NDRs and other garbage mail to subdirectory
#	- moves older mail to subfolders on folder per year basis
#
# variables
# ( script options are -d: starting directory, -s: max allowed files count for directory )
#
while getopts d:s option
do
  case "${option}"
  in
  d) START_DIR=${OPTARG};; # where to start, full path ended with slash "/"
  s) MAX_SIZE=${OPTARG};; # where to start, full path ended with slash "/"
  esac
done
#
# functions
#
#
#
# fill DOMAINS array with domain paths, input is full path ending with /
#
get_domain_path()
{
declare -a DOMAINS=( $(find "${START_DIR}" -maxdepth 1 -type d | tail -n +2) );
(>&2 echo ${DOMAINS[@]});
(>&2 echo ${#DOMAINS[@]});
return 0
}
#
#
#
# returns user paths for DOMAINS and load them into USERS array  
#
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
#
# get file count for user maildir folders of given path, input is full path ending with /
#
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
#
# append path for optimize to OPTIMIZE array, input is full path ending with /
append_for_optimize()
{
declare -a OPTIMIZE+=( ${1} );
(>&2 echo ${#OPTIMIZE[@]});
(>&2 echo ${#OPTIMIZE[@]});
return 0
}
#
#
#
# process all records in USERS, append those over file limit to OPTIMIZE array
search_for_optimize()
{
declare local element;
declare local path;
for element in $(seq 0 $((${#USERS[@]} - 1)))
do
  for path in $(get_user_stats ${USERS[element]})
  do
    declare local -i size=$(echo "${path}" | sed -r s'|^([[:digit:]]+) (\/.*)$|\1|')
    if [ "${size}" -gt "${MAX_SIZE}" ]
    then
      declare local appendpath=$(echo "${path}" | sed -r s'|^([[:digit:]]+) (\/.*)$|\2|')
      append_for_optimize "${appendpath}"
    fi
  done
done
return 0
}
#
# MAIN

# remove last element from array
# array=("${array[@]::${#array[@]}-1}");
