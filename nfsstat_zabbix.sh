#!/usr/local/bin/bash

# NFSStat variables meaning:
# --------------------------
# RKBT = Read KB per Transaction
# RTPS = Read Transactions per Second
# RMBS = Read MB per Second
# RRMS = Read Response in MilliSeconds
# WKBT = Write KB per Transaction
# WTPS = Write Transactions per Second
# WMBS = Write MB per Second
# WRMS = Write Response in MilliSeconds
# CTPC = Commit Transactions per Second
# CRMS = Commit Response in MilliSeconds
# TKBT = Total KB per Transaction
# TTPS = Total Transactions per Second
# TMBS = Total MB per Second
# TRMS = Total Response in MilliSeconds
# TQL  = Total Queue Length
# TSP  = Total Saturation Percent

TRAPPER="185.119.216.161"

# FUNCTION
zabbix_send() # ( zabbix variable name, value )
{
	/usr/local/bin/zabbix_sender -z "${TRAPPER}" -s "$(hostname)" -k "nfsstat.${1}" -o "${2}" # > /dev/null 2>&1
}

report()
{
{ while IFS=' \t' read RKBT RTPS RMBS RRMS WKBT WTPS WMBS WRMS CTPS CRMS TKBT TTPS TMBS TRMS TQL TSP
  do
   echo "RKBT=${RKBT} RTPS=${RTPS} RMBS=${RMBS} RRMS=${RRMS} WKBT=${WKBT} WTPS=${WTPS} WMBS=${WMBS} WRMS=${WRMS} CTPS=${CTPS} CRMS=${CRMS} TKBT=${TKBT} TTPS=${TTPS} TMBS=${TMBS} TRMS=${TRMS} TQL=${TQL} TSP=${TSP}"
   	for VARNAME in RKBT RTPS RMBS RRMS WKBT WTPS WMBS WRMS CTPS CRMS TKBT TTPS TMBS TRMS TQL TSP
	do
	 zabbix_send "${VARNAME}" "${!VARNAME}"
	done
  done
} <<< $(tail -1 /root/nfsstat.txt | egrep -v "Read|KB")
}

# MAIN
start=`date +%s%N | cut -b1-10`
pkill -9 -f nfsstat
/usr/bin/nfsstat -Wd > /root/nfsstat.txt &
sleep 1
for I in {1..55}
 do
  report
  sleep 0.9
 done
end=`date +%s%N | cut -b1-10`
runtime=$((end-start))
echo "${runtime}"
exit 0
