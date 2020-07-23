#!/bin/bash
ldapcheck="$(ldapsearch -x -D 'user@ldap.domain' -w 'ldap password' -b "dc=base,dc=dn" -H ldap://1.2.3.4 | grep 'user@ldap.domain')";
pattern='user@ldap.domain';
if [[ "${ldapcheck}" =~ "${pattern}" ]]
  then
  echo OK
  else
  echo FAIL
fi
exit 0
