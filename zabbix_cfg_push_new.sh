# pusher.sh
# Tool to push files and ssh commands to zabbix hosts
# beranek@icewarp.cz

# add to .ssh/config
# Host *
#    StrictHostKeyChecking no
#    ConnectTimeout=1
#    ConnectionAttempts=1
#    PasswordAuthentication no
#    UserKnownHostsFile=/dev/null

#!/bin/bash

# Vars
logfile="/root/pusher.log"
sshuser="root"
scpuser="root"
dbuser="root"
dbpass="merak1"
groupname="apptocloud_cust_linux"
identity=""

scp1from="/root/crontab.tpl"
scp1to="/root/crontab.tpl"
scp2from=""
scp2to=""
scp3from=""
scp3to=""

ssh1="cat /root/crontab.tpl >> /var/spool/cron/root"
ssh2=""
ssh3=""
ssh4=""
ssh5=""

# Init - load problematic vars into array
arr[0]=${identity}
arr[1]=${ssh1}
arr[2]=${ssh2}
arr[3]=${ssh3}
arr[4]=${ssh4}
arr[5]=${ssh5}
arr[6]=${scp1from}
arr[7]=${scp1to}
arr[8]=${scp2from}
arr[9]=${scp2to}
arr[10]=${scp3from}
arr[11]=${scp3to}

# Execute the commands on all zabbix hosts
for I in $(/usr/bin/mysql -u ${dbuser} -p${dbpass} --execute="use zabbix;SELECT interface.ip FROM hosts JOIN hosts_groups ON hosts_groups.hostid = hosts.hostid JOIN groups ON groups.groupid = hosts_groups.groupid JOIN interface ON interface.hostid = hosts.hostid WHERE hosts.status = 0 AND groups.name like '%${groupname}%' ORDER BY hosts.name;" | grep -v "ip" | grep -v "127.0.0.1");
                do
        host[0]=${I}
		echo "[$(date)] : pusher.sh : running batch on host ${I}" >> ${logfile} 2>&1 
		# Execute scp commands
		[ -n "${arr[0]}" ] && ssh-copy-id -i "${arr[0]}" ${sshuser}@${host[0]} >> ${logfile} 2>&1 	
		[ -n "${arr[6]}" ] && [ -n "${arr[7]}" ] && scp "${arr[6]}" "${scpuser}@${host[0]}:"${arr[7]}"" >> ${logfile} 2>&1
		[ -n "${arr[8]}" ] && [ -n "${arr[9]}" ] && scp "${arr[8]}" "${scpuser}@${host[0]}:"${arr[9]}"" >> ${logfile} 2>&1
		[ -n "${arr[10]}" ] && [ -n "${arr[11]}" ] && scp "${arr[10]}" "${scpuser}@${host[0]}:"${arr[11]}"" >> ${logfile} 2>&1
   		# Execute ssh commands
		[ -n "${arr[1]}" ] && ssh ${sshuser}@${host[0]} "${arr[1]}" >> ${logfile} 2>&1
		[ -n "${arr[2]}" ] && ssh ${sshuser}@${host[0]} "${arr[2]}" >> ${logfile} 2>&1
		[ -n "${arr[3]}" ] && ssh ${sshuser}@${host[0]} "${arr[3]}" >> ${logfile} 2>&1
		[ -n "${arr[4]}" ] && ssh ${sshuser}@${host[0]} "${arr[4]}" >> ${logfile} 2>&1
		[ -n "${arr[5]}" ] && ssh ${sshuser}@${host[0]} "${arr[5]}" >> ${logfile} 2>&1
		echo "[$(date)] : pusher.sh : finished batch on host ${I}" >> ${logfile} 2>&1
                done
exit 0
