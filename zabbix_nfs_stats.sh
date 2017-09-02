#!/usr/local/bin/bash
# Written by beranek@icewarp.cz
#
# This script will send nfsstat output to your Zabbix server at a given interval.
# Put this to run at startup and/or in crontab.
# You will need to set the check up as "trapper" in Zabbix.

PATH=/usr/bin:/sbin:/bin

interval="10" # nfsstat -w interval in seconds. Suggested value is 60.
zabbix_server="185.119.216.161" # Zabbix-server to send to
zabbix_sender="/usr/local/bin/zabbix_sender" # Path to zabbix sender

nfsstat -sew ${interval} | stdbuf -oL awk 'NR > 3 {print($1)}' | xargs -L 1 | grep -v "GtAttr" 

if ! [ -n "$(pgrep -f "nfs.stat.GtAttr")" ]; then
nfsstat -sew ${interval} | stdbuf -o0 awk 'NR > 3 {print($1)}' |  xargs -L 1 $zabbix_sender -z $zabbix_server -k nfs.stat.GtAttr -s `hostname` -o >/dev/null 2>&1 &
fi

if ! [ -n "$(pgrep -f "nfs.stat.Lookup")" ]; then
nfsstat -sew ${interval} | stdbuf -o0 awk 'NR > 3 {print($2)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k nfs.stat.Lookup -s `hostname` -o >/dev/null 2>&1 &
fi

if ! [ -n "$(pgrep -f "nfs.stat.Rdlink")" ]; then
nfsstat -sew ${interval} | stdbuf -o0 awk 'NR > 3 {print($3)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k nfs.stat.Rdlink -s `hostname` -o >/dev/null 2>&1 &
fi

if ! [ -n "$(pgrep -f "nfs.stat.Read")" ]; then
nfsstat -sew ${interval} | stdbuf -o0 awk 'NR > 3 {print($4)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k nfs.stat.Read -s `hostname` -o >/dev/null 2>&1 &
fi

if ! [ -n "$(pgrep -f "nfs.stat.Write")" ]; then
nfsstat -sew ${interval} | stdbuf -o0 awk 'NR > 3 {print($5)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k nfs.stat.Write -s `hostname` -o >/dev/null 2>&1 &
fi

if ! [ -n "$(pgrep -f "nfs.stat.Rename")" ]; then
nfsstat -sew ${interval} | stdbuf -o0 awk 'NR > 3 {print($6)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k nfs.stat.Rename -s `hostname` -o >/dev/null 2>&1 &
fi

if ! [ -n "$(pgrep -f "nfs.stat.Access")" ]; then
nfsstat -sew ${interval} | stdbuf -o0 awk 'NR > 3 {print($7)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k nfs.stat.Access -s `hostname` -o >/dev/null 2>&1 &
fi

if ! [ -n "$(pgrep -f "nfs.stat.Rddir")" ]; then
nfsstat -sew ${interval} | stdbuf -o0 awk 'NR > 3 {print($8)}' | xargs -L 1 $zabbix_sender -z $zabbix_server -k nfs.stat.Rddir -s `hostname` -o >/dev/null 2>&1 &
fi

if ! [ -n "$(pgrep -f "nfs.stat.nfsd.threads")" ]; then
        while :;do sleep ${interval} ; sysctl vfs.nfsd.threads | sed -r 's|^vfs.nfsd.threads: ||' | xargs -L 1 $zabbix_sender -z $zabbix_server -k nfs.stat.nfsd.threads -s `hostname` -o;done >/dev/null 2>&1 &
fi

if ! [ -n "$(pgrep -f "nfs.stat.nfsd.maxthreads")" ]; thennfsstat -sew 1
        while :;do sleep ${interval} ; sysctl vfs.nfsd.maxthreads | sed -r 's|^vfs.nfsd.maxthreads: ||' | xargs -L 1 $zabbix_sender -z $zabbix_server -k nfs.stat.nfsd.maxthreads -s `hostname` -o;done >/dev/null 2>&1 &
fi

exit 0
