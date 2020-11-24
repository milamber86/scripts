#!/bin/bash
# author: beranek@icewarp.com
# version: 20201123_1
# requires: curl, db creds, db name below
# input: "email address of the user" "password reset message file"
# does: extracts mobile number from user's VCARD in IceWarp, calls php sms gw to send the pass reset URL to user's mobile number
#
dbuser='DB_USERNAME'; # IceWarp database connection username
dbpass='DB_PASSWORD'; # IceWarp database connection password
dbhost='DB_HOST'; # IceWarp database connection hostname/IP
dbport='DB_PORT' # IceWarp database connection port
dbname="IW_GW_DB_NAME"; # IceWarp groupware database name
email="${1}"; # user email string from IceWarp
msgfile="${2}"; # IceWarp message filename
logfile="/opt/icewarp/scripts/smstest.log";
#execemail="pwdres@somedomain.ex";
#
#/opt/icewarp/tool.sh set account "${email}" u_alternateemail "${execemail}"
msgbody="$(cat "${msgfile}" | sed -e '1,/Content-Transfer-Encoding: base64/d' | egrep -v '^--' | tr -d '\t\n\r')";
msgtext="$(echo "${msgbody}" | base64 -d | tail -3 | head -2)";
query="SELECT ContactItem.*, ContactLocation.* FROM EventGroup, EventOwner, ContactItem left outer join ContactLocation on itm_id = lctitm_id WHERE Own_Email = \x27${email}\x27 AND ItmFolder = \x27@@mycard@@\x27 AND OWN_ID = GRPOWN_ID AND ITMGRP_ID = GRP_ID limit 1\G";
result="$(echo -e "${query}" | mysql -u ${dbuser} -p${dbpass} -h ${dbhost} -P ${dbport} ${dbname})"
echo "${result}" | grep "LctPhnMobile:" > /dev/null
if [[ ( $? -eq 0 ) && ( ! -z "${result}" ) ]]
  then
    phone="$(echo "${result}" | grep "LctPhnMobile:" | tail -1 | awk '{print $2}';)"
  else
    echo "[$(date)] - ERR: mobile phone number not found in IW VCARD ( user:${email}, iw gw db:${dbname} )." >> "${logfile}"
    exit 1
fi
if [[ ! -z "${msgbody}" ]]
  then
    /usr/bin/curl -s -G -ikL 127.0.0.1/smsgw.php --data-urlencode "from=${email}" --data-urlencode "to=${phone}" --data-urlencode "text=${msgtext}" >> "${logfile}" 2>&1
    echo "[$(date)] - OK: Sent ${msgtext} to ${phone} for user ${email}." >> "${logfile}"
  else
    echo "[$(date)] - ERR: SMS message text empty ( user:${email} )." >> "${logfile}"
    exit 1
fi
exit 0
