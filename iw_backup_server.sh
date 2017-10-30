#!/bin/bash
## description
# synchronizes IceWarp accounts, groups config and groupware database
#
## global vars
TOOL="/opt/icewarp/tool.sh";
IW_INST_DIR="/opt/icewarp";
IW_MAIL_DIR="/opt/icewarp/mail";
MAIN_DIR="/opt/icewarp/sync";
mkdir -p "${MAIN_DIR}";
LOG_DIR="/opt/icewarp/sync/logs";
mkdir -p "${LOG_DIR}";
DATA_DIR="/opt/icewarp/sync/data";
mkdir -p "${DATA_DIR}";
LOG_FILE="${LOG_DIR}/`date "+%d-%m-%y"`_backup.log";
BCK_FILE="${DATA_DIR}/bck.dat";
DOM_FILE="${DATA_DIR}/dom.dat";
ACC_FILE="${DATA_DIR}/acc.dat";
GRP_FILE="${DATA_DIR}/grp.dat";
GRW_FILE="${DATA_DIR}/grw.dat";
IMAPSYNC_FILE="${DATA_DIR}/file.txt";
ICWD="/opt/icewarp/icewarpd.sh";
MYSQL="$(which mysql)";
MASTER="192.168.198.209";
TEST="NULL";
#
## functions
# rename maildir and wipe all local domains and accounts
cleanup()
{
mv "${IW_MAIL_DIR}" "${IW_MAIL_DIR}_tmp"
${TOOL} delete account "*@*" >> "${LOG_FILE}" 2>&1
${TOOL} delete domain "*" >> "${LOG_FILE}" 2>&1
local ret="$(${TOOL} export domain "*")";
if [ -z "${ret}" ]; then
                        mv "${IW_MAIL_DIR}_tmp" "${IW_MAIL_DIR}"
			echo "0"
                    else
                        mv "${IW_MAIL_DIR}_tmp" "${IW_MAIL_DIR}_err"
			echo "Error"
fi
}
#
# get backup of accounts and groups from remote server to local backup file
getbckfile()
{
rm -fv "${BCK_FILE}" >> "${LOG_FILE}" 2>&1
ssh root@${MASTER} "/opt/icewarp/sync/exportacc.sh" > "${BCK_FILE}";
if [ ! -f "${BCK_FILE}" ]; then
    				echo "Error creating file!"
			   else
				echo "0"
fi
}
#
# export domains from remote server
exportdom()
{
rm -fv "${DOM_FILE}" >> "${LOG_FILE}" 2>&1
ssh root@${MASTER} "/opt/icewarp/sync/exportdom.sh" | sed -r 's|^(.*),(.*),$|/opt/icewarp/tool.sh create domain \1 u_backup \2|' > "${DOM_FILE}"
if [ ! -f "${DOM_FILE}" ]; then 
                                echo "Error creating file!"
                           else 
                                echo "exit 0" >> ${DOM_FILE}
                                chmod u+x ${DOM_FILE}
                                echo "0"
fi
}
#
# export remote accounts from local backup file
exportacc()
{
rm -fv "${ACC_FILE}" >> "${LOG_FILE}" 2>&1
egrep "^(.*)@(.*?),0," "${BCK_FILE}" | sed -r 's|^(.*),0,(.*),$|/opt/icewarp/tool.sh create account \1 u_backup \2|' > "${ACC_FILE}"
if [ ! -f "${ACC_FILE}" ]; then
    				echo "Error creating file!"
			   else
				echo "exit 0" >> ${ACC_FILE}	
				chmod u+x ${ACC_FILE}
				echo "0"
fi
}
#
# export remote groups from local backup file
exportgrp()
{
rm -fv "${GRP_FILE}" >> "${LOG_FILE}" 2>&1
egrep "^(.*)@(.*?),7," "${BCK_FILE}" | sed -r 's|^(.*),7,(.*),$|/opt/icewarp/tool.sh create account \1 u_backup \2|' > "${GRP_FILE}"
if [ ! -f "${GRP_FILE}" ]; then
    				echo "Error creating file!"
			   else
				echo "exit 0" >> ${GRP_FILE}	
				chmod u+x ${GRP_FILE}
				echo "0"
fi
}
#
# export remote groupware database
exportgrwdb()
{
rm -fv "${GRW_FILE}" >> "${LOG_FILE}" 2>&1
ssh root@${MASTER} "mysqldump --single-transaction groupware" > "${GRW_FILE}"
if [ ! -f "${GRW_FILE}" ]; then
    				echo "Error creating file!"
			   else
				echo "0"
fi
}
#
# import domains from local backup
importdom()
{
${DOM_FILE} >> ${LOG_FILE} 2>&1
local ret="${?}";
if [ "${ret}" == "0" ]; then
                        echo "0"
                      else
                        echo "Failed with ${ret}"
fi
}
#
# import domains config
importdomcfg()
{
for I in $(ssh root@${MASTER} '/opt/icewarp/tool.sh export domain "*" d_backup' | sed -r 's|^(.*),.*,$|\1|');
        do
        local from_path="${IW_INST_DIR}/config/${I}/";
	local to_path="${IW_INST_DIR}/config/${I}/";
	rsync -av --no-checksum --delete root@${MASTER}:"${from_path}" "${to_path}" >> "${LOG_FILE}" 2>&1
        done
echo "0"
}
#
# import accounts
importacc()
{
${ACC_FILE} >> ${LOG_FILE} 2>&1
${TOOL} set account "*@*" u_authmode 0 >> "${LOG_FILE}" 2>&1
local ret="${?}";
if [ "${ret}" == "0" ]; then
			echo "0"
		      else
			echo "Failed with ${ret}"
fi
}
#
# import groups
importgrp()
{
${GRP_FILE} >> "${LOG_FILE}" 2>&1
local ret="${?}";
if [ "${ret}" == "0" ]; then
			echo "0"
		      else
			echo "Failed with ${ret}"
fi
}
#
# import groupware database
importgrwdb()
{
${MYSQL} groupware < "${GRW_FILE}"
local ret="${?}";
if [ "${ret}" == "0" ]; then
			echo "0"
	  	      else
			echo "Failed with ${ret}"
fi
}
#
# stop IceWarp services
iwstop()
{
${ICWD} --stop all >> "${LOG_FILE}" 2>&1
sleep 5
local ret="$(pgrep -f '/opt/icewarp')";
if [ -z "${ret}" ]; then 
			echo "0"
	   	    else
			echo "Error"
fi
}
#
# start IceWarp services
iwstart()
{
${ICWD} --restart all >> "${LOG_FILE}" 2>&1
sleep 1
local ret=$(pgrep -f '/opt/icewarp')
if [ -z "${ret}" ]; then
                        echo "Error"
                    else
                        echo "0"
fi
}
#
# prepare imapsync file
prepsync()
{
rm -fv ${IMAPSYNC_FILE} >> "${LOG_FILE}" 2>&1
${TOOL} set system C_Accounts_Policies_Pass_AllowAdminPass 1 >> "${LOG_FILE}" 2>&1
${TOOL} set system C_Accounts_Policies_Pass_DenyExport 0 >> "${LOG_FILE}" 2>&1
${TOOL} export account "*@*" u_type u_mailbox u_password | egrep ",0," | sed -r 's:^(.*?),0,(.*?),(.*?),$:\1;\3;\1;\3;:' > "${IMAPSYNC_FILE}"
${TOOL} set system C_Accounts_Policies_Pass_AllowAdminPass 0 >> "${LOG_FILE}" 2>&1
${TOOL} set system C_Accounts_Policies_Pass_DenyExport 1 >> "${LOG_FILE}" 2>&1
if [ ! -f "${IMAPSYNC_FILE}" ]; then
                                echo "Error creating file!"
                           else
                                echo "0"
fi
}
#
# exit with error
die()
{
echo "Exited with ${1}"
echo "Exited with ${1}" >> "${LOG_FILE}"
exit 1
}
#
## main
TEST="$(getbckfile)";
if [ "${TEST}" != "0" ];
        then
                die "Err cfg export!"
        else
