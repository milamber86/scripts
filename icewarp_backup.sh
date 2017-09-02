#!/bin/bash
#-------------------------------------------
# IceWarp cfg and db backup script for cloud
# beranek@icewarp.cz

#---------------init vars-------------------
ID=/usr/bin/id;
ECHO=/bin/echo;
MOUNT=/bin/mount;

MOUNT_DEVICE=/dev/mapper/cl-backup;
backuppath=/mnt/backup;
dbuser=root;
dbpass=merak1;
dbhost=127.0.0.1;
db1=accounts;
db2=antispam;
db3=groupware;

#---------------do backup-------------------
# make sure we're running as root
if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi

# attempt to remount the RW mount point as RW; else abort
$MOUNT -o remount,rw ${MOUNT_DEVICE} ${backuppath} ;
if (( $? )); then
{
	$ECHO "snapshot: could not remount ${backuppath} readwrite";
	exit;
}
fi;

mkdir -p ${backuppath}
mysqldump --single-transaction -u ${dbuser} -p${dbpass} -h${dbhost} ${db1} | gzip -c | cat > ${backuppath}/bck_${db1}`date +%Y%m%d-%H%M`.sql.gz
mysqldump --single-transaction -u ${dbuser} -p${dbpass} -h${dbhost} ${db2} | gzip -c | cat > ${backuppath}/bck_${db2}`date +%Y%m%d-%H%M`.sql.gz
mysqldump --single-transaction -u ${dbuser} -p${dbpass} -h${dbhost} ${db3} | gzip -c | cat > ${backuppath}/bck_${db3}`date +%Y%m%d-%H%M`.sql.gz
tar -czf ${backuppath}/bck_cnf`date +%Y%m%d-%H%M`.tgz /opt/icewarp/config > /dev/null 2>&1
tar -czf ${backuppath}/bck_cal`date +%Y%m%d-%H%M`.tgz /opt/icewarp/calendar > /dev/null 2>&1
/opt/icewarp/tool.sh export account "*@*" u_backup > ${backuppath}/bck_acc_backup`date +%Y%m%d-%H%M`.csv
/opt/icewarp/tool.sh export domain "*" d_backup > ${backuppath}/bck_dom_backup`date +%Y%m%d-%H%M`.csv
find ${backuppath}/ -type f -name "bck_*" -mtime +2 -delete > /dev/null 2>&1

# now remount the RW snapshot mountpoint as readonly

$MOUNT -o remount,ro ${MOUNT_DEVICE} ${backuppath} ;
if (( $? )); then
{
	$ECHO "snapshot: could not remount ${backuppath} readonly";
	exit;
} 
fi;
# todo mail backup completed
exit 0

