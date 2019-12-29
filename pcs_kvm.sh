https://clusterlabs.org/pacemaker/doc/en-US/Pacemaker/1.1/html-single/Pacemaker_Explained/index.html#_the_current_state_of_the_cluster
#
# gfs2
10.1.17.12      node2
10.1.17.14      node4
#
ps -aef --forest | tail -50
ss -tupln
# 
mount -o loop /root/supp-server-7.6-rhel-7-x86_64-dvd.iso /mnt/
cd /mnt/Packages/;
cp -ar *.*  /var/www/html/sup;
createrepo -v /var/www/html/sup
cd /etc/yum.repos.d/;

==================================== iscsi Storage ====================================

# Network2 
yum -y install targetcli
mkdir /home/iscsi_disks

targetcli
/> cd backstores/fileio
/backstores/fileio> create disk01 /home/iscsi_disks/disk01.img 10G
/backstores/fileio> create disk02 /home/iscsi_disks/disk02.img 20G
/backstores/fileio> create disk03 /home/iscsi_disks/disk03.img 300G
# create a target
/backstores/fileio> cd /iscsi
/iscsi> create iqn.2019-08.svtech.lab:storage.target00
/iscsi> cd iqn.2019-08.svtech.lab:storage.target00/tpg1/luns
# set LUN
/iscsi/iqn.20...t00/tpg1/luns> create /backstores/fileio/disk01

# set ACL (it's the IQN of an initiator you permit to connect)
/iscsi/iqn.20...t00/tpg1/luns> cd ../acls
/iscsi/iqn.20...t00/tpg1/acls> create iqn.2019-08.svtech.lab:www.srv.world
/iscsi/iqn.20...t00/tpg1/acls> cd iqn.2019-08.svtech.lab:www.srv.world
# set UserID for authentication
/iscsi/iqn.20....srv.world> set auth userid=admin
/iscsi/iqn.20....srv.world> set auth password=admin123
/iscsi/iqn.20....srv.world> exit

#node2,4
vi /etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.1994-05.com.redhat:55217fcaa7a9
vi /etc/iscsi/initiatorname.iscsi
InitiatorName=iqn.1994-05.com.redhat:dbcf8c9ec8bb
#network2
/iscsi/iqn.20...t00/tpg1/acls> create iqn.1994-05.com.redhat:55217fcaa7a9
/iscsi/iqn.20...t00/tpg1/acls> create iqn.1994-05.com.redhat:dbcf8c9ec8bb



## after configuration above, the target enters in listening like follows.
ss -napt | grep 3260
systemctl enable target


# nodes 
yum -y install iscsi-initiator-utils
vi /etc/iscsi/initiatorname.iscsi
# change to the same IQN you set on the iSCSI target server
InitiatorName=iqn.2019-08.svtech.lab:www.srv.world
[root@www ~]# vi /etc/iscsi/iscsid.conf
# line 57: uncomment
node.session.auth.authmethod = CHAP
# line 61,62: uncomment and specify the username and password you set on the iSCSI target server
node.session.auth.username = username
node.session.auth.password = password

# discover target
[root@node2 ~]# iscsiadm -m discovery -t sendtargets -p network2
10.1.17.15:3260,1 iqn.2019-08.svtech.lab:storage.target00
# confirm status after discovery
iscsiadm -m node -o show
# login to the target
iscsiadm -m node --login
# confirm the established session
iscsiadm -m session -o show
# confirm the partitions
iscsiadm -m session --rescan
cat /proc/partitions

======================================================================================
lsscsi
lsblk -i
/usr/lib/udev/scsi_id -g -u /dev/sdd
udevadm info --query=all --name=/dev/sdd
/usr/lib/udev/scsi_id -g -u -d /dev/sdd

iscsiadm -m node -u
iscsiadm -m node -l

# pacemaker - all nodes
yum -y install pacemaker pcs;
systemctl start pcsd;
systemctl enable pcsd
passwd hacluster
ss -tupln
Netid  State      Recv-Q Send-Q   Local Address:Port      Peer Address:Port     
tcp    LISTEN     0      128    :::2224     :::*     users:(("pcsd",pid=14878,fd=7))

# 1 nodes
pcs cluster auth node2 node4
pcs cluster setup --name ha_cluster node2 node4
pcs cluster start --all
pcs cluster enable --all;
pcs status cluster;
pcs status corosync

