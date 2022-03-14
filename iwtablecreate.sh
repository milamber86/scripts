#!/bin/bash
# takes DB auth strings from cfgexport.cf and creates IceWarp DB tables
iw_install_dir=$(cat /etc/icewarp/icewarp.conf | awk -F "\"" '/^IWS_INSTALL_DIR=/ {print $2}')
cfgExportFile=/root/cfgexport.cf
iwtool="$iw_install_dir/tool.sh"
iwd="$iw_install_dir/icewarpd.sh"
# directory cache
$iwtool create tables 4 "$(grep dcDbConn "$cfgExportFile" | awk '{print $2}')"
# accounts
$iwtool create tables 0 "$(grep accDbConn "$cfgExportFile" | awk '{print $2}')"
# antispam
$iwtool create tables 3 "$(egrep ^asDbConn "$cfgExportFile" | awk '{print $2}')"
# ActiveSync
easUser="$(grep easDbUser "$cfgExportFile" | awk '{print $2}')"; > /dev/null 2>&1
easPass="$(grep easDbPass "$cfgExportFile" | awk '{print $2}')"; > /dev/null 2>&1
easDbName="$(grep easDbConn "$cfgExportFile" | awk '{print $2}'| sed -r 's|.*dbname=(.*)$|\1|')"; > /dev/null 2>&1
easHost="$(grep easDbConn "$cfgExportFile" | awk '{print $2}'| sed -r 's|.*host=(.*);port=.*$|\1|')"; > /dev/null 2>&1
easPort="$(grep easDbConn "$cfgExportFile" | awk '{print $2}'| sed -r 's|.*port=(.*);dbname=.*$|\1|')"; > /dev/null 2>&1
easDbConnString="${easDbName};${easUser};${easPass};${easHost}:${easPort};3;2";
$iwtool create tables 6 "${easDbConnString}"
$iwd --restart all
# groupware
$iwtool create tables 2 "$(grep gwDbConn "$cfgExportFile" | awk '{print $2}')"
exit 0
