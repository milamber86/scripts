#!/bin/bash
# requires iw db access without pass, creds in .my.cnf
# full refresh of directory cache suggested after run
userlist=/root/emails_to_move
sourcedom="example1.loc" # source domain name
targetdom="example2.loc" # destination domain name
sourcepath="/mnt/icewarp/mail/example1.loc" # source domain maildir root path
targetpath="/mnt/icewarp/mail/example2.loc" # destination domain maildir root path
accdbname=accounts # accounts database name
grwdbname=groupware # groupware database name
/opt/icewarp/tool.sh create domain "${targetdom}" # create target domain
mkdir -p ${targetpath} # create target maildir path
{ while IFS='\n' read email
        do
	username=$(/opt/icewarp/tool.sh export account ${email} u_mailbox | awk -F ',' '{print $2}');
        from=$(/opt/icewarp/tool.sh export account "${email}" u_fullmailboxpath | awk -F ',' '{print $2}' | sed -r "s|${sourcepath}/(.*)/|${sourcepath}/\1|");
        to=$(/opt/icewarp/tool.sh export account "${email}" u_fullmailboxpath | awk -F ',' '{print $2}' | sed -r "s|${sourcepath}/(.*)/|${targetpath}/\1|");
        if [ -d "${to}" ]; then
                             echo "Not moving ${from}, target path ${to} already exists!"
                             rc1=1
                           else
                             mv -v "${from}" "${to}"
                             rc1=$?
                           fi
        if [ $rc1 -eq 0 ]; then
                             userid=$(echo -e "use ${accdbname};SELECT U_ID FROM Users WHERE U_Mailbox = \x27${username}\x27 AND U_Domain = \x27${sourcedom}\x27;" | mysql | grep -v U_ID);
                             echo -e "use ${accdbname};UPDATE Users SET U_Domain = \x27${targetdom}\x27 WHERE U_ID = ${userid};" | mysql
                             echo -e "use ${accdbname};UPDATE Aliases SET A_Domain = \x27${targetdom}\x27 WHERE A_UserID = ${userid}" | mysql
                             gwownid=$(echo -e "use ${grwdbname};SELECT OWN_ID FROM EventOwner WHERE OWN_Email = \x27${email}\x27;" | mysql | grep -v OWN_ID | awk '{print $1}');
                             gwgrpid=$(echo -e "use ${grwdbname};SELECT GRP_ID FROM EventGroup WHERE GRPOWN_ID = (SELECT OWN_ID FROM EventOwner WHERE OWN_Email = \x27${email}\x27);" | mysql | grep -v GRP_ID | awk '{print $1}')
                             newemail=$(echo -e "${email}" | sed -r "s|${sourcedom}|${targetdom}|");
                             echo -e "use ${grwdbname};UPDATE EventOwner SET OWN_Email = \x27${newemail}\x27 WHERE OWN_ID = \x27${gwownid}\x27" | mysql
                             echo -e "use ${grwdbname};UPDATE EventGroup SET GrpDailyEventsEmail = \x27${newemail}\x27 WHERE GRP_ID = \x27${gwgrpid}\x27" | mysql
                             echo -e "use ${grwdbname};UPDATE EventGroup SET GrpReminderEmail = \x27${newemail}\x27 WHERE GRP_ID = \x27${gwgrpid}\x27" | mysql
                             newmpath=$(/opt/icewarp/tool.sh export account "${newemail}" u_mailboxpath | awk -F ',' '{print $2}' | sed -r "s|${sourcedom}|${targetdom}|")
                             /opt/icewarp/tool.sh set account "${newemail}" u_mailboxpath "${newmpath}"
                             /opt/icewarp/tool.sh set account "${newemail}" u_directorycache_refreshnow	1
                             sed -i -r "s|${sourcedom}|${targetdom}|g" "${to}/~webmail/settings.xml"
	                    fi
        done
} < ${userlist}
/opt/icewarp/icewarpd.sh --restart pop3
exit 0
