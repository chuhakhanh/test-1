
=================================================== MariaDB  ==============================================================

MariaDB [cinder]> 
delete from `volumes` where display_name = "ceph_inst2_vol1"; 
delete from `instances` where uuid = "9f6eafed-09d0-43e1-8d78-342ae1585b4c"; 
delete from block_device_mapping where instance_uuid='9f6eafed-09d0-43e1-8d78-342ae1585b4c'
=================================================== VM  ==============================================================

openstack image create "cirros" --file /root/cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image create "cirros_2" --file /root/cirros-0.4.0-x86_64-disk.img --disk-format qcow2 --container-format bare --public
openstack image create "win2k16" --file /shared/winsrv-2016.qcow2 --disk-format qcow2 --container-format bare --public;
openstack image create "win2k19" --file /shared/winsrv-2019.qcow2 --disk-format qcow2 --container-format bare --public

openstack flavor create --id 1 --ram 1024 --disk 1 --vcpu 1 tiny
openstack flavor create --id 2 --ram 4096 --disk 10 --vcpu 2 small
openstack flavor create --id 3 --ram 4096 --disk 30 --vcpu 2 medium
openstack flavor create --id 4 --ram 4096 --disk 50 --vcpu 2 medium2

ssh-keygen -q -N ""
openstack keypair create --public-key ~/.ssh/id_rsa.pub key1

# network 

# create network vlan111
openstack network create --share --provider-physical-network physnet1 --provider-network-type vlan --provider-segment=111 pro_vlan111
openstack subnet create --subnet-range 10.1.0.0/16 --gateway 10.1.0.1 --network  pro_vlan111 --allocation-pool start=10.1.17.80,end=10.1.17.90 pro_vlan111_subnet1

# create network vlan126
openstack network create --share --provider-physical-network physnet1 --provider-network-type vlan --provider-segment=126 pro_vlan126
openstack subnet create --subnet-range 192.168.126.0/24 --gateway 192.168.126.1 --network pro_vlan126 --allocation-pool start=192.168.126.80,end=192.168.126.90 pro_vlan126_subnet1

# review network on bridge
[root@compute3 ns-metadata-proxy]#  ovs-ofctl dump-flows br-em2 | grep mod_vlan_vid 
 cookie=0x933b73fd15900d31, duration=278563.998s, table=2, n_packets=33178, n_bytes=2821333, idle_age=94, hard_age=65534, priority=4,in_port=2,dl_vlan=2 actions=mod_vlan_vid:111,NORMAL
 cookie=0x933b73fd15900d31, duration=94978.599s, table=2, n_packets=1066, n_bytes=97007, idle_age=1690, hard_age=65534, priority=4,in_port=2,dl_vlan=7 actions=mod_vlan_vid:126,NORMAL
 
 [root@compute3 ns-metadata-proxy]# ovs-ofctl dump-flows br-int | grep mod_vlan_vid
 cookie=0x5983d9e34dc90c71, duration=278757.400s, table=0, n_packets=17731335, n_bytes=1431007426, idle_age=0, hard_age=65534, priority=3,in_port=1,dl_vlan=111 actions=mod_vlan_vid:2,resubmit(,60)
 cookie=0x5983d9e34dc90c71, duration=95172s, table=0, n_packets=1134, n_bytes=217793, idle_age=2232, hard_age=65534, priority=3,in_port=1,dl_vlan=126 actions=mod_vlan_vid:7,resubmit(,60)
 ===== router
 
# create router1 add to pro_vlan111
openstack router create router1 
openstack network set --external pro_vlan111 
openstack router set router1 --external-gateway pro_vlan111 

openstack router create router2; 
openstack network set --external pro_vlan111;
openstack router set router2 --external-gateway pro_vlan111 

openstack router create router3
openstack network set --external pro_vlan111;
openstack router set router3 --external-gateway pro_vlan111 



