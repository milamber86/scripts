#!/usr/local/bin/bash
# Written by beranek@icewarp.cz
#
# This script will send zfs iostat and nfsstat output to your Zabbix server at a given interval.
# Put this to run at startup and/or in crontab.
# You will need to set the check up as "trapper" in Zabbix.
# Trapped keys are:
# nfs.stat.nfsd.getattr
# nfs.stat.nfsd.setattr
# nfs.stat.nfsd.lookup
# nfs.stat.nfsd.readlink
# nfs.stat.nfsd.read
# nfs.stat.nfsd.write
# nfs.stat.nfsd.create
# nfs.stat.nfsd.remove
# nfs.stat.nfsd.rename
# nfs.stat.nfsd.link
# nfs.stat.nfsd.symlink
# nfs.stat.nfsd.mkdir
# nfs.stat.nfsd.rmdir
# nfs.stat.nfsd.readdir
# nfs.stat.nfsd.rdirplus
# nfs.stat.nfsd.access
# nfs.stat.nfsd.mknod
# nfs.stat.nfsd.fsstat
# nfs.stat.nfsd.fsinfo
# nfs.stat.nfsd.pathconf
# nfs.stat.nfsd.commit
# nfs.stat.nfsd.ret-failed
# nfs.stat.nfsd.faults
# nfs.stat.nfsd.inprog
# nfs.stat.nfsd.idem
# nfs.stat.nfsd.non-idem
# nfs.stat.nfsd.misses
# nfs.stat.nfsd.writeops
# nfs.stat.nfsd.writerpc
# nfs.stat.nfsd.opsaved
#
# nfs.stat.nfsd.threads
# nfs.stat.nfsd.maxthreads
# 
# zfs.zpool.iostat.write.bandwidth
# zfs.zpool.iostat.read.bandwidth
# zfs.zpool.iostat.write.ops
# zfs.zpool.iostat.read.ops

PATH=/usr/bin:/sbin:/bin

interval="10" # nfsstat -w interval in seconds. Suggested value is 10.
zfs_pool="storage" # Pool to check
zabbix_server="185.119.216.161" # Zabbix-server to send to
zabbix_sender="/usr/local/bin/zabbix_sender" # Path to zabbix sender

if ! [ -n "$(pgrep -f "zabbix_sender")" ]; then
# nfsstat
while :;do sleep ${interval};nfsstat -s | grep -i "[0-9]" | tr '\n' ' ' | awk '{print "- nfs.stat.nfsd.getattr "$1"\n""- nfs.stat.nfsd.setattr "$2"\n""- nfs.stat.nfsd.lookup "$3"\n""- nfs.stat.nfsd.readlink "$4"\n""- nfs.stat.nfsd.read "$5"\n""- nfs.stat.nfsd.write "$6"\n""- nfs.stat.nfsd.create "$7"\n""- nfs.stat.nfsd.remove "$8"\n""- nfs.stat.nfsd.rename "$9"\n""- nfs.stat.nfsd.link "$10"\n""- nfs.stat.nfsd.symlink "$11"\n""- nfs.stat.nfsd.mkdir "$12"\n""- nfs.stat.nfsd.rmdir "$13"\n""- nfs.stat.nfsd.readdir "$14"\n""- nfs.stat.nfsd.rdirplus "$15"\n""- nfs.stat.nfsd.access "$16"\n""- nfs.stat.nfsd.mknod "$17"\n""- nfs.stat.nfsd.fsstat "$18"\n""- nfs.stat.nfsd.fsinfo "$19"\n""- nfs.stat.nfsd.pathconf "$20"\n""- nfs.stat.nfsd.commit "$21"\n""- nfs.stat.nfsd.ret-failed "$22"\n""- nfs.stat.nfsd.faults "$23"\n""- nfs.stat.nfsd.inprog "$24"\n""- nfs.stat.nfsd.idem "$25"\n""- nfs.stat.nfsd.non-idem "$26"\n""- nfs.stat.nfsd.misses "$27"\n""- nfs.stat.nfsd.writeops "$28"\n""- nfs.stat.nfsd.writerpc "$29"\n""- nfs.stat.nfsd.opsaved "$30}' | zabbix_sender -z $zabbix_server -s `hostname` -i -;done >/dev/null 2>&1 &

# nfs server threads and maxthreads
while :;do sleep ${interval};sysctl vfs.nfsd.threads vfs.nfsd.maxthreads | tr '\n' ' ' | awk '{print "- nfs.stat.nfsd.threads "$2"\n""- nfs.stat.nfsd.maxthreads "$4}' | zabbix_sender -z 185.119.216.161 -s `hostname` -i -;done >/dev/null 2>&1 &

# zpool iostat operations and bandwidth
zpool iostat $zfs_pool $interval | stdbuf -o0 awk 'NR > 3 {print($7)}' | stdbuf -o0 sed -e 's/K/\*1024/g' -e 's/M/\*1048576/g' -e 's/G/\*1073741824/g' | bc | stdbuf -o0 awk '{printf("%d\n",$1 + 0.5)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k zfs.zpool.iostat.write.bandwidth -s `hostname` -o >/dev/null 2>&1 &

zpool iostat $zfs_pool $interval | stdbuf -o0 awk 'NR > 3 {print($6)}' | stdbuf -o0 sed -e 's/K/\*1024/g' -e 's/M/\*1048576/g' -e 's/G/\*1073741824/g' | bc | stdbuf -o0 awk '{printf("%d\n",$1 + 0.5)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k zfs.zpool.iostat.read.bandwidth -s `hostname` -o >/dev/null 2>&1 &

zpool iostat $zfs_pool $interval | stdbuf -o0 awk 'NR > 3 {print($5)}' | stdbuf -o0 sed -e 's/K/\*1024/g' -e 's/M/\*1048576/g' -e 's/G/\*1073741824/g' | bc | stdbuf -o0 awk '{printf("%d\n",$1 + 0.5)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k zfs.zpool.iostat.write.ops -s `hostname` -o >/dev/null 2>&1 &

zpool iostat $zfs_pool $interval | stdbuf -o0 awk 'NR > 3 {print($4)}' | stdbuf -o0 sed -e 's/K/\*1024/g' -e 's/M/\*1048576/g' -e 's/G/\*1073741824/g' | bc | stdbuf -o0 awk '{printf("%d\n",$1 + 0.5)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k zfs.zpool.iostat.read.ops -s `hostname` -o >/dev/null 2>&1 &
fi
exit 0

