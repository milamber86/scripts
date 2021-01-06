<?php
    if( file_exists ( '/opt/icewarp/var/wcstatus.mon.OK' )) {
          exit("OK");}
    else {
          header('HTTP/1.1 500 Internal Server Error');
          exit("FAIL");
    }
?>
