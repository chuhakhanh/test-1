rsync -avP `cat /shared/rsync_include.txt` /shared/osp_config/`hostname`/

rsync_include.txt
/etc/neutron
/etc/nova
/etc/glance
/etc/keystone
/etc/cinder

tar -cf /shared/osp_config.tar /shared/osp_config

 =================================================== Glance  ==============================================================

openstack user create --domain default --project service --password servicepassword glance
openstack role add --project service --user glance admin 
openstack service create --name glance --description "OpenStack Image service" image 

openstack endpoint create --region RegionOne image public http://vip:9292; 
openstack endpoint create --region RegionOne image admin http://vip:9292; 
openstack endpoint create --region RegionOne image internal http://vip:9292 

create database glance;
grant all privileges on glance.* to glance@'localhost' identified by 'password';
grant all privileges on glance.* to glance@'%' identified by 'password';
flush privileges;

yum --enablerepo=centos-openstack-rocky,epel -y install openstack-glance 


vi /etc/glance/glance-api.conf
mv /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf.org
vi /etc/glance/glance-registry.conf
chmod 640 /etc/glance/glance-api.conf /etc/glance/glance-registry.conf;
chown root:glance /etc/glance/glance-api.conf /etc/glance/glance-registry.conf;
vi /etc/glance/glance-api.conf
su -s /bin/bash glance -c "glance-manage db_sync";
systemctl start openstack-glance-api openstack-glance-registry;
systemctl enable openstack-glance-api openstack-glance-registry 

== network node NFS share

yum install nfs-utils
systemctl enable rpcbind
systemctl enable nfs-server
systemctl enable nfs-lock
systemctl enable nfs-idmap
systemctl start rpcbind
systemctl start nfs-server
systemctl start nfs-lock
systemctl start nfs-idmap
mkdir /home/nfsshare
chmod -R 755 /home/nfsshare
chown nfsnobody:nfsnobody  /home/nfsshare
vi /etc/exports
	/home/nfsshare            *(rw,sync,no_root_squash,no_all_squash)
systemctl restart nfs-server
showmount -e

== control1 -> 3 

echo "network2:/home/nfsshare             /shared   nfs defaults 0 0" >> /etc/fstab 
mkdir /shared 
mount /shared


 =================================================== Nova  ==============================================================

openstack endpoint create --region RegionOne compute public http://vip:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute internal http://vip:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute admin http://vip:8774/v2.1/%\(tenant_id\)s
openstack endpoint create --region RegionOne placement public http://vip:8778; 
openstack endpoint create --region RegionOne placement internal http://vip:8778;
openstack endpoint create --region RegionOne placement admin http://vip:8778 

create database nova;
grant all privileges on nova.* to nova@'localhost' identified by 'password';
grant all privileges on nova.* to nova@'%' identified by 'password';
create database nova_api;
grant all privileges on nova_api.* to nova@'localhost' identified by 'password';
grant all privileges on nova_api.* to nova@'%' identified by 'password';
create database nova_placement;
grant all privileges on nova_placement.* to nova@'localhost' identified by 'password';
grant all privileges on nova_placement.* to nova@'%' identified by 'password';
create database nova_cell0;
grant all privileges on nova_cell0.* to nova@'localhost' identified by 'password';
grant all privileges on nova_cell0.* to nova@'%' identified by 'password';
flush privileges;
SHOW GLOBAL STATUS LIKE 'wsrep_last%';


yum --enablerepo=centos-openstack-rocky,epel -y install openstack-nova
mv /etc/nova/nova.conf /etc/nova/nova.conf.org
vi /etc/nova/nova.conf
chmod 640 /etc/nova/nova.conf;
chgrp nova /etc/nova/nova.conf




vi /etc/httpd/conf.d/00-nova-placement-api.conf
# add near line 15

  <Directory /usr/bin>
    Require all granted
  </Directory>

</VirtualHost>


su -s /bin/bash nova -c "nova-manage api_db sync"
su -s /bin/bash nova -c "nova-manage cell_v2 map_cell0";
su -s /bin/bash nova -c "nova-manage db sync";
su -s /bin/bash nova -c "nova-manage cell_v2 create_cell --name cell1";
systemctl restart httpd

chown nova. /var/log/nova/nova-placement-api.log
for service in api consoleauth conductor scheduler novncproxy; do
systemctl start openstack-nova-$service
systemctl enable openstack-nova-$service
done
# show status
for service in api consoleauth conductor scheduler novncproxy; do
systemctl status openstack-nova-$service
done