ss -tupln
Netid  State      Recv-Q Send-Q   Local Address:Port      Peer Address:Port              
udp    UNCONN     0      0           10.1.17.12:50217                *:*                   users:(("corosync",pid=15526,fd=15))
udp    UNCONN     0      0           10.1.17.12:37803                *:*                   users:(("corosync",pid=15526,fd=16))
udp    UNCONN     0      0           10.1.17.12:5405                 *:*                   users:(("corosync",pid=15526,fd=9))
tcp    LISTEN     0      128                 :::2224                :::*                   users:(("pcsd",pid=15358,fd=7))

pcs resource providers
pcs resource agents ocf:heartbeat

# fence

https://redhatlinux.guru/2018/05/19/pacemaker-configure-hp-ilo-4-ssh-fencing/
fence_ilo5_ssh -a 10.1.17.2 -x -l admin -p admin123 -o status
fence_ilo5_ssh -a node1.mgt -x -l admin -p h@yl4ch1nhb4n -o status
# Change the pcs property to no-quorum-policy to freeze. 
# This property is necessary because it means that cluster nodes will do nothing after losing quorum, and this is required for GFS2
pcs property set no-quorum-policy=freeze 
pcs stonith create node2-ilo5_fence fence_ilo5_ssh ipaddr="10.1.17.2" login="admin" secure="true" passwd=admin123  pcmk_host_list="node2" op monitor interval=60s
pcs stonith create node4-ilo5_fence fence_ilo5_ssh ipaddr="10.1.17.4" login="admin" secure="true" passwd=admin123  pcmk_host_list="node4" op monitor interval=60s
pcs stonith fence node2
pcs stonith fence node4 
# quorum

corosync-quorumtool 

#[6] 	Add required resources. It's OK to set on a node.
https://www.unixarena.com/2016/01/rhel7-configuring-gfs2-on-pacemakercorosync-cluster.html/
https://www.golinuxcloud.com/configure-gfs2-setup-cluster-linux-rhel-centos-7/#Configure_DLM_Resource

lvmconf --enable-cluster;
grep locking_type /etc/lvm/lvm.conf | egrep -v '#';
reboot
yum -y install fence-agents-all lvm2-cluster gfs2-utils 
pcs property show
pcs resource delete dlm;
pcs resource delete clvmd;
pcs resource create dlm ocf:pacemaker:controld op monitor interval=30s on-fail=fence clone interleave=true ordered=true;
pcs resource create clvmd ocf:heartbeat:clvm op monitor interval=30s on-fail=fence clone interleave=true ordered=true;
pcs constraint order start dlm-clone then clvmd-clone;
pcs constraint colocation add clvmd-clone with dlm-clone

# [7] 	Create volumes on shared storage and format with GFS2. It's OK to set on a node. On this example, it is set on sdb and create partitions on it and set LVM type with fdisk.
pvcreate /dev/sde1
Physical volume "/dev/sdb1" successfully created
# create cluster volume group
vgcreate -cy vg_cluster /dev/sde1
vgextend vg_cluster /dev/sdg1
vgs

lvcreate -l100%FREE -n lv_cluster vg_cluster
lvcreate --size 200G -n lv_data1 vg_cluster

#    -t clustername:fsname : is used to specify the name of the locking table
#    -j nn : specifies how many journals(nodes) are used
#    -J : allows specification of the journal size. if not specified, a journal has a default size of 128 MB. Minimal size is 8 MB (NOT recommended) 
mkfs.gfs2 -p lock_dlm -t ha_cluster:gfs2 -j 2 /dev/vg_cluster/lv_cluster
mkfs.gfs2 -p lock_dlm -t ha_cluster:data1 -j 2 /dev/vg_cluster/lv_data1


/dev/vg_cluster/lv_cluster is a symbolic link to /dev/dm-3
This will destroy any data on /dev/dm-3
Are you sure you want to proceed? [y/n] y


# [8] 	Add shared storage to cluster resource. It's OK to set on a node.
pcs resource create fs_gfs2 Filesystem \
device="/dev/vg_cluster/lv_cluster" directory="/disk1" fstype="gfs2" \
options="noatime,nodiratime" op monitor interval=10s on-fail=fence clone interleave=true


pcs resource create data1_gfs2 Filesystem \
device="/dev/vg_cluster/lv_data1" directory="/disk3" fstype="gfs2" \
options="noatime,nodiratime" op monitor interval=10s on-fail=fence clone interleave=true


