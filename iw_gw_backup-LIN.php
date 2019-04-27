<?php
//  * Exports each accounts groupware data to an individual xml file located in variable  location 
//  * Exports all accounts on the server. 
//  * For IceWarp Server v10+
//  * Inspired by script from 24th October 2010 by Bulldust.
//  * Written in the begging of March 2014 by Alan_6k8, Free to use and modify
//  * To restore a user's groupware data, first delete using the current data using the administration console
//  * then use the restore function in the console to restore the groupware data using the backup xml file
//  *
//  * zavolat fci pres:
//  * 
//  * /opt/icewarp/scripts/php.sh -c /opt/icewarp/php/php.ini -f /path/to/migrate_gw.php user@domain
//  * 
//  * Uvnitr skriptu nastavit vychozi hodnoty pro remote DB. Lokalni DB se bere z GW configu lokalniho IW serveru, ze ktereho bezi skript.
//  * 
//  * 
//  * Export_gw.php a Import_gw.php jsou podobne. Vola se:
//  * 
//  * Export
//  * /opt/icewarp/scripts/php.sh -c /opt/icewarp/php/php.ini -f /path/to/export_gw.php [domain.com] /path/to/output.xml
//  * 
//  * (domena je v hranatych zavorkach)
//  * 
//  * 
//  * 
//  * Stejne tak import
//  * 
//  * /opt/icewarp/scripts/php.sh -c /opt/icewarp/php/php.ini -f /path/to/import_gw.php /path/to/output.xml
//  * 
//  * 
//
define( 'DS', DIRECTORY_SEPARATOR );
define( 'SHAREDLIB_PATH', get_cfg_var( 'icewarp_sharedlib_path' ) );

# include IceWarp SharedLib framework PHP API layers (server, account)
include_once (SHAREDLIB_PATH . 'api/api.php');
include_once (SHAREDLIB_PATH . 'api/account.php');

# --- CONF ---
# set to true in order to view debug information on STDOUT
define( 'DEBUG_MODE', false );

# defines LINE_BREAK constat, the value is used in output (use '<br>' for HTML browser, PHP_EOL for CLI)
# this constant can be usefull for debugging as it affect debugging output only
define( 'LINE_BREAK', '<br>' );

# semi-colon separated list of accounts to backup - use * to backup everyone, @yourdomain.com to backup whole domain
$cfgProcessAccount = '*';
# $cfgProcessAccount = '@ad.icewarp.in;lion@icewarp.in;vladimir.sulc@xmigrator.com;andrea@icewarp.in;';

# define how to select accounts for backup
# 1 - will get all accounts (any type)
# 2 - will get accounts of type user only
# 3 - will get accounts of type user, group and resource that are not disabled
$cfgAccountSelectMode = 3;

# base directory for backups - must end with directory separator! (you can use ' = "some dir" . DS;' too)
$cfgBackupStore = "/data/icewarp_other/backup/groupware_backup/";

# 1st level sort directory
$cfgBackupStoreL1 = date( 'Y' );

# 2st level sort directory
$cfgBackupStoreL2 = date( 'm' );

# 3st level sort directory
$cfgBackupStoreL3 = date( 'd_Hi' );

# file name of html log file
$cfgHTMLLogFile = 'gwbackuplog_' . date( 'dmYHi' ) . '.html';

# file name of plain text log file
# you could modify plain text log output format to be CSV suitable for futher automated processing
$cfgPlainLogFile = 'gwbackuplog_' . date( 'dmYHi' ) . '.log';

# save location of individual gwbackup files (directory only), file name is generated from <domain>/<account_email>
# this option does not need to be modified, do so only if you know what you are doing
$cfgXMLExportStore = $cfgBackupStore . $cfgBackupStoreL1 . DS . $cfgBackupStoreL2 . DS . $cfgBackupStoreL3 . DS;

# date format used in logs (text content only not file names)  
$cfgTimestampFormat = 'l jS \of F Y H:i:s';

# if you don't have correct TZ set in php.ini, please use the line below in order to have correct server time/date in the logs
//date_default_timezone_set( 'Etc/GMT-6' );



# --- CLASS ---
class iwServerAPIWorker
{
	private $sid = null;
	private $gid = null;
	private $APIHandler = '';
	private $superuser;
	private $superpass;

	public function __construct()
	{
		// IW PHP API init
		if ( !$this->APIHandler = new IceWarpAPI() )
			die( '[CRITICAL] Server API could not be initialized.' );
		
		$server_api = &$this->APIHandler;
		
		// get superuser credentials from server API
		$this->superuser = $server_api->GetProperty( 'C_GW_SuperUser' );
		$this->superpass = $server_api->GetProperty( 'C_GW_SuperPass' );
	}

