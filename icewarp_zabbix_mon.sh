# launch IceWarp SNMP service
/opt/icewarp/tool.sh set system C_System_Adv_Ext_SNMPServer 1

# restart control
/opt/icewarp/icewarpd.sh --restart control

yum -y install zabbix-sender net-snmp-utils dos2unix

nano /root/icewarp_check.sh


#=====================
#!/bin/bash
# icewarp_check.sh
# Script sending values about icewarp server to zabbix trappers
# beranek@icewarp.cz

# Vars
# zabbix1.wdc.us.apptocloud.net
trapper1="130.185.182.250"
# zabbix01.ttc.cz.apptocloud.net
trapper2="185.119.216.161"
mail_outpath=$(cat /opt/icewarp/path.dat | grep -v retry | grep _outgoing | dos2unix)
[ -z "${mail_outpath}" ] && mail_outpath=$(/opt/icewarp/tool.sh get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_outgoing/|')
mail_inpath=$(cat /opt/icewarp/path.dat | grep -v retry | grep _incoming | dos2unix)
[ -z "${mail_inpath}" ] && mail_inpath=$(/opt/icewarp/tool.sh get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_incoming/|')

# Create PID file
mypidfile=/var/run/icewarp_check.sh.pid

# Ensure PID file is removed on program exit.
trap "rm -f -- '${mypidfile}'" EXIT

# Create a file with current PID to indicate that process is running.
echo $$ > "${mypidfile}"

# Check for duplicate process running, if so, exit with error.
for pid in $(pgrep -f icewarp_check.sh); do
    if [ ${pid} != $$ ]; then
        echo "[$(date)] : icewarp_check.sh : Process is already running with PID ${pid}, exiting 1." > /dev/null 2>&1
        exit 1
    fi
done

# Run checks 20 times with 1s pause
for I in `seq 1 20`;
        do
# icewarp smtp queues
smtp_outgoing_count=$(find ${mail_outpath} -maxdepth 1 -type f | wc -l)
zabbix_sender -z ${trapper1} -s "$(hostname)" -k smtp.outgoing.count -o ${smtp_outgoing_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k smtp.outgoing.count -o ${smtp_outgoing_count} > /dev/null 2>&1
smtp_outgoing_retry_count=$(find ${mail_outpath}retry/ -type f | wc -l)
zabbix_sender -z ${trapper1} -s "$(hostname)" -k smtp.outgoing.retry.count -o ${smtp_outgoing_retry_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k smtp.outgoing.retry.count -o ${smtp_outgoing_retry_count} > /dev/null 2>&1
smtp_outgoing_retry_prio_count=$(find ${mail_outpath}priority_* -type f | wc -l)
zabbix_sender -z ${trapper1} -s "$(hostname)" -k smtp.outgoing.retry.prio.count -o ${smtp_outgoing_retry_prio_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k smtp.outgoing.retry.prio.count -o ${smtp_outgoing_retry_prio_count} > /dev/null 2>&1
smtp_incoming_count=$(find ${mail_inpath} -maxdepth 1 -type f -name "*.dat" | wc -l)
zabbix_sender -z ${trapper1} -s "$(hostname)" -k smtp.incoming.count -o ${smtp_incoming_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k smtp.incoming.count -o ${smtp_incoming_count} > /dev/null 2>&1
smtp_incoming_mda_count=$(find ${mail_inpath} -maxdepth 1 -type f -name "*.tm$.tm$" | wc -l)
zabbix_sender -z ${trapper1} -s "$(hostname)" -k smtp.incoming.mda.count -o ${smtp_incoming_mda_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k smtp.incoming.mda.count -o ${smtp_incoming_mda_count} > /dev/null 2>&1
# icewarp services connections
conn_web_count=$(snmpget -v 1 -c private 127.0.0.1 1.3.6.1.4.1.23736.1.2.1.1.2.8.7 | sed -r 's|^.*INTEGER:\s(.*)$|\1|')
zabbix_sender -z ${trapper1} -s "$(hostname)" -k conn.web.count -o ${conn_web_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k conn.web.count -o ${conn_web_count} > /dev/null 2>&1
conn_smtp_count=$(snmpget -v 1 -c private 127.0.0.1 1.3.6.1.4.1.23736.1.2.1.1.2.8.1 | sed -r 's|^.*INTEGER:\s(.*)$|\1|')
zabbix_sender -z ${trapper1} -s "$(hostname)" -k conn.smtp.count -o ${conn_smtp_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k conn.smtp.count -o ${conn_smtp_count} > /dev/null 2>&1
conn_pop3_count=$(snmpget -v 1 -c private 127.0.0.1 1.3.6.1.4.1.23736.1.2.1.1.2.8.2 | sed -r 's|^.*INTEGER:\s(.*)$|\1|')
zabbix_sender -z ${trapper1} -s "$(hostname)" -k conn.pop3.count -o ${conn_pop3_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k conn.pop3.count -o ${conn_pop3_count} > /dev/null 2>&1
conn_imap_count=$(snmpget -v 1 -c private 127.0.0.1 1.3.6.1.4.1.23736.1.2.1.1.2.8.3 | sed -r 's|^.*INTEGER:\s(.*)$|\1|')
zabbix_sender -z ${trapper1} -s "$(hostname)" -k conn.imap.count -o ${conn_imap_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k conn.imap.count -o ${conn_imap_count} > /dev/null 2>&1
conn_im_count_server=$(snmpget -v 1 -c private 127.0.0.1 1.3.6.1.4.1.23736.1.2.1.1.2.8.4 | sed -r 's|^.*INTEGER:\s(.*)$|\1|')
conn_im_count_client=$(snmpget -v 1 -c private 127.0.0.1 1.3.6.1.4.1.23736.1.2.1.1.2.10.4 | sed -r 's|^.*INTEGER:\s(.*)$|\1|')
conn_im_count=$((${conn_im_count_server} + ${conn_im_count_client}))
zabbix_sender -z ${trapper1} -s "$(hostname)" -k conn.im.count -o ${conn_im_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k conn.im.count -o ${conn_im_count} > /dev/null 2>&1
conn_gw_count=$(snmpget -v 1 -c private 127.0.0.1 1.3.6.1.4.1.23736.1.2.1.1.2.8.5 | sed -r 's|^.*INTEGER:\s(.*)$|\1|')
zabbix_sender -z ${trapper1} -s "$(hostname)" -k conn.gw.count -o ${conn_gw_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k conn.gw.count -o ${conn_gw_count} > /dev/null 2>&1
conn_ftp_count=$(snmpget -v 1 -c private 127.0.0.1 1.3.6.1.4.1.23736.1.2.1.1.2.8.6 | sed -r 's|^.*INTEGER:\s(.*)$|\1|')
zabbix_sender -z ${trapper1} -s "$(hostname)" -k conn.ftp.count -o ${conn_ftp_count} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k conn.tfp.count -o ${conn_ftp_count} > /dev/null 2>&1
sleep 2
	done
exit 0
#=====================



chmod u+x /root/icewarp_check.sh
export EDITOR=nano
crontab -e

# run IceWarp zabbix sender
* * * * * /root/icewarp_check.sh