pcs constraint order start clvmd-clone then fs_gfs2-clone
pcs constraint order start clvmd-clone then data1_gfs2-clone

pcs constraint colocation add fs_gfs2-clone with clvmd-clone
pcs constraint colocation add data1_gfs2-clone with clvmd-clone

pcs constraint show
Location Constraints:
Ordering Constraints:
  start dlm-clone then start clvmd-clone (kind:Mandatory)
  start clvmd-clone then start fs_gfs2-clone (kind:Mandatory)
Colocation Constraints:
  clvmd-clone with dlm-clone (score:INFINITY)
  fs_gfs2-clone with clvmd-clone (score:INFINITY)

pcs resource restart fs_gfs2 --all
pcs resource restart data1_gfs2

# [9] 	It's OK all. Make sure GFS2 filesystem is mounted on an active node and also make sure GFS2 mounts will move to another node if current active node will be down.
[root@node01 ~]# df -hT

Filesystem                        Type      Size  Used Avail Use% Mounted on
/dev/mapper/centos-root           xfs        27G  1.1G   26G   4% /
devtmpfs                          devtmpfs  2.0G     0  2.0G   0% /dev
tmpfs                             tmpfs     2.0G   76M  1.9G   4% /dev/shm
tmpfs                             tmpfs     2.0G  8.4M  2.0G   1% /run
tmpfs                             tmpfs     2.0G     0  2.0G   0% /sys/fs/cgroup
/dev/vda1                         xfs       497M  126M  371M  26% /boot
/dev/mapper/vg_cluster-lv_cluster gfs2     1016M  259M  758M  26% /mnt

echo "`hostname`...`date`" >> /disk1/tiktok.txt;cat /disk1/tiktok.txt

==================================== ha ====================================

systemctl start libvirtd;
systemctl enable libvirtd 

nmcli connection add type bridge autoconnect yes con-name br0 ifname br0; 
nmcli connection delete eno2 ;
nmcli connection add type bridge-slave autoconnect yes con-name eno2 ifname eno2 master br0 
nmcli connection add type bridge autoconnect yes con-name br1 ifname br1; 
nmcli connection delete eno3 ;
nmcli connection add type bridge-slave autoconnect yes con-name eno3 ifname eno3 master br1

virsh autostart centos7 
virsh autostart --disable centos7 
virsh destroy centos7 
virsh shutdown centos7 
virsh list --all 
virsh console centos7 
virsh undefine centos7 
virsh migrate --live centos7 qemu+ssh://10.0.0.21/system 


virsh destroy rhel76
virsh undefine rhel76
rm /disk3/kvm/images/rhel76.img 
nmcli con mod eth0 ipv4.dns "8.8.8.8 8.8.4.4"
yum whatprovides route


mkdir -p /disk3/kvm/images
virt-install \
--name centos76 \
--ram 4096 \
--disk path=/disk3/kvm/images/centos76.img,size=10 \
--vcpus 2 \
--os-type linux \
--os-variant rhel7 \
--graphics none \
--console pty,target_type=serial \
--location 'http://ftp.iij.ad.jp/pub/linux/centos/7/os/x86_64/' \
--extra-args 'console=ttyS0,115200n8 serial'


virt-install \
--name centos76_4 \
--ram 4096 \
--disk path=/var/lib/libvirt/images/centos76_4.img,size=10 \
--vcpus 2 \
--os-type linux \
--os-variant rhel7 \
--graphics none \
--console pty,target_type=serial \
--cdrom /var/lib/libvirt/images/CentOS-7-x86_64-Minimal-1810.iso

virsh edit rhel76
 <interface type='bridge'>
    <source bridge='br0'/>
    <mac address='00:16:3e:1a:b3:4a'/>
    <model type='virtio'/>   # try this if you experience problems with VLANs
 </interface>
==>
# node2
<interface type='bridge'>
    <mac address='52:54:00:a3:e5:f6'/>
    <source bridge='br0'/>
    <target dev='vnet0'/>
    <model type='virtio'/>
    <alias name='net0'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
</interface>

# node4
 <interface type='bridge'>
    <mac address='52:54:00:a3:e5:f6'/>
    <source bridge='br0'/>
    <target dev='vnet0'/>
    <model type='virtio'/>
    <alias name='net0'/>
    <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
