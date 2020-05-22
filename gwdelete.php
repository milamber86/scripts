<?

define('SHAREDLIB_PATH',get_cfg_var('icewarp_sharedlib_path'));
require_once(SHAREDLIB_PATH.'system.php');
slSystem::import('api/gw');
$api = IceWarpAPI::instance('tool/groupware/export');
$gwapi = new IceWarpGWAPI();

$gwapi->user = $api->GetProperty('C_GW_SuperUser');
$gwapi->setPassword( $api->GetProperty('C_GW_SuperPass') );
$gwapi->Login();

echo $gwapi->FunctionCall("DeleteOwner",$gwapi->sessid,$argv[1],1);

?>
