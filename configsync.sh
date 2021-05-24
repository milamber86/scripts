#!/bin/bash
#vars
script_backupdir="/root/configsync_backup";mkdir -p ${script_backupdir};
script_logdir="/root";
logfile_name="$(date --iso-8601=seconds)_configsync.log";
config_maindir="/mnt/config";
source_host_IP="172.16.4.191";
target_host_IP="172.16.5.191";

#func
log() {
echo "${1}: $(date --iso-8601=seconds) - ${2}" | tee -a "${script_logdir}/${logfile_name}"
}

logerr() {
log "Error" "${1}"
}

logdbg() {
log "Debug" "${1}"
}

installDeps() {
cd /root
yum -y install wget rsync
/usr/bin/rm -f /root/iwcfg*port.sh
wget https://raw.githubusercontent.com/milamber86/scripts/master/iwcfgexport.sh
wget https://raw.githubusercontent.com/milamber86/scripts/master/iwcfgimport.sh
chmod u+x iwcfg*port.sh
cd /opt/icewarp/scripts
wget https://raw.githubusercontent.com/milamber86/scripts/master/kpmon.sh
chmod u+x kpmon.sh
cd /opt/icewarp/html/webmail
wget https://raw.githubusercontent.com/milamber86/scripts/master/iwhealthcheck.php
chown icewarp:icewarp iwhealthcheck.php
cd /root
}

getSlaveNodes() {
local nodes="$(head -16 /opt/icewarp/path.dat | tail -1 | tr -d '\r')"
local arr_slave_nodes=(${nodes//;/ });
for I in "${arr_slave_nodes[@]}"; do
    echo "${I}"
  done
}

backupConfig() {
tar czf "${script_backupdir}/config_backup_$(date).tgz" "${config_maindir}"
if [[ $? -ne 0 ]]; then logerr "Config backup failed, exiting."; exit 1; fi;
}

prepareConfig() {
local res="$(rsync -a --delete --no-checksum root@${source_host_IP}:/${config_maindir}/ ${config_maindir}/)"
if [[ $? -ne 0 ]]; then logerr "Config rsync failed with err: ${res}, exiting."; exit 1;
else
local res="$(rsync -a --no-checksum root@${source_host_IP}:/opt/icewarp/path.dat /opt/icewarp/path.dat)"
if [[ $? -ne 0 ]]; then logerr "Config rsync failed with err: ${res}, exiting."; exit 1;
else
/root/iwcfgexport.sh
sed -i -r s'|172\.16\.4\.|172.16.5.|g' /root/cfgexport.cf
sed -i -r s'|172\.16\.4\.|172.16.5.|g' /root/cfgexport.cf.web
sed -i -r s'|172\.16\.4\.|172.16.5.|g' /opt/icewarp/path.dat
sed -i -r s'|172\.16\.4\.|172.16.5.|g' /opt/icewarp/php/php.ini
/root/iwcfgimport.sh
/usr/bin/cp -fv /opt/icewarp/path.dat /root/path.dat.tpl
CNT=11
for I in $(getSlaveNodes); do
    ((CNT=CNT+1))
    sed -i "4s|.*|$CNT|" /root/path.dat.tpl
    sed -i "14s|0|1|" /root/path.dat.tpl
    scp /root/path.dat.tpl root@${I}:/opt/icewarp/path.dat
    scp /opt/icewarp/php/php.ini root@${I}:/opt/icewarp/php/php.ini
    scp /opt/icewarp/license01.key root@${I}:/opt/icewarp/license01.key
  done
fi;fi;
}

zabbixConf() {
rsync -a --no-checksum root@${source_host_IP}:/etc/zabbix/ /etc/zabbix/
sed -i -r s'|172\.16\.4\.|172.16.5.|g' /etc/zabbix/zabbix_agentd.conf
}

#main
installDeps
backupConfig
prepareConfig
zabbixConf
exit 0

#alg
#- rsync <configpath>
#- rsync /opt/icewarp/path.dat, sed ???teamchatapi!!!
#- export config on target
#- sed config export on target and import back, update webdoc IP in IW API ( /opt/icewarp/tool.sh get system C_WebDocuments_Connection )
#- sed redis IP in php.ini
#- rsync /etc/zabbix/, sed zabbix_agentd.conf
#- ( fstab check on target? )

#todo
#- teamchatapi IPS?
#- webdoc IPS?
