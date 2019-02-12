#!/bin/bash
# iw smtp check
smtpstat()
{
SMTP_RESPONSE="$(echo "QUIT" | nc -w 3 127.0.0.1 25 | egrep -o "^220")"
if [ "${SMTP_RESPONSE}" == "220" ]; then
                        echo "OK" > /opt/icewarp/var/smtpstatus.mon
                          else
                        echo "FAIL" > /opt/icewarp/var/smtpstatus.mon
fi
}
# iw imap check
imapstat()
{
IMAP_RESPONSE="$(echo ". logout" | nc -w 3 127.0.0.1 143 | egrep -o "\* OK " | egrep -o "OK")"
if [ "${IMAP_RESPONSE}" == "OK" ]; then
                        echo "OK" > /opt/icewarp/var/imapstatus.mon
                          else
                        echo "FAIL" > /opt/icewarp/var/imapstatus.mon
fi
}
# iw webclient check
wcstat()
{
HTTP_RESPONSE="$(curl -s -k -o /dev/null -w "%{http_code}" -m 3 https://127.0.0.1/webmail/)"
if [ "${HTTP_RESPONSE}" == "200" ]; then
                        echo "OK" > /opt/icewarp/var/httpstatus.mon
                          else
                        echo "FAIL" > /opt/icewarp/var/httpstatus.mon
fi
}
# iw xmpp client check
xmppstat()
{
XMPP_RESPONSE="$(echo '<?xml version="1.0"?>  <stream:stream to="healthcheck" xmlns="jabber:client" xmlns:stream="http://etherx.jabber.org/streams" version="1.0">' | nc -w 3 127.0.0.1 5222 | egrep -o "^<stream:stream xmlns" |egrep -o "xmlns")"
if [ "${XMPP_RESPONSE}" == "xmlns" ]; then
                        echo "OK" > /opt/icewarp/var/xmppcstatus.mon
                          else
                        echo "FAIL" > /opt/icewarp/var/xmppcstatus.mon
fi
}
# iw groupware server check
grwstat()
{
GRW_RESPONSE="$(echo "test" | nc -w 3 127.0.0.1 5229 | egrep -o "<greeting" | egrep -o "greeting")"
if [ "${GRW_RESPONSE}" == "greeting" ]; then
                        echo "OK" > /opt/icewarp/var/grwstatus.mon
                          else
                        echo "FAIL" > /opt/icewarp/var/grwstatus.mon
fi
}
### MAIN
smtpstat
imapstat
grwstat
xmppstat
wcstat
exit 0
