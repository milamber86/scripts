<?php

try{
    $s = new SoapClient("http://smsgw.internet.fo/SendSMS/SendSMS.asmx?wsdl");

    $params = array("from"          => $_GET["from"],
                    "to"            => $_GET["to"],
                    "text"          => $_GET["text"],
                    "media_code"    => "mccode",
                    "user_name"     => "username",
                    "user_password" => "pass");

    print_r($s->sendSms($params));

}catch(SoapFault $e){
    print_r($e);
}

?>