TEST="INIT";
TEST="$(exportdom)";
if [ "${TEST}" != "0" ];
        then
                die "Err dom export!"
        else
TEST="INIT";
TEST="$(exportacc)";
if [ "${TEST}" != "0" ];
	then
		die "Err acc export!"
	else							
TEST="INIT";
TEST="$(exportgrp)";
if [ "${TEST}" != "0" ];
	then
		die "Err grp export!"
	else							
TEST="INIT";
TEST="$(exportgrwdb)";
if [ "${TEST}" != "0" ];
	then
		die "Err grw export!"
	else							
TEST="INIT";
TEST="$(iwstop)";
if [ "${TEST}" != "0" ];
	then
		TEST="INIT";
		TEST="$(iwstop)";
		if [ "${TEST}" != "0" ]; then die "Err stop IW services!";fi;
	else
TEST="INIT";
TEST="$(cleanup)";
if [ "${TEST}" != "0" ];
	then
		die "Err init cleanup!"
	else
TEST="INIT";
TEST="$(importdom)";
if [ "${TEST}" != "0" ];
        then    
                die "Err dom import!"
        else
TEST="INIT";
TEST="$(importacc)";
if [ "${TEST}" != "0" ];
	then
		die "Err acc import!"
	else
TEST="INIT";
TEST="$(importdomcfg)";
if [ "${TEST}" != "0" ];
        then
                die "Err dom cfg import!"
        else
TEST="INIT";
TEST="$(importgrp)";
if [ "${TEST}" != "0" ];
	then
		die "Err grp import!"
	else
TEST="INIT";
TEST="$(importgrwdb)";
if [ "${TEST}" != "0" ];
	then
		die "Err grw import!"
	else
TEST="INIT";
TEST="$(iwstart)";
if [ "${TEST}" != "0" ];
	then
		die "Err IW svc start!"
	else
TEST="INIT";
TEST="$(prepsync)";
if [ "${TEST}" != "0" ];
        then
                die "Err prep imapsync file!"
        else
echo "Finished OK" >> "${LOG_FILE}"
fi;fi;fi;fi;fi;fi;fi;fi;fi;fi;fi;fi;fi;fi;
exit 0
