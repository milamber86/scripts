#!/bin/bash
srcnum="2";
dstnum="1";
rm -f /zstore/qcow/mvlist.txt
zfs create zstore/qcow
cd /zstore/qcow
ssh root@hv${dstnum}.wdc.us.apptocloud.net "zfs create zstore/qcow;zfs create zstore/hv${srcnum}backup"
for I in $(virsh list --all --name); do echo -n "${I};";virsh dumpxml ${I} > /zstore/qcow/${I}.xml && cat /zstore/qcow/${I}.xml | egrep -o "storage([[:digit:]]*)"; done >> /zstore/qcow/mvlist.txt; sed -r -i 's|^(.*)|\1;|' /zstore/qcow/mvlist.txt
# echo "virtual2105;storage1761;" > /zstore/qcow/mvlist.txt # test run with one host
{ while IFS=';' read virtual storage
  do
  sed -r -i "s|dev/zstore/storage|dev/zstore/hv${srcnum}backup/storage|" /zstore/qcow/${virtual}.xml
  scp /zstore/qcow/${virtual}.xml root@hv${dstnum}.wdc.us.apptocloud.net:/zstore/hv${srcnum}backup/
  sed -r -i "s|dev/zstore/hv${srcnum}backup/storage|dev/zstore/storage|" /zstore/qcow/${virtual}.xml
  virsh destroy ${virtual}
  sleep 1
  nice -n 19 qemu-img convert -f raw -O qcow2 -t writeback -m 8 /dev/zstore/${storage} /zstore/qcow/${storage}.qcow2
  sleep 1
  virsh start ${virtual}
  ssh root@hv${dstnum}.wdc.us.apptocloud.net "virsh destroy ${virtual}"
  scp /zstore/qcow/${storage}.qcow2 root@hv${dstnum}.wdc.us.apptocloud.net:/zstore/qcow/${storage}.qcow2 && rm -fv /zstore/qcow/${storage}.qcow2
  if ssh -q root@hv${dstnum}.wdc.us.apptocloud.net stat /zstore/qcow/${storage}.qcow2 \> /dev/null 2\>\&1
       then
       ssh root@hv${dstnum}.wdc.us.apptocloud.net "zfs create -V 200G zstore/hv${srcnum}backup/${storage}"
       ssh root@hv${dstnum}.wdc.us.apptocloud.net "nice -n 19 qemu-img convert -f qcow2 -O raw -t writeback -m 8 /zstore/qcow/${storage}.qcow2 /dev/zstore/hv${srcnum}backup/${storage} && rm -fv /zstore/qcow/${storage}.qcow2"
       ssh root@hv${dstnum}.wdc.us.apptocloud.net "virsh define /zstore/hv${srcnum}backup/${virtual}.xml"
       virsh destroy ${virtual} && ssh root@hv${dstnum}.wdc.us.apptocloud.net "virsh start ${virtual}"
       virsh undefine ${virtual}
       else
       echo "Migration of ${virtual};${storage} failed !"
  fi
  done
} < /zstore/qcow/mvlist.txt
exit 0
