#!/bin/bash
# iwmon_agent.sh
# IceWarp monitoring for Zabbix
# ver. 20201217_001
#
# zabbix agent config example ( place in /etc/zabbix/zabbix_agentd.d/userparameter_icewarp.conf ):
#
# UserParameter=icewarp.iwbackup,/opt/icewarp/scripts/iwmon.sh "iwver";cat /opt/icewarp/var/iwbackupstatus.mon
# UserParameter=icewarp.iwver,/opt/icewarp/scripts/iwmon.sh "iwver";cat /opt/icewarp/var/iwverstatus.mon
# UserParameter=icewarp.cfg,/opt/icewarp/scripts/iwmon.sh "cfg";cat /opt/icewarp/var/cfgstatus.mon
# UserParameter=icewarp.nfs,/opt/icewarp/scripts/iwmon.sh "nfs";cat /opt/icewarp/var/nfsmntstatus.mon
# UserParameter=icewarp.smtp,/opt/icewarp/scripts/iwmon.sh "smtp";cat /opt/icewarp/var/smtpstatus.mon
# UserParameter=icewarp.imap,/opt/icewarp/scripts/iwmon.sh "imap";cat /opt/icewarp/var/imapstatus.mon
# UserParameter=icewarp.http,/opt/icewarp/scripts/iwmon.sh "wc";cat /opt/icewarp/var/httpstatus.mon
# UserParameter=icewarp.xmpp,/opt/icewarp/scripts/iwmon.sh "xmpp";cat /opt/icewarp/var/xmppstatus.mon
# UserParameter=icewarp.grw,/opt/icewarp/scripts/iwmon.sh "grw";cat /opt/icewarp/var/grwstatus.mon
# UserParameter=icewarp.wcresult,/opt/icewarp/scripts/iwmon.sh "wclogin" "0";cat /opt/icewarp/var/wcstatus.mon
# UserParameter=icewarp.wcspeed,cat /opt/icewarp/var/wcruntime.mon
# UserParameter=icewarp.easresult,/opt/icewarp/scripts/iwmon.sh "easlogin";cat /opt/icewarp/var/easstatus.mon
# UserParameter=icewarp.easspeed,cat /opt/icewarp/var/easruntime.mon
# UserParameter=icewarp.connsmtp,/opt/icewarp/scripts/iwmon.sh "connstat" "smtp";cat /opt/icewarp/var/connstat_smtp.mon
# UserParameter=icewarp.connpop,/opt/icewarp/scripts/iwmon.sh "connstat" "pop";cat /opt/icewarp/var/connstat_pop.mon
# UserParameter=icewarp.connimap,/opt/icewarp/scripts/iwmon.sh "connstat" "imap";cat /opt/icewarp/var/connstat_imap.mon
# UserParameter=icewarp.connxmpp,/opt/icewarp/scripts/iwmon.sh "connstat" "xmpp";cat /opt/icewarp/var/connstat_xmpp.mon
# UserParameter=icewarp.connhttp,/opt/icewarp/scripts/iwmon.sh "connstat" "http";cat /opt/icewarp/var/connstat_http.mon
# UserParameter=icewarp.queueinc,/opt/icewarp/scripts/iwmon.sh "queuestat" "inc";cat /opt/icewarp/var/queuestat_inc.mon
# UserParameter=icewarp.queueoutg,/opt/icewarp/scripts/iwmon.sh "queuestat" "outg";cat /opt/icewarp/var/queuestat_outg.mon
# UserParameter=icewarp.queueretr,/opt/icewarp/scripts/iwmon.sh "queuestat" "retr";cat /opt/icewarp/var/queuestat_retr.mon
# UserParameter=icewarp.msgout,/opt/icewarp/scripts/iwmon.sh "connstat" "msgout";cat /opt/icewarp/var/smtpstat_msgout.mon
# UserParameter=icewarp.msgin,/opt/icewarp/scripts/iwmon.sh "connstat" "msgin";cat /opt/icewarp/var/smtpstat_msgin.mon
# UserParameter=icewarp.msgfail,/opt/icewarp/scripts/iwmon.sh "connstat" "msgfail";cat /opt/icewarp/var/smtpstat_msgfail.mon
# UserParameter=icewarp.msgfaildata,/opt/icewarp/scripts/iwmon.sh "connstat" "msgfaildata";cat /opt/icewarp/var/smtpstat_msgfaildata.mon
# UserParameter=icewarp.msgfailvirus,/opt/icewarp/scripts/iwmon.sh "connstat" "msgfailvirus";cat /opt/icewarp/var/smtpstat_msgfailvirus.mon
# UserParameter=icewarp.msgfailcf,/opt/icewarp/scripts/iwmon.sh "connstat" "msgfailcf";cat /opt/icewarp/var/smtpstat_msgfailcf.mon
# UserParameter=icewarp.msgfailextcf,/opt/icewarp/scripts/iwmon.sh "connstat" "msgfailextcf";cat /opt/icewarp/var/smtpstat_msgfailextcf.mon
# UserParameter=icewarp.msgfailrule,/opt/icewarp/scripts/iwmon.sh "connstat" "msgfailrule";cat /opt/icewarp/var/smtpstat_msgfailrule.mon
# UserParameter=icewarp.msgfaildnsbl,/opt/icewarp/scripts/iwmon.sh "connstat" "msgfaildnsbl";cat /opt/icewarp/var/smtpstat_msgfaildnsbl.mon
# UserParameter=icewarp.msgfailips,/opt/icewarp/scripts/iwmon.sh "connstat" "msgfailips";cat /opt/icewarp/var/smtpstat_msgfailips.mon
# UserParameter=icewarp.msgfailspam,/opt/icewarp/scripts/iwmon.sh "connstat" "msgfailspam";cat /opt/icewarp/var/smtpstat_msgfailspam.mon
#
#VARS
HOST="127.0.0.1";
SNMPPORT="161"
ctimeout=30;
EASFOLDER="INBOX";
scriptdir="$(cd $(dirname $0) && pwd)"
logdate="$(date +%Y%m%d)"
logfile="${scriptdir}/iwmon_${logdate}.log"
admemail="admuser"                                           # full IceWarp server admin credentials for impersonated checks
admpass="admpass";                                           # password ^
email="test_user";                                           # email address, standard user must exist, guest user will be created by this script if it does not exist
pass="guestpass";                                            # password for guest account ( only for webclient login quest account check )
wcguest=0;                                                   # 0 - use standard account for webclient check, 1 - use autocreated guest account for webclient check and check using login to teamchat ( must be enabled )
outputpath="/opt/icewarp/var";                               # results output path
nfstestfile="/mnt/data/storage.dat"                          # path to nfs mount test file ( must exist )
toolSh="/opt/icewarp/tool.sh";
icewarpdSh="/opt/icewarp/icewarpd.sh";
/usr/bin/touch "${scriptdir}/iwmon.cfg"
/usr/bin/chmod 600 "${scriptdir}/iwmon.cfg"

