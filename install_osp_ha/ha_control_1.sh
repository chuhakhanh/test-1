 =================================================== Support  ==============================================================
ps -fH --ppid 2
ps -fH --ppid 1
systemctl list-unit-files -t service 
systemctl -t service |grep running
ss -tupln
cat /etc/keystone/keystone.conf |grep -v "#" |grep .
SHOW GLOBAL STATUS LIKE 'wsrep_%';
SHOW GLOBAL STATUS LIKE 'wsrep_last%';
sed -i 's/enforcing/disabled/g' /etc/selinux/config

OS_TOKEN=$(openstack token issue -f value -c id)
curl -s -H "X-Auth-Token: $OS_TOKEN" http://control1:8778/ |  python -m json.tool 
curl -s -H "X-Auth-Token: $OS_TOKEN" http://vip:8778/ |  python -m json.tool 
curl http://vip:5672 |  python -m json.tool 
sudo route add default gw 10.1.0.1


curl -s -H "X-Auth-Token: $OS_TOKEN" http://vip:8778/ |  python -m json.tool   
curl -vv -d '{"auth":{"passwordCredentials":{"username": "admin", "password": "adminpassword"}}}' -H "Content-type: application/json" http://vip:5000/v2.0/tokens | python -m json.tool

sudo watch 'ovs-ofctl dump-flows br-tun|grep -v n_packets=0|sed -r "s/\S+//2"|sed -r "s/\S+//5"| sed -r "s/\S+//1"'
sudo watch 'ovs-ofctl dump-flows br-int|grep -v n_packets=0|sed -r "s/\S+//2"|sed -r "s/\S+//5"| sed -r "s/\S+//1"'
 =================================================== Centos 7 ==============================================================

=====================================NTP

yum -y install ntp ntpdate 
mv /etc/ntp.conf /etc/ntp.conf.org
echo "restrict default kod nomodify notrap nopeer noquery" >> /etc/ntp.conf
echo "restrict -6 default kod nomodify notrap nopeer noquery" >> /etc/ntp.conf
echo "restrict 127.0.0.1" >> /etc/ntp.conf
echo "server 0.asia.pool.ntp.org" >> /etc/ntp.conf
ntpdate -u -s 0.asia.pool.ntp.org
systemctl restart ntpd.service
systemctl enable ntpd.service
systemctl status ntpd.service
timedatectl set-local-rtc 0
timedatectl
timedatectl
date


===================================== IP

public network = 10.1.0.0/16
osd pool default size = 2

/etc/hosts

# gfs2
10.1.17.12      node2
10.1.17.14      node4

# ceph
10.1.17.20      packstack
10.1.17.21      osd1
10.1.17.22      osd2
10.1.17.23      osd3
10.1.17.24      mon1
10.1.17.25      admin

# ha control
10.1.17.101      control1
10.1.17.102      control2
10.1.17.103      control3
10.1.17.104      lb1
10.1.17.105      lb2
10.1.17.106      vip
10.1.17.17      compute2
10.1.17.15  network2
10.1.17.18      compute3

192.168.126.13 network3.tun 
192.168.126.15 network2.tun
192.168.126.17 compute2.tun
192.168.126.18 compute3.tun

# vm

# kvm 70-90
10.1.17.70 kvm_vm1




timedatectl set-timezone Asia/Saigon
yum -y install centos-release-openstack-rocky

sed 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config 
chkconfig firewalld off
echo "nameserver 8.8.8.8">> /etc/resolv.conf
hostnamectl set-hostname control1
systemctl stop firewalld


 =================================================== Galera MariaDB ==============================================================

yum --enablerepo=centos-openstack-rocky -y install mariadb-server galera

cat /etc/yum.repos.d/mariadb.repo 
cat /etc/my.cnf.d/server.cnf

[root@control1 ~]# mysql -V
mysql  Ver 15.1 Distrib 10.3.15-MariaDB, for Linux (x86_64) using readline 5.1



vi /etc/my.cnf.d/server.cnf

[mysqld]
character-set-server=utf8
# default value 151 is not enough on Openstack Env
max_connections=500

[galera]
bind-address=0.0.0.0
binlog_format=ROW
default-storage-engine=innodb
innodb_autoinc_lock_mode=2

# Mandatory settings
wsrep_on=ON
wsrep_provider=/usr/lib64/galera/libgalera_smm.so
wsrep_cluster_address=gcomm://10.1.17.101,10.1.17.102,10.1.17.103


wsrep_cluster_name=”db_clu_1”
wsrep_node_address=”10.1.17.101"
wsrep_node_name=”control1"
wsrep_sst_method=rsync

**

bind-address=0.0.0.0
# Mandatory settings
wsrep_on=ON
wsrep_provider=/usr/lib64/galera/libgalera_smm.so
wsrep_cluster_address=gcomm://10.1.17.101,10.1.17.102,10.1.17.103


