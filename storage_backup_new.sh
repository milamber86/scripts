#! /usr/local/bin/bash
logfile="/root/backup/backup-`date +%Y%m%d-%H%M`.log";
rep_target_ip="10.255.255.2";
rep_src_dataset="storage/nfs4";
rep_target_dataset="storage/nfs4";
snapexpire="4";
for storage in $(zfs list -r -t filesystem -o name ${rep_src_dataset} | tail -n +3)
do
 {
  longsnap=$(cat /root/dosnap);
  if [ "${longsnap}" == "true" ]; then
      for lsstor in $(zfs list -r -t filesystem -o name ${rep_src_dataset} | tail -n +3) 
          do
          /usr/local/sbin/zfsnap snapshot -RsSvz -a 32d ${lsstor} >> ${logfile} 2>&1
          /usr/local/sbin/zfsnap destroy -RsSv ${lsstor} >> ${logfile} 2>&1
          sh -n root@${rep_target_ip} "/usr/local/sbin/zfsnap destroy -RsSv ${lsstor}" >> ${logfile} 2>&1
          done
   echo "false" > /root/dosnap
  fi
 snapuuid=`uuidgen`;
 snapdate=`date +%Y%m%d-%H%M`;
 thissnap="${snapdate}-${snapuuid}";
 lastsnap=$(ssh -n root@${rep_target_ip} "zfs list -o name -t snapshot -r ${storage}" | egrep "-" | sed -r 's:^.*@(.*)$:\1:' | tail -1);
 if [ -n "${lastsnap}" ]
   then
   echo "`date -u` - rep_target_ip = ${rep_target_ip}, storage = ${storage}, thissnap = ${thissnap}, lastsnap = ${lastsnap}, rep_target_dataset = ${rep_target_dataset} " >> ${logfile} 2>&1
   zfs snap ${storage}@${thissnap};echo "`date -u` - snapshot ${storage}@${thissnap} finished" >> ${logfile} 2>&1
   echo "`date -u` - setting expiration on snapshot ..." >> ${logfile} 2>&1
   zfs set custom:rep="true" ${storage}@${thissnap}                        
   zfs set custom:expire=${snapexpire} ${storage}@${thissnap}
   zfs send -R -I @${lastsnap} ${storage}@${thissnap} | mbuffer -q -s 1024k -m 2G 2>/dev/null | ssh -c aes128-gcm@openssh.com ${rep_target_ip} "mbuffer -q -s 1024k -m 2G | zfs recv -Fv ${storage}" >> ${logfile} 2>&1
   echo "`date -u` - backup ${storage}@${thissnap} --> ${rep_target_ip} ${rep_target_dataset} finished" >> ${logfile} 2>&1
   echo "`date -u` - expiration of our snapshots of ${storage} start..." >> ${logfile} 2>&1
   for I in $(zfs list -o name -t snapshot -r ${storage} | grep -v NAME);
      do
      isrep=$(zfs get -o value custom:rep ${I} | grep -v VALUE);
      if [ "${isrep}" == "true" ]; then
               curexpire=$(zfs get -o value custom:expire ${I} | grep -v VALUE);
               cursnap=$(zfs get -o name custom:expire ${I} | grep -v NAME);
               echo "`date -u` - snapshot ${cursnap}, expiration ${curexpire} ..." >> ${logfile} 2>&1
               if [ "${curexpire}" == "0" ]; then
                        echo "`date -u` - removing LOCAL snapshot ${cursnap} with expiration ${curexpire}" >> ${logfile} 2>&1
                        zfs destroy -v ${cursnap} >> ${logfile} 2>&1
                        ssh -n root@${rep_target_ip} "zfs destroy -v ${cursnap}" >> ${logfile} 2>&1
                                             else
                            echo "`date -u` - decrementing expiration for snapshot ${cursnap} with expiration ${curexpire}" >> ${logfile} 2>&1
                            if [ "${curexpire}" -ne "0" ]; then
                                        decexpire=$(( ${curexpire}-1 ));
                            fi
                        zfs set custom:expire=${decexpire} ${cursnap}
                        echo "`date -u` - expiration for ${cursnap} is now ${decexpire}" >> ${logfile} 2>&1
               fi
      fi
   done
   for I in $(ssh -n root@${rep_target_ip} "zfs list -o name -t snapshot -r ${storage} | grep -v NAME");
         do
         isrep=$(ssh -n root@${rep_target_ip} "zfs get -o value custom:rep ${I} | grep -v VALUE");
         if [ "${isrep}" == "true" ]; then
                       curexpire=$(ssh -n root@${rep_target_ip} "zfs get -o value custom:expire ${I} | grep -v VALUE");
                       cursnap=$(ssh -n root@${rep_target_ip} "zfs get -o name custom:expire ${I} | grep -v NAME");
                       if [ "${curexpire}" == "0" ]; then
                                   echo "`date -u` - removing REMOTE snapshot ${cursnap} with expiration ${curexpire} on ${rep_target_ip}" >> ${logfile}2>&1
                                   ssh -n root@${rep_target_ip} "zfs destroy -v ${cursnap}" >> ${logfile} 2>&1
                       fi
         fi
   done
        else
                        echo "`date -u` - dataset ${storage} does not exist on backup target, doing initial seed" >> ${logfile} 2>&1
                        zfs snap ${storage}@${thissnap}
                        zfs set custom:rep="true" ${storage}@${thissnap}
                        zfs set custom:expire=${snapexpire} ${storage}@${thissnap}
                        zfs send -Rv ${storage}@${thissnap} | mbuffer -s 1024k -m 2G 2>/dev/null | ssh -c aes128-gcm@openssh.com ${rep_target_ip} "mbuffer -q -s 1024k -m 2G | zfs receive -Fv ${storage}" >> ${logfile} 2>&1
                        echo "`date -u` - initial seed of ${storage} --> ${rep_target_ip} ${storage}@${thissnap} done" >> ${logfile} 2>&1
        fi
        }
done
exit 0