#FUNC
# write log to local syslog
function slog
{
local logsvr="${1}";
local logmsg="${2}";
local logdate="$(date '+%b %d %H:%M:%S')";
/usr/bin/logger "${logdate} ${HOSTNAME} IWMON: ${logsvr} ${logmsg}"
}

# write setting to configfile
function writecfg() # ( setting_name, setting_value )
{
tmpcfg="$(cat ${scriptdir}/iwmon.cfg | grep -v "${1}")";
echo "${tmpcfg}" > "${scriptdir}"/iwmon_tmp.cfg
echo "${1}:${2}" >> "${scriptdir}"/iwmon_tmp.cfg
mv -f "${scriptdir}"/iwmon_tmp.cfg "${scriptdir}"/iwmon.cfg
return 0
}

# read setting from configfile
function readcfg() # ( setting_name -> setting_value )
{
result="$(/usr/bin/grep "${1}" ${scriptdir}/iwmon.cfg | awk -F ':' '{print $2}' )";
if [ -z "${result}" ]
  then
  echo "Variable ${1} empty or not found";
  return 1
  else
  echo "${result}"
  return 0
fi
}

# set initial settings to iwmon.cfg
function init()
{
local FILE="/opt/icewarp/path.dat"
if [ -f "${FILE}" ]
  then
  local mail_outpath=$(cat /opt/icewarp/path.dat | grep -v retry | grep _outgoing | dos2unix)
  [ -z "${mail_outpath}" ] && local mail_outpath=$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_outgoing/|')
  local mail_inpath=$(cat /opt/icewarp/path.dat | grep -v retry | grep _incoming | dos2unix)
  [ -z "${mail_inpath}" ] && local mail_inpath=$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_incoming/|')
  else
  local mail_outpath=$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_outgoing/|');
  local mail_inpath=$(timeout -k ${ctimeout} ${ctimeout} ${toolSh} get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_incoming/|');
fi
writecfg "mail_outpath" "${mail_outpath}";
writecfg "mail_inpath" "${mail_inpath}";
local super="$(timeout -k 30 30 ${toolSh} get system C_Accounts_Policies_SuperUserPassword | awk '{print $2}')";
writecfg "super" "${super}";
declare DBUSER=$(timeout -k 3 3 ${toolSh} get system C_ActiveSync_DBUser | sed -r 's|^C_ActiveSync_DBUser: (.*)$|\1|')
declare DBPASS=$(timeout -k 3 3 ${toolSh} get system C_ActiveSync_DBPass | sed -r 's|^C_ActiveSync_DBPass: (.*)$|\1|')
read DBHOST DBPORT DBNAME <<<$(timeout -k 3 3 ${toolSh} get system C_ActiveSync_DBConnection | sed -r 's|^C_ActiveSync_DBConnection: mysql:host=(.*);port=(.*);dbname=(.*)$|\1 \2 \3|')
read -r USER aURI aTYPE aVER aKEY <<<$(echo "select * from devices order by last_sync asc\\G" | timeout -k 3 3 mysql -u ${DBUSER} -p${DBPASS} -h ${DBHOST} -P ${DBPORT} ${DBNAME} | tail -24 | egrep "user_id:|uri:|type:|protocol_version:|synckey:" | xargs -n1 -d'\n' | tr -d '\040\011\015\012' | sed -r 's|^user_id:(.*)uri:(.*)type:(.*)protocol_version:(.*)synckey:(.*)$|\1 \2 \3 \4 \5|')
timeout -k 3 3 ${toolSh} set system C_Accounts_Policies_EnableGlobalAdmin 1 > /dev/null 2>&1
timeout -k 3 3 ${toolSh} set system C_Accounts_Policies_Pass_DenyExport 0 > /dev/null 2>&1
timeout -k 3 3 ${toolSh} set system C_Accounts_Policies_Pass_AllowAdminPass 1 > /dev/null 2>&1
declare PASS=$(timeout -k 3 3 ${toolSh} export account "${USER}" u_password | sed -r 's|^.*,(.*),$|\1|')
timeout -k 3 3 ${toolSh} set system C_Accounts_Policies_Pass_AllowAdminPass 1 > /dev/null 2>&1
timeout -k 3 3 ${toolSh} set system C_Accounts_Policies_Pass_DenyExport 1 > /dev/null 2>&1
writecfg "EASUser" "${USER}"
writecfg "EASPass" "${PASS}"
writecfg "EASVers" "${aVER}"
}

# install dependencies
function installdeps()
{
utiltest="$(/usr/bin/find /usr/lib64 -type f -name "Entities.pm")"
if [[ -z "${utiltest}" ]]
  then
  log "Installing Entities.pm"
  /usr/bin/yum -y install epel-release
  /usr/bin/yum -y install perl-HTML-Encoding.noarch
fi
which curl > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing curl"
  /usr/bin/yum -y install curl
fi
which nc > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing nc"
  /usr/bin/yum -y install nc
fi
which wget > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing wget"
  /usr/bin/yum -y install nc
fi
which dos2unix > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing dos2unix"
  /usr/bin/yum -y install dos2unix
fi
which mysql > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing mysql client"
  /usr/bin/yum -y install mysql
fi
which snmpget > /dev/null 2>&1
if [[ ${?} -ne 0 ]]
  then
  log "Installing net-snmp-utils"
  /usr/bin/yum -y install net-snmp-utils
fi
if [ ! -f ${scriptdir}/activesync.txt ]
  then
  cd "${scriptdir}"
  wget https://mail.icewarp.cz/webdav/ticket/eJwNy0EOhCAMAMDf9KZbKw1w6NUP.IICZWNMNFE06.,duc9XWF0cCpY4qkGVeb,SfjyQZYJT2CeqgRHNEA7paHDeMfrgwASWfyZS5opa.KO5Lbedz5b79muwCuUQNOKY0gsMHR5N/activesync.txt
fi
utiltest="$(${toolSh} get system C_System_Adv_Ext_SNMPServer | awk '{print $2}')"
if [[ ${utiltest} != "1" ]]
  then
  log "Enabling IceWarp SNMP and restarting control service"
  ${toolSh} set system C_System_Adv_Ext_SNMPServer 1
  ${icewarpdSh} --restart control
fi
}

function log()
{
echo $(date '+%b %d %H:%M:%S') $1 >> ${logfile}
}

# nfs mount available check
function nfsmntstat()
{
if [ -f "${nfstestfile}" ]
  then
  echo "OK" > ${outputpath}/nfsmntstatus.mon;slog "INFO" "NFS mount OK.";
  return 0
  else
  echo "FAIL" > ${outputpath}/nfsmntstatus.mon;slog "ERROR" "NFS mount FAIL!";
  return 1
fi
}

# check main config changed ( detect accidental configuration self-reset )
function cfgstat()
{
local super="$(readcfg "super")";
local result="$(timeout -k 10 10 ${toolSh} get system C_Accounts_Policies_SuperUserPassword | awk '{print $2}')";
if [[ "${super}" == "${result}" ]]
  then
  echo "OK" > ${outputpath}/cfgstatus.mon;slog "INFO" "IceWarp config reset check OK.";
  return 0
  else
  echo "FAIL" > ${outputpath}/cfgstatus.mon;slog "ERROR" "IceWarp config reset check FAIL!";
  return 1
fi
}

# get icewarp control version string
function iwvercheck()
{
local result="$(timeout -k 10 10 ${toolSh} get system C_Version | awk '{print $2}' | tr -d '.')";
local re='^[0-9]+$'
if ! [[ $result =~ $re ]]
  then
    echo "Failed to get IW version using tool."; return 1;
  else
    echo "$result" > ${outputpath}/iwverstatus.mon; return 0;
fi
}

# get icewarp backup status
function iwbackupcheck()
{
local void=1
}

# check groupware database is available
function gwdbcheck()
{
local todo=1
# TODO
}

# get value from IceWarp snmp ( https://esupport.icewarp.com/index.php?/Knowledgebase/Article/View/180/16/snmp-in-icewarp )
function iwsnmpget() # ( iw snmp SvcID.SVC -> snmp response value )
{
local test="$(snmpget -r 1 -t 1 -v 1 -c private ${HOST}:${SNMPPORT} "1.3.6.1.4.1.23736.1.2.1.1.2.${1}")"
      if [[ ${?} != 0 ]]
        then
          echo "Fail";
          return 1;
        else
          local result="$(echo "${test}" | sed -r 's|^.*INTEGER:\s(.*)$|\1|')";
          echo "${result}";
          return 0
      fi
}

# get number of connections for IceWarp service using SNMP
function connstat() # ( service name in smtp,pop,imap,xmpp,grw,http -> number of connections )
{
case "${1}" in
smtp) local conn_smtp_count="$(iwsnmpget "8.1")";
      if [[ "${conn_smtp_count}" != "Fail" ]]
              then
              echo "${conn_smtp_count}" > ${outputpath}/connstat_smtp.mon;
              else
              echo "99999" > ${outputpath}/connstat_smtp.mon;
      fi
;;
pop)  local conn_pop3_count="$(iwsnmpget "8.2")";
      if [[ "${conn_pop3_count}" != "Fail" ]]
              then
              echo "${conn_pop3_count}" > ${outputpath}/connstat_pop.mon;
              else
              echo "99999" > ${outputpath}/connstat_pop.mon;
      fi

