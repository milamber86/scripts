#!/bin/sh

#  iwmon.sh
#  icewarp monitoring for zabbix
#
#  Created by Otto Beranek on 15/02/2020.
#
#VARS
HOST="127.0.0.1";                                            # monitored host IP/hostname
ctimeout=30;                                                 # check timeout
EASFOLDER="INBOX";                                           # folder to search in the foldersync response ( eas login check )
scriptdir="$(cd $(dirname $0) && pwd)"
logdate="$(date +%Y%m%d)"
logfile="${scriptdir}/iwmon_${logdate}.log"
email="wczabbixmon@example.loc";                             # email address, standard user must exist, guest user will be created by this script if it does not exist
pass="somepass";                                             # password
outputpath="/opt/icewarp/var";                               # results output path

#FUNC
# install deps
installdeps()
{
utiltest="$(/usr/bin/find /usr/lib64 -type f -name "Entities.pm")"
if [[ -z "${utiltest}" ]]
  then
  log "Installing Entities.pm"
  /usr/bin/yum -y install epel-release
  /usr/bin/yum -y install perl-HTML-Encoding.noarch
fi
utiltest="$(which curl)"
if [[ "${utiltest}" == *"no curl in"* ]]
  then
  log "Installing curl"
  /usr/bin/yum -y install curl
fi
utiltest="$(which nc)"
if [[ "${utiltest}" == *"no nc in"* ]]
  then
  log "Installing nc"
  /usr/bin/yum -y install nc
fi
}

# log function
log()
{
echo $(date +%H:%M:%S) $1 >> ${logfile}
}

# iw smtp server simple check
smtpstat()
{
SMTP_RESPONSE="$(echo "QUIT" | nc -w 3 "${HOST}" 25 | egrep -o "^220")"
if [ "${SMTP_RESPONSE}" == "220" ]; then
                        echo "OK" > ${outputpath}/smtpstatus.mon
                          else
                        echo "FAIL" > ${outputpath}/smtpstatus.mon
fi
}

# iw imap server simple check
imapstat()
{
IMAP_RESPONSE="$(echo ". logout" | nc -w 3 "${HOST}" 143 | egrep -o "\* OK " | egrep -o "OK")"
if [ "${IMAP_RESPONSE}" == "OK" ]; then
                        echo "OK" > ${outputpath}/imapstatus.mon
                          else
                        echo "FAIL" > ${outputpath}/imapstatus.mon
fi
}

# iw web server simple check
wcstat()
{
HTTP_RESPONSE="$(curl -s -k -o /dev/null -w "%{http_code}" -m 5 https://"${HOST}"/webmail/)"
if [ "${HTTP_RESPONSE}" == "200" ]; then
                        echo "OK" > ${outputpath}/httpstatus.mon
                          else
                        echo "FAIL" > ${outputpath}/httpstatus.mon
fi
}

# iw xmpp server simple check
xmppstat()
{
XMPP_RESPONSE="$(echo '<?xml version="1.0"?>  <stream:stream to="healthcheck" xmlns="jabber:client" xmlns:stream="http://etherx.jabber.org/streams" version="1.0">' | nc -w 3 "${HOST}" 5222 | egrep -o "^<stream:stream xmlns" |egrep -o "xmlns")"
if [ "${XMPP_RESPONSE}" == "xmlns" ]; then
                        echo "OK" > ${outputpath}/xmppcstatus.mon
                          else
                        echo "FAIL" > ${outputpath}/xmppcstatus.mon
fi
}

# iw groupware server simple check
grwstat()
{
GRW_RESPONSE="$(echo "test" | nc -w 3 "${HOST}" 5229 | egrep -o "<greeting" | egrep -o "greeting")"
if [ "${GRW_RESPONSE}" == "greeting" ]; then
                        echo "OK" > ${outputpath}/grwstatus.mon
                          else
                        echo "FAIL" > ${outputpath}/grwstatus.mon
fi
}