# restart
for service in api consoleauth conductor scheduler novncproxy; do
systemctl restart openstack-nova-$service
done

for service in api consoleauth conductor scheduler novncproxy; do
systemctl stop openstack-nova-$service
done

for service in api consoleauth conductor scheduler novncproxy; do
systemctl start openstack-nova-$service
done


[root@dlp ~(keystone)]# openstack compute service list 




DELETE FROM compute_node_stats WHERE compute_node_id='2';


openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_host vip;
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_userid openstack;
openstack-config --set /etc/nova/nova.conf oslo_messaging_rabbit rabbit_password password 

=================================================== Neutron  ==============================================================

openstack user create --domain default --project service --password servicepassword neutron;
openstack role add --project service --user neutron admin;
openstack service create --name neutron --description "OpenStack Networking service" network;
openstack endpoint create --region RegionOne network public http://vip:9696;
openstack endpoint create --region RegionOne network internal http://vip:9696;
openstack endpoint create --region RegionOne network admin http://vip:9696

mysql -u root -p
create database neutron_ml2;
grant all privileges on neutron_ml2.* to neutron@'localhost' identified by 'password';
grant all privileges on neutron_ml2.* to neutron@'%' identified by 'password';
flush privileges;
exit


------------+---------------------------+---------------------------+------------
            |                           |                           |
        eno1|vip              eno1|10.1.17.15              eno1|10.1.17.17
+-----------+-----------+   +-----------+-----------+   +-----------+-----------+
|    [ Control Node ]   |   |    [ Network Node ]   |   |    [ Compute Node ]   |
|                       |   |                       |   |                       |
|  MariaDB    RabbitMQ  |   |      Open vSwitch     |   |        Libvirt        |
|  Memcached  httpd     |   |        L2 Agent       |   |     Nova Compute      |
|  Keystone   Glance    |   |        L3 Agent       |   |      Open vSwitch     |
|  Nova API             |   |                       |   |        L2 Agent       |
|  Neutron Server       |   |                       |   |    Metadata Agent     |
|                       |   |                       |   |      DHCP Agent       |
+-----------------------+   +-----------------------+   +-----------------------+

 yum --enablerepo=centos-openstack-rocky,epel -y install openstack-neutron openstack-neutron-ml2 

========================== server ==========================

mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.org
vi /etc/neutron/neutron.conf
chmod 640 /etc/neutron/neutron.conf
chgrp neutron /etc/neutron/neutron.conf

mv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.org
vi /etc/neutron/plugins/ml2/ml2_conf.ini
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini 


vi /etc/nova/nova.conf  
#(17)
ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/bash neutron -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head"
systemctl start neutron-server neutron-metadata-agent
systemctl enable neutron-server neutron-metadata-agent
systemctl restart openstack-nova-api 

========================== compute2  ==========================

yum --enablerepo=centos-openstack-rocky,epel -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch 
mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.org 
mv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.org
mv /etc/neutron/plugins/ml2/openvswitch_agent.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini.org
mv /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini.org 
mv /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini.org 

vi /etc/neutron/neutron.conf
chmod 640 /etc/neutron/neutron.conf
chgrp neutron /etc/neutron/neutron.conf

vi /etc/neutron/plugins/ml2/ml2_conf.ini
vi /etc/neutron/plugins/ml2/openvswitch_agent.ini
vi /etc/nova/nova.conf
#(17)
#(19)

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
systemctl start openvswitch
systemctl enable openvswitch
ovs-vsctl add-br br-int
systemctl restart openstack-nova-compute
systemctl start neutron-openvswitch-agent
systemctl enable neutron-openvswitch-agent 
cat /etc/neutron/dhcp_agent.ini.org | grep -v "#" | grep . >> /etc/neutron/dhcp_agent.ini
cat  /etc/neutron/metadata_agent.ini.org | grep -v "#" | grep . >> /etc/neutron/metadata_agent.ini


 for service in dhcp-agent metadata-agent openvswitch-agent; do
systemctl start neutron-$service
systemctl enable neutron-$service
done 

for service in dhcp-agent metadata-agent openvswitch-agent; do
systemctl restart neutron-$service
done 

 for service in dhcp-agent metadata-agent openvswitch-agent; do
systemctl status neutron-$service
done 

========================== network2  ==========================

yum --enablerepo=centos-openstack-rocky,epel -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch 

mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.org 
mv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.org
mv /etc/neutron/plugins/ml2/openvswitch_agent.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini.org
mv /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.org
cat /etc/neutron/l3_agent.ini.org | grep -v "#" | grep . >>  /etc/neutron/l3_agent.ini

vi /etc/neutron/neutron.conf
vi /etc/neutron/plugins/ml2/ml2_conf.ini
vi /etc/neutron/plugins/ml2/openvswitch_agent.ini

ovs-vsctl add-br br-eno2
ovs-vsctl add-port br-eno2 eno2


for service in l3-agent openvswitch-agent; do
systemctl start neutron-$service
systemctl enable neutron-$service
done 

for service in l3-agent openvswitch-agent; do
systemctl restart neutron-$service
done 

========================== network3  ==========================

yum --enablerepo=centos-openstack-rocky,epel -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-openvswitch 

mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.org 
mv /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini.org
mv /etc/neutron/plugins/ml2/openvswitch_agent.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini.org
mv /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini.org
cat /etc/neutron/l3_agent.ini.org | grep -v "#" | grep . >>  /etc/neutron/l3_agent.ini

vi /etc/neutron/neutron.conf
vi /etc/neutron/l3_agent.ini
vi /etc/neutron/plugins/ml2/ml2_conf.ini
vi /etc/neutron/plugins/ml2/openvswitch_agent.ini

ovs-vsctl add-br br-eno2
ovs-vsctl add-port br-eno2 eno2


for service in l3-agent openvswitch-agent; do
systemctl start neutron-$service
systemctl enable neutron-$service
done 

for service in l3-agent openvswitch-agent; do
systemctl restart neutron-$service
done 
=================================================== Metadata  ==============================================================

ip netns exec qdhcp-aa3f480d-f4c9-4a41-aedd-30ae275ef371 tcpdump -i tap84cb0ed2-80
ip netns exec qdhcp-aa3f480d-f4c9-4a41-aedd-30ae275ef371 netstat -anp

ip netns exec qrouter-2b661bf4-4e5c-4239-8918-397e260ed85d iptables -L -t nat | grep 169
REDIRECT   tcp  --  anywhere             169.254.169.254      tcp dpt:http redir ports 9697

ip netns exec qrouter-2b661bf4-4e5c-4239-8918-397e260ed85d netstat -anp
Active Internet connections (servers and established)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:9697            0.0.0.0:*               LISTEN      30888/haproxy       
Active UNIX domain sockets (servers and established)
Proto RefCnt Flags       Type       State         I-Node   PID/Program name     Path
unix  2      [ ]         DGRAM                    659086   30888/haproxy        


[root@network2 ~]# ps -f --pid 30888 | fold -s -w 90
UID        PID  PPID  C STIME TTY          TIME CMD
neutron  30888     1  0 Jun25 ?        00:00:01 haproxy -f 
/var/lib/neutron/ns-metadata-proxy/2b661bf4-4e5c-4239-8918-397e260ed85d.conf


[root@network2 ~]# cat /var/lib/neutron/ns-metadata-proxy/2b661bf4-4e5c-4239-8918-397e260ed85d.conf

global
    log         /dev/log local0 info
    log-tag     haproxy-metadata-proxy-2b661bf4-4e5c-4239-8918-397e260ed85d
    user        neutron
    group       neutron
    maxconn     1024
    pidfile     /var/lib/neutron/external/pids/2b661bf4-4e5c-4239-8918-397e260ed85d.pid
    daemon

defaults
    log global
    mode http
    option httplog
    option dontlognull
    option http-server-close
    option forwardfor
    retries                 3
    timeout http-request    30s
    timeout connect         30s
    timeout client          32s
    timeout server          32s
    timeout http-keep-alive 30s

listen listener
    bind 0.0.0.0:9697
    server metadata /var/lib/neutron/metadata_proxy
    http-request add-header X-Neutron-Router-ID 2b661bf4-4e5c-4239-8918-397e260ed85d
	



 curl http://vip:8775
 
 
 cat /var/lib/neutron/dhcp/b99ed8b1-7c68-4516-a3ed-def5465f63e0/opts 
tag:tag0,option:dns-server,10.1.17.15
tag:tag0,option:classless-static-route,169.254.169.254/32,192.168.102.1,0.0.0.0/0,192.168.102.1
tag:tag0,249,169.254.169.254/32,192.168.102.1,0.0.0.0/0,192.168.102.1
tag:tag0,option:router,192.168.102.1[root@compute2 ~]# 

