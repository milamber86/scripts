#!/bin/sh
#  iwmon.sh
#  icewarp monitoring for zabbix
#
# zabbix agent config example ( place in /etc/zabbix/zabbix_agentd.d/userparameter_icewarp.conf ):
#
# UserParameter=icewarp.smtp,/opt/icewarp/scripts/iwmon.sh "smtp";cat /opt/icewarp/var/smtpstatus.mon
# UserParameter=icewarp.imap,/opt/icewarp/scripts/iwmon.sh "imap";cat /opt/icewarp/var/imapstatus.mon
# UserParameter=icewarp.http,/opt/icewarp/scripts/iwmon.sh "wc";cat /opt/icewarp/var/httpstatus.mon
# UserParameter=icewarp.xmpp,/opt/icewarp/scripts/iwmon.sh "xmpp";cat /opt/icewarp/var/xmppcstatus.mon
# UserParameter=icewarp.grw,/opt/icewarp/scripts/iwmon.sh "grw";cat /opt/icewarp/var/grwstatus.mon
# UserParameter=icewarp.wcresult,/opt/icewarp/scripts/iwmon.sh "wclogin" "1";cat /opt/icewarp/var/wcstatus.mon
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
#
#
#VARS
HOST="127.0.0.1";
ctimeout=30;
EASFOLDER="INBOX";
scriptdir="$(cd $(dirname $0) && pwd)"
logdate="$(date +%Y%m%d)"
logfile="${scriptdir}/iwmon_${logdate}.log"
email="wczabbixmon@icewarp.loc";                             # email address, standard user must exist, guest user will be created by this script if it does not exist
pass="Some-Pass-12345";                                      # password
outputpath="/opt/icewarp/var";                               # results output path
#
#FUNC
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
utiltest="$(/opt/icewarp/tool.sh get system C_System_Adv_Ext_SNMPServer | awk '{print $2}')"
if [[ ${utiltest} != "1" ]]
  then
  log "Enabling IceWarp SNMP and restarting control service"
  /opt/icewarp/tool.sh set system C_System_Adv_Ext_SNMPServer 1
  /opt/icewarp/icewarpd.sh --restart control
fi
}

function log()
{
echo $(date +%H:%M:%S) $1 >> ${logfile}
}

# get number of connections for IceWarp service using SNMP
function connstat() # ( service name in smtp,pop,imap,xmpp,grw,http -> number of connections )
{
case "${1}" in
smtp) local conn_smtp_count=$(snmpget -r 2 -t 3 -v 1 -c private ${HOST}:${SNMPPORT} 1.3.6.1.4.1.23736.1.2.1.1.2.8.1 | sed -r 's|^.*INTEGER:\s(.*)$|\1|');
      if [[ ! -z "${conn_smtp_count}" ]]
              then
              echo "${conn_smtp_count}" > ${outputpath}/connstat_smtp.mon;
              else
              echo "99999" > ${outputpath}/connstat_smtp.mon;
      fi
;;
pop)  local conn_pop3_count=$(snmpget -r 2 -t 3 -v 1 -c private ${HOST}:${SNMPPORT} 1.3.6.1.4.1.23736.1.2.1.1.2.8.2 | sed -r 's|^.*INTEGER:\s(.*)$|\1|');
      if [[ ! -z "${conn_pop3_count}" ]]
              then
              echo "${conn_pop3_count}" > ${outputpath}/connstat_pop.mon;
              else
              echo "99999" > ${outputpath}/connstat_pop.mon;
      fi

;;
imap) local conn_imap_count=$(snmpget -r 2 -t 3 -v 1 -c private ${HOST}:${SNMPPORT} 1.3.6.1.4.1.23736.1.2.1.1.2.8.3 | sed -r 's|^.*INTEGER:\s(.*)$|\1|');
      if [[ ! -z "${conn_imap_count}" ]]
              then
              echo "${conn_imap_count}" > ${outputpath}/connstat_imap.mon;
              else
              echo "99999" > ${outputpath}/connstat_imap.mon;
      fi