;;
imap) local conn_imap_count="$(iwsnmpget "8.3")";
      if [[ "${conn_imap_count}" != "Fail" ]]
              then
              echo "${conn_imap_count}" > ${outputpath}/connstat_imap.mon;
              else
              echo "99999" > ${outputpath}/connstat_imap.mon;
      fi
;;
xmpp) local conn_im_count_server="$(iwsnmpget "8.4")";
      local conn_im_count_client="$(iwsnmpget "10.4")";
      if [[ "${conn_im_count_server}" != "Fail" ]];then if [[ "${conn_im_count_client}" != "Fail" ]]
            then
            local conn_im_count=$((${conn_im_count_server} + ${conn_im_count_client}));
            echo "${conn_im_count}" > ${outputpath}/connstat_xmpp.mon;
            else
            echo "99999" > ${outputpath}/connstat_xmpp.mon;
            fi
      fi
;;
grw)  local conn_gw_count="$(iwsnmpget "8.5")";
      if [[ "${conn_gw_count}" != "Fail" ]]
              then
              echo "${conn_gw_count}" > ${outputpath}/connstat_grw.mon;
              else
              echo "99999" > ${outputpath}/connstat_grw.mon;
      fi
;;
http) local conn_web_count="$(iwsnmpget "8.7")";
      if [[ "${conn_web_count}" != "Fail" ]]
              then
              echo "${conn_web_count}" > ${outputpath}/connstat_http.mon;
              else
              echo "99999" > ${outputpath}/connstat_web.mon;
      fi