	public function __destruct()
	{
		$this->LogoutUser();
	}

	public function LogoutUser()
	{
		$sid = &$this->sid;
		if ( !empty( $sid ) )
		{
			$result = icewarp_calendarfunctioncall( "logoutuser", $sid );
			if ( $result )
			{
				$sid = null;
				return true;
			}
			else
				return false;
		}
	}

	public function OpenSuperSession()
	{
		return $this->OpenSession( $this->superuser, $this->superpass, null );
	}

	private function OpenSession( $email, $password, $substitute_entity )
	{
		$flgError = 0;
		
		# it is not possible to revert the session ($sid) back to superuser
		# relog is needed each time after substituteuser is called as only superuser can use substituteuser function
		$this->sid = icewarp_calendarfunctioncall( 'loginuser', $email, $password );
		empty( $this->sid ) ? $flgError += 1 : null;
		
		if ( $substitute_entity )
		{
			$result = icewarp_calendarfunctioncall( 'substituteuser', $this->sid, $substitute_entity );
			if ( !$result )
			{
				printf( '[ERROR] Failed to substitute user %s.', $substitute_entity );
				$flgError += 2;
			}
		}
		
		$this->gid = icewarp_calendarfunctioncall( 'opengroup', $this->sid, '*' );
		empty( $this->gid ) ? $flgError += 4 : null;
		
		if ( DEBUG_MODE )
			echo 'Open session result: ' . $flgError . LINE_BREAK;
		
		$flgError ? $ret = false : $ret = true;
		return $ret;
	}

	public function __call( $method, $params )
	{
		return $this->APIHandler->FunctionCall( $method, isset( $params[0] ) ? $params[0] : null, isset( $params[1] ) ? $params[1] : null, isset( $params[2] ) ? $params[2] : null, isset( $params[3] ) ? $params[3] : null, isset( $params[4] ) ? $params[4] : null );
	}

	public function ExportUserGWData( $email )
	{
		$ret = icewarp_calendarfunctioncall( 'Exportdata', $this->sid, $email );
		return $ret;
	}
}

class iwAccountWorker
{
	private $APIHandler = '';

	public function __construct()
	{
		// IW PHP API init
		if ( !$this->APIHandler = new IceWarpAccount() )
			die( '[CRITICAL] Account API could not be initialized.' );
	}

	public function __destruct()
	{
		// destructor
	}

	public function GetAccountListFromSet( $param )
	{
		$query = '';
		$ret = array();
		foreach ( $param as $domain => $aliases )
		{
			$mailbox = array();
			foreach ( $aliases as $alias )
			{
				if ( empty( $alias ) )
				{
					$ret[$domain] = $this->GetAccountList( ACC_SELECT_MODE, $domain );
					continue 2;
				}
				if ( $this->APIHandler->Open( $alias . '@' . $domain ) )
				{
					$mailbox[] = $this->GetAccountData();
				}
			}
			$ret[$domain] = $mailbox;
		}
		return $ret;
	}

	public function GetAccountList( $mode, $domain_name = false )
	{
		$mode = (int)$mode;
		if ( $mode > 0 && empty( $domain_name ) )
			return false;
			
			# this function is an example of GetDomainAccount method power
			# here we will get accounts of user type only because of the additional query used
			# you can write query which would select only not disabled user accounts
		switch ( $mode )
		{
			case 0 :
				// will get all server accounts
				$ret = $this->GetServerAccounts( '', '' );
				break;
			case 1 :
				// will get all accounts in domain $domain_name
				$ret = $this->GetServerAccounts( $domain_name, '' );
				break;
			case 2 :
				// will get accounts of type user in the domain $domain_name
				$ret = $this->GetServerAccounts( $domain_name, 'U_Type=0' );
				break;
			case 3 :
				// will get accounts of type user, group and resource in the domain $domain_name that are not disabled 
				$ret = $this->GetServerAccounts( $domain_name, '(U_Type=0 or U_Type=7 or U_Type=8) and U_AccountDisabled=0' );
				break;
			default :
				return false;
		}
		if ( DEBUG_MODE )
			echo 'entities found by GetAccountList: ' . count( $ret ) . LINE_BREAK;
		
		return $ret;
	}

