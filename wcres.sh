# update curl
# centos 6
yum -y install http://nervion.us.es/city-fan/yum-repo/rhel6/x86_64/city-fan.org-release-1-13.rhel6.noarch.rpm
yum clean all
yum install libcurl

# centos 7
wget http://cbs.centos.org/kojifiles/packages/curl/7.43.0/1.el7/x86_64/curl-7.43.0-1.el7.x86_64.rpm
wget http://cbs.centos.org/kojifiles/packages/curl/7.43.0/1.el7/x86_64/libcurl-7.43.0-1.el7.x86_64.rpm
yum -y install libcurl-7.43.0-1.el7.x86_64.rpm curl-7.43.0-1.el7.x86_64.rpm


# test it from cmdline:
curl --connect-timeout 10 -m 10 -s -k -o /dev/null -w "%{http_code}" https://127.0.0.1/webmail/
# should output 200
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_AllowAdminPass 1
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_DenyExport 0
curl --connect-timeout 20 --silent --insecure --login-options AUTH=DIGEST-MD5 --url "imaps://127.0.0.1/" --user "$(/opt/icewarp/tool.sh export account "*@*" u_admin u_password | grep ",1," | head -1 | sed -r 's|^(.*),1,(.*),|\1:\2|')" --request "EXAMINE INBOX" | grep EXISTS
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_AllowAdminPass 0
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_DenyExport 1
# should output * <number> EXISTS

nano /opt/icewarp/wcres.sh


#=====================
#!/bin/bash
# wcres.sh
# Script to detect IceWarp imaps returns number of messages in first admin's inbox folder and https result is other than 200 on http://127.0.0.1/webmail/ and restarts services.
# beranek@icewarp.cz

# Vars
ok_logfile=/opt/icewarp/wcres.out
fail_logfile=/opt/icewarp/wcres.out.fail
debugdir=/mnt/data/debug
# Create PID file
mypidfile=/var/run/wcres.sh.pid
# Ensure PID file is removed on program exit.
trap "rm -f -- '${mypidfile}'" EXIT

# Create a file with current PID to indicate that process is running.
echo $$ > "${mypidfile}"

# Check for duplicate process running, if so, exit with error.
for pid in $(pgrep -f wcres.sh); do
    if [ ${pid} != $$ ]; then
        echo "[$(date)] : wcres.sh : Process is already running with PID ${pid}, exiting 1." >> /opt/icewarp/httpchk.out 2>&1
        exit 1
    fi
done

# Check for IceWarp installer  or restart running, if so, exit with error.
if [[ $(ps -ef | grep "install.sh" | grep -v grep | wc -l) != 0 ]]; then
                echo "[$(date)] : wcres.sh : IceWarp install.sh detected, exiting 1." >> /opt/icewarp/httpchk.out 2>&1
                exit 1
        fi

if [[ $(ps -ef | grep "icewarpd.sh" | grep -v grep | wc -l) != 0 ]]; then
                echo "[$(date)] : wcres.sh : IceWarp icewarpd.sh detected, exiting 1." >> /opt/icewarp/httpchk.out 2>&1
                exit 1
        fi

# Check if imap is running and able to examine inbox folder of first admin's account ?
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_AllowAdminPass 1
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_DenyExport 0
imap_credentials=$(/opt/icewarp/tool.sh export account "*@*" u_admin u_password | grep ",1," | head -1 | sed -r 's|^(.*),1,(.*),|\1:\2|')
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_AllowAdminPass 0
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_DenyExport 1
imaps_response=$(curl --connect-timeout 20 --silent --insecure --login-options AUTH=DIGEST-MD5 --url "imaps://127.0.0.1/" --user "${imap_credentials}" --request "EXAMINE INBOX" | grep EXISTS)
if grep -q "EXISTS" <<<"${imaps_response}"
							   then
						echo "[$(date)] IMAPs check_OK, response ${imaps_response}" > ${ok_logfile}
							   else
						echo "[$(date)] IMAPs check_failed with ${imaps_response} response code, restarting IMAP service, wait 30s." >> ${fail_logfile} 2>&1
                        echo "[$(date)] trying to dump IMAP service to ${debugdir}" >> ${fail_logfile} 2>&1
                        mkdir -p ${debugdir}
                        gcore -o "${debugdir}/`date "+%y-%m-%d_%H:%M:%S"`-pop3.core" $(cat /opt/icewarp/var/pop3.pid)
                        killall -9 pop3
                        /opt/icewarp/icewarpd.sh --restart pop3 >> ${fail_logfile} 2>&1
                        sleep 30
fi

# Check if https on localhost respondes with 200 OK response code ?
https_response=$(curl -s -k -o /dev/null -w "%{http_code}" https://127.0.0.1/webmail/);
if [ "200" == "${https_response}" ]; then
                        echo "[$(date)] HTTPs check_OK, response 200 ${https_rensponse}" >> ${ok_logfile}
                               else
						echo "[$(date)] HTTPs check_failed with ${https_response} response code, restarting IceWarp services, wait 30s." >> ${fail_logfile} 2>&1
						echo "[$(date)] dumping php workers and control service" >> ${fail_logfile} 2>&1
						mkdir -p ${debugdir}
						for pid in $(pgrep php-fpm)
						do gcore -o "${debugdir}/`date "+%y-%m-%d_%H:%M:%S"`-php-fpm.core" $pid 
						done
						gcore -o "${debugdir}/`date "+%y-%m-%d_%H:%M:%S"`-control.core" $(cat /opt/icewarp/var/control.pid)
						echo "[$(date)] deleting php sessions" >> ${fail_logfile} 2>&1
						rm -rfv /opt/icewarp/php/tmp/sess_* | wc -l >> ${fail_logfile} 2>&1
						echo "[$(date)] killing IceWarp services" >> ${fail_logfile} 2>&1
						killall -9 control
						killall -9 php-fpm
						killall -9 pop3
						killall -9 cal
						killall -9 smtp
						echo "[$(date)] restarting IceWarp services" >> ${fail_logfile} 2>&1
						/opt/icewarp/icewarpd.sh --restart all >> ${fail_logfile} 2>&1
                        sleep 30
fi
exit 0
#=====================


chmod u+x /opt/icewarp/wcres.sh
export EDITOR=nano
crontab -e

# run IceWarp imaps, https watchdog script.
* * * * * /opt/icewarp/wcres.sh

