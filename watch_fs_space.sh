#!/bin/bash
# Watches specified paths for disk space lower than percentual or absolute treshold
# and sends warning email if the disk space is lower that that.
# Repeated warnings for the same path are not sent unless the problem with the path
# are not resolved before the problem occurs again.
# Put paths and tresholds into watched_paths.csv in the same directory
# in the following format:
# /absolute/path/to/watched/directory/;minimal_absolute_free_in_bytes;minimal_percent_free;
# example:
# /opt/icewarp/;104857600;10;
# /mnt/data/;524288000;5;

warning_email="user@domain.tld" # this is the email address warnings will be sent to from "root@<server_hostname>"
# you may want to set antispam exceptions for the FROM: address and test you can receive these notifications
# setting a limit which is already exceeded in watched_paths.csv

if ! rpm -q sendmail > /dev/null 2>&1; then
  yum -y install sendmail
fi
if ! rpm -q mutt > /dev/null 2>&1; then
  yum -y install mutt
fi

if [[ ! -f watched_paths.csv ]]; then
  echo "Config file watched_paths.csv not found in the script directory. Please configure path(s) to watch."
fi

md5()
{
echo -n "${1}" | md5sum | awk '{print $1}'
}

number_regex="[0-9]{1,}"
touch warning_sent.txt

while IFS=';' read watch_path absolute_free percent_free;
  do
    if [[ ! -d "${watch_path}" ]]; then echo "Watched path ${watch_path} does not exist. Ignoring path ${watch_path}."; continue; fi
    if [[ ! ${absolute_free} =~ ${number_regex} ]]; then echo "Absolute free limit for ${watch_path} set in watched_paths.csv is not a number. Please fill in a number in Bytes. Ignoring path ${watch_path}."; continue; fi
    if [[ ! ${percent_free} =~ ${number_regex} ]]; then echo "Percent free limit for ${watch_path} set in watched_paths.csv is not a number. Please fill in a number in Bytes. Ignoring path ${watch_path}."; continue; fi
    path_data="$(df -B1 "${watch_path}" | tail -1 | awk '{print $1";"$4";"$5}')";
    path_device="$(echo -n "${path_data}" | awk -F';' '{print $1}')";
    path_md5sum="$(md5 "${watch_path}")";
    path_absolute_free=$(echo -n "${path_data}" | awk -F';' '{print $2}');
    path_percent_full=$(echo -n "${path_data}" | awk -F';' '{print $3}' | tr -d '%');
    path_percent_free=$( expr 100 - ${path_percent_full} );
    if [[ ( ${path_absolute_free} -le ${absolute_free} ) || ( ${path_percent_free} -le ${percent_free} ) ]]; then
      warn_text_short="Disk space low on path ${watch_path}, device ${path_device}"
      warn_text_long="                       $(date)
                      !!! Disk space Limit is Exceeded !!!
                      ====================================
                      Path:                ${watch_path}
                      Device:            ${path_device}
                      Percent free:  ${path_percent_free}%, ( limit set to min. of ${percent_free}% free )
                      Bytes free:      ${path_absolute_free}B, ( limit set to min. of ${absolute_free}B free )";
      grep -Fx "${path_md5sum}" warning_sent.txt > /dev/null; warning_sent=$?;
      if [[ ${warning_sent} -ne 0 ]]; then
        echo "${warn_text_long}" | mutt -s "${warn_text_short}" ${warning_email}; email_sent=$?;
        if [[ ${email_sent} -eq 0 ]]; then echo "${path_md5sum}" >> warning_sent.txt; fi
      fi
    else
      sed -i "\#${path_md5sum}#d" warning_sent.txt
    fi
done < watched_paths.csv
