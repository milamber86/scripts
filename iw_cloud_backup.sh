#!/bin/bash
# ver. 20201118_02
source /etc/icewarp/icewarp.conf
maildirpath="$(${IWS_INSTALL_DIR}/tool.sh get system C_System_Storage_Dir_MailPath | grep -P '(?<=: ).*(?=/mail/)' -o)"
backuppath="${maildirpath}/backup"
scriptdir="$(cd $(dirname $0) && pwd)"
mkdir -p ${maildirpath}
mkdir -p ${backuppath}
mkdir -p ${scriptdir}/logs
#dbport=4008;
backupsrvhost="${1}" # if we take backups from another host
backupsrvport="${2}" # than the one in IW connection strings
cloudplan=$(${IWS_INSTALL_DIR}/tool.sh get system c_license_xml | grep -P '(?<=<licensetype>).*(?=</licensetype>)' -o -m 1)
logdate="$(date +%Y%m%d)"
logfile="${scriptdir}/logs/bck_${logdate}.log"
retention_days=3;
retention_log_days=30;


function log()
{
  echo $(date +%H:%M:%S) $1 >> ${logfile}
}

function die_error() # ( die with error, log failure to /opt/icewarp/var/iwbackup.mon )
{
echo "FAIL" > /opt/icewarp/var/iwbackupstatus.mon
exit 1
}

function preflight_check() # ( check src/dst paths,src database connection, cloudplan, util test )
{
# check src storage
fstabtest=$(/usr/bin/cat /etc/fstab | grep -o "${maildirpath}")
mounttest=$(/usr/bin/mount | grep -o "${maildirpath}" | tail -1)
if [[ "$maildirpath" == "$fstabtest" ]]
then
  log "Storage is a mountpoint - checking."
  if [[ "$maildirpath" != "$mounttest" ]]
    then
    log "Storage not mounted. Aborting."
    die_error;
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
   die_error;
  else
   log "Backup destination OK";
fi

# check cloud plan
#if [ -z "$cloudplan" ] || [ "$cloudplan" != "cloud" ]
#then
#  log "Aborting - not Cloud licence."
#  die_error;
#fi

# util test
utiltest="$(/usr/bin/find /usr/lib64 -type f -name "Entities.pm")"
if [[ -z "${utiltest}" ]]
  then
  log "Installing Entities.pm"
  /usr/bin/yum -y install epel-release
  /usr/bin/yum -y install perl-HTML-Encoding.noarch
fi
}

function discover_dbnames() # ( 1: dbtype -> dbname )
{
case ${1} in
acc) local accdbname="$(${IWS_INSTALL_DIR}/tool.sh get system c_system_storage_accounts_odbcconnstring | perl -pe 's|^c_system_storage_accounts_odbcconnstring: (.*);(.*);.*;.*;.*;.*$|\1|')";
echo "${accdbname}"
;;
asp) local aspdbname="$(${IWS_INSTALL_DIR}/tool.sh get system c_as_challenge_connectionstring | egrep -v '^mysql:' | perl -pe 's|^c_as_challenge_connectionstring: (.*);.*;.*;.*;.*;.*$|\1|')";
echo "${aspdbname}"
;;
grw) local grwdbname="$(${IWS_INSTALL_DIR}/tool.sh get system c_gw_connectionstring | perl -pe 's|^c_gw_connectionstring: (.*);(.*);.*;.*;.*;.*$|\1|')";
echo "${grwdbname}"
;;
dc) local dcdbname="$(${IWS_INSTALL_DIR}/tool.sh get system c_accounts_global_accounts_directorycacheconnectionstring | perl -pe 's|^c_accounts_global_accounts_directorycacheconnectionstring: (.*);(.*);.*;.*;.*;.*$|\1|')";
echo "${dcdbname}"
;;
eas) local easdbname="$(${IWS_INSTALL_DIR}/tool.sh get system c_activesync_dbconnection | ${IWS_INSTALL_DIR}/tool.sh get system c_activesync_dbconnection | egrep -o "mysql:host=.*;dbname=.*" | perl -pe 's|^mysql:host=.*;port=.*;dbname=(.*)$|\1|')";
echo "${easdbname}"
;;
wc) local wcdbname="$(cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbconn>mysql:host=.*;port=.*;dbname=.*</dbconn>" | perl -pe 's|^\<dbconn\>mysql:host=(.*);port=(.*);dbname=(.*)\</dbconn\>$|\3|')";
echo "${wcdbname}"
esac
}

function discover_creds() # ( -> username password )
{
local dbuser="$(/usr/bin/cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbuser>.*</dbuser>" | perl -pe 's|^\<dbuser\>(.*)\</dbuser\>$|\1|')";
local dbpass="$(/usr/bin/cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbpass>.*</dbpass>" | perl -pe 's|^\<dbpass\>(.*)\</dbpass\>$|\1|' | perl -MHTML::Entities -pe 'decode_entities($_);')";
echo "${dbuser} ${dbpass}"
}