wsrep_cluster_name=db_clu_1
wsrep_node_address=10.1.17.102
wsrep_node_name=control2
wsrep_sst_method=rsync

**

bind-address=0.0.0.0
# Mandatory settings
wsrep_on=ON
wsrep_provider=/usr/lib64/galera/libgalera_smm.so
wsrep_cluster_address=gcomm://10.1.17.101,10.1.17.102,10.1.17.103


wsrep_cluster_name=db_clu_1
wsrep_node_address=10.1.17.103
wsrep_node_name=control3
wsrep_sst_method=rsync

=======================================

galera_new_cluster
systemctl start mariadb
systemctl enable mariadb.service
systemctl status mariadb
mysql_secure_installation
mysql -u root -p
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'Admin@123';

===================

# Fix error cannot start cluster
vi /var/lib/mysql/grastate.dat
=> safe_to_bootstrap: 1
galera_new_cluster
systemctl start mariadb
systemctl enable mariadb.service

ss -tupln | grep mysql
tcp    LISTEN     0      128       *:4567                  *:*                   users:(("mysqld",pid=2088,fd=11))
tcp    LISTEN     0      80       :::3306                 :::*                   users:(("mysqld",pid=2088,fd=29))

SET GLOBAL general_log=1;
SET GLOBAL general_log_file='mariadb.log';

systemctl restart mariadb
 =================================================== RabbitMQ ==============================================================



yum --enablerepo=centos-openstack-stein -y install rabbitmq-server
systemctl status rabbitmq-server
scp /var/lib/rabbitmq/.erlang.cookie root@control2:/var/lib/rabbitmq/
scp /var/lib/rabbitmq/.erlang.cookie root@control3:/var/lib/rabbitmq/


chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
chmod 400 /var/lib/rabbitmq/.erlang.cookie
systemctl enable rabbitmq-server
systemctl start  rabbitmq-server
rabbitmqctl stop_app
rabbitmqctl join_cluster --ram rabbit@control1
rabbitmqctl start_app
rabbitmqctl cluster_status


[
	{
		nodes,
		[
			{
				disc,
					[
						rabbit@control1
					
					]
			}
			,
			{
				ram,
					[
						rabbit@control3,
						rabbit@control2
					]
			}
		]
	},
	{
		alarms,
		[
		{
			rabbit@control1,[]}
		]
	}
 ]
 
 rabbitmqctl set_policy ha-all '^(?!amq\.).*' '{"ha-mode": "all"}'
 
 
 
[root@control1 ~(keystone)]#  rabbitmq-plugins list
 Configured: E = explicitly enabled; e = implicitly enabled
 | Status:   * = running on rabbit@control1
 |/
[  ] amqp_client                       3.6.16
[  ] cowboy                            1.0.4
[  ] cowlib                            1.0.2
[  ] rabbitmq_amqp1_0                  3.6.16
[  ] rabbitmq_auth_backend_ldap        3.6.16
[  ] rabbitmq_auth_mechanism_ssl       3.6.16
[  ] rabbitmq_consistent_hash_exchange 3.6.16
[  ] rabbitmq_event_exchange           3.6.16
[  ] rabbitmq_federation               3.6.16
[  ] rabbitmq_federation_management    3.6.16
[  ] rabbitmq_jms_topic_exchange       3.6.16
[  ] rabbitmq_management               3.6.16
[  ] rabbitmq_management_agent         3.6.16
[  ] rabbitmq_management_visualiser    3.6.16
[  ] rabbitmq_mqtt                     3.6.16
[  ] rabbitmq_random_exchange          3.6.16
[  ] rabbitmq_recent_history_exchange  3.6.16
[  ] rabbitmq_sharding                 3.6.16
[  ] rabbitmq_shovel                   3.6.16
[  ] rabbitmq_shovel_management        3.6.16
[  ] rabbitmq_stomp                    3.6.16
[  ] rabbitmq_top                      3.6.16
[  ] rabbitmq_tracing                  3.6.16
[  ] rabbitmq_trust_store              3.6.16
[  ] rabbitmq_web_dispatch             3.6.16
[  ] rabbitmq_web_mqtt                 3.6.16
[  ] rabbitmq_web_mqtt_examples        3.6.16
[  ] rabbitmq_web_stomp                3.6.16
[  ] rabbitmq_web_stomp_examples       3.6.16
[  ] sockjs                            0.3.4
[root@control1 ~(keystone)]# ss -tupln |grep 15672
[root@control1 ~(keystone)]# rabbitmq-plugins enable rabbitmq_management 
The following plugins have been enabled:
  amqp_client
  cowlib
  cowboy
  rabbitmq_web_dispatch
  rabbitmq_management_agent
  rabbitmq_management