	private function GetServerAccounts( &$domain_name, $query )
	{
		# This function let you loop through all accounts in the domain. 
		# You can even loop thru all users on the mail server. In such case the $domain_name must be empty. 
		# All accounts of the server will be returned then.
		$mailbox = array();
		$handler = &$this->APIHandler;
		
		if ( $handler->FindInitQuery( $domain_name, $query ) )
		{
			while ( $handler->FindNext() )
			{
				$mailbox[] = $this->GetAccountData();
			}
		}
		$handler->FindDone();
		
		empty( $mailbox ) ? $ret = false : $ret = &$mailbox;
		
		return $ret;
	}

	private function GetAccountData()
	{
		$handler = &$this->APIHandler;
		$ret = array();
		
		# customize the data you want to learn by adding more lines with GetProperty('<property_name>');
		# if glue used in implode function can be present in data read, escape it!
		# example: $ret[] = str_replace(',', '\\,', $handler->GetProperty('u_name') );
		$ret[] = $handler->EmailAddress;
		$ret[] = $handler->GetProperty( 'U_type' );
		
		return implode( ',', $ret );
	}
}

class iwGWExportScript
{
	private static $HTMLLog = ''; // 0x1
	private static $PlainTextLog = ''; // 0x2

	public static function AccountTypeAsText( $index )
	{
		$hashtable = array( 0 => "User", 1 => "Mailing List", 2 => "Executable", 3 => "Notification", 4 => "Static Route", 5 => "Catalog", 6 => "List Server", 7 => "Group", 8 => "Resource" );
		return $hashtable[$index];
	}

	public static function ParseAccountData( $data )
	{
		$ret = array();
		$a = explode( ',', $data );
		
		foreach ( $a as $property )
		{
			// unescape glue character used in $data
			$ret[] = str_replace( '\\,', ',', $property );
		}
		return $ret;
	}

	public static function LogAppend( $value, $flgTarget = 2 )
	{
		$flgTarget & 1 ? self::$PlainTextLog .= $value : null;
		$flgTarget & 2 ? self::$HTMLLog .= $value : null;
	}

	public static function LogGet( $flgTarget )
	{
		if ( $flgTarget == 1 )
			return self::$PlainTextLog;
		if ( $flgTarget == 2 )
			return self::$HTMLLog;
		
		if ( DEBUG_MODE )
			echo 'LogGet called with wrong target flag:' . $flgTarget . LINE_BREAK;
		return false;
	}

	public static function PrepareStore( $file_name )
	{
		// prepares save location
		$path_parts = pathinfo( $file_name );
		$save_dir = $path_parts['dirname'];
		if ( !file_exists( $save_dir ) )
			return mkdir( $save_dir, 0777, true );
		else
			return true;
	}

	public static function SaveLogToFile( $file_name, $flgTarget )
	{
		$data_link = self::LogGet( $flgTarget );
		// exit function if there's nothing to save
		if ( empty( $data_link ) )
		{
			// DEBUG_MODE output could be added here
			return false;
		}
		
		if ( !self::PrepareStore( $file_name ) )
			return false;
			
			// append to existing file or create a new one, use exclusive lock
		$ret = file_put_contents( $file_name, $data_link, FILE_APPEND | LOCK_EX );
		
		if ( DEBUG_MODE )
			printf( 'SaveLogToFile written %s bytes to file: %s %s', $ret, $file_name, LINE_BREAK );
		
		$ret === false ? null : $ret = true;
		return $ret;
	}
}

function parseListToArray( &$list, $delimiter = ';' )
{
	$ret = array();
	$ret = explode( $delimiter, $list );
	
	$last = array_pop( $ret );
	if ( !empty( $last ) )
		$ret[] = $last;
	
	return $ret;
}


# --- MAIN ---
define( 'ACC_SELECT_MODE', $cfgAccountSelectMode );
$timestamp = date( $cfgTimestampFormat );
$root_api = new iwServerAPIWorker();
$account_api = new iwAccountWorker();
$cfgProcessAccount == '*' ? (int)$flgMode = 1 : (int)$flgMode = 2;
$account_list = array();
$root_api->DoLog( 0, 3, "SCRIPT", "Individual Groupware Backup started...", 1 );

// open groupware session as superuser as required by Exportdata API method
$root_api->OpenSuperSession();