=========== no dvr =============
# create subnet int_net1 add to router1
openstack network create --provider-network-type vxlan int_net1
openstack subnet create int_net1_sub1 --network int_net1 --subnet-range 192.168.1.0/24 --gateway 192.168.1.1 
openstack router add subnet router1 int_net1_sub1

# create subnet int_net2 add to router1
openstack network create --provider-network-type vxlan int_net2
openstack subnet create int_net2_sub1 --network int_net2 --subnet-range 192.168.2.0/24 --gateway 192.168.2.1 
openstack router add subnet router1 int_net2_sub1


=========== dvr =============
# create subnet int_net4 add to router1
openstack network create --provider-network-type vxlan int_net4;
openstack subnet create int_net4_sub --network int_net4 --subnet-range 192.168.104.0/24 --gateway 192.168.104.1 --dns-nameserver 192.168.104.1;
openstack router add subnet router2 int_net4_sub

# create subnet int_net5 add to router1
openstack network create --provider-network-type vxlan int_net5;
openstack subnet create int_net5_sub --network int_net5 --subnet-range 192.168.105.0/24 --gateway 192.168.105.1 --dns-nameserver 192.168.105.1;
openstack router add subnet router2 int_net5_sub

==========

# Create VM

# vlan 111 net0
openstack server create --flavor 1 --image cirros --nic net-id=aa3f480d-f4c9-4a41-aedd-30ae275ef371 --key-name key1 net0_inst1
openstack server add security group net0_inst1 sg_linux
openstack server create --flavor 3 --image win2k16 --nic net-id=aa3f480d-f4c9-4a41-aedd-30ae275ef371 --key-name key1 inst7
openstack server create --flavor 3 --image inst8_vm1 --nic net-id=aa3f480d-f4c9-4a41-aedd-30ae275ef371 --key-name key1 inst2
openstack server create --flavor 3 --image centos --nic net-id=aa3f480d-f4c9-4a41-aedd-30ae275ef371 --key-name key1 net0_centos_1
openstack server add security group net0_centos_1 sg_linux;

# vlan 126 net0
openstack server create --flavor 3 --image centos --nic net-id=4af496b7-dd33-418d-b9ec-e2b7341dd0d9 --key-name key1 vlan126-centos-1
openstack server add security group vlan126-centos-1 sg_linux;

# vxlan int_net1 (192.168.1.0/24)
openstack server create --flavor 1 --image cirros --nic net-id=833d4b29-e87b-4f95-b424-800e98b45115 --key-name key1 net1_inst1
openstack server add security group net1_inst1 sg_linux

openstack server create --flavor 3 --image web_net1_inst --nic net-id=833d4b29-e87b-4f95-b424-800e98b45115 --key-name key1 net1-centos-1
openstack server create --flavor 3 --image web_net1_inst --nic net-id=833d4b29-e87b-4f95-b424-800e98b45115 --key-name key1 net1-centos-2
openstack server add security group net1-centos-1 sg_linux
openstack server add security group net1-centos-2 sg_linux
# port in int_net2_sub1
openstack port create int_net2_sub1_p1 --network b79e931e-889e-4ace-a3e4-a5dbcb2958e1
openstack port create int_net2_sub1_p2 --network b79e931e-889e-4ace-a3e4-a5dbcb2958e1

# vxlan int_net2
openstack server create --flavor 1 --image cirros --nic net-id=b99ed8b1-7c68-4516-a3ed-def5465f63e0 --key-name key1 inst4

# vxlan int_net3
openstack server create --flavor 1 --image cirros --nic net-id=06ffa670-d97a-4be3-a324-fc4520d6075e --key-name key1 inst5

ssh -i /root/.ssh/id_rsa centos@10.1.17.106
# vxlan int_net4
# net4_inst1 192.168.104.6 compute2
# net4_inst2 192.168.104.17 compute3

