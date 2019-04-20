<?
define('SHAREDLIB_PATH',get_cfg_var('icewarp_sharedlib_path'));
require_once(SHAREDLIB_PATH.'system.php');
slSystem::import('api/gw');

$api = IceWarpAPI::instance('tool/groupware/export');
$gwapi = new IceWarpGWAPI();
$filename = $argv[1]?$argv[1]:'groupware.xml';

$gwapi->user = $api->GetProperty('C_GW_SuperUser');
$gwapi->pass = $api->GetProperty('C_GW_SuperPass');
$gwapi->Login();

echo $gwapi->FunctionCall("ImportData",$gwapi->sessid,file_get_contents($filename));


?>