;;
xmpp) local conn_im_count_server=$(snmpget -r 2 -t 3 -v 1 -c private ${HOST}:${SNMPPORT} 1.3.6.1.4.1.23736.1.2.1.1.2.8.4 | sed -r 's|^.*INTEGER:\s(.*)$|\1|');
      local conn_im_count_client=$(snmpget -r 2 -t 3 -v 1 -c private ${HOST}:${SNMPPORT} 1.3.6.1.4.1.23736.1.2.1.1.2.10.4 | sed -r 's|^.*INTEGER:\s(.*)$|\1|');
      if [[ ! -z "${conn_im_count_server}" ]];then if [[ ! -z "${conn_im_count_client}" ]]
            then
            local conn_im_count=$((${conn_im_count_server} + ${conn_im_count_client}));
            echo "${conn_im_count}" > ${outputpath}/connstat_xmpp.mon;
            else
            echo "99999" > ${outputpath}/connstat_xmpp.mon;
            fi
      fi
;;
grw)  local conn_gw_count=$(snmpget -r 2 -t 3 -v 1 -c private ${HOST}:${SNMPPORT} 1.3.6.1.4.1.23736.1.2.1.1.2.8.5 | sed -r 's|^.*INTEGER:\s(.*)$|\1|');
      if [[ ! -z "${conn_gw_count}" ]]
              then
              echo "${conn_gw_count}" > ${outputpath}/connstat_grw.mon;
              else
              echo "99999" > ${outputpath}/connstat_grw.mon;
      fi
;;
http) local conn_web_count=$(snmpget -r 2 -t 3 -v 1 -c private ${HOST}:${SNMPPORT} 1.3.6.1.4.1.23736.1.2.1.1.2.8.7 | sed -r 's|^.*INTEGER:\s(.*)$|\1|');
      if [[ ! -z "${conn_web_count}" ]]
              then
              echo "${conn_web_count}" > ${outputpath}/connstat_http.mon;
              else
              echo "99999" > ${outputpath}/connstat_web.mon;
      fi
;;
*)    echo "Invalid argument. Use IceWarp service name: smtp, pop, imap, xmpp, grw, http"
;;
esac
}