=
=
=
=
=
=
# ban dau VM duoc cap IP boi dhcp co cau hinh nhu sau:
tag:tag0,option:classless-static-route,
169.254.169.254/32,192.168.126.80,
0.0.0.0/0,192.168.126.1
tag:tag0,249,169.254.169.254/32,192.168.126.80,0.0.0.0/0,192.168.126.1
tag:tag0,option:router,192.168.126.1

# route: => vao metadata 169.254.169.254  thi di qua IP 192.168.126.80

[centos@vlan126-centos-1 ~]$ netstat -rn
Kernel IP routing table
Destination     Gateway         Genmask         Flags   MSS Window  irtt Iface
0.0.0.0         192.168.126.1   0.0.0.0         UG        0 0          0 eth0
169.254.169.254 192.168.126.80  255.255.255.255 UGH       0 0          0 eth0
192.168.126.0   0.0.0.0         255.255.255.0   U         0 0          0 eth0


# proxy IP: 192.168.126.80 
[root@compute3 ns-metadata-proxy]# cat 61aa4820-74b2-44dc-9228-176f23ad471d.conf

global
    log         /dev/log local0 info
    log-tag     haproxy-metadata-proxy-61aa4820-74b2-44dc-9228-176f23ad471d
    user        neutron
    group       neutron
    maxconn     1024
    pidfile     /var/lib/neutron/external/pids/61aa4820-74b2-44dc-9228-176f23ad471d.pid
    daemon

defaults
    log global
    mode http
    option httplog
    option dontlognull
    option http-server-close
    option forwardfor
    retries                 3
    timeout http-request    30s
    timeout connect         30s
    timeout client          32s
    timeout server          32s
    timeout http-keep-alive 30s

listen listener
    bind 169.254.169.254:80
    server metadata /var/lib/neutron/metadata_proxy
    http-request add-header X-Neutron-Network-ID 61aa4820-74b2-44dc-9228-176f23ad471d

[root@compute3 ns-metadata-proxy]# file  /var/lib/neutron/metadata_proxy
/var/lib/neutron/metadata_proxy: socket

=================================================== Horizon  ==============================================================

yum --enablerepo=centos-openstack-rocky,epel -y install openstack-dashboard
cp /etc/openstack-dashboard/local_settings /etc/openstack-dashboard/local_settings.org;
cat /etc/openstack-dashboard/local_settings.org  |grep -v "#" | grep . >> /etc/openstack-dashboard/local_settings
watch -d -n 1 'memcached-tool 127.0.0.1:11211 stats |grep get_hits' 
vi /etc/openstack-dashboard/local_settings 
vi /etc/httpd/conf.d/openstack-dashboard.conf 
 # line 4: add

WSGIDaemonProcess dashboard
WSGIProcessGroup dashboard
WSGISocketPrefix run/wsgi
WSGIApplicationGroup %{GLOBAL}

systemctl restart httpd 


=================================================== Cinder  ==============================================================


openstack user create --domain default --project service --password servicepassword cinder;
openstack role add --project service --user cinder admin;
openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3;
openstack endpoint create --region RegionOne volumev3 public http://vip:8776/v3/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev3 internal http://vip:8776/v3/%\(tenant_id\)s
openstack endpoint create --region RegionOne volumev3 admin http://vip:8776/v3/%\(tenant_id\)s

mysql -u root -p
create database cinder;
grant all privileges on cinder.* to cinder@'localhost' identified by 'password';
grant all privileges on cinder.* to cinder@'%' identified by 'password';
flush privileges;
exit

yum --enablerepo=centos-openstack-rocky,epel -y install openstack-cinder
mv /etc/cinder/cinder.conf /etc/cinder/cinder.conf.org
vi /etc/cinder/cinder.conf


[DEFAULT]
my_ip = 10.1.17.101
log_dir = /var/log/cinder
state_path = /var/lib/cinder
auth_strategy = keystone

transport_url = rabbit://openstack:password@vip
enable_v3_api = True

[database]
connection = mysql+pymysql://cinder:password@vip/cinder

[keystone_authtoken]
www_authenticate_uri = http://vip:5000
auth_url = http://vip:5000
memcached_servers = control1:11211,control2:11211,control3:11211
auth_type = password
project_domain_name = default
user_domain_name = default
project_name = service
username = cinder
password = servicepassword

[oslo_concurrency]
lock_path = $state_path/tmp

