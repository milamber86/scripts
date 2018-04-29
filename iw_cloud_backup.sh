#!/bin/bash
backuppath="/mnt/data/backup"
mkdir -p /mnt/data
mkdir -p ${backuppath}
backupsrvhost="${1}" # if we take backups from another host
backupsrvport="${2}" # than the one we connect to
test="$(find /usr/lib64 -type f -name "Entities.pm")"
if [[ -z "${test}" ]]
  then
  /usr/bin/yum -y install epel-release
  /usr/bin/yum -y install perl-HTML-Encoding.noarch
fi
dbpass="$(cat /opt/icewarp/config/_webmail/server.xml | cat /opt/icewarp/config/_webmail/server.xml | egrep -o "<dbpass>.*</dbpass>" | perl -pe 's|^\<dbpass\>(.*)\</dbpass\>$|\1|' | perl -MHTML::Entities -pe 'decode_entities($_);')"
wcdbuser="$(cat /opt/icewarp/config/_webmail/server.xml | egrep -o "<dbuser>.*</dbuser>" | perl -pe 's|^\<dbuser\>(.*)\</dbuser\>$|\1|')"
read -r dbhost dbport wcdbname <<< $(cat /opt/icewarp/config/_webmail/server.xml | egrep -o "<dbconn>mysql:host=.*;port=.*;dbname=.*</dbconn>" | perl -pe 's|^\<dbconn\>mysql:host=(.*);port=(.*);dbname=(.*)\</dbconn\>$|\1 \2 \3|')
read -r accdbname accdbuser <<< $(/opt/icewarp/tool.sh get system c_system_storage_accounts_odbcconnstring | perl -pe 's|^c_system_storage_accounts_odbcconnstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|')
read -r aspdbname aspdbuser <<< $(/opt/icewarp/tool.sh get system c_as_challenge_connectionstring | perl -pe 's|^c_as_challenge_connectionstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|')
read -r grwdbname grwdbuser <<< $(/opt/icewarp/tool.sh get system c_gw_connectionstring | perl -pe 's|^c_gw_connectionstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|')
read -r dcdbname dcdbuser <<< $(/opt/icewarp/tool.sh get system c_accounts_global_accounts_directorycacheconnectionstring | perl -pe 's|^c_accounts_global_accounts_directorycacheconnectionstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|')
easdbname="$(/opt/icewarp/tool.sh get system c_activesync_dbconnection | perl -pe 's|^c_activesync_dbconnection: mysql:host=.*;port=.*;dbname=(.*)$|\1|')"
easdbuser="$(/opt/icewarp/tool.sh get system c_activesync_dbuser | perl -pe 's|^c_activesync_dbuser: (.*)$|\1|')"
easdbpass="$(/opt/icewarp/tool.sh get system c_activesync_dbpass | perl -pe 's|^c_activesync_dbpass: (.*)$|\1|')"
if [ -z "${dbpass}" ]; then dbpass="pass_not_discovered"; fi
if [ ! -z "${backupsrvhost}" ]; then dbhost="${backupsrvhost}"; fi # if we take backups from another host
if [ ! -z "${backupsrvport}" ]; then dbport="${backupsrvport}"; fi # than the one we connect to
if [[ "${accdbuser}" = *"DBUIWC"* ]]
then # generic_cloud ( DBUIWC*, DBUIWC*EAS, DBUIWC*WC)
/usr/bin/mysqldump --single-transaction -u ${accdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${accdbname} | gzip -c | cat > ${backuppath}/bck_db_acc_asp_grw_dc_${accdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${easdbuser} -p${easdbpass} -h${dbhost} -P ${dbport} ${easdbname} | gzip -c | cat > ${backuppath}/bck_db_eas_${easdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${accdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${wcdbname} | gzip -c | cat > ${backuppath}/bck_db_wc_${wcdbname}`date +%Y%m%d-%H%M`.sql.gz &
else # non-generic cloud ( other db name settings )
/usr/bin/mysqldump --single-transaction -u ${accdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${accdbname} | gzip -c | cat > ${backuppath}/bck_db_acc_${accdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${aspdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${aspdbname} | gzip -c | cat > ${backuppath}/bck_db_asp_${aspdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${grwdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${grwdbname} | gzip -c | cat > ${backuppath}/bck_db_grw_${grwdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${dcdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${dcdbname} | gzip -c | cat > ${backuppath}/bck_db_dc_${dcdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${easdbuser} -p${easdbpass} -h${dbhost} -P ${dbport} ${easdbname} | gzip -c | cat > ${backuppath}/bck_db_eas_${easdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${wcdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${wcdbname} | gzip -c | cat > ${backuppath}/bck_db_wc_${wcdbname}`date +%Y%m%d-%H%M`.sql.gz &
fi
wait ${!}
tar -czf ${backuppath}/bck_cnf`date +%Y%m%d-%H%M`.tgz /opt/icewarp/config > /dev/null 2>&1
tar -czf ${backuppath}/bck_cal`date +%Y%m%d-%H%M`.tgz /opt/icewarp/calendar > /dev/null 2>&1
/opt/icewarp/tool.sh export account "*@*" u_backup > ${backuppath}/bck_acc_backup`date +%Y%m%d-%H%M`.csv
/opt/icewarp/tool.sh export domain "*" d_backup > ${backuppath}/bck_dom_backup`date +%Y%m%d-%H%M`.csv
find ${backuppath}/ -type f -name "bck_*" -mtime +3 -delete > /dev/null 2>&1
exit 0
