#!/bin/bash

#
# The purpose of this script is to ease the proces of database charset and collation conversion
# by default, it coverts to utf8mb4 charset and utf8mb4_unicode_ci collation, however you can use what ever you like
# Using unicode collation variant is more accureate while general is faster (choice is yours)
# switch to utf8mb4 enables support of insertions of 4bytes symbols into mysql 

# databases you do not want to affect should be listed into exclude file (exclude_dbs.txt) one per line 
# it is also possible to alter the line where database names are read so grep selects instead of excluding databases
# script also attempts automatically modify column indexes to varchar(191) if they are bigger than that
# otherwise it leaves them unaffected
# maximum size of the index will vary depending on character set converted to (191 is for default)

 

###

#

#replace user and pass with your mysql credentials

#

user=root
pass=pass
grwdb=groupware

char=utf8mb4

coll=utf8mb4_czech_ci

#uncomment and set ip if mysql is not running on same machine as script is executed:
#host=$(echo '-h 10.10.10.10 -P 4008')

####

#
echo "Script for automatic conversion of database charset has started,  please backup your databases and check whether your selection of databases to process is correct indeed."
read -p "Do you wish to continue? (yes/no)" CONT
if [ "$CONT" == "yes" ]; then
 # read db names
 mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.documenteditingpermission DROP FOREIGN KEY documenteditingpermission_ibfk_1;"
 mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.documenteditingstatus DROP FOREIGN KEY documenteditingstatus_ibfk_1;"
 mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.eventcomment DROP FOREIGN KEY eventcomment_ibfk_1;"
 mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.eventmymention DROP FOREIGN KEY eventmymention_ibfk_1;"
 mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.eventmyreaction DROP FOREIGN KEY eventmyreaction_ibfk_1;"
 mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.eventpin DROP FOREIGN KEY eventpin_ibfk_1;"
 mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.globaleventpin DROP FOREIGN KEY globaleventpin_ibfk_1;"
 mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.teamchatpluginsubscription DROP FOREIGN KEY teamchatpluginsubscription_ibfk_1;"
 mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.teamchatpluginuserconfig DROP FOREIGN KEY teamchatpluginuserconfig_ibfk_1;"
 databases=`mysql ${host} -u$user -p$pass -N -e "SHOW DATABASES;" | tr -d "| " | grep "iwcz_"`
 for db in $databases; do
       mysql ${host} -u$user -p$pass -N -e "ALTER DATABASE ${db} CHARACTER SET = ${char} COLLATE = ${coll};"
       echo "Reading tables from database: $db"
       tables=$(mysql ${host} -u$user -p$pass -N -e "SHOW TABLES FROM ${db}" | tr -d "| ")
       for table in $tables; do
                >|text
               echo $table
               # alter tables
               mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${db}.${table} CONVERT TO CHARACTER SET ${char} COLLATE ${coll};"
               if [ $? -gt 0 ]; then
                 echo "SHOW FTABLES: ${db}.${table}"
                 mysql ${host} -u$user -p$pass -N -e "show indexes in ${db}.${table} where column_name in (select column_name from information_schema.statistics where column_name in (select column_name from information_schema.columns where table_schema = '${db}' and column_type > 'varchar(191)'));" >> text
                 cat text | while read line
                 do
                   query=$(echo -e "${db}\t${line}" | awk -F"\t" '{printf("SET FOREIGN_KEY_CHECKS = 0;alter table %s.%s modify %s varchar(191);SET FOREIGN_KEY_CHECKS = 1;\n", $1, $2, $6)}')
                   mysql ${host} -u$user -p$pass -N -e "${query}" >>sql.log 2>&1
                   if [ $? -gt 0 ]; then
                     echo -e "error in:\n $query"
                   fi
                 done
                 mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${db}.${table} CONVERT TO CHARACTER SET ${char} COLLATE ${coll};"
               fi
       done
   done
mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.documenteditingpermission ADD CONSTRAINT \`documenteditingpermission_ibfk_1\` FOREIGN KEY (\`DEPODE_ID\`) REFERENCES \`onlinedocumentediting\` (\`ODE_ID\`) ON DELETE CASCADE;"
mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.documenteditingstatus ADD CONSTRAINT \`documenteditingstatus_ibfk_1\` FOREIGN KEY (\`DESODE_ID\`) REFERENCES \`onlinedocumentediting\` (\`ODE_ID\`) ON DELETE CASCADE;"
mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.eventcomment ADD CONSTRAINT \`eventcomment_ibfk_1\` FOREIGN KEY (\`COMGRP_ID\`, \`COM_FOLDER\`, \`COMEVN_ID\`) REFERENCES \`event\` (\`EVNGRP_ID\`, \`EvnFolder\`, \`EVN_ID\`) ON DELETE CASCADE ON UPDATE CASCADE;"
mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.eventmymention ADD CONSTRAINT \`eventmymention_ibfk_1\` FOREIGN KEY (\`MENGRP_ID\`, \`MEN_FOLDER\`, \`MENEVN_ID\`) REFERENCES \`event\` (\`EVNGRP_ID\`, \`EvnFolder\`, \`EVN_ID\`) ON DELETE CASCADE ON UPDATE CASCADE;"
mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.eventmyreaction ADD CONSTRAINT \`eventmyreaction_ibfk_1\` FOREIGN KEY (\`REAGRP_ID\`, \`REA_FOLDER\`, \`REAEVN_ID\`) REFERENCES \`event\` (\`EVNGRP_ID\`, \`EvnFolder\`, \`EVN_ID\`) ON DELETE CASCADE ON UPDATE CASCADE;"
mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.eventpin ADD CONSTRAINT \`eventpin_ibfk_1\` FOREIGN KEY (\`PINGRP_ID\`, \`PIN_FOLDER\`, \`PINEVN_ID\`) REFERENCES \`event\` (\`EVNGRP_ID\`, \`EvnFolder\`, \`EVN_ID\`) ON DELETE CASCADE ON UPDATE CASCADE;"
mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.globaleventpin ADD CONSTRAINT \`globaleventpin_ibfk_1\` FOREIGN KEY (\`PINGRP_ID\`, \`PIN_FOLDER\`, \`PINEVN_ID\`) REFERENCES \`event\` (\`EVNGRP_ID\`, \`EvnFolder\`, \`EVN_ID\`) ON DELETE CASCADE ON UPDATE CASCADE;"
mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.teamchatpluginsubscription ADD CONSTRAINT \`teamchatpluginsubscription_ibfk_1\` FOREIGN KEY (\`TPSTP_ID\`) REFERENCES \`teamchatplugin\` (\`TP_ID\`) ON DELETE CASCADE;"
mysql ${host} -u$user -p$pass -N -e "ALTER TABLE ${grwdb}.teamchatpluginuserconfig ADD CONSTRAINT \`teamchatpluginuserconfig_ibfk_1\` FOREIGN KEY (\`TPUTPS_ID\`) REFERENCES \`teamchatpluginsubscription\` (\`TPS_ID\`) ON DELETE CASCADE;"
elif [ "$CONT" == "no" ]
   then
    echo "script has been succesfully terminated";
 exit
  else
    echo "well, correct answer is yes or no";
 exit
fi
