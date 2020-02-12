#!/bin/bash
monitoring="185.119.216.161"
storagepath1="/mnt/data"
storagepath2="/mnt/data_storage3"
logfile="/root/check_storage.log"
trap "zabbix_sender -z ${monitoring} -s "$(hostname)" -k StorageAlert -o 1 >> ${logfile} 2>&1" ERR
mypidfile=/var/run/check_storage.pid
start_services_on_recovery=0
trap "rm -f -- '${mypidfile}'" EXIT
echo $$ > "${mypidfile}"
for pid in $(pgrep -f check_storage.sh); do
	if [ ${pid} != $$ ]; then
	 echo "$(date) - Another check already running, killing PID ${pid}, sending alert to ${monitoring}, killing IceWarp services." >> ${logfile} 2>&1
	 zabbix_sender -z ${monitoring} -s "$(hostname)" -k StorageAlert -o 1 >> ${logfile} 2>&1
	 kill -9 ${pid}
#    	 /opt/icewarp/icewarpd.sh --stop all >> ${logfile}
	fi
done
if [[ ( -f "${storagepath1}"/storage.dat && -f "${storagepath2}"/storage.dat ) ]]
	then
	 zabbix_sender -z ${monitoring} -s "$(hostname)" -k StorageAlert -o 0 > /dev/null 2>&1
	 echo "$(date) - OK" >> ${logfile}
	 if [[ ${start_services_on_recovery} -eq 1 ]]
		then 
		echo "$(date) - Starting IW services after storage recovery." >> ${logfile}
		/opt/icewarp/icewarpd.sh --restart all >> ${logfile}
		start_services_on_recovery=0
	 fi
	else
	 zabbix_sender -z ${monitoring} -s "$(hostname)" -k StorageAlert -o 1 >> ${logfile} 2>&1
	 echo "$(date) - Storage FAIL, stopping IW services." >> ${logfile}
	 /opt/icewarp/icewarpd.sh --stop all >>	${logfile}
	 start_services_on_recovery=1
	fi
exit 0