openstack server create --flavor 1 --image cirros --nic net-id=50a78bea-b44b-493d-ab4d-2913a5c30067 --key-name key1 --availability-zone nova:compute2:compute2 net4_inst1;
openstack server create --flavor 1 --image cirros --nic net-id=50a78bea-b44b-493d-ab4d-2913a5c30067 --key-name key1 --availability-zone nova:compute3:compute3 net4_inst2
openstack server add security group net4_inst1 sg_linux;
openstack server add security group net4_inst2 sg_linux

ip netns exec qrouter-5a29c08d-c051-40cf-87e3-89c3a6d48163 tcpdump -nei qr-15ba535b-e1

# vxlan int_net5
# net5_inst1 192.168.105.16 compute2
# net5_inst2 192.168.105.11 compute3
openstack server create --flavor 1 --image cirros --nic net-id=055fac7d-e09f-49b4-8f46-a2cb94508f49 --key-name key1 --availability-zone nova:compute2:compute2 net5_inst1;
openstack server create --flavor 1 --image cirros --nic net-id=055fac7d-e09f-49b4-8f46-a2cb94508f49 --key-name key1 --availability-zone nova:compute3:compute3 net5_inst2


ssh -i /root/.ssh/id_rsa centos@10.1.17.106

openstack server delete inst4;
openstack server delete inst5;
openstack server delete inst6

# ceph
openstack volume create --type volume_from_ceph --size 10 ceph_inst1
openstack server create --flavor 3 --image win2k16 --block-device source=697ff017-c39b-401e-ae46-9c65ba023b6d --nic net-id=aa3f480d-f4c9-4a41-aedd-30ae275ef371 --key-name key1 ceph_inst1
openstack server add security group ceph_inst1 group2

openstack volume create --type volume_from_ceph --size 5 ceph-share-2
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
# Web Server
openstack server add security group inst_net1_inst1 group1 
openstack server add security group net1_inst2 group_web

openstack server add security group inst5 group1
openstack server add security group inst8 group2



[root@control1 ~(keystone)]# openstack server list
+--------------------------------------+--------+--------+-------------------------+--------+--------+
| ID                                   | Name   | Status | Networks                | Image  | Flavor |
+--------------------------------------+--------+--------+-------------------------+--------+--------+
| 64f90883-0ac0-4ebd-b099-9a2969d84939 | inst5  | ACTIVE | int_net3=192.168.103.4  | cirros | tiny   |

[root@compute2 ~]#  ip netns exec qdhcp-06ffa670-d97a-4be3-a324-fc4520d6075e ping 192.168.103.4
PING 192.168.103.4 (192.168.103.4) 56(84) bytes of data.
64 bytes from 192.168.103.4: icmp_seq=1 ttl=64 time=0.578 ms

ip netns exec qdhcp-06ffa670-d97a-4be3-a324-fc4520d6075e ssh cirros@192.168.103.4

================= KVM to OSP
# vm1 1 * hdd

scp vm1.img control1:/shared
openstack image create "kvm_rh6" --file /shared/vm1.img --disk-format qcow2 --container-format bare --public
openstack server create --flavor 3 --image kvm_rh76 --nic net-id=aa3f480d-f4c9-4a41-aedd-30ae275ef371,v4-fixed-ip=10.1.17.201 --key-name key1 net0-kvm-rh67-2
openstack server add security group net0-kvm-rh67-2 sg_linux;
# vm2 2 * hdd
openstack image create "vm2" --file /shared/vm2.img --disk-format qcow2 --container-format bare --public
openstack image create "vm2-hdd2" --file /shared/vm2-hdd2.qcow2 --disk-format qcow2 --container-format bare --public
openstack server create --flavor 3 --image vm2 --nic net-id=aa3f480d-f4c9-4a41-aedd-30ae275ef371,v4-fixed-ip=10.1.17.201 --key-name key1 net0-vm2
openstack server add volume net0-vm2 vm2-hdd2
openstack server add security group net0-vm2 sg_linux;