;;
msgout) local smtp_msg_out="$(iwsnmpget "16.1")";
      if [[ "${smtp_msg_out}" != "Fail" ]]
        then
        echo "${smtp_msg_out}" > ${outputpath}/smtpstat_msgout.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgout.mon;
      fi
;;
msgin) local smtp_msg_in="$(iwsnmpget "17.1")";
      if [[ "${smtp_msg_in}" != "Fail"  ]]
        then
        echo "${smtp_msg_in}" > ${outputpath}/smtpstat_msgin.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgin.mon;
      fi
;;
msgfail) local smtp_msg_fail="$(iwsnmpget "18.1")";
      if [[ "${smtp_msg_fail}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail}" > ${outputpath}/smtpstat_msgfail.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgfail.mon;
      fi
;;
msgfaildata) local smtp_msg_fail_data="$(iwsnmpget "19.1")";
      if [[ "${smtp_msg_fail_data}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_data}" > ${outputpath}/smtpstat_msgfaildata.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgfaildata.mon;
      fi
;;
msgfailvirus) local smtp_msg_fail_virus="$(iwsnmpget "20.1")";
      if [[ "${smtp_msg_fail_virus}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_virus}" > ${outputpath}/smtpstat_msgfailvirus.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgfailvirus.mon;
      fi
;;
msgfailcf) local smtp_msg_fail_cf="$(iwsnmpget "21.1")";
      if [[ "${smtp_msg_fail_cf}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_cf}" > ${outputpath}/smtpstat_msgfailcf.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgfailcf.mon;
      fi
;;
msgfailextcf) local smtp_msg_fail_extcf="$(iwsnmpget "22.1")";
      if [[ "${smtp_msg_fail_extcf}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_extcf}" > ${outputpath}/smtpstat_msgfailextcf.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgfailextcf.mon;
      fi
;;
msgfailrule) local smtp_msg_fail_rule="$(iwsnmpget "23.1")";
      if [[ "${smtp_msg_fail_rule}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_rule}" > ${outputpath}/smtpstat_msgfailrule.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgfailrule.mon;
      fi
;;
msgfaildnsbl) local smtp_msg_fail_dnsbl="$(iwsnmpget "24.1")";
      if [[ "${smtp_msg_fail_dnsbl}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_dnsbl}" > ${outputpath}/smtpstat_msgfaildnsbl.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgfaildnsbl.mon;
      fi
;;
msgfailips) local smtp_msg_fail_ips="$(iwsnmpget "25.1")";
      if [[ "${smtp_msg_fail_ips}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_ips}" > ${outputpath}/smtpstat_msgfailips.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgfailips.mon;
      fi
;;
msgfailspam) local smtp_msg_fail_spam="$(iwsnmpget "26.1")";
      if [[ "${smtp_msg_fail_spam}" != "Fail"  ]]
        then
        echo "${smtp_msg_fail_spam}" > ${outputpath}/smtpstat_msgfailspam.mon;
        else
        echo "99999" > ${outputpath}/smtpstat_msgfailspam.mon;
      fi
;;
*)    echo "Invalid argument. Use IceWarp service snmp name: smtp, pop, imap, xmpp, grw, http,"
      echo "SMTP stats: msgout, msgin, msgfail, msgfaildata, msgfailvirus, msgfailcf, msgfailextcf, msgfailrule, msgfaildnsbl, msgfailips, msgfailspam"
;;
esac
}

# get number of mail in server queues
function queuestat() # ( queue name in outg, inc, retr -> number of messages )
{
local mail_outpath=$(readcfg "mail_outpath");
local mail_inpath=$(readcfg "mail_inpath");
case "${1}" in
outg) local queue_outgoing_count=$(timeout -k ${ctimeout} ${ctimeout} find ${mail_outpath} -maxdepth 1 -type f | wc -l);
      if [[ ${?} -eq 0 ]]; then
                           echo "${queue_outgoing_count}" > ${outputpath}/queuestat_outg.mon;
                           else
                           echo "9999" > ${outputpath}/queuestat_outg.mon;
      fi
;;
inc)  local queue_incoming_count=$(timeout -k ${ctimeout} ${ctimeout} find ${mail_inpath} -maxdepth 1 -type f -name "*.dat" | wc -l);
      if [[ ${?} -eq 0 ]]; then
                           echo "${queue_incoming_count}" > ${outputpath}/queuestat_inc.mon;
                           else
                           echo "9999" > ${outputpath}/queuestat_inc.mon;
      fi
;;
retr) local queue_outgoing_retry_count=$(timeout -k ${ctimeout} ${ctimeout} find ${mail_outpath}retry/ -type f | wc -l);
      if [[ ${?} -eq 0 ]]; then
                           echo "${queue_outgoing_retry_count}" > ${outputpath}/queuestat_retr.mon;
                           else
                           echo "9999" > ${outputpath}/queuestat_retr.mon;
      fi
;;
*)    echo "Invalid argument. Use IceWarp queue name: outg, inc, retr"
;;
esac
}

# iw smtp server simple check
function smtpstat()
{
local SMTP_RESPONSE="$(echo "QUIT" | nc -w 3 "${HOST}" 25 | egrep -o "^220" | head -1)"
if [ "${SMTP_RESPONSE}" == "220" ]; then
                        echo "OK" > ${outputpath}/smtpstatus.mon;slog "INFO" "IceWarp SMTP OK.";
                          else
                        echo "FAIL" > ${outputpath}/smtpstatus.mon;slog "ERROR" "IceWarp SMTP FAIL!";
fi
}

# iw imap server simple check
function imapstat()
{
local IMAP_RESPONSE="$(echo ". logout" | nc -w 3 "${HOST}" 143 | egrep -o "\* OK " | egrep -o "OK")"
if [ "${IMAP_RESPONSE}" == "OK" ]; then
                        echo "OK" > ${outputpath}/imapstatus.mon;slog "INFO" "IceWarp IMAP OK.";
                          else
                        echo "FAIL" > ${outputpath}/imapstatus.mon;slog "ERROR" "IceWarp IMAP FAIL!";
fi
}

# iw web server simple check
function wcstat()
{
local HTTP_RESPONSE="$(curl -s -k --connect-timeout 5 -o /dev/null -w "%{http_code}" -m 5 https://"${HOST}"/webmail/)"
if [ "${HTTP_RESPONSE}" == "200" ]; then
                        echo "OK" > ${outputpath}/httpstatus.mon;slog "INFO" "IceWarp HTTP OK.";
                          else
                        echo "FAIL" > ${outputpath}/httpstatus.mon;slog "ERROR" "IceWarp HTTP FAIL!";
fi
}

# iw xmpp server simple check
function xmppstat()
{
local XMPP_RESPONSE="$(echo '<?xml version="1.0"?>  <stream:stream to="healthcheck" xmlns="jabber:client" xmlns:stream="http://etherx.jabber.org/streams" version="1.0">' | nc -w 3 "${HOST}" 5222 | egrep -o "^<stream:stream xmlns" |egrep -o "xmlns")"
if [ "${XMPP_RESPONSE}" == "xmlns" ]; then
                        echo "OK" > ${outputpath}/xmppstatus.mon;slog "INFO" "IceWarp XMPP OK.";
                          else
                        echo "FAIL" > ${outputpath}/xmppstatus.mon;slog "ERROR" "IceWarp XMPP FAIL!";
fi
}

# iw groupware server simple check
function grwstat()
{
local GRW_RESPONSE="$(echo "test" | nc -w 3 "${HOST}" 5229 | egrep -o "<greeting" | egrep -o "greeting")"
if [ "${GRW_RESPONSE}" == "greeting" ]; then
                        echo "OK" > ${outputpath}/grwstatus.mon;slog "INFO" "IceWarp GRW OK.";
                          else
                        echo "FAIL" > ${outputpath}/grwstatus.mon;slog "ERROR" "IceWarp GRW FAIL!";
fi
}

# urlencode string
function rawurlencode() {
  local string="${1}"
  local strlen=${#string}
  local encoded=""
  local pos c o

  for (( pos=0 ; pos<strlen ; pos++ )); do
     c=${string:$pos:1}
     case "$c" in
        [-_.~a-zA-Z0-9] ) o="${c}" ;;
        * )               printf -v o '%%%02x' "'$c"
     esac
     encoded+="${o}"
  done
  echo "${encoded}"
}

# iw web client login healthcheck
function wccheck() # ( guest 0/1 -> OK, FAIL; time spent in ms )
{
local guest=${1}
local iwserver="${HOST}"
if [[ ${guest} != 0 ]] # generate guest account email, test if guest account exists, if not, create one
    then
     local guestaccemail="$(echo ${email} | sed -r s'|(.*)\@(.*)|\1_\2\@##internalservicedomain.icewarp.com##|')"  # generate teamchat guest account email
     local guestacclogin="$(echo ${email} | sed -r s'|(.*)\@(.*)|\1|')"
     timeout -k 10 10 ${toolSh} export account "${guestaccemail}" u_name | grep -o ",${guestacclogin}," > /dev/null 2>&1
     local result=$?
     if [[ ${result} != 0 ]]
         then
         timeout -k 10 10 ${toolSh} create account "${guestaccemail}" u_name "${guestacclogin}" u_mailbox "${email}" u_password "${pass}"
         local result=$?
         if [[ ${result} != 0 ]];then local freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;slog "ERROR" "Webclient error creating guest test account!";return 1;fi
     else
     local email="${guestaccemail}";
     fi
fi
local start=`date +%s%N | cut -b1-13`
# get admin auth token
local atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>authenticate</commandname><commandparams><email>${admemail}</email><password>${admpass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
local wcatoken="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o 'sid="(.*)"' | sed -r 's|sid="(.*)"|\1|')"
if [ -z "${wcatoken}" ];
  then
  local freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
  slog "ERROR" "Webclient Stage 1 fail - Error getting webclient auth token from control!";
  return 1;
fi
# impersonate webclient user
local imp_request="<iq sid=\"${wcatoken}\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>impersonatewebclient</commandname><commandparams><email>${email}</email></commandparams></query></iq>"
local wclogin="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${imp_request}" "https://${iwserver}/icewarpapi/" | egrep -o '<result>(.*)</result>' | sed -r 's|<result>(.*)</result>|\1|')"
if [ -z "${wclogin}" ];
  then
  local freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
  slog "ERROR" "Webclient Stage 2 fail - Error impersonating webclient user!";
  return 1;
fi
# get user phpsessid
local wcphpsessid="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL "${wclogin}" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"
if [ -z "${wcphpsessid}" ];
  then
  local freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
  slog "ERROR" "Webclient Stage 3 fail - Error getting php session ID";
  return 1;
fi
# auth user webclient session
local auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
local wcsid="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${auth_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";
if [ -z "${wcsid}" ];
  then
  local freturn="FAIL";echo "FAIL" > ${outputpath}/wcstatus.mon;echo "99999" > ${outputpath}/wcruntime.mon;
  slog "ERROR" "Webclient Stage 4 fail - Error logging to the webclient";
  return 1;
fi
if [[ ${guest} == 0 ]] # test response for standard or teamchat guest account
    then
     # refresh folders standard account start
     # get settings
     get_settings_request="<iq sid=\"wm-"${wcsid}"\" type=\"get\" format=\"json\"><query xmlns=\"webmail:iq:private\"><resources><skins/><banner_options/><im/><sip/><chat/><mail_settings_default/><mail_settings_general/><login_settings/><layout_settings/><homepage_settings/><calendar_settings/><default_calendar_settings/><cookie_settings/><default_reminder_settings/><event_settings/><spellchecker_languages/><signature/><groups/><restrictions/><aliases/><read_confirmation/><global_settings/><paths/><streamhost/><password_policy/><fonts/><certificate/><timezones/><external_settings/><gw_mygroup/><default_folders/><documents/></resources></query></iq>";
     get_settings_response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${get_settings_request}" "https://${iwserver}/webmail/server/webmail.php")";
     if [[ "${get_settings_response}" =~ "result" ]];
         then
          local freturn=OK;slog "INFO" "Webclient check OK.";
         else
          local freturn=FAIL;slog "ERROR" "Stage 5 fail - Error getting settings, possible API problem";
     fi
     local refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${email}\" type=\"set\" format=\"xml\"><query xmlns=\"webmail:iq:accounts\"><account action=\"refresh\" uid=\"${email}\"/></query></iq>"
     local response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o "folder uid=\"INBOX\"")"
     if [[ "${response}" =~ "INBOX" ]];
         then
          local freturn=OK;slog "INFO" "Webclient check OK.";
         else
          local freturn=FAIL;slog "ERROR" "Webclient Stage 6 fail - No INBOX in folder sync response";
     fi # refresh folders standard account end
     else
     # refresh folders teamchat guest account start
     local refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${guestaccemail}\" type=\"get\" format=\"json\"><query xmlns=\"webmail:iq:folders\"><account uid=\"${guestaccemail}\"/></query></iq>"
     local response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o "INHERITED_ACL" | head -1)"
     if [[ "${response}" =~ "INHERITED_ACL" ]];
         then
          local freturn=OK;slog "INFO" "Webclient guest login check OK.";
         else
          local freturn=FAIL;slog "ERROR" "Webclient guest login check FAIL!";
     fi # refresh folders teamchat guest account end