</interface>

virsh suspend centos76;
virt-clone \
--connect qemu:///system \
--original centos76 \
--name centos76-2 \
--file /disk3/kvm/images/centos76-2
virsh resume centos76
virsh start centos76-2

virt-clone \
--connect qemu:///system \
--original centos76 \
--name ha-centos76 \
--file /disk3/kvm/images/ha-centos76


[root@node2 ~]# ssh-keygen -t rsa
[root@node2 ~]# cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
[root@node2 ~]# ssh root@node2
[root@node2 ~]# scp -r /root/.ssh* node4:/root/

tcpdump -nni br0 icmp
virsh migrate --live centos76_2 qemu+ssh://node4/system 
virsh migrate --live centos76_2 qemu+ssh://node2/system 

cp /etc/libvirt/qemu/centos76_2.xml /disk3/kvm/config/ha_centos76_2.xml
cp /etc/libvirt/qemu/centos76.xml /disk3/kvm/config/ha-centos76.xml

pcs resource create ha_centos76_2 VirtualDomain hypervisor="qemu:///system" config="/disk3/kvm/config/ha_centos76_2.xml" \
migration_transport=ssh op start timeout="120s" op stop timeout="120s" op monitor  timeout="30" interval="10" \
meta allow-migrate="true" priority="100" op migrate_from interval="0" timeout="120s" op migrate_to interval="0" timeout="120" --group havm

pcs resource create ha_centos76_2 VirtualDomain hypervisor="qemu:///system" config="/disk3/kvm/config/ha_centos76_2.xml" \
migration_transport=ssh op start timeout="120s" op stop timeout="120s" op monitor  timeout="30" interval="10" \
meta allow-migrate="true" priority="100" op migrate_from interval="0" timeout="120s" op migrate_to interval="0" timeout="120"

pcs resource create ha_centos76 ocf:heartbeat:VirtualDomain \
        config="/disk3/kvm/config/ha-centos76.xml" migration_transport="ssh" force_stop="0" hypervisor="qemu:///system" \
        op start interval="0" timeout="90" \
        op stop interval="0" timeout="90" \
        op migrate_from interval="0" timeout="240" \
        op migrate_to interval="0" timeout="240" \
        op monitor interval="10" timeout="30" start-delay="0" \
        meta allow-migrate="true" failure-timeout="10min" target-role="Started"

pcs resource create ha_centos76-2 ocf:heartbeat:VirtualDomain \
        config="/disk3/kvm/config/ha-centos76-2.xml" migration_transport="ssh" force_stop="0" hypervisor="qemu:///system" \
        op start interval="0" timeout="90" \
        op stop interval="0" timeout="90" \
        op migrate_from interval="0" timeout="240" \
        op migrate_to interval="0" timeout="240" \
        op monitor interval="10" timeout="30" start-delay="0" \
        meta allow-migrate="true" failure-timeout="10min" target-role="Started"

pcs resource move ha_centos76 node4
pcs resource move ha_centos76 node2
pcs resource delete ha_centos76
pcs resource delete ha_centos76-2

=> 2 timeout
Reply from 10.1.17.70: bytes=32 time=7ms TTL=63
Reply from 10.1.17.70: bytes=32 time=1ms TTL=63
Request timed out.
Request timed out.
Request timed out.
Reply from 10.1.17.70: bytes=32 time=1ms TTL=63


=================================== oVirt
yum -y install http://resources.ovirt.org/pub/yum-repo/ovirt-release42.rpm 
yum -y install ovirt-engine 

[root@network2 ~]# engine-setup 
[ INFO  ] Stage: Initializing
[ INFO  ] Stage: Environment setup
          Configuration files: ['/etc/ovirt-engine-setup.conf.d/10-packaging-jboss.conf', '/etc/ovirt-engine-setup.conf.d/10-packaging.conf']
          Log file: /var/log/ovirt-engine/setup/ovirt-engine-setup-20190903150707-xkvd7b.log
          Version: otopi-1.7.8 (otopi-1.7.8-1.el7)
