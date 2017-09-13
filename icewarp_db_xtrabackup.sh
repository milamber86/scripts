# simple innobackupex backup script for RHEL/CentOS 6,7
# install innobackupex on Centos6,7:
# yum -y install epel-release
# yum -y install http://www.percona.com/downloads/percona-release/redhat/0.1-4/percona-release-0.1-4.noarch.rpm
# yum -y install percona-xtrabackup-24
#!/bin/bash
logpath="/root/dbbackup"
backuppath="/root/dbbackup"
thisdate="$(date +%Y%m%d-%H%M)"
dbuser="user"
dbpass="password"
mkdir -p ${backuppath}
innobackupex --no-lock --user=${dbuser} --password=${dbpass} --stream=tar /tmp/ 2>> ${logpath}/${thisdate}.log | gzip -c | cat > ${backuppath}/bck_mysql_${thisdate}.tar.gz
find ${backuppath}/ -type f -name "bck_*" -mtime +3 -delete > ${logpath}/${thisdate}.log 2>&1
find ${backuppath}/ -type f -name "*.log" -mtime +30 -delete > ${logpath}/${thisdate}.log 2>&1
exit 0
