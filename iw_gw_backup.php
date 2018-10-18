<!-- START OF GROUPWARE BACKUP SCRIPT -->
<!--
Exports each accounts groupware data to an individual xml file located in variable $saveto location
Exports all accounts on the server.
For Icewarp V10 - 24 October 2010 by Bulldust. Free to use

To restore a user's groupware data, first delete using the administration console delete groupware data
function and use the restore function in the console to restore the groupware data using the backup xml file

-->
<?php
//INVOKE API'S
$root_api = new COM('IceWarpServer.apiObject');
if (!$root_api) {
echo "Root API couldn't be invoked";
return;
}
$account_api = new COM('IceWarpServer.AccountObject');
if (!$account_api) {
echo "Account API couldn't be invoked";
return;
}
$root_api->DoLog(0,3,"SCRIPT","Individual Groupware Backup started...",1);
ob_start(); $stamp=date("d M Y H:i");echo "<h2> Groupware Backup for $stamp</h2>";?>
<style>
table{
width: 50%;font-family: verdana;border-width: 0 0 1px 1px;
border-spacing: 0;border-collapse: collapse;border-style: solid;
border-color: #A4C357;font-size: 12px;margin:0px 0px 25px 0px;
}
th{
background-color:#98bf21;color: #fff;font-weight: bold;padding: 2px;
border-width: 1px 1px 0 0;border-style: solid;border-color: white;
}

td{
padding: 2px;border-width: 1px 1px 0 0;border-style: solid;border-color: #A4C357;
}
</style>
<?php

//Login as Superuser to backup all system accounts
$gwsuperuser = $root_api->GetProperty("C_GW_SuperUser");
$gwsuperpass = $root_api->GetProperty('C_GW_SuperPass');
$sessionid = icewarp_calendarfunctioncall('Loginuser', $gwsuperuser, $gwsuperpass);

$acc_array = array(0 => "User", 1 => "Mailing List", 2 => "Executable", 3 =>"Notification", 4 => "Static Route",
5 => "Catalog", 6 => "List Server", 7 =>"Group", 8 => "Resource");

//Loop through all domains and backup each account - all account types
$domCount = $root_api->GetDomainCount();
for ($i = 0; $i < $domCount; $i++) {
$domain = $root_api->OpenDomain($root_api->GetDomain($i));
$domain = $domain->Name;

echo "<table cellspacing='0'><thead><tr ><th colspan='3'><span style='color:black;'>Domain: $domain</span>
</th></tr> <tr ><th>Account</th><th>Type</th><th>Backup Status</th></tr></thead>";

if ($account_api->FindInit($domain)) {
while ($account_api->FindNext()) {
$acc_type = $account_api->getProperty("u_type");
$acc_type = $acc_array[$acc_type];
$alias = explode(";", $account_api->getProperty("U_alias"));
$username = $alias[0] . "@" . $domain;
// Edit date formats and file locations if need be
$month_yr = date("M_Y");
$stamp = date("d_M_Y_H_i");
$date = date("d_M_Y");
/**********************************DETAILS TO CHANGE IF REQUIRED**************************************************/
$saveto = "F:/IceWarp/groupware_backup/".$month_yr."/".$date."/".$domain."/"; //Save location of individual gwbackup files
$logFile = $saveto . "groupwarebackup_" . $domain . "_" . $date . ".log";//Save location of individual gwbackup log
$html_log = "F:/IceWarp/groupware_backup/".$month_yr."/".$date."/gwbackuplog_".$date.".htm"; //Save location of main gwbackup log
/*****************************************************************************************************************/
if (!file_exists($saveto))
mkdir($saveto, 0777, true);
// Check to see whether log file exists.create one if it doesnt otherwise append
if (file_exists($logFile))
$gwbackuplog = fopen($logFile, "a");
else
$gwbackuplog = fopen($logFile, "w");
$exportuser = icewarp_calendarfunctioncall('Exportdata', $sessionid, $username);
//Export User's groupware data to xml file
if ($exportuser) {
//save file with username and date
if (file_put_contents($saveto.$username."_".$stamp."_".$acc_type.".xml",$exportuser)) {
echo "<tr><td align='center'>$username</td><td align='center'>$acc_type</td><td align='center'>OK</td> </tr>";
fwrite($gwbackuplog, "$username - $acc_type - OK \r\n");
} else {
echo "<span style='font-family:verdana;color:red;'><b>$username : Save Error - Cannot Save File to $saveto </b></span><br/>";
fwrite($gwbackuplog, "$username : Save Error - Cannot Save File to $saveto \r\n");
}
} else {
echo "<tr bgcolor='#ffebe8'><td align='center'>$username</td><td align='center'>$acc_type</td><td align='center'>ERROR</td> </tr>";
fwrite($gwbackuplog, "$username - $acc_type - ERROR \r\n");
}
}
$account_api->FindDone();
}
echo "<tr> <th colspan='3'> Domain: $domain Complete </th> </tr>";
fwrite($gwbackuplog, "***** Domain: $domain - Complete ***** \r\n");
}
echo "</table>";
$completed = date("d M Y H:i");
echo "<h2> Groupware Backup Complete $completed</h2>";
file_put_contents($html_log, ob_get_contents(),FILE_APPEND); // save main gwbackup log file (all domains) in html format
//do cleanups. logout superuser, end buffering, close files and reset array
icewarp_calendarfunctioncall('logoutuser', $sessionid);
ob_end_flush();
fclose($gwbackuplog);
unset($acc_type);
$root_api->DoLog(0,3,"SCRIPT","Individual Groupware Backup completed",1);
?>
<!-- END OF GROUPWARE BACKUP SCRIPT -->