[ INFO  ] Stage: Environment packages setup
[ INFO  ] Stage: Programs detection
[ INFO  ] Stage: Environment setup
[ INFO  ] Stage: Environment customization
         
          --== PRODUCT OPTIONS ==--
         
          Configure Engine on this host (Yes, No) [Yes]: 
          Configure ovirt-provider-ovn (Yes, No) [Yes]: 
          Configure Image I/O Proxy on this host (Yes, No) [Yes]: 
          Configure WebSocket Proxy on this host (Yes, No) [Yes]: 
         
          * Please note * : Data Warehouse is required for the engine.
          If you choose to not configure it on this host, you have to configure
          it on a remote host, and then configure the engine on this host so
          that it can access the database of the remote Data Warehouse host.
          Configure Data Warehouse on this host (Yes, No) [Yes]: 
          Configure VM Console Proxy on this host (Yes, No) [Yes]: 
         
          --== PACKAGES ==--
         
[ INFO  ] Checking for product updates...
[ INFO  ] No product updates found
         
          --== NETWORK CONFIGURATION ==--
         
          Host fully qualified DNS name of this server [network2]: 
[WARNING] Host name network2 has no domain suffix
[WARNING] Failed to resolve network2 using DNS, it can be resolved only locally
          Setup can automatically configure the firewall on this system.
          Note: automatic configuration of the firewall may overwrite current settings.
          NOTICE: iptables is deprecated and will be removed in future releases
          Do you want Setup to configure the firewall? (Yes, No) [Yes]: no
[WARNING] Host name network2 has no domain suffix
[WARNING] Host name network2 has no domain suffix
[WARNING] Host name network2 has no domain suffix
         
          --== DATABASE CONFIGURATION ==--
         
          Where is the DWH database located? (Local, Remote) [Local]: 
          Setup can configure the local postgresql server automatically for the DWH to run. This may conflict with existing applications.
          Would you like Setup to automatically configure postgresql and create DWH database, or prefer to perform that manually? (Automatic, Manual) [Automatic]: 
          Where is the Engine database located? (Local, Remote) [Local]: 
          Setup can configure the local postgresql server automatically for the engine to run. This may conflict with existing applications.
          Would you like Setup to automatically configure postgresql and create Engine database, or prefer to perform that manually? (Automatic, Manual) [Automatic]: 
         
          --== OVIRT ENGINE CONFIGURATION ==--
         
          Engine admin password: 
          Confirm engine admin password: 
[WARNING] Password is weak: it is based on a dictionary word
          Use weak password? (Yes, No) [No]: yes
          Application mode (Virt, Gluster, Both) [Both]: 
          Use default credentials (admin@internal) for ovirt-provider-ovn (Yes, No) [Yes]: 
         
          --== STORAGE CONFIGURATION ==--
         
          Default SAN wipe after delete (Yes, No) [No]: 
         
          --== PKI CONFIGURATION ==--
         
          Organization name for certificate [Test]: 
         
          --== APACHE CONFIGURATION ==--
         
          Setup can configure the default page of the web server to present the application home page. This may conflict with existing applications.
          Do you wish to set the application as the default page of the web server? (Yes, No) [Yes]: 
          Setup can configure apache to use SSL using a certificate issued from the internal CA.
          Do you wish Setup to configure that, or prefer to perform that manually? (Automatic, Manual) [Automatic]: 
         
          --== SYSTEM CONFIGURATION ==--
         
         
          --== MISC CONFIGURATION ==--
         
          Please choose Data Warehouse sampling scale:
          (1) Basic
          (2) Full
          (1, 2)[1]: 
         
          --== END OF CONFIGURATION ==--
         
[ INFO  ] Stage: Setup validation
         
          --== CONFIGURATION PREVIEW ==--
         
          Application mode                        : both
          Default SAN wipe after delete           : False
          Update Firewall                         : False
          Host FQDN                               : network2
          Configure local Engine database         : True
          Set application as default page         : True
          Configure Apache SSL                    : True
          Engine database secured connection      : False
          Engine database user name               : engine
          Engine database name                    : engine
          Engine database host                    : localhost
          Engine database port                    : 5432
          Engine database host name validation    : False
          Engine installation                     : True
          PKI organization                        : Test
          Set up ovirt-provider-ovn               : True
          Configure WebSocket Proxy               : True
          DWH installation                        : True
          DWH database host                       : localhost
          DWH database port                       : 5432
          Configure local DWH database            : True
          Configure Image I/O Proxy               : True
          Configure VMConsole Proxy               : True
         
          Please confirm installation settings (OK, Cancel) [OK]: 