fi
# session logout
local logout_request="<iq sid=\"wm-"${wcsid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${logout_request}" "https://${iwserver}/webmail/server/webmail.php" > /dev/null 2>&1
local end=`date +%s%N | cut -b1-13`
local runtime=$((end-start))
echo "${freturn}" > ${outputpath}/wcstatus.mon;
echo "${runtime}" > ${outputpath}/wcruntime.mon;
if [[ "${freturn}" == "OK" ]]; then return 0;else return 1;fi
}

# iw ActiveSync client login healthcheck
function eascheck() # ( -> status OK, FAIL; time spent in ms )
{
local USER=$(readcfg "EASUser");
local PASS=$(readcfg "EASPass");
local aVER=$(readcfg "EASVers");
local FOLDER="${EASFOLDER}";
local aURI="000EASHealthCheck000"
local aTYPE="IceWarpAnnihilator"
local start=`date +%s%N | cut -b1-13`
local result=`/usr/bin/curl -s -k --connect-timeout ${ctimeout} -m ${ctimeout} --basic --user "$USER:$PASS" -H "Expect: 100-continue" -H "Host: $HOST" -H "MS-ASProtocolVersion: ${aVER}" -H "Connection: Keep-Alive" -A "${aTYPE}" --data-binary @${scriptdir}/activesync.txt -H "Content-Type: application/vnd.ms-sync.wbxml" "https://$HOST/Microsoft-Server-ActiveSync?User=$USER&DeviceId=$aURI&DeviceType=$aTYPE&Cmd=FolderSync" | strings`
local end=`date +%s%N | cut -b1-13`
local runtime=$((end-start))
if [[ $result == *$FOLDER* ]]
then
local freturn=OK;slog "INFO" "ActiveSync login check OK.";
else
local freturn=FAIL;slog "ERROR" "ActiveSync login check FAIL!";
fi
echo "${freturn}" > ${outputpath}/easstatus.mon;
echo "${runtime}" > ${outputpath}/easruntime.mon;
if [[ "${freturn}" == "OK" ]]; then return 0;else return 1;fi
}

