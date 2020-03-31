<?php
    if( exec('grep OK /opt/icewarp/var/wcstatus.mon')) {
          exit("OK");}
    else {
          header('HTTP/1.1 500 Internal Server Error');
          exit("FAIL");
    }
?>