[root@dlp ~(keystone)]# chmod 640 /etc/cinder/cinder.conf
[root@dlp ~(keystone)]# chgrp cinder /etc/cinder/cinder.conf
[root@dlp ~(keystone)]# su -s /bin/bash cinder -c "cinder-manage db sync"
[root@dlp ~(keystone)]# systemctl start openstack-cinder-api openstack-cinder-scheduler
[root@dlp ~(keystone)]# systemctl enable openstack-cinder-api openstack-cinder-scheduler
[root@dlp ~(keystone)]# echo "export OS_VOLUME_API_VERSION=3" >> ~/keystonerc
[root@dlp ~(keystone)]# source ~/keystonerc
[root@dlp ~(keystone)]# openstack volume service list

# Network2 - Storage Node
[root@network3 ~]# cat /etc/cinder/cinder.conf
enabled_backends=lvmdriver-1,lvmdriver-2
#28
backup_driver = cinder.backup.drivers.nfs
backup_mount_point_base = $state_path/backup_nfs
backup_share = network2:/home/cinder-backup 

[lvmdriver-1]
volume_group=vg_1
volume_driver=cinder.volume.drivers.lvm.LVMVolumeDriver
volume_backend_name=big_vg
target_helper = lioadm
target_protocol = iscsi
[lvmdriver-2]
volume_group=vg_2
volume_driver=cinder.volume.drivers.lvm.LVMVolumeDriver
volume_backend_name=big_vg
target_helper = lioadm
target_protocol = iscsi

[root@control1 ceph(keystone)]# openstack volume type list
+--------------------------------------+--------------------+-----------+
| ID                                   | Name               | Is Public |
+--------------------------------------+--------------------+-----------+
| 2f8db0d9-7401-4c2a-ba28-36279d8476eb | volume_from_big_vg | True      |
+--------------------------------------+--------------------+-----------+
[root@control1 ceph(keystone)]# openstack volume type show volume_from_big_vg
+--------------------+--------------------------------------+
| Field              | Value                                |
+--------------------+--------------------------------------+
| access_project_ids | None                                 |
| description        | None                                 |
| id                 | 2f8db0d9-7401-4c2a-ba28-36279d8476eb |
| is_public          | True                                 |
| name               | volume_from_big_vg                   |
| properties         | volume_backend_name='big_vg'         |
| qos_specs_id       | None                                 |
+--------------------+--------------------------------------+

[root@control1 ceph(keystone)]# openstack volume service list
+------------------+----------------------+------+---------+-------+----------------------------+
| Binary           | Host                 | Zone | Status  | State | Updated At                 |
+------------------+----------------------+------+---------+-------+----------------------------+
| cinder-scheduler | control1             | nova | enabled | up    | 2019-07-31T10:51:22.000000 |
| cinder-scheduler | control2             | nova | enabled | up    | 2019-07-31T10:51:28.000000 |
| cinder-scheduler | control3             | nova | enabled | up    | 2019-07-31T10:51:22.000000 |
| cinder-volume    | network3@lvmdriver-1 | nova | enabled | down  | 2019-07-31T10:53:51.000000 |
| cinder-volume    | network3@lvmdriver-2 | nova | enabled | down  | 2019-07-31T10:53:53.000000 |
| cinder-volume    | network3@lvmdriver-3 | nova | enabled | down  | 2019-07-17T07:30:44.000000 |
| cinder-backup    | network3             | nova | enabled | down  | 2019-07-31T10:53:52.000000 |
+------------------+----------------------+------+---------+-------+----------------------------+

 openstack volume type create --property volume_backend_name='ceph'  volume_from_ceph 

========================== add node compute3 : DVR + Compute ==========================

compute2:
scp /etc/nova/nova.conf compute3:/etc/nova/nova.conf;
scp /etc/neutron/neutron.conf compute3:/etc/neutron/neutron.conf;
scp /etc/neutron/plugins/ml2/ml2_conf.ini compute3:/etc/neutron/plugins/ml2/ml2_conf.ini;
scp /etc/neutron/plugins/ml2/openvswitch_agent.ini compute3:/etc/neutron/plugins/ml2/openvswitch_agent.ini;
scp /etc/neutron/dhcp_agent.ini compute3:/etc/neutron/dhcp_agent.ini;
scp /etc/neutron/metadata_agent.ini compute3:/etc/neutron/metadata_agent.ini
network2:
scp  /etc/neutron/l3_agent.ini compute3:/etc/neutron/l3_agent.ini
chown root:neutron /etc/neutron/neutron.conf /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/openvswitch_agent.ini /etc/neutron/dhcp_agent.ini /etc/neutron/l3_agent.ini