[ INFO  ] Stage: Transaction setup
[ INFO  ] Stopping engine service
[ INFO  ] Stopping ovirt-fence-kdump-listener service
[ INFO  ] Stopping dwh service
[ INFO  ] Stopping Image I/O Proxy service
[ INFO  ] Stopping vmconsole-proxy service
[ INFO  ] Stopping websocket-proxy service
[ INFO  ] Stage: Misc configuration
[ INFO  ] Stage: Package installation
[ INFO  ] Stage: Misc configuration
[ INFO  ] Upgrading CA
[ INFO  ] Initializing PostgreSQL
[ INFO  ] Creating PostgreSQL 'engine' database
[ INFO  ] Configuring PostgreSQL
[ INFO  ] Creating PostgreSQL 'ovirt_engine_history' database
[ INFO  ] Configuring PostgreSQL
[ INFO  ] Creating CA
[ INFO  ] Creating/refreshing DWH database schema
[ INFO  ] Configuring Image I/O Proxy
[ INFO  ] Setting up ovirt-vmconsole proxy helper PKI artifacts
[ INFO  ] Setting up ovirt-vmconsole SSH PKI artifacts
[ INFO  ] Configuring WebSocket Proxy
[ INFO  ] Creating/refreshing Engine database schema
[ INFO  ] Creating/refreshing Engine 'internal' domain database schema
[ INFO  ] Creating default mac pool range
[ INFO  ] Adding default OVN provider to database
[ INFO  ] Adding OVN provider secret to database
[ INFO  ] Setting a password for internal user admin
[ INFO  ] Generating post install configuration file '/etc/ovirt-engine-setup.conf.d/20-setup-ovirt-post.conf'
[ INFO  ] Stage: Transaction commit
[ INFO  ] Stage: Closing up
[ INFO  ] Starting engine service
[ INFO  ] Starting dwh service
[ INFO  ] Restarting ovirt-vmconsole proxy service
         
          --== SUMMARY ==--
         
[ INFO  ] Restarting httpd
          In order to configure firewalld, copy the files from
              /etc/ovirt-engine/firewalld to /etc/firewalld/services
              and execute the following commands:
              firewall-cmd --permanent --add-service ovirt-nfs
              firewall-cmd --permanent --add-service ovirt-postgres
              firewall-cmd --permanent --add-service ovirt-https
              firewall-cmd --permanent --add-service ovn-central-firewall-service
              firewall-cmd --permanent --add-service ovirt-fence-kdump-listener
              firewall-cmd --permanent --add-service ovirt-imageio-proxy
              firewall-cmd --permanent --add-service ovirt-websocket-proxy
              firewall-cmd --permanent --add-service ovirt-http
              firewall-cmd --permanent --add-service ovirt-vmconsole-proxy
              firewall-cmd --permanent --add-service ovirt-provider-ovn
              firewall-cmd --reload
          The following network ports should be opened:
              tcp:111
              tcp:2049
              tcp:2222
              tcp:32803
              tcp:35357
              tcp:443
              tcp:5432
              tcp:54323
              tcp:6100
              tcp:662
              tcp:6641
              tcp:6642
              tcp:80
              tcp:875
              tcp:892
              tcp:9696
              udp:111
              udp:32769
              udp:662
              udp:7410
              udp:875
              udp:892
          An example of the required configuration for iptables can be found at:
              /etc/ovirt-engine/iptables.example
          Please use the user 'admin@internal' and password specified in order to login
          Web access is enabled at:
              http://network2:80/ovirt-engine
              https://network2:443/ovirt-engine
          Internal CA 4F:EA:7E:B9:35:7B:01:4B:35:52:AE:05:C8:E8:09:29:F8:70:71C

# node2 node4
yum -y install http://resources.ovirt.org/pub/yum-repo/ovirt-release42.rpm
yum -y install qemu-kvm libvirt virt-install bridge-utils vdsm 

============================ fence virtd
https://access.redhat.com/solutions/293183
yum -y install qemu-kvm libvirt virt-install bridge-utils
yum -y install vnc-server
 yum install virt-manager
fence_xvm -o list
ip maddr show
tcpdump -i eno1 udp port 1229 


-------

yum install fence-virt fence-virtd fence-virtd-libvirt fence-virtd-multicast fence-virtd-serial
mkdir -p /etc/cluster
dd if=/dev/urandom of=/etc/cluster/fence_xvm.key bs=4k count=1
fence_virtd -c

