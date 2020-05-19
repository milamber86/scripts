<?php

define('SHAREDLIB_PATH',get_cfg_var('icewarp_sharedlib_path'));
include_once SHAREDLIB_PATH.'api/api.php';


$api = IceWarpAPI::instance('tool/invalidate');
$result = $api->CacheFileWithUpdate('$argv[1]');

print_r($result);

?>