for service in l3-agent dhcp-agent metadata-agent openvswitch-agent; do
systemctl start neutron-$service
systemctl enable neutron-$service
done 

for service in l3-agent dhcp-agent metadata-agent openvswitch-agent; do
systemctl restart neutron-$service
done 

 for service in l3-agent dhcp-agent metadata-agent openvswitch-agent; do
systemctl status neutron-$service
done 


==========================  network2 : LBaaSv2  ==========================



openstack floating ip create pro_vlan111
openstack server add floating ip net1_inst2 10.1.17.169

[1] 	On Control Node, Change settings like follows.
# install from Rocky, EPEL

[root@dlp ~(keystone)]# yum --enablerepo=centos-openstack-rocky,epel -y install openstack-neutron-lbaas net-tools
[root@dlp ~(keystone)]# vi /etc/neutron/neutron.conf
# add to [service_plugins]

service_plugins = router,lbaasv2
[root@dlp ~(keystone)]# vi /etc/neutron/neutron_lbaas.conf
# line 207: add

[service_providers]
service_provider = LOADBALANCERV2:Haproxy:neutron_lbaas.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default

[root@dlp ~(keystone)]# vi /etc/neutron/lbaas_agent.ini
# add into [DEFAULT] section

[DEFAULT]
interface_driver = openvswitch
[root@dlp ~(keystone)]# su -s /bin/bash neutron -c "neutron-db-manage --subproject neutron-lbaas --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugin.ini upgrade head"

[root@dlp ~(keystone)]# systemctl restart neutron-server

[2] 	On Network Node and Compute Node, Change settings like follows.
# install from Rocky, EPEL

[root@network ~]# yum --enablerepo=centos-openstack-rocky,epel -y install openstack-neutron-lbaas haproxy net-tools
[root@network ~]# vi /etc/neutron/neutron.conf
# add to [service_plugins]

service_plugins = router,lbaasv2
[root@network ~]# vi /etc/neutron/neutron_lbaas.conf
# line 207: add

[service_providers]
service_provider = LOADBALANCERV2:Haproxy:neutron_lbaas.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default

[root@network ~]# vi /etc/neutron/lbaas_agent.ini
# add into [DEFAULT] section

[DEFAULT]
interface_driver = openvswitch
[root@network ~]# systemctl start neutron-lbaasv2-agent
[root@network ~]# systemctl enable neutron-lbaasv2-agent 


neutron lbaas-loadbalancer-create --name lb01 int_net1_sub1 
neutron lbaas-loadbalancer-show lb01
+---------------------+--------------------------------------+
| Field               | Value                                |
+---------------------+--------------------------------------+
| admin_state_up      | True                                 |
| description         |                                      |
| id                  | 06473beb-8026-4349-8a9b-f9559a5576b0 |
| listeners           |                                      |
| name                | lb01                                 |
| operating_status    | ONLINE                               |
| pools               |                                      |
| provider            | haproxy                              |
| provisioning_status | ACTIVE                               |
| tenant_id           | f9e2fdffdca54bf1a4e554de73781ab6     |
| vip_address         | 192.168.100.12                       |
| vip_port_id         | f04d88be-622b-405b-8550-0ccf55bcc628 |
| vip_subnet_id       | ff418fde-2a89-4007-a71d-20bea2257d01 |
+---------------------+--------------------------------------+
openstack port set --security-group group_web f04d88be-622b-405b-8550-0ccf55bcc628
neutron lbaas-listener-create --name lb01-http --loadbalancer lb01 --protocol HTTP --protocol-port 80 
neutron lbaas-pool-create --name lb01-http-pool --lb-algorithm ROUND_ROBIN --listener lb01-http --protocol HTTP 

[root@control1 shared(keystone)]# openstack server list
+--------------------------------------+------------------+---------+-------------------------------------+---------+--------+
| ID                                   | Name             | Status  | Networks                            | Image   | Flavor |
+--------------------------------------+------------------+---------+-------------------------------------+---------+--------+
| 2794818b-d28d-4fc9-8dc6-820c582283fe | web_net1_inst_-1 | ACTIVE  | int_net1=192.168.100.7              |         | small  |
| a1329000-dc80-47d5-9c83-e7eee814d0a0 | web_net1_inst_-2 | ACTIVE  | int_net1=192.168.100.10             |         | small  |

echo `hostname`> /var/www/html/index.html; cat /var/www/html/index.html
systemctl start httpd
systemctl enable httpd

