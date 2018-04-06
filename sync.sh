#!/bin/bash
LOG_DIR="/opt/icewarp/IMAPSYNC/log";
mkdir -p ${LOG_DIR}
LOG_FILE="`date "+%d-%m-%y"`.log";
GENLOG="${LOG_DIR}/general.log"
HOST1="source_host_ip";
HOST2="destination_host_ip";
MAXFORKS="16"
SLINT="1";
{ while IFS=';' read u1 p1 u2 p2
do
{ echo "$u1" | egrep "^#" ; } > /dev/null && continue # this skip commented lines in sourcefile
# max number of spawned forks controll
while true
	do
       	CFORKS="$(pgrep -f "/usr/bin/imapsync" | wc -l)";
        if [ "${CFORKS}" -ge "${MAXFORKS}" ]
                                        then
                                         sleep ${SLINT}
                                        else
                                         break
        fi
	done
LOGTO="${LOG_DIR}/${u1}_${LOG_FILE}";
echo "==== Syncing user $u1 to user $u2 ====" >> ${GENLOG} 2>&1
imapsync --host1 "$HOST1" --user1 "$u1" --password1 "$p1" --host2 "$HOST2" --user2 "$u2" --password2 "$p2" \
--regextrans2 's/Sent Items$/Odeslan&AOk-/' \
--regextrans2 's/Deleted Items$/Ko&AWE-/' \
--regextrans2 's/Drafts$/Koncepty/' \
--regextrans2 's/Junk E-mail$/Ko&AWE-/' \
--regextrans2 's/Deleted Messages$/Ko&AWE-/' \
--regextrans2 's/Infected Items$/Ko&AWE-/' \
--regextrans2 's/AVG Virov&AP0- trezor$/Ko&AWE-/' \
--regextrans2 's/Infikovan&AOk- polo&AX4-ky$/Ko&AWE-/' \
--exclude '^Public Folders' \
--syncinternaldates --addheader --noauthmd5 >> ${LOGTO} 2>&1 &
done
} < file.txt
wait ${!}
exit 0
