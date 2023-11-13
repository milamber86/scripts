#!/bin/bash

iw_install_dir=$(cat /etc/icewarp/icewarp.conf | awk -F "\"" '/^IWS_INSTALL_DIR=/ {print $2}')
cfgExportFile=/root/cfgexport.cf
iwtool="$iw_install_dir/tool.sh"

mv -fv "${cfgExportFile}" "${cfgExportFile}_bak.$(date)"
if [[ -f "$iw_install_dir/path.dat" ]]; then
    test="$(head -1 $iw_install_dir/path.dat)";
    if [[ ! -z "${test}" ]]; then
        config_path="$(echo -n ${test} | tr -d '\r')";
       else
        config_path="$iw_install_dir/config";
    fi
fi

orderId="$(${iwtool} get system C_License | egrep -o "<header><purchaseid>(.*)</purchaseid>" | sed -r 's|<header><purchaseid>(.*)</purchaseid>|\1|')"
superPass="$(${iwtool} get system C_Accounts_Policies_SuperUserPassword | awk '{print $2}')"
gwSuperPass="$(${iwtool} get system C_GW_SuperPass | awk '{print $2}')"
accStorageMode="$(${iwtool} get system C_System_Storage_Accounts_StorageMode | awk '{print $2}')"
mailPath="$(${iwtool} get system C_System_Storage_Dir_MailPath | awk '{print $2}')"
archivePath="$(${iwtool} get system C_System_Tools_AutoArchive_Path | awk '{print $2}')"
tempPath="$(${iwtool} get system C_System_Storage_Dir_TempPath | awk '{print $2}')"
logsPath="$(${iwtool} get system C_System_Storage_Dir_LogPath | awk '{print $2}')"
accDbConn="$(${iwtool} get system c_system_storage_accounts_odbcconnstring | awk '{print $2}')"
dcDbConn="$(${iwtool} get system c_accounts_global_accounts_directorycacheconnectionstring | awk '{print $2}')"
gwDbConn="$(${iwtool} get system c_gw_connectionstring | awk '{print $2}')"
asDbConn="$(${iwtool} get system c_as_challenge_connectionstring | awk '{print $2}')"
easDbConn="$(${iwtool} get system C_ActiveSync_DBConnection | awk '{print $2}')"
easDbUser="$(${iwtool} get system C_ActiveSync_DBUser | awk '{print $2}')"
easDbPass="$(${iwtool} get system C_ActiveSync_DBPass | awk '{print $2}')"

for I in orderId superPass gwSuperPass accStorageMode mailPath archivePath tempPath logsPath accDbConn dcDbConn gwDbConn asDbConn easDbConn easDbUser easDbPass;
  do
    eval ref=\$${I};
    echo -e "${I} ${ref}" >> ${cfgExportFile};
    echo -e "${I} ${ref}";
  done
cat "${config_path}/_webmail/server.xml" | tee ${cfgExportFile}.web

exit 0