# urlencode string
rawurlencode() {
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
wccheck() # ( guest 0/1 -> OK, FAIL; time spent in ms )
{
local guest=${1}
local iwserver="${HOST}"
if [[ ${guest} != 0 ]] # generate guest account email, test if guest account exists, if not, create one
    then
     guestaccemail="$(echo ${email} | sed -r s'|(.*)\@(.*)|\1_\2\@##internalservicedomain.icewarp.com##|')"  # generate teamchat guest account email
     guestacclogin="$(echo ${email} | sed -r s'|(.*)\@(.*)|\1|')"
     /opt/icewarp/tool.sh export account "${guestaccemail}" u_name | grep -o ",${guestacclogin},"
     result=$?
     if [[ ${result} != 0 ]]
         then
         /opt/icewarp/tool.sh create account "${guestaccemail}" u_name "${guestacclogin}" u_mailbox "${email}" u_password "${pass}"
     fi
fi
local start=`date +%s%N | cut -b1-13`
# get auth token
local atoken_request="<iq uid=\"1\" format=\"text/xml\"><query xmlns=\"admin:iq:rpc\" ><commandname>getauthtoken</commandname><commandparams><email>${email}</email><password>${pass}</password><digest></digest><authtype>0</authtype><persistentlogin>0</persistentlogin></commandparams></query></iq>"
local wcatoken="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${atoken_request}" "https://${iwserver}/icewarpapi/" | egrep -o "<authtoken>(.*)</authtoken>" | sed -r s'|<authtoken>(.*)</authtoken>|\1|')"
# get phpsessid
local wcphpsessid="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL "https://${iwserver}/webmail/?atoken=$( rawurlencode "${wcatoken}" )" | egrep -o "PHPSESSID_LOGIN=(.*); path=" | sed -r 's|PHPSESSID_LOGIN=wm(.*)\; path=|\1|' | head -1 | tr -d '\n')"
# auth wc session
local auth_request="<iq type=\"set\"><query xmlns=\"webmail:iq:auth\"><session>wm"${wcphpsessid}"</session></query></iq>"
local wcsid="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${auth_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o 'iq sid="(.*)" type=' | sed -r s'|iq sid="wm-(.*)" type=|\1|')";
if [[ ${guest} == 0 ]] # test response for standard or teamchat guest account
    then
     # refresh folders standard account start
     refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${email}\" type=\"set\" format=\"xml\"><query xmlns=\"webmail:iq:accounts\"><account action=\"refresh\" uid=\"${email}\"/></query></iq>"
     response="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o "folder uid=\"INBOX\"")"
     if [[ "${response}" =~ "INBOX" ]];
         then
          local freturn=OK
         else
          local freturn=FAIL
     fi # refresh folders standard account end
    else
     # refresh folders teamchat guest account start
     refreshfolder_request="<iq sid=\"wm-"${wcsid}"\" uid=\"${guestaccemail}\" type=\"get\" format=\"json\"><query xmlns=\"webmail:iq:folders\"><account uid=\"${guestaccemail}\"/></query></iq>"
     response="$(curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${refreshfolder_request}" "https://${iwserver}/webmail/server/webmail.php" | egrep -o "INHERITED_ACL" | head -1)"
     if [[ "${response}" =~ "INHERITED_ACL" ]];
         then
          local freturn=OK
         else
          local freturn=FAIL
     fi # refresh folders teamchat guest account end
fi
# session logout
logout_request="<iq sid=\"wm-"${wcsid}"\" type=\"set\"><query xmlns=\"webmail:iq:auth\"/></iq>"
curl --connect-timeout ${ctimeout} -m ${ctimeout} -ikL --data-binary "${logout_request}" "https://${iwserver}/webmail/server/webmail.php"
local end=`date +%s%N | cut -b1-13`
local runtime=$((end-start))
echo "${freturn} ${runtime}"
}

# iw ActiveSync client login healthcheck
eascheck() # ( -> status OK, FAIL; time spent in ms )
{
local FOLDER="${EASFOLDER}";
declare DBUSER=$(/opt/icewarp/tool.sh get system C_ActiveSync_DBUser | sed -r 's|^C_ActiveSync_DBUser: (.*)$|\1|')
declare DBPASS=$(/opt/icewarp/tool.sh get system C_ActiveSync_DBPass | sed -r 's|^C_ActiveSync_DBPass: (.*)$|\1|')
read DBHOST DBPORT DBNAME <<<$(/opt/icewarp/tool.sh get system C_ActiveSync_DBConnection | sed -r 's|^C_ActiveSync_DBConnection: mysql:host=(.*);port=(.*);dbname=(.*)$|\1 \2 \3|')
read -r USER aURI aTYPE aVER aKEY <<<$(echo "select * from devices order by last_sync asc\\G" |  mysql -u ${DBUSER} -p${DBPASS} -h ${DBHOST} -P ${DBPORT} ${DBNAME} | tail -24 | egrep "user_id:|uri:|type:|protocol_version:|synckey:" | xargs -n1 -d'\n' | tr -d '\040\011\015\012' | sed -r 's|^user_id:(.*)uri:(.*)type:(.*)protocol_version:(.*)synckey:(.*)$|\1 \2 \3 \4 \5|')
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_DenyExport 0
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_AllowAdminPass 1
declare PASS=$(/opt/icewarp/tool.sh export account "${USER}" u_password | sed -r 's|^.*,(.*),$|\1|')
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_DenyExport 1
/opt/icewarp/tool.sh set system C_Accounts_Policies_Pass_AllowAdminPass 0

aURI="000EASHealthCheck000"
aTYPE="IceWarpAnnihilator"
declare -i aSYNCKEY=${aKEY};

start=`date +%s%N | cut -b1-13`
result=`/usr/bin/curl -k -m ${ctimeout} --basic --user "$USER:$PASS" -H "Expect: 100-continue" -H "Host: $HOST" -H "MS-ASProtocolVersion: ${aVER}" -H "Connection: Keep-Alive" -A "${aTYPE}" --data-binary @/root/activesync.txt -H "Content-Type: application/vnd.ms-sync.wbxml" "https://$HOST/Microsoft-Server-ActiveSync?User=$USER&DeviceId=$aURI&DeviceType=$aTYPE&Cmd=FolderSync" | strings`
end=`date +%s%N | cut -b1-13`
runtime=$((end-start))

if [[ $result == *$FOLDER* ]]
then
local freturn=OK
else
local freturn=FAIL
fi
echo "${freturn} ${runtime}"
}

#MAIN
installdeps
case ${1} in
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
wclogin) wccheck > ${outputpath}/wclogin.mon;
;;
easlogin) eascheck > ${outputpath}/easlogin.mon;
;;
*) echo -e 'Invalid command. Usage: iwmon.sh "<check_name>" "<optional: check_parameter>"\n Available checks: smtp, imap, xmpp, grw, wc, wclogin ( guest 0/1 ), easlogin'
;;
esac
exit 0
