#!/bin/bash
# vars
PATH=/bin:/sbin:/usr/bin:/usr/sbin
monitoring="zabbix_IP"
trap "zabbix_sender -z ${monitoring} -s "$(hostname)" -k SlaveBackupAlert -o 1 > /dev/null 2>&1" ERR
backuppath="/mnt/data/dbbackup/"
dbuser="user"
dbpass="pass"
TMPFILE="/tmp/tmp"
mkdir -p ${backuppath}
# checks
MasterIP="$(echo "show slave status\G" | mysql | grep "Master_Host:" | awk '{print $2}')"
MasterPort="$(echo "show slave status\G" | mysql | grep "Master_Port:" | awk '{print $2}')"
SlaveIO="$(echo "show slave status\G" | mysql | grep "Slave_IO_Running:" | awk '{print $2}')"
SlaveSQL="$(echo "show slave status\G" | mysql | grep "Slave_SQL_Running:" | awk '{print $2}')"
declare -i SlaveBehind=$(echo "show slave status\G" | mysql | grep "Seconds_Behind_Master:" | awk '{print $2}');
# run backup
if [[ ( "${SlaveIO}" = "Yes" && "${SlaveSQL}" = "Yes" && "${SlaveBehind}" -le 120 ) ]]
# if slave ok, take local backup and reset alert on monitoring
	then
	  zabbix_sender -z ${monitoring} -s "$(hostname)" -k SlaveLagAlert -o 0 > /dev/null 2>&1
	  innobackupex --no-lock --user=${dbuser} --password=${dbpass} --stream=tar /tmp/ | gzip -c | cat > ${backuppath}/bck_mysql`date +%Y%m%d-%H%M`.tar.gz 2> ${TMPFILE}
# if slave Nok, take backup from the master and raise alert on monitoring
	else
	  zabbix_sender -z ${monitoring} -s "$(hostname)" -k SlaveLagAlert -o 1 > /dev/null 2>&1
	  ssh root@${MasterIP} "innobackupex --no-lock --user=${dbuser} --password=${dbpass} --stream=tar /tmp/ | gzip -c | cat" > ${backuppath}/bck_mysql`date +%Y%m%d-%H%M`.tar.gz 2> ${TMPFILE}
fi
# send backup result to monitoring
	  result="$(grep -o " completed OK" ${TMPFILE})";
          rm -f ${TMPFILE};
if [[ "${result}" = " completed OK" ]]
	then
# if last backup OK, remove older backups
	  find ${backuppath}/ -type f -name "bck_*" -mtime +8 -delete > /dev/null 2>&1
	  zabbix_sender -z ${monitoring} -s "$(hostname)" -k SlaveBackupAlert -o 0 > /dev/null 2>&1
	  exit 0
	else
	  zabbix_sender -z ${monitoring} -s "$(hostname)" -k SlaveBackupAlert -o 1 > /dev/null 2>&1
	  exit 1
fi
