/opt/icewarp/tool.sh set system C_System_Log_Services_SMTP 4
/opt/icewarp/tool.sh set system C_System_Log_Services_POP3 0
/opt/icewarp/tool.sh set system C_System_Log_Services_IMAP 0
/opt/icewarp/tool.sh set system C_System_Log_Services_IM 0
/opt/icewarp/tool.sh set system C_System_Log_Services_GW 0
/opt/icewarp/tool.sh set system C_System_Log_Services_Control 4
/opt/icewarp/tool.sh set system C_System_Log_Services_FTP 0
/opt/icewarp/tool.sh set system C_System_Log_Services_LDAP 0
/opt/icewarp/tool.sh set system C_System_Log_Services_AV 3
/opt/icewarp/tool.sh set system C_System_Log_Services_AS 4
/opt/icewarp/tool.sh set system C_System_Log_Services_SIP 0
/opt/icewarp/tool.sh set system C_System_Log_Services_SMS 0
/opt/icewarp/tool.sh set system C_System_Log_Services_SyncPush 0
/opt/icewarp/tool.sh set system C_System_Log_Services_Socks 0
/opt/icewarp/tool.sh set system C_System_Log_Services_CISCO 0
/opt/icewarp/tool.sh set system C_System_Log_Services_ActiveSync 0
/opt/icewarp/tool.sh set system C_System_Log_Services_WCS 0
/opt/icewarp/tool.sh set system C_System_Log_Services_Meeting 0
/opt/icewarp/tool.sh set system C_System_Log_Services_SyncML 0
/opt/icewarp/tool.sh set system C_System_Log_Services_WebDAV 0
/opt/icewarp/tool.sh set system C_Accounts_Global_Accounts_Maintenancelog 4
/opt/icewarp/tool.sh set system C_Accounts_Global_Accounts_Authlog 4
/opt/icewarp/tool.sh set system C_System_SQLLogType 2
/opt/icewarp/tool.sh set system C_System_Log_Services_DirectoryCache 0
/opt/icewarp/tool.sh set system C_System_Log_MailQueue 0
/opt/icewarp/tool.sh set system C_System_Log_API 0
/opt/icewarp/tool.sh set system C_System_Log_DNS 0
/opt/icewarp/tool.sh set system C_System_Log_Performance_Level 10
/opt/icewarp/tool.sh set system C_System_Log_Performance 10
/opt/icewarp/tool.sh set system C_System_Log_MaxLogSize 512000
/opt/icewarp/tool.sh set system C_System_Logging_General_LogRotation 524288
/opt/icewarp/tool.sh set system C_System_Logging_General_EnableODBCLog 0
/opt/icewarp/tool.sh set system C_System_Logging_General_LogCache 262144
/opt/icewarp/tool.sh set system C_System_Logging_General_EnableStackTrace 1
/opt/icewarp/tool.sh set system C_System_KerberosLogType 0
/opt/icewarp/tool.sh set system C_System_ADSyncLogType 0
/opt/icewarp/tool.sh set system C_System_Logging_General_Experimentalfastlogging 1
echo 'noop' > /sys/block/sda/queue/scheduler
cat /sys/block/sda/queue/scheduler
echo 'vm.swappiness=0' >> /etc/sysctl.conf
sysctl -p
swapoff -va && swapon -va
exit 0
