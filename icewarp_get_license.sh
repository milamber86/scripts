#!/bin/bash
PATH=/opt/icewarp:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
mkdir -p /root/license
logfile=/root/license/log.txt
MONTH=`date +%Y%m`;
FILENAME="license-`date +%Y%m%d-%H%M`.txt";

export_license () {
# export enabled accounts to file with their activesync policy status ( to determine if the account is light or full user )
/opt/icewarp/tool.sh export account "*@*" u_type u_accountdisabled u_activesync | egrep "^(.*)\@(.*),0,0,(.*)," | perl -pe 's|(.*)\@(.*),0,0,(.*),|\2,\1,\3,|' > /root/license/${FILENAME}

# print full and light user counts for individual domains and all together
for DOM in $(/usr/bin/cat /root/license/${FILENAME} | awk -F "," '{ print $1 }' | sort | uniq);
  do
  /usr/bin/echo -n "${DOM} ALL: "
  grep "${DOM}" /root/license/${FILENAME} | wc -l
  /usr/bin/echo -n "${DOM} FULL: "
  grep "${DOM}" /root/license/${FILENAME} | grep ",1," | wc -l
  /usr/bin/echo -n "${DOM} LIGHT: "
  grep "${DOM}" /root/license/${FILENAME} | grep ",0," | wc -l
  done
/usr/bin/echo "---"
/usr/bin/echo ""
/usr/bin/echo -n "ALL ALL: "
/usr/bin/cat /root/license/${FILENAME} | wc -l
/usr/bin/echo -n "ALL FULL: "
grep ",1," /root/license/${FILENAME} | wc -l
/usr/bin/echo -n "ALL LIGHT: "
grep ",0," /root/license/${FILENAME} | wc -l
/usr/bin/echo ""
/usr/bin/echo ""
/usr/bin/echo ""

# export and print active EAS users from SQL database ( db connection and credentials should be stored in users home in .my.cnf file  )
for DOM in $(/usr/bin/cat /root/license/${FILENAME} | awk -F "," '{ print $1 }' | sort | uniq)
  do /usr/bin/echo -n "${DOM} EAS Active: "
  /usr/bin/echo -e "use eas;select device_id, user_id from eas.devices where user_id like \x27%${DOM}%\x27 group by user_id;" | mysql | grep -v "device_id" | wc -l
  done
/usr/bin/echo "---"
/usr/bin/echo ""
/usr/bin/echo -n "ALL EAS Active: "
/usr/bin/echo -e "use eas;select device_id, user_id from eas.devices group by user_id;" | mysql | grep -v "device_id" | wc -l
/usr/bin/echo ""
}

# MAIN
# save license info to file and mail it out
export_license > /root/license/proc_${FILENAME}
/usr/bin/unix2dos /root/license/proc_${FILENAME}
/usr/bin/echo "License report for ${MONTH} is attached." | mutt -s "License report - ${MONTH}" a@b.cz -c b@b.cz -a "/root/license/proc_${FILENAME}"

exit 0
