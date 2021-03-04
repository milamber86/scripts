cfgImportFile=/root/cfgexport.cf
function setval()
{
prop="${1}";
val="${2}";
echo -n "Setting ${prop} = ${val} ..";
/opt/icewarp/tool.sh set system ${prop} "${val}"
return $?
}

for I in orderId superPass gwSuperPass accStorageMode mailPath archivePath tempPath logsPath accDbConn dcDbConn gwDbConn asDbConn easDbConn easDbUser easDbPass;
  do
    val="$(egrep "${I}" "${cfgImportFile}" | awk '{print $2}')";
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
mv -v "/opt/icewarp/config/_webmail/server.xml" "/opt/icewarp/config/_webmail/server.xml_bak_iwcfgimport_$(date '+%s')"
cp -fv "${cfgImportFile}.web" /opt/icewarp/config/_webmail/server.xml
exit 0
