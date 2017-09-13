# update curl
# centos 6
# yum -y install http://nervion.us.es/city-fan/yum-repo/rhel6/x86_64/city-fan.org-release-1-13.rhel6.noarch.rpm
# yum clean all
# yum install libcurl

# centos 7
# wget http://cbs.centos.org/kojifiles/packages/curl/7.43.0/1.el7/x86_64/curl-7.43.0-1.el7.x86_64.rpm
# wget http://cbs.centos.org/kojifiles/packages/curl/7.43.0/1.el7/x86_64/libcurl-7.43.0-1.el7.x86_64.rpm
# yum -y install libcurl-7.43.0-1.el7.x86_64.rpm curl-7.43.0-1.el7.x86_64.rpm


# test it from cmdline:
# curl --connect-timeout 10 -m 10 -s -k -o /dev/null -w "%{http_code}" https://127.0.0.1/webmail/
# should output 200
# /opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_AllowAdminPass 1
# /opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_DenyExport 0
# curl --connect-timeout 20 --silent --insecure --login-options AUTH=DIGEST-MD5 --url "imaps://127.0.0.1/" --user "$(/opt/icewarp/tool.sh export account "*@*" u_admin u_password | grep ",1," | head -1 | sed -r 's|^(.*),1,(.*),|\1:\2|')" --request "EXAMINE INBOX" | grep EXISTS
# /opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_AllowAdminPass 0
# /opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_DenyExport 1
# should output * <number> EXISTS

#!/bin/bash
# icewarp_watchdog.sh
# beranek@icewarp.cz
#
## variable :
ok_logfile="/opt/icewarp/watchdog_ok.log";
fail_logfile="/opt/icewarp/watchdog_fail.log";
debugdir="/opt/icewarp/debug";
icewarp_path="/opt/icewarp";
#
## function :
# return https response from 127.0.0.1/webmail/
http_check()
{
local https_response="null";
https_response=$(curl -s -k -o /dev/null -w "%{http_code}" -m 10 https://127.0.0.1/webmail/);
return "${https_response}";
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
local filename="`date "+%y-%m-%d_%H:%M:%S"`-${1}.core";
gcore -o "${debugdir}/${filename}" $(cat /opt/icewarp/var/${1}.pid)
if [ -f "${debugdir}/${filename}" ]; then
	echo "[$(date)] ${debugdir}/${filename}" >> ${fail_logfile} 2>&1	
	return "${debugdir}/${filename}";
		else
	echo "[$(date)] dump of ${1} failed" >> ${fail_logfile} 2>&1	
	return "dump of ${1} failed";
		fi
}
#
# determine if we want to run dump in case of fail or we want to just restart service based on current hour
dowedump()
{
declare -i hour=$(date +%H);
if (( 8 > 10#${hour} && 10#${hour} > 20 )); then
	echo "[$(date)] not between 8-20, we can dump .." >> ${fail_logfile} 2>&1	
	return 1
		else
	echo "[$(date)] between 8-20, we cannot dump .." >> ${fail_logfile} 2>&1
	return 0
}
# check for duplicate process running, if so, exit with error.
dowerun()
{
for pid in $(pgrep -f icewarp_watchdog.sh); do
    if [ ${pid} != $$ ]; then
        echo "[$(date)] : icewarp_watchdog.sh : Process is already running with PID ${pid}, exiting 1." >> ${ok_logfile} 2>&1
        exit 1
    fi
done
}
#
## MAIN ##
#
dowerun; # check for another icewarp_watchdog.sh running, if so, exit
response="null";
response="$(http_check)";
if [ "${response}" == "200" ]; then
	echo "[$(date)] HTTPs check_OK, response ${rensponse}" >> ${ok_logfile}
	exit 0
		else
			if [ "$(dowedump)" == 1 ]; then
				dump_php;
				dump_service "control";
				kill_php;
				restart_service "control";
				echo "[$(date)] php killed, dump done, control restarted" >> ${fail_logfile} 2>&1
					else
				kill_php;
				restart_service "control";
				echo "[$(date)] php killed, control restarted" >> ${fail_logfile} 2>&1
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
	restart_service "control";
	echo "[$(date)] second try, php killed, sessions removed, control restarted" >> ${fail_logfile} 2>&1	
fi
#
# todo : mount nfs, pack dumps and logs there, umount nfs
# todo : report to mail/zabbix
exit 0