function printStats() {
echo "IceWarp stats for ${HOSTNAME} at $(date)"
echo "last value update - service: check result"
echo "--- Status ( OK | FAIL ):"
for SIMPLECHECK in smtp imap xmpp grw http nfsmnt cfg iwver iwbackup
    do
    echo -n "$(stat -c'%y' "${outputpath}/${SIMPLECHECK}status.mon") - "
    echo -n "${SIMPLECHECK}: "
    cat "${outputpath}/${SIMPLECHECK}status.mon"
done
echo "--- Number of connections:"
for CONNCHECK in smtp imap xmpp http
    do
    echo -n "$(stat -c'%y' "${outputpath}/connstat_${CONNCHECK}.mon") - "
    echo -n "${CONNCHECK}: "
    cat "${outputpath}/connstat_${CONNCHECK}.mon"
done
echo "--- SMTP queues number of messages:"
for QUEUECHECK in inc outg retr
    do
    echo -n "$(stat -c'%y' "${outputpath}/queuestat_${QUEUECHECK}.mon") - "
    echo -n "${QUEUECHECK}: "
    cat "${outputpath}/queuestat_${QUEUECHECK}.mon"
done
echo "--- SMTP message stats:"
for SMTPSTAT in msgout msgin msgfail msgfaildata msgfailvirus msgfailcf msgfailextcf msgfailrule msgfaildnsbl msgfailips msgfailspam
    do
    echo -n "$(stat -c'%y' "${outputpath}/smtpstat_${SMTPSTAT}.mon") - "
    echo -n "${SMTPSTAT}: "
    cat "${outputpath}/smtpstat_${SMTPSTAT}.mon"
done
echo "--- WebClient and ActiveSync:"
echo -n "$(stat -c'%y' "${outputpath}/wcstatus.mon") - "
echo -n "WebClient login: "
cat "${outputpath}/wcstatus.mon"
echo -n "$(stat -c'%y' "${outputpath}/wcruntime.mon") - "
echo -n "time spent: "
cat "${outputpath}/wcruntime.mon"
echo -n "$(stat -c'%y' "${outputpath}/easstatus.mon") - "
echo -n "ActiveSync login: "
cat "${outputpath}/easstatus.mon"
echo -n "$(stat -c'%y' "${outputpath}/easruntime.mon") - "
echo -n "time spent: "
cat "${outputpath}/easruntime.mon"
}