neutron lbaas-member-create --name lb01-member-01 --subnet int_net1_sub1 --address 192.168.100.3 --protocol-port 80 lb01-http-pool;
neutron lbaas-member-create --name lb01-member-02 --subnet int_net1_sub1 --address 192.168.100.10 --protocol-port 80 lb01-http-pool;
neutron lbaas-member-list lb01-http-pool 
(
neutron lbaas-member-delete lb01-member-02 lb01-http-pool
)
openstack floating ip create pro_vlan111
+---------------------+--------------------------------------+
| Field               | Value                                |
+---------------------+--------------------------------------+
| created_at          | 2019-07-24T11:54:12Z                 |
| description         |                                      |
| dns_domain          | None                                 |
| dns_name            | None                                 |
| fixed_ip_address    | None                                 |
| floating_ip_address | 10.1.17.182                          |
| floating_network_id | aa3f480d-f4c9-4a41-aedd-30ae275ef371 |
| id                  | 269d368a-a3ff-4706-8585-2038aad4b2bc |
| name                | 10.1.17.182                          |
| port_details        | None                                 |
| port_id             | None                                 |
| project_id          | f9e2fdffdca54bf1a4e554de73781ab6     |
| qos_policy_id       | None                                 |
| revision_number     | 0                                    |
| router_id           | None                                 |
| status              | DOWN                                 |
| subnet_id           | None                                 |
| tags                | []                                   |
| updated_at          | 2019-07-24T11:54:12Z                 |

neutron floatingip-associate 269d368a-a3ff-4706-8585-2038aad4b2bc f04d8/etc/neutron/fwaas_driver.ini8be-622b-405b-8550-0ccf55bcc628

https://www.rdoproject.org/networking/lbaas/

yum -y install openstack-neutron-lbaas openstack-neutron-lbaas-ui
systemctl restart httpd memcached

=== delete

neutron lbaas-listener-delete --name lb01-http
neutron lbaas-pool-delete --name lb01-http-pool        
neutron lbaas-loadbalancer-delete --name lb01 

==========================  network2 : FWaaSv1 ==========================

https://techopenstack.wordpress.com/2016/10/06/lbaasfwaas-in-openstack/
yum install openstack-neutron-fwaas

# network 
vi /etc/neutron/neutron.conf
[DEFAULT]
core_plugin = ml2
service_plugins = router,lbaasv2,firewall

vi /etc/neutron/fwaas_driver.ini
[fwaas]
driver = iptables
enabled = True
[service_providers]
service_provider = LOADBALANCER:Haproxy:neutron_lbaas.services.loadbalancer.drivers.haproxy.plugin_driver.HaproxyOnHostPluginDriver:default

# control
vi /etc/openstack-dashboard/local_settings
service neutron-l3-agent restart;
service neutron-server restart;
service httpd restart


yum --enablerepo=centos-openstack-rocky,epel -y install python-pip

# Tham khao
# Linux security group 1 ( Linux )
openstack security group rule create group1 --protocol tcp --dst-port 22:22 --remote-ip 0.0.0.0/0
openstack security group rule create group1 --protocol icmp --remote-ip 0.0.0.0/0

# Windows security group 2 ( Windows )
openstack security group rule create group2 --protocol udp --dst-port 3389:3389 --remote-ip 0.0.0.0/0
openstack security group rule create group2 --protocol tcp --dst-port 3389:3389 --remote-ip 0.0.0.0/0
openstack security group rule create group2 --protocol icmp --remote-ip 0.0.0.0/0

# Linux security group  ( Linux )
openstack security group create group_web
openstack security group rule create group_web --protocol tcp --dst-port 80:80 --remote-ip 0.0.0.0/0
openstack security group rule create group_web --protocol tcp --dst-port 443:443 --remote-ip 0.0.0.0/0



firewall-create                    Create a firewall.
firewall-delete                    Delete a given firewall.
firewall-list                      List firewalls that belong to a given tenant.
firewall-policy-create             Create a firewall policy.
firewall-policy-delete             Delete a given firewall policy.
firewall-policy-insert-rule        Insert a rule into a given firewall policy.
firewall-policy-list               List firewall policies that belong to a given tenant.
firewall-policy-remove-rule        Remove a rule from a given firewall policy.
firewall-policy-show               Show information of a given firewall policy.
firewall-policy-update             Update a given firewall policy.
firewall-rule-create               Create a firewall rule.
firewall-rule-delete               Delete a given firewall rule.
firewall-rule-list                 List firewall rules that belong to a given tenant.
firewall-rule-show                 Show information of a given firewall rule.
firewall-rule-update               Update a given firewall rule.
firewall-show                      Show inf
firewall-update
  
