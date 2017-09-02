nano /root/galera_check.sh

#=====================
#!/bin/bash
# galera_check.sh
# Script sending values about Galera nodes to zabbix trappers
# beranek@icewarp.cz

# Vars
trapper1="82.113.48.145"
trapper2="185.119.216.161"
mysql_user="root"
mysql_pass="hd35s6g4fe"
# Create PID file
mypidfile=/var/run/galera_check.sh.pid

# Ensure PID file is removed on program exit.
trap "rm -f -- '${mypidfile}'" EXIT

# Create a file with current PID to indicate that process is running.
echo $$ > "${mypidfile}"

# Check for duplicate process running, if so, exit with error.
for pid in $(pgrep -f galera_check.sh); do
    if [ ${pid} != $$ ]; then
        echo "[$(date)] : galera_check.sh : Process is already running with PID ${pid}, exiting 1." > /dev/null 2>&1
        exit 1
    fi
done

# Run checks 10 times with 5s pause
for I in `seq 1 10`;
        do
wsrep_last_committed=$(/usr/bin/mysql -u ${mysql_user} -p${mysql_pass} --execute="SHOW STATUS LIKE 'wsrep_last_committed'\G" | grep "Value:" | sed -r 's|^.*Value:\s(.*)|\1|' | tail -c 5)
zabbix_sender -z ${trapper1} -s "$(hostname)" -k wsrep.last.committed -o ${wsrep_last_committed} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k wsrep.last.committed -o ${wsrep_last_committed} > /dev/null 2>&1
wsrep_cluster_size=$(/usr/bin/mysql -u ${mysql_user} -p${mysql_pass} --execute="SHOW STATUS LIKE 'wsrep_cluster_size'\G" | grep "Value:" | sed -r 's|^.*Value:\s(.*)|\1|')
zabbix_sender -z ${trapper1} -s "$(hostname)" -k wsrep.cluster.size -o ${wsrep_cluster_size} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k wsrep.cluster.size -o ${wsrep_cluster_size} > /dev/null 2>&1
wsrep_flow_control_paused=$(/usr/bin/mysql -u ${mysql_user} -p${mysql_pass} --execute="SHOW STATUS LIKE 'wsrep_flow_control_paused'\G" | grep "Value:" | sed -r 's|^.*Value:\s(.*)|\1|')
zabbix_sender -z ${trapper1} -s "$(hostname)" -k wsrep.flow.control.paused -o ${wsrep_cluster_size} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k wsrep.flow.control.paused -o ${wsrep_cluster_size} > /dev/null 2>&1
wsrep_flow_control_sent=$(/usr/bin/mysql -u ${mysql_user} -p${mysql_pass} --execute="SHOW STATUS LIKE 'wsrep_flow_control_sent'\G" | grep "Value:" | sed -r 's|^.*Value:\s(.*)|\1|')
zabbix_sender -z ${trapper1} -s "$(hostname)" -k wsrep.flow.control.sent -o ${wsrep_cluster_size} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k wsrep.flow.control.sent -o ${wsrep_cluster_size} > /dev/null 2>&1
wsrep_flow_control_recv=$(/usr/bin/mysql -u ${mysql_user} -p${mysql_pass} --execute="SHOW STATUS LIKE 'wsrep_flow_control_recv'\G" | grep "Value:" | sed -r 's|^.*Value:\s(.*)|\1|')
zabbix_sender -z ${trapper1} -s "$(hostname)" -k wsrep.flow.control.recv -o ${wsrep_cluster_size} > /dev/null 2>&1
zabbix_sender -z ${trapper2} -s "$(hostname)" -k wsrep.flow.control.recv -o ${wsrep_cluster_size} > /dev/null 2>&1
sleep 4
	done
exit 0
#=====================



chmod u+x /root/galera_check.sh
export EDITOR=nano
crontab -e

* * * * * /root/galera_check.sh



# Add zabbix Galera template to all db node hosts in zabbix