systemctl enable fence_virtd
systemctl start fence_virtd


yum install fence-virt 
#
10.1.17.14      compute4 # vm1, vm2
10.1.29.20      compute1 # vm3
# fence
(on compute1)
address = "225.0.1.12";
(on compute4)
address = "225.0.4.12";


fence_xvm  -a 225.0.4.12 -k /etc/cluster/fence_xvm-compute4.key -o list
fence_xvm  -a 225.0.1.12 -k /etc/cluster/fence_xvm-compute1.key -o list

fence_xvm -o reboot -a 225.0.1.12 -k /etc/cluster/fence_xvm-compute1.key -H vm3 

======================== HA lvm + vip =================
#node2, node6
https://www.golinuxcloud.com/configure-ha-lvm-cluster-resource-linux/
https://www.unixarena.com/2015/12/rhel-7-pacemaker-cluster-resource-group-management.html/

-------
yum install fence-virt fence-virtd fence-virtd-libvirt fence-virtd-multicast fence-virtd-serial
mkdir -p /etc/cluster
dd if=/dev/urandom of=/etc/cluster/fence_xvm.key bs=4k count=1
fence_virtd -c

systemctl enable fence_virtd
systemctl start fence_virtd
ip maddr show
tcpdump -i bond0 udp port 1229 
tcpdump -i bond0 -nn port 1229
tcpdump -i bond1 -nn port 1229
fence_xvm  -a 225.0.2.12 -k /etc/cluster/fence_xvm-node2.key -o list
fence_xvm  -a 225.0.6.12 -k /etc/cluster/fence_xvm-node6.key -o list
# vm
yum install fence-virt 

# pacemaker - all nodes
yum -y install pacemaker pcs;
systemctl start pcsd;
systemctl enable pcsd
passwd hacluster
ss -tupln
Netid  State      Recv-Q Send-Q   Local Address:Port      Peer Address:Port     
tcp    LISTEN     0      128    :::2224     :::*     users:(("pcsd",pid=14878,fd=7))

# 1 nodes
pcs cluster auth olap-db1 olap-db2
pcs cluster setup --name olap-db-cluster olap-db1 olap-db2
pcs cluster start --all
pcs cluster enable --all;
pcs status cluster;
pcs status corosync

ss -tupln
Netid  State      Recv-Q Send-Q   Local Address:Port      Peer Address:Port              
udp    UNCONN     0      0           10.1.17.12:50217                *:*                   users:(("corosync",pid=15526,fd=15))
udp    UNCONN     0      0           10.1.17.12:37803                *:*                   users:(("corosync",pid=15526,fd=16))
udp    UNCONN     0      0           10.1.17.12:5405                 *:*                   users:(("corosync",pid=15526,fd=9))
tcp    LISTEN     0      128                 :::2224                :::*                   users:(("pcsd",pid=15358,fd=7))

pcs resource providers
pcs resource agents ocf:heartbeat

olap-db-vip		10.38.22.63

/dev/sda 200GB /edb/wal 
/dev/sdb 15TB /edb/data 
pvcreate /dev/sda
pvcreate /dev/sdb
vgcreate vg_wal /dev/sda
lvcreate -L 195GB -n lv_wal vg_wal

vgcreate vg_data /dev/sdb
lvcreate -L 14.5TB -n lv_data vg_data