function printUsage() {
    cat <<EOF

Synopsis
    iwmon.sh setup
    checks and installs dependencies, sets initial runtime configuration

    iwmon.sh check_name [ check_parameter ]
    supported health-checks: iwbackup, iwver, cfg, nfs, smtp, imap, xmpp, grw, wc, wclogin ( guest 0/1 parameter ), easlogin

    iwmon.sh connstat [ service_name ]
    supported services: smtp, imap, xmpp, grw, http

    iwmon.sh queuestat [ smtp_queue_name ]
    available queues: inc ( incoming ), outg ( outgoing ), retr ( outgoing-retry )

    iwmon.sh connstat [ smtp_msg_stat_name ]
    available smtp stats: msgout, msgin, msgfail, msgfaildata, msgfailvirus, msgfailcf, msgfailextcf, msgfailrule
    ( for more details, see https://esupport.icewarp.com/index.php?/Knowledgebase/Article/View/180/16/snmp-in-icewarp )

    iwmon.sh all silent/verbose
    get all stats in one run and optionally print the stats to STDOUT

    ---
    Performs healthchecks and queries service connection number stats and smtp
    queue lengths for IceWarp server.

EOF
}


#MAIN
case ${1} in
setup) installdeps;
       init;
;;
iwbackup) iwbackupcheck;
;;
iwver) iwvercheck;
;;
cfg) cfgstat;
;;
nfs) nfsmntstat;
;;
smtp) smtpstat;
;;
imap) imapstat;
;;
xmpp) xmppstat;
;;
grw) grwstat;
;;
wc) wcstat;
;;
wclogin) wccheck "${2}";
;;
easlogin) eascheck;
;;
connstat) connstat "${2}";
;;
queuestat) queuestat "${2}";
;;
all) if [[ "${2}" == "verbose" ]]
        then
        smtpstat;imapstat;xmppstat;grwstat;wcstat;wccheck "${wcguest}";eascheck;nfsmntstat;cfgstat;iwvercheck;iwbackupcheck;
        for STATNAME in smtp imap xmpp grw http msgout msgin msgfail msgfaildata msgfailvirus msgfailcf msgfailextcf msgfailrule msgfaildnsbl msgfailips msgfailspam; do connstat "${STATNAME}";done;
        for QUEUENAME in inc outg retr; do queuestat "${QUEUENAME}";done;
        printStats;
     fi
     if [[ "${2}" == "silent" ]]
        then
        smtpstat;imapstat;xmppstat;grwstat;wcstat;wccheck "${wcguest}";eascheck;nfsmntstat;cfgstat;iwvercheck;iwbackupcheck;
        for STATNAME in smtp imap xmpp grw http msgout msgin msgfail msgfaildata msgfailvirus msgfailcf msgfailextcf msgfailrule msgfaildnsbl msgfailips msgfailspam; do connstat "${STATNAME}";done;
        for QUEUENAME in inc outg retr; do queuestat "${QUEUENAME}";done;
     fi
     if [[ "${2}" != "verbose" ]]
        then
        if [[ "${2}" != "silent" ]]
            then
            printUsage;
        fi
     fi
;;
*) printUsage;
;;
esac
exit 0
