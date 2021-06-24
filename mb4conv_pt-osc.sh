#!/bin/bash
# changes IceWarp database charset and collation for all databases and tables online using pt-osc ( compatible with Percona PXC and other Galera clusters )
# requires pt-online-schema-change from percona-toolkit, primary keys required on all tables including MetaData tables:
# ( https://github.com/milamber86/galera/blob/master/icewarp_keys_for_sql_rep )
dbuser="root";
dbpass="rootpass";
dbhost="127.0.0.1";
dbport="3306";
grwdb="grwdbname";
charset="utf8mb4";
collate="utf8mb4_swedish_ci";
echo 'SET GLOBAL FOREIGN_KEY_CHECKS=0;' | mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport}
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.documenteditingpermission DROP FOREIGN KEY documenteditingpermission_ibfk_1;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.documenteditingstatus DROP FOREIGN KEY documenteditingstatus_ibfk_1;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.eventcomment DROP FOREIGN KEY eventcomment_ibfk_1;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.eventmymention DROP FOREIGN KEY eventmymention_ibfk_1;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.eventmyreaction DROP FOREIGN KEY eventmyreaction_ibfk_1;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.eventpin DROP FOREIGN KEY eventpin_ibfk_1;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.globaleventpin DROP FOREIGN KEY globaleventpin_ibfk_1;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.teamchatpluginsubscription DROP FOREIGN KEY teamchatpluginsubscription_ibfk_1;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.teamchatpluginuserconfig DROP FOREIGN KEY teamchatpluginuserconfig_ibfk_1;"
databases=`mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "SHOW DATABASES;" | tr -d "| " | egrep -v "Database|schema|mysql|sys"`
for db in ${databases}
  do
    echo -ne "ALTER DATABASE ${db} DEFAULT CHARACTER SET ${charset} COLLATE ${collate};" | mysql ${db}
    tables=$(mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "SHOW TABLES FROM ${db}" | tr -d "| ")
    for table in ${tables}
      do
        pt-online-schema-change --user=${dbuser} --password=${dbpass} --host=${dbhost} --port=${dbport} --charset utf8mb4 --alter "CONVERT TO CHARACTER SET ${charset} COLLATE ${collate}" D=${db},t=${table} --exec --alter-foreign-keys-method=auto --nocheck-foreign-keys
    done
done
mysql mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.documenteditingpermission ADD CONSTRAINT \`documenteditingpermission_ibfk_1\` FOREIGN KEY (\`DEPODE_ID\`) REFERENCES \`onlinedocumentediting\` (\`ODE_ID\`) ON DELETE CASCADE;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.documenteditingstatus ADD CONSTRAINT \`documenteditingstatus_ibfk_1\` FOREIGN KEY (\`DESODE_ID\`) REFERENCES \`onlinedocumentediting\` (\`ODE_ID\`) ON DELETE CASCADE;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.eventcomment ADD CONSTRAINT \`eventcomment_ibfk_1\` FOREIGN KEY (\`COMGRP_ID\`, \`COM_FOLDER\`, \`COMEVN_ID\`) REFERENCES \`event\` (\`EVNGRP_ID\`, \`EvnFolder\`, \`EVN_ID\`) ON DELETE CASCADE ON UPDATE CASCADE;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.eventmymention ADD CONSTRAINT \`eventmymention_ibfk_1\` FOREIGN KEY (\`MENGRP_ID\`, \`MEN_FOLDER\`, \`MENEVN_ID\`) REFERENCES \`event\` (\`EVNGRP_ID\`, \`EvnFolder\`, \`EVN_ID\`) ON DELETE CASCADE ON UPDATE CASCADE;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.eventmyreaction ADD CONSTRAINT \`eventmyreaction_ibfk_1\` FOREIGN KEY (\`REAGRP_ID\`, \`REA_FOLDER\`, \`REAEVN_ID\`) REFERENCES \`event\` (\`EVNGRP_ID\`, \`EvnFolder\`, \`EVN_ID\`) ON DELETE CASCADE ON UPDATE CASCADE;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.eventpin ADD CONSTRAINT \`eventpin_ibfk_1\` FOREIGN KEY (\`PINGRP_ID\`, \`PIN_FOLDER\`, \`PINEVN_ID\`) REFERENCES \`event\` (\`EVNGRP_ID\`, \`EvnFolder\`, \`EVN_ID\`) ON DELETE CASCADE ON UPDATE CASCADE;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.globaleventpin ADD CONSTRAINT \`globaleventpin_ibfk_1\` FOREIGN KEY (\`PINGRP_ID\`, \`PIN_FOLDER\`, \`PINEVN_ID\`) REFERENCES \`event\` (\`EVNGRP_ID\`, \`EvnFolder\`, \`EVN_ID\`) ON DELETE CASCADE ON UPDATE CASCADE;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.teamchatpluginsubscription ADD CONSTRAINT \`teamchatpluginsubscription_ibfk_1\` FOREIGN KEY (\`TPSTP_ID\`) REFERENCES \`teamchatplugin\` (\`TP_ID\`) ON DELETE CASCADE;"
mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "ALTER TABLE ${grwdb}.teamchatpluginuserconfig ADD CONSTRAINT \`teamchatpluginuserconfig_ibfk_1\` FOREIGN KEY (\`TPUTPS_ID\`) REFERENCES \`teamchatpluginsubscription\` (\`TPS_ID\`) ON DELETE CASCADE;"
echo 'SET GLOBAL FOREIGN_KEY_CHECKS=1;' | mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport}
exit 0
