nano /root/kvm_cpu_check.sh


#=====================
#!/bin/bash
# kvm_cpu_check.sh
# Script sending values about kvm domains to zabbix trappers
# beranek@icewarp.cz

# Vars
# zabbix1.wdc.us.apptocloud.net
trapper1="82.113.48.145"
# zabbix01.ttc.cz.apptocloud.net
trapper2="185.119.216.161"

# Create PID file
mypidfile=/var/run/kvm_cpu_check.sh.pid

# Ensure PID file is removed on program exit.
trap "rm -f -- '${mypidfile}'" EXIT

# Create a file with current PID to indicate that process is running.
echo $$ > "${mypidfile}"

# Check for duplicate process running, if so, exit with error.
for pid in $(pgrep -f kvm_cpu_check.sh); do
    if [ ${pid} != $$ ]; then
        echo "[$(date)] : kvm_cpu_check.sh : Process is already running with PID ${pid}, exiting 1." > /dev/null 2>&1
        exit 1
    fi
done

for domain in $(/usr/local/bin/zabbix-kvm-res.py --resource domain --action list | grep virtual | sed -r 's|^.*virtual(.*)"$|virtual\1|');
	do 
	zabbix_sender -z ${trapper1} -s "$(hostname)" -k domain.cpu.all.time[${domain}] -o $(virsh domstats ${domain} --cpu-total | grep cpu.time | sed -r 's|^.*cpu\.time=(.*)$|\1|');
	zabbix_sender -z ${trapper1} -s "$(hostname)" -k domain.cpu.sys.time[${domain}] -o $(virsh domstats ${domain} --cpu-total | grep cpu.system | sed -r 's|^.*cpu\.system=(.*)$|\1|');
	zabbix_sender -z ${trapper1} -s "$(hostname)" -k domain.cpu.usr.time[${domain}] -o $(virsh domstats ${domain} --cpu-total | grep cpu.user | sed -r 's|^.*cpu\.user=(.*)$|\1|');
	zabbix_sender -z ${trapper2} -s "$(hostname)" -k domain.cpu.all.time[${domain}] -o $(virsh domstats ${domain} --cpu-total | grep cpu.time | sed -r 's|^.*cpu\.time=(.*)$|\1|');
	zabbix_sender -z ${trapper2} -s "$(hostname)" -k domain.cpu.sys.time[${domain}] -o $(virsh domstats ${domain} --cpu-total | grep cpu.system | sed -r 's|^.*cpu\.system=(.*)$|\1|');
	zabbix_sender -z ${trapper2} -s "$(hostname)" -k domain.cpu.usr.time[${domain}] -o $(virsh domstats ${domain} --cpu-total | grep cpu.user | sed -r 's|^.*cpu\.user=(.*)$|\1|');
	done
exit 0
#=====================



chmod u+x /root/kvm_cpu_check.sh
export EDITOR=nano
crontab -e

# run IceWarp zabbix sender
* * * * * /root/kvm_cpu_check.sh