Applying plugin configuration to rabbit@control1... started 6 plugins.
[root@control1 ~(keystone)]#  rabbitmq-plugins list                      
 Configured: E = explicitly enabled; e = implicitly enabled
 | Status:   * = running on rabbit@control1
 |/
[e*] amqp_client                       3.6.16
[e*] cowboy                            1.0.4
[e*] cowlib                            1.0.2
[  ] rabbitmq_amqp1_0                  3.6.16
[  ] rabbitmq_auth_backend_ldap        3.6.16
[  ] rabbitmq_auth_mechanism_ssl       3.6.16
[  ] rabbitmq_consistent_hash_exchange 3.6.16
[  ] rabbitmq_event_exchange           3.6.16
[  ] rabbitmq_federation               3.6.16
[  ] rabbitmq_federation_management    3.6.16
[  ] rabbitmq_jms_topic_exchange       3.6.16
[E*] rabbitmq_management               3.6.16
[e*] rabbitmq_management_agent         3.6.16
[  ] rabbitmq_management_visualiser    3.6.16
[  ] rabbitmq_mqtt                     3.6.16
[  ] rabbitmq_random_exchange          3.6.16
[  ] rabbitmq_recent_history_exchange  3.6.16
[  ] rabbitmq_sharding                 3.6.16
[  ] rabbitmq_shovel                   3.6.16
[  ] rabbitmq_shovel_management        3.6.16
[  ] rabbitmq_stomp                    3.6.16
[  ] rabbitmq_top                      3.6.16
[  ] rabbitmq_tracing                  3.6.16
[  ] rabbitmq_trust_store              3.6.16
[e*] rabbitmq_web_dispatch             3.6.16
[  ] rabbitmq_web_mqtt                 3.6.16
[  ] rabbitmq_web_mqtt_examples        3.6.16
[  ] rabbitmq_web_stomp                3.6.16
[  ] rabbitmq_web_stomp_examples       3.6.16
[  ] sockjs                            0.3.4
[root@control1 ~(keystone)]# ss -tupln |grep 15672                       
tcp    LISTEN     0      128       *:15672                 *:*                   users:(("beam.smp",pid=1351,fd=94)) 


[root@control1 ~]# rabbitmqctl add_user openstack password 
Creating user "openstack"
[root@control1 ~]# rabbitmqctl set_permissions openstack ".*" ".*" ".*" 
Setting permissions for user "openstack" in vhost "/"

rabbitmqctl add_user admin admin123
rabbitmqctl set_user_tags admin administrator
rabbitmqctl set_permissions -p / admin ".*" ".*" ".*"

 =================================================== Keepalived ==============================================================
yum install keepalived
vi /etc/sysctl.conf
net.ipv4.ip_nonlocal_bind=1
sysctl -p	

vi /etc/keepalived/keepalived.conf 


vrrp_script chk_haproxy {
	script "killall -0 haproxy" # check the haproxy process
	interval 2 # every 2 seconds
	weight 2 # add 2 points if OK
}

vrrp_instance VI_1 {
	interface ens192 # interface to monitor
	state MASTER # MASTER on haproxy1, BACKUP on haproxy2
	virtual_router_id 51
	priority 101 # 101 on haproxy1, 100 on haproxy2
	virtual_ipaddress {
		10.1.17.106 # virtual ip address 
	}
	track_script {
		chk_haproxy
	}
}



 =================================================== HAProxy  ==============================================================

vi /etc/haproxy/haproxy.cfg
systemctl start haproxy    
[root@lb2 ~]# ss -tupln |grep haproxy
tcp    LISTEN     0      128       *:8775                  *:*                   users:(("haproxy",pid=9171,fd=11))
tcp    LISTEN     0      128       *:9191                  *:*                   users:(("haproxy",pid=9171,fd=8))
tcp    LISTEN     0      128       *:5672                  *:*                   users:(("haproxy",pid=9171,fd=17))
tcp    LISTEN     0      128       *:8776                  *:*                   users:(("haproxy",pid=9171,fd=12))
tcp    LISTEN     0      128       *:5000                  *:*                   users:(("haproxy",pid=9171,fd=9))
tcp    LISTEN     0      128       *:8777                  *:*                   users:(("haproxy",pid=9171,fd=13))
tcp    LISTEN     0      128       *:3306                  *:*                   users:(("haproxy",pid=9171,fd=6))
tcp    LISTEN     0      128       *:9292                  *:*                   users:(("haproxy",pid=9171,fd=7))
tcp    LISTEN     0      128       *:1936                  *:*                   users:(("haproxy",pid=9171,fd=18))
tcp    LISTEN     0      128       *:8080                  *:*                   users:(("haproxy",pid=9171,fd=16))
tcp    LISTEN     0      128       *:80                    *:*                   users:(("haproxy",pid=9171,fd=5))
tcp    LISTEN     0      128       *:9696                  *:*                   users:(("haproxy",pid=9171,fd=15))
tcp    LISTEN     0      128       *:6080                  *:*                   users:(("haproxy",pid=9171,fd=14))
tcp    LISTEN     0      128       *:8774                  *:*                   users:(("haproxy",pid=9171,fd=10))


