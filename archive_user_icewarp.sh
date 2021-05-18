#!/bin/bash
mkdir -p /mnt/data/export
mkdir -p /opt/icewarp/custom_scripts
cd /opt/icewarp/custom_scripts/
wget https://raw.githubusercontent.com/milamber86/scripts/master/gwexport.php
for I in $(cat /root/backupuserlist | uniq)
	do
        echo "[$(date)] backing up ${I}."
        mpath="$(/opt/icewarp/tool.sh export account ${I} u_fullmailboxpath | awk -F',' '{print $2}')";
#	userpart="$(echo ${I} | sed -r 's|^(.*)\@(.*)$|\1|')";
#	domainpart="$(echo ${I} | sed -r 's|^(.*)\@(.*)$|\2|')";
	mkdir -p "/mnt/data/export/${I}"
	/opt/icewarp/tool.sh export account "${I}" u_backup > "/mnt/data/export/${I}/${I}_settings.txt"
        echo -n "groupware export: "
	/opt/icewarp/scripts/php.sh -c /opt/icewarp/php/php.ini -f /opt/icewarp/custom_scripts/gwexport.php ${I} "/mnt/data/export/${I}/${I}_gwexport.xml"
        echo "original mail and archives size:"
        du -hs "${mpath}" | sed -r 's|/mnt/data/||'
        tar czf "/mnt/data/export/${I}/${I}_mail.tgz" "${mpath}" 2> /dev/null
        archpath="$(echo "${mpath}" | sed -r 's|/mail/|/archive/|')";
        du -hs "${archpath}" | sed -r 's|/mnt/data/||'
	tar czf "/mnt/data/export/${I}/${I}_archive.tgz" "${archpath}" 2> /dev/null
        sleep 5
        echo "backups size:"
        du -hs /mnt/data/export/${I}/*
        echo "[$(date)] finish backing up ${I}."
#	/opt/icewarp/tool.sh delete account "${I}"
done
exit 0
