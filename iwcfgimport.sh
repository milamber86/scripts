#!/bin/bash
cfgImportFile=/root/cfgexport.cf
iw_install_dir=$(cat /etc/icewarp/icewarp.conf | awk -F "\"" '/^IWS_INSTALL_DIR=/ {print $2}')
test="$(head -1 $iw_install_dir/path.dat)";
if [[ ! -z "${test}" ]]
  then
    config_path="$(echo -n ${test} | tr -d '\r')";
  else
    config_path="$iw_install_dir/config";
fi

function setval()
{
prop="${1}";
val="${2}";
"$iw_install_dir/tool.sh" set system ${prop} "${val}" > /dev/null 2>&1
ret=$?
echo "${ret} - ${prop} : ${val}";
}

for I in orderId superPass gwSuperPass accStorageMode mailPath archivePath tempPath logsPath accDbConn dcDbConn gwDbConn asDbConn easDbConn easDbUser easDbPass;
  do
    val="$(egrep "^${I}" "${cfgImportFile}" | awk '{print $2}')";
    case "${I}" in
      orderId) echo "Activate using /opt/icewarp/wizard.sh using OrderID: "${val}""
      ;;
      superPass) setval C_Accounts_Policies_SuperUserPassword "${val}"
      ;;
      gwSuperPass) setval C_GW_SuperPass "${val}"
      ;;
      accStorageMode) setval C_System_Storage_Accounts_StorageMode "${val}"
      ;;
      mailPath) setval C_System_Storage_Dir_MailPath "${val}"
      ;;
      archivePath) setval C_System_Tools_AutoArchive_Path "${val}"
      ;;
      tempPath) setval C_System_Storage_Dir_TempPath "${val}"
      ;;
      logsPath) setval C_System_Storage_Dir_LogPath "${val}"
      ;;
      accDbConn) setval c_system_storage_accounts_odbcconnstring "${val}"
      ;;
      dcDbConn) setval c_accounts_global_accounts_directorycacheconnectionstring "${val}"
      ;;
      gwDbConn) setval c_gw_connectionstring "${val}"
      ;;
      asDbConn) setval c_as_challenge_connectionstring "${val}"
      ;;
      easDbConn) setval C_ActiveSync_DBConnection "${val}"
      ;;
      easDbUser) setval C_ActiveSync_DBUser "${val}"
      ;;
      easDbPass) setval C_ActiveSync_DBPass "${val}"
      ;;
    esac
  done
mv -v "$config_path/_webmail/server.xml" "$config_path/_webmail/server.xml_bak_iwcfgimport_$(date '+%s')"
cp -fv "${cfgImportFile}.web" "$config_path/_webmail/server.xml"
chown icewarp:icewarp "$config_path/_webmail/server.xml"
exit 0
