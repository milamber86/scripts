#! /usr/local/bin/bash
logfile="/root/backup-`date +%Y%m%d-%H%M`.log"
configfile="/root/backup.cfg"
{ while IFS=';' read backupsrv backupfs targetfs
do
{ echo "${backupsrv}" | egrep "^#" ; } > /dev/null && continue # this skip commented lines in configfile
targetdataset=$(echo ${backupfs} | perl -pe 's:^storage/cloudbak/(.*?)$:\1:')
lastsnap=$(ssh -n root@${backupsrv} "zfs list -o name -t snapshot -r ${targetfs}/${targetdataset}" | egrep "-" | sed -r 's:^.*@(.*)$:\1:' | tail -1)
thissnap=`date +%Y%m%d-%H%M`
echo "`date -u` - backupsrv = ${backupsrv}" >> ${logfile} 2>&1
echo "`date -u` - backupfs = ${backupfs}" >> ${logfile} 2>&1
echo "`date -u` - targetfs = ${targetfs}" >> ${logfile} 2>&1
echo "`date -u` - thissnap = ${thissnap}" >> ${logfile} 2>&1
echo "`date -u` - lastsnap = ${lastsnap}" >> ${logfile} 2>&1
echo "`date -u` - targetdataset = ${targetdataset}" >> ${logfile} 2>&1
zfs snap ${backupfs}@${thissnap}
echo "`date -u` - snapshot ${backupfs}@${thissnap} finished" >> ${logfile} 2>&1
zfs send -I @${lastsnap} ${backupfs}@${thissnap} | mbuffer -q -s 1024k -m 2G 2>/dev/null | ssh -c aes128-gcm@openssh.com ${backupsrv} "mbuffer -q -s 1024k -m 2G | zfs recv -Fv ${targetfs}/${targetdataset}" >> ${logfile} 2>&1
echo "`date -u` - backup ${backupfs}@${thissnap} --> ${backupsrv} ${targetfs}/${targetdataset} finished" >> ${logfile} 2>&1
done
} < ${configfile}
exit 0
