#!/bin/bash
# takes DB auth strings from cfgexport.cf and creates IceWarp DB tables
# directory cache
/opt/icewarp/tool.sh create tables 4 "$(grep dcDbConn cfgexport.cf | awk '{print $2}')"
# accounts
/opt/icewarp/tool.sh create tables 0 "$(grep accDbConn cfgexport.cf | awk '{print $2}')"
# antispam
/opt/icewarp/tool.sh create tables 3 "$(egrep ^asDbConn cfgexport.cf | awk '{print $2}')"
# ActiveSync
easUser="$(grep easDbUser cfgexport.cf | awk '{print $2}')"; > /dev/null 2>&1
easPass="$(grep easDbPass cfgexport.cf | awk '{print $2}')"; > /dev/null 2>&1
easDbName="$(grep easDbConn cfgexport.cf | awk '{print $2}'| sed -r 's|.*dbname=(.*)$|\1|')"; > /dev/null 2>&1
easHost="$(grep easDbConn cfgexport.cf | awk '{print $2}'| sed -r 's|.*host=(.*);port=.*$|\1|')"; > /dev/null 2>&1
easPort="$(grep easDbConn cfgexport.cf | awk '{print $2}'| sed -r 's|.*port=(.*);dbname=.*$|\1|')"; > /dev/null 2>&1
easDbConnString="${easDbName};${easUser};${easPass};${easHost}:${easPort};3;2";
/opt/icewarp/tool.sh create tables 6 "${easDbConnString}"
/opt/icewarp/icewarpd.sh --restart all
# groupware
/opt/icewarp/tool.sh create tables 2 "$(grep gwDbConn cfgexport.cf | awk '{print $2}')"
exit 0