systemctl mask lvm2-lvmetad.socket
# 2 node 
mkdir /edb
mkdir /edb/wal
mkdir /edb/data 
# pcmk_host_map: A mapping of host names to ports numbers for devices that do not support host names. Eg. node1:1;node2:2,3 would tell the cluster to use port 1 for node1 and ports 2 and 3 for node2
# pcmk_host_list: A list of machines controlled by this device (Optional unless pcmk_host_check=static-list).
# pcmk_host_check: How to determine which machines are controlled by the device. Allowed values: dynamic-list (query the device), static-list (check the pcmk_host_list attribute), none(assume every device can fence every machine)
# pcmk_delay_max: Enable a random delay for stonith actions and specify the maximum of random delay. This prevents double fencing when using slow devices such as sbd. Use this to enable a random delay for stonith actions. The overall delay is derived from this random delay value adding a static delay so that the sum is kept below the maximum delay.
# pcmk_delay_base: Enable a base delay for stonith actions and specify base delay value. This prevents double fencing when different delays are configured on the nodes. Use this to enable a static delay for stonith actions. The overall delay is derived from a random delay value adding this static delay so that the sum is kept below the maximum delay.
# pcmk_action_limit: The maximum number of actions can be performed in parallel on this device Pengine property concurrent-fencing=true needs to be configured first. Then use this to specify the maximum number of actions can be performed in parallel on this device. -1 is unlimited.
pcs property set no-quorum-policy=freeze
pcs stonith create fence_xvm-node2 fence_xvm pcmk_host_map="node2:olap-db1-prod node6:olap-db2-prod" pcmk_host_list="olap-db1-prod" port="olap-db1-prod" key_file=/etc/cluster/fence_xvm-node2.key multicast_address=225.0.2.12
pcs stonith create fence_xvm-node6 fence_xvm pcmk_host_map="node2:olap-db1-prod node6:olap-db2-prod" pcmk_host_list="olap-db2-prod" port="olap-db2-prod" key_file=/etc/cluster/fence_xvm-node6.key multicast_address=225.0.6.12
pcs stonith create fence_xvm-olap-db1 fence_xvm pcmk_host_list="olap-db1-prod" key_file=/etc/cluster/fence_xvm-node2.key multicast_address=225.0.2.12
pcs stonith create fence_xvm-olap-db2 fence_xvm pcmk_host_list="olap-db2-prod" key_file=/etc/cluster/fence_xvm-node6.key multicast_address=225.0.6.12
# vip
pcs status
pcs resource create rs_vip IPaddr2 ip=10.38.22.63 cidr_netmask=25 --group halvmfs

# 
mv /etc/lvm/lvm.conf /etc/lvm/lvm.conf.orig
cat /etc/lvm/lvm.conf.orig  |grep -v "#" |grep . > /etc/lvm/lvm.conf
grep use_lvmetad /etc/lvm/lvm.conf |grep -v "#"
    use_lvmetad = 0
dracut -H -f /boot/initramfs-$(uname -r).img $(uname -r)
ls -l /boot/
-rw-------  1 root root 28503572 Sep 20 10:44 initramfs-3.10.0-862.el7.x86_64.img <==

pcs resource create rs_lvm_wal LVM volgrpname=vg_wal exclusive=true --group halvmfs
pcs resource create rs_lvm_data LVM volgrpname=vg_data exclusive=true --group halvmfs

mkfs.xfs /dev/vg_wal/lv_wal
mkfs.xfs /dev/vg_data/lv_data
pcs resource create rs_fs_wal Filesystem device="/dev/vg_wal/lv_wal" directory="/edb/wal" fstype="xfs" --group halvmfs
pcs resource create rs_fs_data Filesystem device="/dev/vg_data/lv_data" directory="/edb/data" fstype="xfs" --group halvmfs

pcs resource delete rs_lvm_wal 
pcs resource delete rs_lvm_data 
pcs resource delete rs_fs_wal
pcs resource delete rs_fs_data 

http://computerexpress1.blogspot.com/2017/11/activepassive-postgresql-cluster-using.html

[root@olap-db1 /]# su - postgres -c '/var/lib/pgsql/pgdb_service status'
pg_ctl: server is running (PID: 28559)
/usr/pgsql-10/bin/postgres "-D" "/edb/data/pgdb"

pcs resource create rs_pgsql ocf:heartbeat:pgsql pgctl="/usr/pgsql-10/bin/pg_ctl" psql="/usr/pgsql-10/bin/psql" pgdata="/edb/data/pgdb" \
pgport="5432" pgdba="postgres" node_list="olap-db1 olap-db2" op start timeout="60s" interval="0s" on-fail="restart"  \
op monitor timeout="60s" interval="4s" on-fail="restart" op promote timeout="60s" interval="0s" on-fail="restart" \
op demote timeout="60s" interval="0s" on-fail="stop" op stop timeout="60s" interval="0s" on-fail="block" \
op notify timeout="60s" interval="0s" --group halvmfs

pcs constraint order rs_lvm_wal then rs_pgsql
pcs constraint order rs_pgsql then rs_vip
pcs constraint order remove rs_lvm_wal then rs_pgsql
pcs constraint order remove rs_pgsql then rs_vip

# local volume
pvcreae /dev/sdf
vgcreate -c n vg_archive /dev/sdf
lvcreate -n lv_share -L 1500G vg_archive