if ( $flgMode & 1 )
{
	$domain = parseListToArray( $root_api->GetDomainList() );
	// get list of accounts in all domains
	foreach ( $domain as $domain_name )
	{
		# see GetAccountList( $mode, $domain ) method definition for info on modes (or define your own)
		$account_list[$domain_name] = $account_api->GetAccountList( ACC_SELECT_MODE, $domain_name );
		
		if ( DEBUG_MODE )
			printf( 'Processing domain: %s %s Accounts found: %s %2$s', $domain_name, LINE_BREAK, print_r( $account_list[$domain_name], true ) );
	}
}
else
{
	// parse list of users into array ($list[$domain] = array(<alias1>, <alias2>)) 
	$i = 0;
	$account_list = parseListToArray( $cfgProcessAccount );
	foreach ( $account_list as $account )
	{
		list ( $alias, $domain_name ) = explode( '@', $account, 2 );
		$account_query[$domain_name][$i] = $alias;
		$i++;
	}
	$account_list = $account_api->GetAccountListFromSet( $account_query );
}

$s = <<<END
<h2>Groupware Backup from {$timestamp}</h2>
<style>
table {
	width: 50%;
	font-family: verdana;
	border-width: 0 0 1px 1px;
	border-spacing: 0;
	border-collapse: collapse;
	border-style: solid;
	border-color: #A4C357;
	font-size: 12px;
	margin: 0 0 24px 0;
}

th {
	background-color: #417D1D;
	color: #fff;
	font-weight: bold;
	padding: 2px;
	border-width: 1px 1px 0 0;
	border-style: solid;
	border-color: white;
	text-align: center;
}

td {
	padding: 2px 0 2px 12px;
	border-width: 1px 1px 0 0;
	border-style: solid;
	border-color: #417D1D;
	text-align: left;
.error {
	color: red;
}
}
</style>
END;
iwGWExportScript::LogAppend( $s );

// walk through all domains/accounts and backup each account
foreach ( $account_list as $domain => $accounts )
{
	$s = sprintf( '<table cellspacing="0"><tr><th colspan="3" >Processing domain: %s</th></tr>
			 <tr><th>Account</th><th>Type</th><th>Backup Status</th></tr></thead>', $domain );
	iwGWExportScript::LogAppend( $s );
	foreach ( $accounts as $account_data )
	{
		# extend this list as needed, depends on data collected see iwAccountWorker::GetAccountData();
		list ( $account, $acc_type ) = iwGWExportScript::ParseAccountData( $account_data );
		$acc_type = iwGWExportScript::AccountTypeAsText( $acc_type );
		$export_data = $root_api->ExportUserGWData( $account );
		if ( $export_data )
		{
			//save file with username and date
			$export_file_name = $cfgXMLExportStore . $domain . DS . $account . '.xml';
			if ( iwGWExportScript::PrepareStore( $export_file_name ) && file_put_contents( $export_file_name, $export_data ) )
			{
				$s = sprintf( '<tr><td>%s</td><td>%s</td><td>OK</td></tr>', $account, $acc_type );
				iwGWExportScript::LogAppend( $s );
				iwGWExportScript::LogAppend( "$account - $acc_type - OK" . PHP_EOL, 1 );
			}
			else
			{
				$s = sprintf( '<tr><td>%s</td><td></td><td class="error">Save Error</td></tr>', $account );
				iwGWExportScript::LogAppend( $s );
				iwGWExportScript::LogAppend( "$account : Save Error - Cannot Save File to $export_file_name" . PHP_EOL, 1 );
			}
		}
		else
		{
			$s = sprintf( '<tr><td>%s</td><td>%s</td><td class="error">Export Error</td></tr>', $account, $acc_type );
			iwGWExportScript::LogAppend( $s );
			iwGWExportScript::LogAppend( "$account - $acc_type - ERROR" . PHP_EOL, 1 );
		}
	}
	iwGWExportScript::LogAppend( sprintf( '<tr><th colspan="3">Completed domain: %s</th></tr>', $domain ) );
	iwGWExportScript::LogAppend( "***** Domain: $domain - Completed *****" . PHP_EOL, 1 );
}

iwGWExportScript::LogAppend( sprintf( '</table><h2> Groupware Backup Complete %s</h2>', $timestamp ) );

// save main gwbackup log file (all domains) in html (flag 0x2) format
iwGWExportScript::SaveLogToFile( $cfgXMLExportStore . $cfgHTMLLogFile, 2 );

// save main gwbackup log file (all domains) in plain text (flag 0x1) format
iwGWExportScript::SaveLogToFile( $cfgXMLExportStore . $cfgPlainLogFile, 1 );

// log end of this script to IceWarp Server log
$root_api->DoLog( 0, 3, "SCRIPT", "Individual Groupware Backup completed", 1 );
?>
