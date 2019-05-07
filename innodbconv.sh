for DBNAME in accounts antispam groupware dircache eas webclient
  do
  for TBLNAME in $(echo -e "use ${DBNAME}; show tables;" | mysql | egrep -v "^Tables")
    do
    echo -e "use ${DBNAME}; alter table ${TBLNAME} ENGINE InnoDB;" | mysql
    done
  done
