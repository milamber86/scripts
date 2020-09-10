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
cloudplan=$(${IWS_INSTALL_DIR}/tool.sh get system c_license_xml | grep -P '(?<=<licensetype>).*(?=</licensetype>)' -o -m 1)
logdate="$(date +%Y%m%d)"
logfile="${scriptdir}/logs/bck_${logdate}.log"
retention_days=3;
retention_log_days=30;

function log()
{
  echo $(date +%H:%M:%S) $1 >> ${logfile}
}

function preflight_check() # ( check src/dst paths,src database connection, cloudplan, util test )
{
# check src storage
fstabtest=$(/bin/cat /etc/fstab | grep -o "${maildirpath}")
mounttest=$(/bin/mount | grep -o "${maildirpath}")
if [[ "$maildirpath" == "$fstabtest" ]]
then
  log "Storage is a mountpoint - checking."
  if [[ "$maildirpath" != "$mounttest" ]]
    then
    log "Storage not mounted. Aborting."
    exit 1
  else
    log "Storage mountcheck ok."
  fi
else
  log "Storage is not a mountpoint - continuing."
fi
# check dst storage
sizeK=$(df -k "${backuppath}" | tail -1 | awk '{print $4}');
sizeM=$(( $sizeK / 1024 ));
if [[ $sizeM -le 2048 ]];
  then
   log "Insufficient space on the backup target path: ${sizeM} MB left on ${backuppath}";
   exit 1
  else
   log "Backup destination OK";
fi
# check src database
dbcheck=$(/usr/bin/mysql -u ${accdbuser} -p${dbpass} -h ${dbhost} -P ${dbport} -e 'SHOW DATABASES;' | grep -cw "${accdbname}\|${grwdbname}\|${aspdbname}\|${dcdbname}\|${easdbname}\|${wcdbname}");
echo "dbcheck";
# check cloud plan
if [ -z "$cloudplan" ] || [ "$cloudplan" != "cloud" ]
then
  log "Aborting - not Cloud licence."
  exit 1
fi
# util test
utiltest="$(/bin/find /usr/lib64 -type f -name "Entities.pm")"
if [[ -z "${utiltest}" ]]
  then
  log "Installing Entities.pm"
  /usr/bin/yum -y install epel-release
  /usr/bin/yum -y install perl-HTML-Encoding.noarch
fi
}

log "Starting backup."
log "Reading DB access data."

