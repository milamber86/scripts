#!/bin/bash
source /etc/icewarp/icewarp.conf
maildirpath="$(${IWS_INSTALL_DIR}/tool.sh get system C_System_Storage_Dir_MailPath | grep -P '(?<=: ).*(?=/mail/)' -o)"
backuppath="${maildirpath}/backup"
scriptdir="$(cd $(dirname $0) && pwd)"
mkdir -p ${maildirpath}
mkdir -p ${backuppath}
mkdir -p ${scriptdir}/logs
backupsrvhost="${1}" # if we take backups from another host
backupsrvport="${2}" # than the one we connect to
logdate="$(date +%Y%m%d)"
logfile="${scriptdir}/logs/bck_${logdate}.log"

function log {
  echo $(date +%H:%M:%S) $1 >> ${logfile}
}

log "Starting backup."

utiltest="$(/usr/bin/find /usr/lib64 -type f -name "Entities.pm")"
if [[ -z "${utiltest}" ]]
  then
  log "Installing Entities.pm"
  /usr/bin/yum -y install epel-release
  /usr/bin/yum -y install perl-HTML-Encoding.noarch
fi

log "Reading DB access data."
dbpass="$(/usr/bin/cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbpass>.*</dbpass>" | perl -pe 's|^\<dbpass\>(.*)\</dbpass\>$|\1|' | perl -MHTML::Entities -pe 'decode_entities($_);')"
wcdbuser="$(/usr/bin/cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbuser>.*</dbuser>" | perl -pe 's|^\<dbuser\>(.*)\</dbuser\>$|\1|')"
read -r dbhost dbport wcdbname <<< $(cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbconn>mysql:host=.*;port=.*;dbname=.*</dbconn>" | perl -pe 's|^\<dbconn\>mysql:host=(.*);port=(.*);dbname=(.*)\</dbconn\>$|\1 \2 \3|')
read -r accdbname accdbuser <<< $(${IWS_INSTALL_DIR}/tool.sh get system c_system_storage_accounts_odbcconnstring | perl -pe 's|^c_system_storage_accounts_odbcconnstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|')
read -r aspdbname aspdbuser <<< $(${IWS_INSTALL_DIR}/tool.sh get system c_as_challenge_connectionstring | perl -pe 's|^c_as_challenge_connectionstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|')
read -r grwdbname grwdbuser <<< $(${IWS_INSTALL_DIR}/tool.sh get system c_gw_connectionstring | perl -pe 's|^c_gw_connectionstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|')
read -r dcdbname dcdbuser <<< $(${IWS_INSTALL_DIR}/tool.sh get system c_accounts_global_accounts_directorycacheconnectionstring | perl -pe 's|^c_accounts_global_accounts_directorycacheconnectionstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|')
easdbname="$(${IWS_INSTALL_DIR}/tool.sh get system c_activesync_dbconnection | ${IWS_INSTALL_DIR}/tool.sh get system c_activesync_dbconnection | egrep -o "mysql:host=.*;dbname=.*" | perl -pe 's|^mysql:host=.*;port=.*;dbname=(.*)$|\1|')"
easdbuser="$(${IWS_INSTALL_DIR}/tool.sh get system c_activesync_dbuser | perl -pe 's|^c_activesync_dbuser: (.*)$|\1|')"
easdbpass="$(${IWS_INSTALL_DIR}/tool.sh get system c_activesync_dbpass | perl -pe 's|^c_activesync_dbpass: (.*)$|\1|')"
if [ -z "${easdbpass}" ]; then easdbpass="easdbpass not discovered"; fi
if [[ "${dbpass}" =~ "^sqlite:.*" ]]; then dbpass="${easdbpass}"; fi
if [ -z "${dbpass}" ]; then dbpass="dbpass not discovered"; fi
if [ ! -z "${backupsrvhost}" ]; then dbhost="${backupsrvhost}"; fi # if we take backups from another host
if [ ! -z "${backupsrvport}" ]; then dbport="${backupsrvport}"; fi # than the one we connect to

/usr/bin/mysqldump --single-transaction -u ${accdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${accdbname} | gzip -c | cat > ${backuppath}/bck_db_acc_${accdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${aspdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${aspdbname} | gzip -c | cat > ${backuppath}/bck_db_asp_${aspdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${grwdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${grwdbname} | gzip -c | cat > ${backuppath}/bck_db_grw_${grwdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${dcdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${dcdbname} | gzip -c | cat > ${backuppath}/bck_db_dc_${dcdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${easdbuser} -p${easdbpass} -h${dbhost} -P ${dbport} ${easdbname} | gzip -c | cat > ${backuppath}/bck_db_eas_${easdbname}`date +%Y%m%d-%H%M`.sql.gz &
/usr/bin/mysqldump --single-transaction -u ${wcdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${wcdbname} | gzip -c | cat > ${backuppath}/bck_db_wc_${wcdbname}`date +%Y%m%d-%H%M`.sql.gz &

log "Finished DB backup."
wait ${!}
log "Starting IW config backup."
/usr/bin/tar -czf ${backuppath}/bck_cnf`date +%Y%m%d-%H%M`.tgz ${IWS_INSTALL_DIR}/config > /dev/null 2>&1
/usr/bin/tar -czf ${backuppath}/bck_cal`date +%Y%m%d-%H%M`.tgz ${IWS_INSTALL_DIR}/calendar > /dev/null 2>&1
${IWS_INSTALL_DIR}/tool.sh export account "*@*" u_backup > ${backuppath}/bck_acc_backup`date +%Y%m%d-%H%M`.csv
${IWS_INSTALL_DIR}/tool.sh export domain "*" d_backup > ${backuppath}/bck_dom_backup`date +%Y%m%d-%H%M`.csv
log "Finished IW config backup."
log "Cleaning old backups and logs."
/usr/bin/find ${backuppath}/ -type f -name "bck_*" -mtime +3 -delete > /dev/null 2>&1
/usr/bin/find ${scriptdir}/logs/ -type f -name "bck_*.log" -mtime +30 -delete > /dev/null 2>&1
log "All done."
exit 0