rules(N) --> policy(1) --> fw(1)


neutron firewall-rule-create --protocol tcp --destination-port 22:22 --action allow
neutron firewall-policy-create --firewall-rules 59b5e9fa-c116-4bb0-bffb-c00ab1d4d2e7 allow_webserver # Policy 05202ee2-3441-4726-8978-c4f8820b89e6

neutron firewall-rule-create --protocol tcp --destination-port 443:443 --action allow
neutron firewall-policy-insert-rule allow_webserver 59dbf017-4156-4314-afe7-407b9a1a1f5b 

# create FW
neutron firewall-create 05202ee2-3441-4726-8978-c4f8820b89e6

# Test web server die, no ping
neutron firewall-rule-create --protocol icmp --action allow
neutron firewall-policy-insert-rule allow_webserver 4c2671a4-9faa-456c-ab36-83934a80d27c

# test web ok
neutron firewall-rule-create --protocol tcp --destination-port 80:80 --action allow
neutron firewall-policy-insert-rule allow_webserver 3ef86d32-2021-48fd-abe6-c599cb262cef 
neutron firewall-policy-remove-rule allow_webserver 3ef86d32-2021-48fd-abe6-c599cb262cef 

[root@control1 neutron(keystone)]# neutron firewall-list
neutron CLI is deprecated and will be removed in the future. Use openstack CLI instead.
+--------------------------------------+------+----------------------------------+--------------------------------------+
| id                                   | name | tenant_id                        | firewall_policy_id                   |
+--------------------------------------+------+----------------------------------+--------------------------------------+
| e85a48f0-3140-43b9-9d66-bce39a2dabd7 |      | f9e2fdffdca54bf1a4e554de73781ab6 | 05202ee2-3441-4726-8978-c4f8820b89e6 |
+--------------------------------------+------+----------------------------------+--------------------------------------+
[root@control1 neutron(keystone)]# 
[root@control1 neutron(keystone)]# 
[root@control1 neutron(keystone)]# 
[root@control1 neutron(keystone)]# neutron firewall-show e85a48f0-3140-43b9-9d66-bce39a2dabd7
neutron CLI is deprecated and will be removed in the future. Use openstack CLI instead.
+--------------------+--------------------------------------+
| Field              | Value                                |
+--------------------+--------------------------------------+
| admin_state_up     | True                                 |
| description        |                                      |
| firewall_policy_id | 05202ee2-3441-4726-8978-c4f8820b89e6 |
| id                 | e85a48f0-3140-43b9-9d66-bce39a2dabd7 |
| name               |                                      |
| project_id         | f9e2fdffdca54bf1a4e554de73781ab6     |
| router_ids         | 2b661bf4-4e5c-4239-8918-397e260ed85d |
|                    | 64b37d2d-e3a3-497e-98b6-89c6b3756c30 |
|                    | e4790aff-3ce4-4854-9123-a740e276407a |
| status             | ACTIVE                               |
| tenant_id          | f9e2fdffdca54bf1a4e554de73781ab6     |
+--------------------+--------------------------------------+

POLICY_FILES['neutron-fwaas'] = /root/neutron-fwaas-dashboard-stable-rocky/etc/neutron-fwaas-policy.json

==========================  packstack : FWaaSv2 ==========================

https://docs.openstack.org/neutron-fwaas-dashboard/latest/install/index.html
git clone https://opendev.org/openstack/neutron-fwaas-dashboard
cd neutron-fwaas-dashboard
sudo pip install .

# control/network node
 cat /etc/neutron/neutron.conf
[DEFAULT]
service_plugins = firewall_v2 
[service_providers]
service_provider = FIREWALL_V2:fwaas_db:neutron_fwaas.services.firewall.service_drivers.agents.agents.FirewallAgentDriver:default
[fwaas]
agent_version = v2
driver = neutron_fwaas.services.firewall.drivers.linux.iptables_fwaas_v2.IptablesFwaasDriver
enabled = True

[root@control1 ~(keystone)]# cat /etc/neutron/fwaas_driver.ini 
[DEFAULT]

cat /etc/neutron/fwaas_driver.ini 
[fwaas]
agent_version = v2
driver = neutron_fwaas.services.firewall.drivers.linux.iptables_fwaas_v2.IptablesFwaasDriver
enabled = True
firewall_l2_driver = noop

cat /etc/neutron/l3_agent.ini
[DEFAULT]
[agent]
extensions = fwaas_v2
[ovs]
