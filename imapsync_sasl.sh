#!/bin/bash
# logging
LOG_DIR="/opt/icewarp/sync/log";
mkdir -p ${LOG_DIR}
LOG_FILE="`date "+%d-%m-%y"`.log";
GENLOG="${LOG_DIR}/general.log"

# textfile with users to migrate
USERS_LIST="/opt/icewarp/sync/list.txt"
# example of list.txt content:
# user1-server1@domain.com;user1-server2@domain.com;
# user2-server1@domain.com;user2-server2@domain.com;

# server and port to migrate from
HOST1="127.0.0.1";
PORT1="9993"
# server and port to migrate to
HOST2="127.0.0.1";
PORT2="143"
# server 1 admin and pass
admacc1="adm@mgmt.loc"
admpass1="pass"
# server 2 admin and pass
admacc2="adm@mgmt.loc"
admpass2="pass"

# max number of parallel forks
MAXFORKS="16"
# sleep interval before spawning new fork(s)
SLINT="1";

##
{ while IFS=';' read u1 u2
do
{ echo "$u1" | egrep "^#" ; } > /dev/null && continue # this skip commented lines in sourcefile
# max number of spawned forks controll
while true
do
CFORKS="$(pgrep -f imapsync | wc -l)";
if [ "${CFORKS}" -ge "${MAXFORKS}" ]
then
sleep ${SLINT}
else
break
fi
done
LOGTO="${LOG_DIR}/${u1}_${LOG_FILE}";
echo "==== Syncing user $u1 to user $u2 ====" >> ${GENLOG} 2>&1
imapsync --authmech1 PLAIN --authmech2 PLAIN --authuser1 ${admacc1} --authuser2 ${admacc2} \
         --host1 "$HOST1" --user1 "$u1" --password1 "${admpass1}" --host2 "$HOST2" --user2 "$u2" --password2 "${admpass2}" \
         --port1 ${PORT1} --ssl1 --port2 ${PORT2} \
         --syncinternaldates --addheader --noauthmd5 >> ${LOGTO} 2>&1 &
done
} < ${USERS_LIST}
wait
exit 0