dbpass="$(/bin/cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbpass>.*</dbpass>" | perl -pe 's|^\<dbpass\>(.*)\</dbpass\>$|\1|' | perl -MHTML::Entities -pe 'decode_entities($_);')";
wcdbuser="$(/bin/cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbuser>.*</dbuser>" | perl -pe 's|^\<dbuser\>(.*)\</dbuser\>$|\1|')";
read -r dbhost dbport wcdbname <<< $(cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbconn>mysql:host=.*;port=.*;dbname=.*</dbconn>" | perl -pe 's|^\<dbconn\>mysql:host=(.*);port=(.*);dbname=(.*)\</dbconn\>$|\1 \2 \3|');
read -r accdbname accdbuser <<< $(${IWS_INSTALL_DIR}/tool.sh get system c_system_storage_accounts_odbcconnstring | perl -pe 's|^c_system_storage_accounts_odbcconnstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|');
read -r aspdbname aspdbuser <<< $(${IWS_INSTALL_DIR}/tool.sh get system c_as_challenge_connectionstring | perl -pe 's|^c_as_challenge_connectionstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|');
read -r grwdbname grwdbuser <<< $(${IWS_INSTALL_DIR}/tool.sh get system c_gw_connectionstring | perl -pe 's|^c_gw_connectionstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|');
read -r dcdbname dcdbuser <<< $(${IWS_INSTALL_DIR}/tool.sh get system c_accounts_global_accounts_directorycacheconnectionstring | perl -pe 's|^c_accounts_global_accounts_directorycacheconnectionstring: (.*);(.*);.*;.*;.*;.*$|\1 \2|');
easdbname="$(${IWS_INSTALL_DIR}/tool.sh get system c_activesync_dbconnection | ${IWS_INSTALL_DIR}/tool.sh get system c_activesync_dbconnection | egrep -o "mysql:host=.*;dbname=.*" | perl -pe 's|^mysql:host=.*;port=.*;dbname=(.*)$|\1|')";
easdbuser="$(${IWS_INSTALL_DIR}/tool.sh get system c_activesync_dbuser | perl -pe 's|^c_activesync_dbuser: (.*)$|\1|')";
easdbpass="$(${IWS_INSTALL_DIR}/tool.sh get system c_activesync_dbpass | perl -pe 's|^c_activesync_dbpass: (.*)$|\1|')";
if [ -z "${easdbpass}" ]; then easdbpass="easdbpass not discovered"; fi
if [[ "${dbpass}" =~ "^sqlite:.*" ]]; then dbpass="${easdbpass}"; fi
if [ -z "${dbpass}" ]; then dbpass="dbpass not discovered"; fi
if [ ! -z "${backupsrvhost}" ]; then dbhost="${backupsrvhost}"; fi # if we take backups from another host
if [ ! -z "${backupsrvport}" ]; then dbport="${backupsrvport}"; fi # than the one we connect to

# generate backup file names ( databases: accounts, antispam, groupware, directory cache, activesync, webclient cache; server config and calendar folder; domains and accounts csv export )
accdbbckfile="${backuppath}/bck_db_acc_${accdbname}`date +%Y%m%d-%H%M`.sql.gz";
aspdbbckfile="${backuppath}/bck_db_asp_${aspdbname}`date +%Y%m%d-%H%M`.sql.gz";
grwdbbckfile="${backuppath}/bck_db_grw_${grwdbname}`date +%Y%m%d-%H%M`.sql.gz";
dcdbbckfile="${backuppath}/bck_db_dc_${dcdbname}`date +%Y%m%d-%H%M`.sql.gz";
easdbbckfile="${backuppath}/bck_db_eas_${easdbname}`date +%Y%m%d-%H%M`.sql.gz";
wcdbbckfile="${backuppath}/bck_db_wc_${wcdbname}`date +%Y%m%d-%H%M`.sql.gz";
cnfbckfile="${backuppath}/bck_cnf`date +%Y%m%d-%H%M`.tgz";
calbckfile="${backuppath}/bck_cal`date +%Y%m%d-%H%M`.tgz";
logbckfile="${backuppath}/bck_log`date +%Y%m%d-%H%M`.tgz";
accbckfile="${backuppath}/bck_acc_backup`date +%Y%m%d-%H%M`.csv";
dombckfile="${backuppath}/bck_dom_backup`date +%Y%m%d-%H%M`.csv";

log "Starting DB backup."
/usr/bin/mysqldump --single-transaction -u ${accdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${accdbname} | gzip -c | cat > ${accdbbckfile} &
/usr/bin/mysqldump --single-transaction -u ${aspdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${aspdbname} | gzip -c | cat > ${aspdbbckfile} &
/usr/bin/mysqldump --single-transaction -u ${grwdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${grwdbname} | gzip -c | cat > ${grwdbbckfile} &
/usr/bin/mysqldump --single-transaction -u ${dcdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${dcdbname} | gzip -c | cat > ${dcdbbckfile} &
/usr/bin/mysqldump --single-transaction -u ${easdbuser} -p${easdbpass} -h${dbhost} -P ${dbport} ${easdbname} | gzip -c | cat > ${easdbbckfile} &
/usr/bin/mysqldump --single-transaction -u ${wcdbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${wcdbname} | gzip -c | cat > ${wcdbbckfile} &
log "Finished DB backup."
wait ${!}
log "Starting IW config backup."
/bin/tar -czf ${cnfbckfile} ${IWS_INSTALL_DIR}/config > /dev/null 2>&1
/bin/tar -czf ${calbckfile} ${IWS_INSTALL_DIR}/calendar > /dev/null 2>&1
/bin/find ${IWS_INSTALL_DIR}/logs -type f -mtime -1 -print0 | /bin/tar -czvf ${logbckfile} --null -T - > /dev/null 2>&1
${IWS_INSTALL_DIR}/tool.sh export account "*@*" u_backup > ${accbckfile}
${IWS_INSTALL_DIR}/tool.sh export domain "*" d_backup > ${dombckfile}
log "Finished IW config backup."
log "Checking all backupfiles are created."
for I in accdbbckfile aspdbbckfile grwdbbckfile dcdbbckfile easdbbckfile wcdbbckfile cnfbckfile calbckfile logbckfile accbckfile dombckfile;
  do
   sizeK=$(du -k ${I} | awk '{print $1}');
   if [[ $sizeK -le 1024 ]]
     then
      log "Backup file ${I} size lower than 1M ( ${sizeK}KB ), fail."; exit 1;
     else
      log "Backup file ${I} size ${sizeK}KB, OK"
   fi
  done
log "Cleaning old backups and logs."
/bin/find ${backuppath}/ -type f -name "bck_*" -mtime +${retention_days} -delete > /dev/null 2>&1
/bin/find ${scriptdir}/logs/ -type f -name "bck_*.log" -mtime +${retention_log_days} -delete > /dev/null 2>&1
log "All done."
exit 0
