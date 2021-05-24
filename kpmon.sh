#!/bin/bash
reqchecks="imapstatus httpstatus wcstatus";
wcmaxlatency=24000;
#dbmasterstatus=$(mysql -e "SELECT @@global.read_only\G" | tail -1 | awk '{print $2}');
#if [[ ${dbmasterstatus} -ne 0 ]]
#  then
#    echo "Database set to read-only, not a master IceWarp cluster instance.";
#    rm -f /opt/icewarp/var/wcstatus.mon.OK
#    exit 1
#fi
for I in ${reqchecks}
  do
  grep "OK" /opt/icewarp/var/${I}.mon > /dev/null 2>&1
  if [[ ${?} -ne 0 ]]
  then
    echo "Check for ${I} failed."
    rm -f /opt/icewarp/var/wcstatus.mon.OK
    exit 1
  fi
done
wcls=$(cat /opt/icewarp/var/wcruntime.mon)
if [[ ${wcls} -ge ${wcmaxlatency} ]]
  then
    echo "Webclient latency ${wcls} greater than ${wcmaxlatency}";
    rm -f /opt/icewarp/var/wcstatus.mon.OK
    exit 1
fi
touch /opt/icewarp/var/wcstatus.mon.OK
exit 0
