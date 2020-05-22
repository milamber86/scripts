<?
define('SHAREDLIB_PATH',get_cfg_var('icewarp_sharedlib_path'));
require_once(SHAREDLIB_PATH.'system.php');
slSystem::import('api/gw');

$api = IceWarpAPI::instance('tool/groupware/export');
$gwapi = new IceWarpGWAPI();
$list = $argv[1]?$argv[1]:'*';
$filename = $argv[2]?$argv[2]:'groupware.xml';

$gwapi->user = $api->GetProperty('C_GW_SuperUser');
$gwapi->setPassword( $api->GetProperty('C_GW_SuperPass') );
$gwapi->Login();

$data = $gwapi->FunctionCall("ExportData",$gwapi->sessid,$list);
echo file_put_contents($filename,$data);

?>