function discover_dbhost() # ( -> db connection IP/hostname )
{
local dbhost="$(/usr/bin/cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbconn>mysql:host=.*;port=.*;dbname=.*</dbconn>" | perl -pe 's|^\<dbconn\>mysql:host=(.*);port=(.*);dbname=(.*)\</dbconn\>$|\1|')";
echo "${dbhost}"
}

function discover_dbport() # ( -> db connection port )
{
local dbport="$(/usr/bin/cat ${IWS_INSTALL_DIR}/config/_webmail/server.xml | egrep -o "<dbconn>mysql:host=.*;port=.*;dbname=.*</dbconn>" | perl -pe 's|^\<dbconn\>mysql:host=(.*);port=(.*);dbname=(.*)\</dbconn\>$|\2|')";
echo "${dbport}"
}


# MAIN

trap 'echo "FAIL" > /opt/icewarp/var/iwbackupstatus.mon' SIGINT SIGTERM

log "Starting backup."
preflight_check;
log "Reading DB access data."
read -r dbuser dbpass <<< "$(discover_creds)";
dbhost="$(discover_dbhost)";
dbport="$(discover_dbport)";
accdbname="$(discover_dbnames "acc")";
aspdbname="$(discover_dbnames "asp")";
grwdbname="$(discover_dbnames "grw")";
dcdbname="$(discover_dbnames "dc")";
easdbname="$(discover_dbnames "eas")";
wcdbname="$(discover_dbnames "wc")";

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
/usr/bin/mysqldump --single-transaction -u ${dbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${accdbname} | gzip -c | cat > ${accdbbckfile}
/usr/bin/mysqldump --single-transaction -u ${dbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${aspdbname} | gzip -c | cat > ${aspdbbckfile}
/usr/bin/mysqldump --single-transaction -u ${dbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${grwdbname} | gzip -c | cat > ${grwdbbckfile}
/usr/bin/mysqldump --single-transaction -u ${dbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${dcdbname} | gzip -c | cat > ${dcdbbckfile}
/usr/bin/mysqldump --single-transaction -u ${dbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${easdbname} | gzip -c | cat > ${easdbbckfile}
/usr/bin/mysqldump --single-transaction -u ${dbuser} -p${dbpass} -h${dbhost} -P ${dbport} ${wcdbname} | gzip -c | cat > ${wcdbbckfile}
log "Finished DB backup."
log "Starting IW config backup."
/usr/bin/tar -czf ${cnfbckfile} ${IWS_INSTALL_DIR}/config > /dev/null 2>&1
/usr/bin/tar -czf ${calbckfile} ${IWS_INSTALL_DIR}/calendar > /dev/null 2>&1
/usr/bin/find ${IWS_INSTALL_DIR}/logs -type f -mtime -1 -print0 | /usr/bin/tar -czvf ${logbckfile} --null -T - > /dev/null 2>&1
${IWS_INSTALL_DIR}/tool.sh export account "*@*" u_backup > ${accbckfile}
${IWS_INSTALL_DIR}/tool.sh export domain "*" d_backup > ${dombckfile}
log "Finished IW config backup."
log "Checking all backupfiles are created."
for I in accdbbckfile aspdbbckfile grwdbbckfile dcdbbckfile easdbbckfile wcdbbckfile cnfbckfile calbckfile logbckfile accbckfile dombckfile;
  do
    eval ref=\$${I};
    if [ "${I}" = "accbckfile" ] || [ "${I}" = "dombckfile" ];
      then
        lines=$(wc -l ${ref} | awk '{print $1}')
        if [[ ${lines} -lt 2 ]]
          then
            log "Backup file ${I} shorter than 2 lines ( ${lines} lines ), fail."; die_error;
          else
            log "Backup file ${I} lenght ${lines} lines, OK"
        fi
      else
        sizeK=$(du -k ${ref} | awk '{print $1}');
        if [[ ${sizeK} -le 8 ]]
          then
            log "Backup file ${I} size lower than 1M ( ${sizeK}KB ), fail."; die_error;
          else
            log "Backup file ${I} size ${sizeK}KB, OK"
        fi
    fi
  done
log "Cleaning old backups and logs."
/usr/bin/find ${backuppath}/ -type f -name "bck_*" -mtime +${retention_days} -delete > /dev/null 2>&1
/usr/bin/find ${scriptdir}/logs/ -type f -name "bck_*.log" -mtime +${retention_log_days} -delete > /dev/null 2>&1
log "All done."
echo "OK" > /opt/icewarp/var/iwbackupstatus.mon
exit 0