~]# tcpdump -i ens192 -c 15 -nn host control1 and port 3306


===========  Log =====================
https://www.percona.com/blog/2014/10/03/haproxy-give-me-some-logs-on-centos-6-5/

vi /etc/haproxy/haproxy.cfg
global
        log         127.0.0.1 local2

defaults
        log  global
        mode  tcp
        
		
vi /etc/rsyslog.conf
	
# Provides UDP syslog reception
$ModLoad imudp
$UDPServerRun 514
$UDPServerAddress 127.0.0.1

vi /etc/rsyslog.d/haproxy.conf 
local2.*    /var/log/haproxy.log
local2.=info     /var/log/haproxy-info.log
local2.notice    /var/log/haproxy-allbutinfo.log

 =================================================== memcached  ==============================================================
 
yum --enablerepo=centos-openstack-rocky -y install memcached 
vi /etc/sysconfig/memcached
OPTIONS="-l 0.0.0.0,::" 
systemctl restart memcached
systemctl status memcached
systemctl enable memcached 
memcached-tool 127.0.0.1:11211 stats

vi /etc/sysconfig/memcached
CACHESIZE=2048


lsof -i :11211
watch –d –n 1 "memcached-tool 127.0.0.1:11211 stats"

 =================================================== Openstack Services  ==============================================================
 
vi ~/keystonerc  
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=adminpassword
export OS_AUTH_URL=http://vip:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export PS1='[\u@\h \W(keystone)]\$ '

chmod 600 ~/keystonerc;
source ~/keystonerc;
echo "source ~/keystonerc " >> ~/.bash_profile 


=================================================== Keystone  ==============================================================
 
mysql -u root -p
create database keystone;
grant all privileges on keystone.* to keystone@'localhost' identified by 'password';
grant all privileges on keystone.* to keystone@'%' identified by 'password';
flush privileges;
exit

yum --enablerepo=centos-openstack-rocky,epel -y install openstack-keystone openstack-utils python-openstackclient httpd mod_wsgi 
yum --enablerepo=centos-openstack-rocky,epel -y reinstall openstack-keystone openstack-utils python-openstackclient httpd mod_wsgi 

vi /etc/keystone/keystone.conf
su -s /bin/bash keystone -c "keystone-manage db_sync"

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone 
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone 
scp -r /etc/keystone/credential-keys/ control2:/etc/keystone/
scp -r /etc/keystone/credential-keys/ control3:/etc/keystone/
scp -r /etc/keystone/fernet-keys/ control3:/etc/keystone/               
scp -r /etc/keystone/fernet-keys/ control2:/etc/keystone/

chown -R keystone:keystone /etc/keystone
systemctl restart httpd

keystone-manage bootstrap --bootstrap-password adminpassword \
--bootstrap-admin-url http://vip:5000/v3/ \
--bootstrap-internal-url http://vip:5000/v3/ \
--bootstrap-public-url http://vip:5000/v3/ \
--bootstrap-region-id RegionOne 
ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/ 
  
curl http://vip:5000


[root@control1 fernet-keys(keystone)]# curl http://10.1.17.102:5000                                 
{"versions": {"values": [{"status": "stable", "updated": "2018-10-15T00:00:00Z", "media-types": [{"base": "application/json", "type": "application/vnd.openstack.identity-v3+json"}], "id": "v3.11", "links": [{"href": "http://10.1.17.102:5000/v3/", "rel": "self"}]}]}}[root@control1 fernet-keys(keystone)]# 
[root@control1 fernet-keys(keystone)]# curl http://10.1.17.103:5000
{"versions": {"values": [{"status": "stable", "updated": "2018-10-15T00:00:00Z", "media-types": [{"base": "application/json", "type": "application/vnd.openstack.identity-v3+json"}], "id": "v3.11", "links": [{"href": "http://10.1.17.103:5000/v3/", "rel": "self"}]}]}}[root@control1 fernet-keys(keystone)]# 
[root@control1 fernet-keys(keystone)]# curl http://10.1.17.101:5000
{"versions": {"values": [{"status": "stable", "updated": "2018-10-15T00:00:00Z", "media-types": [{"base": "application/json", "type": "application/vnd.openstack.identity-v3+json"}], "id": "v3.11", "links": [{"href": "http://10.1.17.101:5000/v3/", "rel": "self"}]}]}}[root@control1 fernet-keys(keystone)]# 