# get number of mail in server queues
function queuestat() # ( queue name in outg, inc, retr -> number of messages )
{
# get server mail queues paths
local mail_outpath=$(cat /opt/icewarp/path.dat | grep -v retry | grep _outgoing | dos2unix)
[ -z "${mail_outpath}" ] && local mail_outpath=$(/opt/icewarp/tool.sh get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_outgoing/|')
local mail_inpath=$(cat /opt/icewarp/path.dat | grep -v retry | grep _incoming | dos2unix)
[ -z "${mail_inpath}" ] && local mail_inpath=$(/opt/icewarp/tool.sh get system C_System_Storage_Dir_MailPath | sed -r 's|^.*:\s(.*)|\1_incoming/|')
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
local SMTP_RESPONSE="$(echo "QUIT" | nc -w 3 "${HOST}" 25 | egrep -o "^220")"
if [ "${SMTP_RESPONSE}" == "220" ]; then
                        echo "OK" > ${outputpath}/smtpstatus.mon
                          else
                        echo "FAIL" > ${outputpath}/smtpstatus.mon
fi
}

# iw imap server simple check
function imapstat()
{
local IMAP_RESPONSE="$(echo ". logout" | nc -w 3 "${HOST}" 143 | egrep -o "\* OK " | egrep -o "OK")"
if [ "${IMAP_RESPONSE}" == "OK" ]; then
                        echo "OK" > ${outputpath}/imapstatus.mon
                          else
                        echo "FAIL" > ${outputpath}/imapstatus.mon
fi
}

# iw web server simple check
function wcstat()
{
local HTTP_RESPONSE="$(curl -s -k -o /dev/null -w "%{http_code}" -m 5 https://"${HOST}"/webmail/)"
if [ "${HTTP_RESPONSE}" == "200" ]; then
                        echo "OK" > ${outputpath}/httpstatus.mon
                          else
                        echo "FAIL" > ${outputpath}/httpstatus.mon
fi
}

# iw xmpp server simple check
function xmppstat()
{
local XMPP_RESPONSE="$(echo '<?xml version="1.0"?>  <stream:stream to="healthcheck" xmlns="jabber:client" xmlns:stream="http://etherx.jabber.org/streams" version="1.0">' | nc -w 3 "${HOST}" 5222 | egrep -o "^<stream:stream xmlns" |egrep -o "xmlns")"
if [ "${XMPP_RESPONSE}" == "xmlns" ]; then
                        echo "OK" > ${outputpath}/xmppstatus.mon
                          else
                        echo "FAIL" > ${outputpath}/xmppstatus.mon
fi
}

# iw groupware server simple check
function grwstat()
{
local GRW_RESPONSE="$(echo "test" | nc -w 3 "${HOST}" 5229 | egrep -o "<greeting" | egrep -o "greeting")"
if [ "${GRW_RESPONSE}" == "greeting" ]; then
                        echo "OK" > ${outputpath}/grwstatus.mon
                          else
                        echo "FAIL" > ${outputpath}/grwstatus.mon
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
     /opt/icewarp/tool.sh export account "${guestaccemail}" u_name | grep -o ",${guestacclogin}," > /dev/null 2>&1
     local result=$?
     if [[ ${result} != 0 ]]
         then
         /opt/icewarp/tool.sh create account "${guestaccemail}" u_name "${guestacclogin}" u_mailbox "${email}" u_password "${pass}"
     fi
fi
local start=`date +%s%N | cut -b1-13`
# get auth token
local atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>getauthtoken</commandname><commandparams><email>${email}</email><password>${pass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
local wcatoken="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o "<authtoken>(.*)</authtoken>" | sed -r s'|<authtoken>(.*)</authtoken>|\1|')"
# get phpsessid
local wcphpsessid="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL "https://${iwserver}/webmail/?atoken=$( rawurlencode "${wcatoken}" )" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"
# auth wc session
local auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
local wcsid="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${auth_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";
if [[ ${guest} == 0 ]] # test response for standard or teamchat guest account
    then
     # refresh folders standard account start
     local refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${email}\" type=\"set\" format=\"xml\"><query xmlns=\"webmail:iq:accounts\"><account action=\"refresh\" uid=\"${email}\"/></query></iq>"
     local response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o "folder uid=\"INBOX\"")"
     if [[ "${response}" =~ "INBOX" ]];
         then
          local freturn=OK
         else
          local freturn=FAIL
     fi # refresh folders standard account end
    else
     # refresh folders teamchat guest account start
     local refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${guestaccemail}\" type=\"get\" format=\"json\"><query xmlns=\"webmail:iq:folders\"><account uid=\"${guestaccemail}\"/></query></iq>"
     local response="$(curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o "INHERITED_ACL" | head -1)"
     if [[ "${response}" =~ "INHERITED_ACL" ]];
         then
          local freturn=OK
         else
          local freturn=FAIL
     fi # refresh folders teamchat guest account end
fi
# session logout
local logout_request="<iq sid=\"wm-"${wcsid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
curl -s --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${logout_request}" "https://${iwserver}/webmail/server/webmail.php" > /dev/null 2>&1
local end=`date +%s%N | cut -b1-13`
local runtime=$((end-start))
echo "${freturn}" > ${outputpath}/wcstatus.mon;
echo "${runtime}" > ${outputpath}/wcruntime.mon;
}

# iw ActiveSync client login healthcheck
function eascheck() # ( -> status OK, FAIL; time spent in ms )
{
local FOLDER="${EASFOLDER}";
declare DBUSER=$(/opt/icewarp/tool.sh get system C_ActiveSync_DBUser | sed -r 's|^C_ActiveSync_DBUser: (.*)$|\1|')
declare DBPASS=$(/opt/icewarp/tool.sh get system C_ActiveSync_DBPass | sed -r 's|^C_ActiveSync_DBPass: (.*)$|\1|')
read DBHOST DBPORT DBNAME <<<$(/opt/icewarp/tool.sh get system C_ActiveSync_DBConnection | sed -r 's|^C_ActiveSync_DBConnection: mysql:host=(.*);port=(.*);dbname=(.*)$|\1 \2 \3|')
read -r USER aURI aTYPE aVER aKEY <<<$(echo "select * from devices order by last_sync asc\\G" |  mysql -u ${DBUSER} -p${DBPASS} -h ${DBHOST} -P ${DBPORT} ${DBNAME} | tail -24 | egrep "user_id:|uri:|type:|protocol_version:|synckey:" | xargs -n1 -d'\n' | tr -d '\040\011\015\012' | sed -r 's|^user_id:(.*)uri:(.*)type:(.*)protocol_version:(.*)synckey:(.*)$|\1 \2 \3 \4 \5|')
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_DenyExport 0 > /dev/null 2>&1
declare PASS=$(/opt/icewarp/tool.sh export account "${USER}" u_password | sed -r 's|^.*,(.*),$|\1|')
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_DenyExport 1 > /dev/null 2>&1
local aURI="000EASHealthCheck000"
local aTYPE="IceWarpAnnihilator"
declare -i aSYNCKEY=${aKEY};
local start=`date +%s%N | cut -b1-13`
local result=`/usr/bin/curl -s -k -m ${ctimeout} --basic --user "$USER:$PASS" -H "Expect: 100-continue" -H "Host: $HOST" -H "MS-ASProtocolVersion: ${aVER}" -H "Connection: Keep-Alive" -A "${aTYPE}" --data-binary @${scriptdir}/activesync.txt -H "Content-Type: application/vnd.ms-sync.wbxml" "https://$HOST/Microsoft-Server-ActiveSync?User=$USER&DeviceId=$aURI&DeviceType=$aTYPE&Cmd=FolderSync" | strings`
local end=`date +%s%N | cut -b1-13`
local runtime=$((end-start))
if [[ $result == *$FOLDER* ]]
then
local freturn=OK
else
local freturn=FAIL
fi
echo "${freturn}" > ${outputpath}/easstatus.mon;
echo "${runtime}" > ${outputpath}/easruntime.mon;
}

function printStats() {
echo "last value update - service: check result"
for SIMPLECHECK in smtp imap xmpp grw http
    do
    echo -n "$(stat -c'%y' "${outputpath}/${SIMPLECHECK}status.mon") - "
    echo -n "${SIMPLECHECK}: "
    cat "${outputpath}/${SIMPLECHECK}status.mon"
done
for CONNCHECK in smtp imap xmpp http
    do
    echo -n "$(stat -c'%y' "${outputpath}/connstat_${CONNCHECK}.mon") - "
    echo -n "${CONNCHECK}: "
    cat "${outputpath}/connstat_${CONNCHECK}.mon"
done
for QUEUECHECK in inc outg retr
    do
    echo -n "$(stat -c'%y' "${outputpath}/queuestat_${QUEUECHECK}.mon") - "
    echo -n "${QUEUECHECK}: "
    cat "${outputpath}/queuestat_${QUEUECHECK}.mon"
done
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
    checks and installs dependencies
 
    iwmon.sh check_name [ check_parameter ]
    supported health-checks: smtp, imap, xmpp, grw, wc, wclogin ( guest 0/1 parameter ), easlogin
    
    iwmon.sh connstat [ service_name ]
    supported services: smtp, imap, xmpp, grw, http
    
    iwmon.sh queuestat [ smtp_queue_name ]
    available queues: inc ( incoming ), outg ( outgoing ), retr ( outgoing-retry )
    
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
        smtpstat;imapstat;xmppstat;grwstat;wcstat;wccheck "1";eascheck;
        for STATNAME in smtp imap xmpp grw http; do connstat "${STATNAME}";done;
        for QUEUENAME in inc outg retr; do queuestat "${QUEUENAME}";done;
        printStats;
     fi
     if [[ "${2}" == "silent" ]]
        then
        smtpstat;imapstat;xmppstat;grwstat;wcstat;wccheck "1";eascheck;
        for STATNAME in smtp imap xmpp grw http; do connstat "${STATNAME}";done;
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
