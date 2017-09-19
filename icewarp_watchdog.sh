#!/bin/bash
# icewarp_watchdog.sh
# beranek@icewarp.cz
#
## variable :
ok_logfile="/opt/icewarp/watchdog_ok.log";
fail_logfile="/opt/icewarp/watchdog_fail.log";
debugdir="/opt/icewarp/debug";
mkdir -p ${debugdir};
icewarp_path="/opt/icewarp";
#
## function :
# return https response from 127.0.0.1/webmail/
http_check()
{
local https_response="null";
https_response=$(curl -s -k -o /dev/null -w "%{http_code}" -m 10 https://127.0.0.1/webmail/);
echo "${https_response}";
}
#
# kill all php workers
kill_php()
{
pkill -9 -f php-fpm;
}
#
# do core dump of all php workers
dump_php()
{
for pid in $(pgrep php-fpm); do
	gcore -o "${debugdir}/`date "+%y-%m-%d_%H:%M:%S"`-php-fpm.core" $pid
done
}
#
# restart icewarp service
restart_service()
{
${icewarp_path}/icewarpd.sh --stop "${1}";
pkill -9 -f "${1}";
${icewarp_path}/icewarpd.sh --restart "${1}";
}
#
# do core dump of icewarp service
dump_service()
{
procpid=$(cat /opt/icewarp/var/${1}.pid)
local filename="`date "+%y-%m-%d_%H:%M:%S"`-${1}.core.${procpid}";
gcore -o "${debugdir}/${filename}" $(cat /opt/icewarp/var/${1}.pid)
if [ -f "${debugdir}/${filename}" ]; then
	echo "[$(date)] ${debugdir}/${filename}" >> ${fail_logfile}
	echo "${debugdir}/${filename}";
		else
	echo "[$(date)] dump of ${1} failed" >> ${fail_logfile}
	echo "dump of ${1} failed";
		fi
}
#
# determine if we want to run dump in case of fail or we want to just restart service based on current hour
dowedump()
{
declare -i hour=$(date +%H);
if (( 8 < 10#${hour} && 10#${hour} < 20 )); then
	echo "[$(date)] not between 8-20, we can dump .." >> ${fail_logfile}	
	echo "1"
		else
	echo "[$(date)] between 8-20, we cannot dump .." >> ${fail_logfile}
	echo "0"
fi
}
#
# check for duplicate process running, if so, exit with error.
dowerun()
{
for pid in $(pgrep -f icewarp_watchdog.sh); do
    if [ ${pid} != $$ ]; then
        echo "[$(date)] Process is already running with PID ${pid}, exiting 1." >> ${ok_logfile}
        exit 1
    fi
done
}
#
# pack generated dumps
packdmp()
{

}
#
# move dumps to repository
mvdmp()
{

}
#
# clean dumps
rmdumps()
{

}
## MAIN ##
#
dowerun; # check for another icewarp_watchdog.sh running, if so, exit
response="null";
response="$(http_check)";
if [ "${response}" == "200" ]; then
	echo "[$(date)] HTTPs check_OK, response ${response}" >> ${ok_logfile}
	exit 0
		else
			if [ "$(dowedump)" == 1 ]; then
				dump_php;
				dump_service "control";
				kill_php;
				restart_service "control";
				echo "[$(date)] php killed, dump done, control restarted" >> ${fail_logfile}
					else
				kill_php;
				restart_service "control";
				echo "[$(date)] php killed, control restarted" >> ${fail_logfile}
			fi	
fi
sleep 1;
response="null";
response="$(http_check)";
if [ "${response}" == "200" ]; then
	echo "[$(date)] HTTPs check_OK, response ${rensponse}" >> ${ok_logfile}
	exit 0
		else
	kill_php;
	rm -fv ${icewarp_path}/php/tmp/sess_* >> ${fail_logfile} 2>&1		
	restart_service "control" >> ${fail_logfile} 2>&1
	echo "[$(date)] second try, php killed, sessions removed, control restarted" >> ${fail_logfile}
fi
#
# todo : mount nfs, pack dumps and logs there, umount nfs
# todo : report to mail/zabbix
exit 0
