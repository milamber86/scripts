#! /usr/local/bin/bash
logfile="/root/backup-`date +%Y%m%d-%H%M`.log"
rep_target_ip="10.255.255.2"
rep_target_dataset="storage/nfs4"
for storage in $(zfs list -r -t filesystem -o name storage/nfs4 | tail -n +3)
do
	{
	thissnap=`date +%Y%m%d-%H%M`	
	lastsnap=$(ssh -n root@${rep_target_ip} "zfs list -o name -t snapshot -r ${storage}" | egrep "-" | sed -r 's:^.*@(.*)$:\1:' | tail -1)
	if [ -n "${lastsnap}" ]
	 	then
			echo "`date -u` - rep_target_ip = ${rep_target_ip}" >> ${logfile} 2>&1
			echo "`date -u` - storage = ${storage}" >> ${logfile} 2>&1
			echo "`date -u` - thissnap = ${thissnap}" >> ${logfile} 2>&1
			echo "`date -u` - lastsnap = ${lastsnap}" >> ${logfile} 2>&1
			echo "`date -u` - rep_target_dataset = ${rep_target_dataset}" >> ${logfile} 2>&1
			zfs snap ${storage}@${thissnap}
			echo "`date -u` - snapshot ${storage}@${thissnap} finished" >> ${logfile} 2>&1
			zfs send -I @${lastsnap} ${storage}@${thissnap} | mbuffer -q -s 1024k -m 2G 2>/dev/null | ssh -c aes128-gcm@openssh.com ${rep_target_ip} "mbuffer -q -s 1024k -m 2G | zfs recv -Fv ${storage}" >> ${logfile} 2>&1
			echo "`date -u` - backup ${storage}@${thissnap} --> ${rep_target_ip} ${rep_target_dataset} finished" >> ${logfile} 2>&1
		else
			echo "`date -u` - dataset ${storage} does not exist on backup target, doing initial seed" >> ${logfile} 2>&1		
			zfs snap ${storage}@${thissnap}
			zfs send -Rv ${storage}@${thissnap} | mbuffer -s 1024k -m 2G 2>/dev/null | ssh -c aes128-gcm@openssh.com ${rep_target_ip} "mbuffer -q -s 1024k -m 2G | zfs receive -Fv ${storage}" >> ${logfile} 2>&1
			echo "`date -u` - initial seed of ${storage} --> ${rep_target_ip} ${storage}@${thissnap} done" >> ${logfile} 2>&1
		fi
	}
done
exit 0
