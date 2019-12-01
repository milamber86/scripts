#!/bin/bash
monitoring="<zabbix_IP>"
storagepath="<monitored_fullpath_without_trailing_slash>"
logfile="logfile_fullpath"
trap "zabbix_sender -z ${monitoring} -s "$(hostname)" -k StorageAlert -o 1 > ${logfile} 2>&1" ERR
mypidfile="<pidfile_fullpath>"
trap "rm -f -- '${mypidfile}'" EXIT
echo $$ > "${mypidfile}"
for pid in $(pgrep -f check_storage.sh); do
	if [ ${pid} != $$ ]; then
	 echo "$(date) - Another check already running, killing PID ${pid}, sending alert to ${monitoring}, killing IceWarp services." > ${logfile} 2>&1
	 kill -9 ${pid}
#    	 /opt/icewarp/icewarpd.sh --stop all >> ${logfile}
	fi
done
if [ -f "${storagepath}"/storage.dat ]
	then
	 zabbix_sender -z ${monitoring} -s "$(hostname)" -k StorageAlert -o 0 > /dev/null 2>&1
	 echo "$(date) - OK" >> ${logfile}
	else
	 zabbix_sender -z ${monitoring} -s "$(hostname)" -k StorageAlert -o 1 > ${logfile} 2>&1
	 /opt/icewarp/icewarpd.sh --stop all >>	${logfile}
	 echo "$(date) - FAIL" >> ${logfile}
         exit 1
	fi
exit 0
