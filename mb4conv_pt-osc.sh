#!/bin/bash
# changes IceWarp database charset and collation for all databases and tables online using pt-osc ( compatible with Percona PXC and other Galera clusters )
# requires pt-online-schema-change from percona-toolkit, primary keys required on all tables including MetaData tables:
# ( https://github.com/milamber86/galera/blob/master/icewarp_keys_for_sql_rep )
dbuser="root";
dbpass="rootpass";
dbhost="127.0.0.1";
dbport="3306";
charset="utf8mb4";
collate="utf8mb4_swedish_ci";
databases=`mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -N -e "SHOW DATABASES;" | tr -d "| " | egrep -v "Database|schema|mysql|sys"`
for db in ${databases}
  do
    echo -ne "ALTER DATABASE ${db} DEFAULT CHARACTER SET ${charset} COLLATE ${collate};" | mysql ${db}
    tables=$(mysql -h ${dbhost} -u ${dbuser} -p${dbpass} -P ${dbport} -N -e "SHOW TABLES FROM ${db}" | tr -d "| ")
    for table in ${tables}
      do
        pt-online-schema-change --user=${dbuser} --password=${dbpass} --host=${dbhost} --port=${dbport} --charset ${charset} --alter "CONVERT TO CHARACTER SET ${charset} COLLATE ${collate}" D=${db},t=${table} --exec --alter-foreign-keys-method=rebuild_constraints
    done
done
exit 0
