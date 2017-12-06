# simple innobackupex backup script for RHEL/CentOS 6,7
# install innobackupex on Centos6,7:
# yum -y install epel-release
# yum -y install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm
# yum -y install percona-xtrabackup-24
#!/bin/bash
backuppath="/mnt/backup/icewarp"
thisdate="$(date +%Y%m%d-%H%M)"
dbuser="root"
dbpass="password"
mkdir -p ${backuppath}
innobackupex --no-lock --user=${dbuser} --password=${dbpass} --stream=tar /tmp/ | gzip -c | cat > ${backuppath}/bck_xtra_mysql_${thisdate}.tar.gz
mysqldump --single-transaction -u ${dbuser} -p${dbpass} accounts | gzip -c | cat > ${backuppath}/bck_${thisdate}_db_acc.sql.gz
mysqldump --single-transaction -u ${dbuser} -p${dbpass} antispam | gzip -c | cat > ${backuppath}/bck_${thisdate}_db_asp.sql.gz
mysqldump --single-transaction -u ${dbuser} -p${dbpass} groupware | gzip -c | cat > ${backuppath}/bck_${thisdate}_db_grw.sql.gz
mysqldump --single-transaction -u ${dbuser} -p${dbpass} webclient | gzip -c | cat > ${backuppath}/bck_${thisdate}_db_wc.sql.gz
mysqldump --single-transaction -u ${dbuser} -p${dbpass} eas | gzip -c | cat > ${backuppath}/bck_${thisdate}_db_eas.sql.gz
mysqldump --single-transaction -u ${dbuser} -p${dbpass} dircache | gzip -c | cat > ${backuppath}/bck_${thisdate}_db_dc.sql.gz
tar -czf ${backuppath}/bck_${thisdate}_cf_cnf.tgz /opt/icewarp/config > /dev/null 2>&1
tar -czf ${backuppath}/bck_${thisdate}_cf_cal.tgz /opt/icewarp/calendar > /dev/null 2>&1
find ${backuppath}/ -type f -name "bck_*" -mtime +7 -delete > ${logpath}/${thisdate}.log 2>&1
exit 0
