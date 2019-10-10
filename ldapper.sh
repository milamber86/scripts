#!/usr/bin/env bash
#
if ! mkdir /tmp/ldapper.lock; then
    printf "Failed to acquire lock.\n" >&2
    exit 1
fi
trap 'rm -rf /tmp/ldapper.lock' EXIT  # remove the lockdir on exit
#
MY_PATH="`( cd \"$MY_PATH\" && pwd )`"  # absolutized and normalized
if [ -z "$MY_PATH" ] ; then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
  exit 1  # fail
fi
#
ldapsearch -x -h 10.234.134.30 -D "CN=LDAP,OU=Users,OU=Services,DC=MyTEST,DC=com" -y <(cat "${MY_PATH}"/.pass.txt | tr -d '\n\r') -b "OU=RO,OU=Test,DC=MyTEST,DC=com" -s sub '(&(objectClass=user)(mail=*@sub.domain.com)(!(UserAccountControl:1.2.840.113556.1.4.803:=2))(memberof=CN=ro_icewarp_full_users_uat,OU=UserGroups,OU=RO,OU=Test,DC=MyTEST,DC=com))' mail -E pr=1000/noprompt > /root/full_usr.txt
for USR in $(grep "^mail: " "${MY_PATH}"/full_usr.txt | sed -r 's|^mail: ||')
  do
    STR=`grep ${USR} "${MY_PATH}"/full_usr_done.txt`
    if [ "${USR}" != "${STR}" ]
      then
      /opt/icewarp/tool.sh set account "${USR}" u_authmode 2
      echo "${USR}" >> "${MY_PATH}"/full_usr_done.txt
    fi
  done
ldapsearch -x -h 10.234.134.30 -D "CN=LDAP,OU=Users,OU=Services,DC=MyTEST,DC=com" -y <(cat "${MY_PATH}"/.pass.txt | tr -d '\n\r') -b "OU=RO,OU=Test,DC=MyTEST,DC=com" -s sub '(&(objectClass=user)(mail=*@sub.domain.com)(!(UserAccountControl:1.2.840.113556.1.4.803:=2))(memberof=CN=ro_icewarp_light_users_uat,OU=UserGroups,OU=RO,OU=Test,DC=MyTEST,DC=com))' mail -E pr=1000/noprompt > /root/light_usr.txt
for USR in $(grep "^mail: " "${MY_PATH}"/light_usr.txt | sed -r 's|^mail: ||')
  do
    STR=`grep ${USR} "${MY_PATH}"/light_usr_done.txt`
    if [ "${USR}" != "${STR}" ]
      then
      /opt/icewarp/tool.sh set account "${USR}" u_im 0
      /opt/icewarp/tool.sh set account "${USR}" u_gw 0
      /opt/icewarp/tool.sh set account "${USR}" u_sip 0
      /opt/icewarp/tool.sh set account "${USR}" u_syncml 0
      /opt/icewarp/tool.sh set account "${USR}" u_ftp 0
      /opt/icewarp/tool.sh set account "${USR}" u_sms 0
      /opt/icewarp/tool.sh set account "${USR}" u_activesync 0
      /opt/icewarp/tool.sh set account "${USR}" u_webdav 0
      /opt/icewarp/tool.sh set account "${USR}" u_archive 0
      /opt/icewarp/tool.sh set account "${USR}" u_client_connector 0
      /opt/icewarp/tool.sh set account "${USR}" u_client_desktop 0
      /opt/icewarp/tool.sh set account "${USR}" u_meeting 0
      /opt/icewarp/tool.sh set account "${USR}" u_teamchat 0
      /opt/icewarp/tool.sh set account "${USR}" u_webdocuments 0
      /opt/icewarp/tool.sh set account "${USR}" u_cisco 0
      echo "${USR}" >> "${MY_PATH}"/light_usr_done.txt
    fi
  done
exit 0
