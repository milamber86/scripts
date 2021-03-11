#!/bin/bash
# run on node node1 keydbinstall.sh "<IP node 1>" "<IP node 2>" "<IP keepalived VIP>" "<interface name, ie: eth0 or ens192>"
# set keepalived priotity 98 and swap its unicast peers for node2
IPnode1="${1}";
IPnode2="${2}";
IPVIP="${3}";
VIPifname="${4}";
keydbPass="$(tr -cd '[:alnum:]' < /dev/urandom | fold -w12 | head -n1)";
keepalivedPass="$(tr -cd '[:alnum:]' < /dev/urandom | fold -w12 | head -n1)"

### keydb
yum -y update
yum -y install vim rsync
rpm --import https://download.keydb.dev/packages/rpm/RPM-GPG-KEY-keydb
yum -y install https://download.keydb.dev/packages/rpm/centos7/x86_64/keydb-latest-1.el7.x86_64.rpm
cp -v /etc/keydb/keydb.conf /etc/keydb/keydb.conf_bak
cat > /etc/keydb/keydb.conf << 'EOL'
bind 0.0.0.0
port 6379
requirepass ${keydbPass}
masterauth ${keydbPass}
multi-master yes
active-replica yes
replica-read-only no
replicaof ${IPnode2} 6379
dbfilename dump.rdb
dir /var/lib/keydb/
daemonize yes
pidfile /var/run/keydb/keydb-server.pid
EOL

systemctl enable keydb
systemctl start keydb
systemctl status keydb

### haproxy
LATEST_HAPROXY=$(wget -qO-  http://www.haproxy.org/download/2.0/src/ | egrep -o "haproxy-2\.[0-9]+\.[0-9]+" | head -1)
cd /usr/src/
wget http://www.haproxy.org/download/2.0/src/${LATEST_HAPROXY}.tar.gz
tar xzvf ${LATEST_HAPROXY}.tar.gz
yum install gcc-c++ openssl-devel pcre-static pcre-devel systemd-devel -y
cd /usr/src/${LATEST_HAPROXY}
make TARGET=linux-glibc USE_PCRE=1 USE_OPENSSL=1 USE_ZLIB=1 USE_CRYPT_H=1 USE_LIBCRYPT=1 USE_SYSTEMD=1
mkdir /etc/haproxy
make install
cat > /usr/lib/systemd/system/haproxy.service << 'EOL'
[Unit]
Description=HAProxy Load Balancer
After=syslog.target network.target

[Service]
Environment="CONFIG=/etc/haproxy/haproxy.cfg" "PIDFILE=/run/haproxy.pid"
ExecStartPre=/usr/local/sbin/haproxy -f $CONFIG -c -q
ExecStart=/usr/local/sbin/haproxy -Ws -f $CONFIG -p $PIDFILE
ExecReload=/usr/local/sbin/haproxy -f $CONFIG -c -q
ExecReload=/bin/kill -USR2 $MAINPID
KillMode=mixed
Restart=always
SuccessExitStatus=143
Type=notify

[Install]
WantedBy=multi-user.target
EOL

cat > /etc/haproxy/haproxy.cfg << 'EOL'
global
user haproxy
group haproxy

defaults KEYDB
mode tcp
timeout connect 3s
timeout server 6s
timeout client 6s

listen mykeydb
    bind *:9736
    maxconn 40000
    mode tcp
    balance first
    option tcplog
    option tcp-check
    tcp-check send AUTH\ ${keydbPass}\r\n
    tcp-check expect string +OK
    tcp-check send PING\r\n
    tcp-check expect string +PONG
    tcp-check send info\ replication\r\n
    tcp-check expect string role:active-replica
    tcp-check send QUIT\r\n
    tcp-check expect string +OK
    server node1 ${IPnode1}:6379 check inter 100ms
    server node2 ${IPnode2}:6379 check inter 100ms
EOL

systemctl enable haproxy
systemctl start haproxy
systemctl status haproxy

### keepalived
yum -y install keepalived
mv -v /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf_bak
cat > /etc/keepalived/keepalived.conf << 'EOL'
vrrp_instance VIP_1 {
    state MASTER
    interface ${VIPifname}
    virtual_router_id 101
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass ${keepalivedPass}
    }

   unicast_src_ip ${IPnode1}     # Unicast specific option, this is the IP of the interface keepalived listens on
   unicast_peer {                # Unicast specific option, this is the IP of the peer instance
     ${IPnode2}
   }

    virtual_ipaddress {
        ${IPVIP}
    }
}
EOL

systemctl enable keepalived
systemctl start keepalived
systemctl status keepalived
exit 0
