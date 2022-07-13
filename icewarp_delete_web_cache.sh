#!/bin/bash
# requires mysql credentials in .my.cnf
email="${1}"
if [[ -z "${1}" ]]; then echo "Requires user email address as a parameter."; exit 1; fi
echo "Cleaning up the webclient cache for [${email}]."
echo "The number of items before the cleanup:"
echo -en "SELECT COUNT(*) AS Items FROM item WHERE folder_id IN (SELECT folder_id FROM folder WHERE account_id = \x27${email}\x27);SELECT COUNT(*) AS Folders FROM folder WHERE account_id = \x27${email}\x27;" | mysql iwwc
echo -en "DELETE FROM item WHERE folder_id IN (SELECT folder_id FROM folder WHERE account_id = \x27${email}\x27);DELETE FROM folder WHERE account_id = \x27${email}\x27;" | mysql iwwc
ret=$?
echo "Cleanup of the webclient cache for [${email}] is completed with result [${ret}]."
echo "The number of items after the cleanup:"
echo -en "SELECT COUNT(*) AS Items FROM item WHERE folder_id IN (SELECT folder_id FROM folder WHERE account_id = \x27${email}\x27);SELECT COUNT(*) AS Folders FROM folder WHERE account_id = \x27${email}\x27;" | mysql iwwc
exit ${ret}
