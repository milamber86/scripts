#!/bin/bash
srcnum="7";
dstnum="3";
srcprefix="hv3backup/";
dstprefix="";
UUID="$(cat /proc/sys/kernel/random/uuid)";
rm -f /zstore/qcow/mvlist.txt
zfs create zstore/qcow
ssh root@hv${dstnum}.wdc.us.apptocloud.net "zfs create zstore/qcow"
[[ ! -z "${dstprefix}" ]] && ssh root@hv${dstnum}.wdc.us.apptocloud.net "zfs create zstore${dstprefix}"
for I in $(virsh list --all --name); do echo -n "${I};";virsh dumpxml ${I} > /zstore/qcow/${I}.xml && cat /zstore/qcow/${I}.xml | egrep -o "storage([[:digit:]]*)"; done >> /zstore/qcow/mvlist.txt; sed -r -i 's|^(.*)|\1;|' /zstore/qcow/mvlist.txt
#echo "virtual2044;storage1700;" > /zstore/qcow/mvlist.txt # test run with one host
{ while IFS=';' read virtual storage
  do
  sed -r -i "s|dev/zstore/${srcprefix}storage|dev/zstore${dstprefix}/storage|" /zstore/qcow/${virtual}.xml
  scp /zstore/qcow/${virtual}.xml root@hv${dstnum}.wdc.us.apptocloud.net:/zstore/qcow/${virtual}.xml
  sed -r -i "s|dev/zstore${dstprefix}/storage|dev/zstore/${srcprefix}storage|" /zstore/qcow/${virtual}.xml
  if zfs snap zstore/${srcprefix}${storage}@mvstart-${UUID} 
    then
    zfs send -Rv zstore/${srcprefix}${storage}@mvstart-${UUID} | mbuffer -s 512k -m 1G | ssh -c aes128-gcm@openssh.com hv${dstnum}.wdc.us.apptocloud.net "mbuffer -q -s 512k -m 1G | zfs receive -Fv zstore${dstprefix}/${storage}"
    sleep 1
    virsh destroy ${virtual}
    virsh dumpxml ${virtual} > ${virtual}_bak.xml
    virsh undefine ${virtual}
    zfs snap zstore/${srcprefix}${storage}@mvend-${UUID} && zfs send -I @mvstart-${UUID} zstore/${srcprefix}${storage}@mvend-${UUID} | mbuffer -s 512k -m 1G | ssh -c aes128-gcm@openssh.com hv${dstnum}.wdc.us.apptocloud.net "mbuffer -q -s 512k -m 1G | zfs receive -Fv zstore${dstprefix}/${storage}"
    ssh root@hv${dstnum}.wdc.us.apptocloud.net "virsh define /zstore/qcow/${virtual}.xml"
    ssh root@hv${dstnum}.wdc.us.apptocloud.net "virsh start ${virtual}"
    fi
  done
} < /zstore/qcow/mvlist.txt
exit 0
