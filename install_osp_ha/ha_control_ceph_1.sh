/etc/hosts
10.1.17.21      osd1
10.1.17.22      osd2
10.1.17.23      osd3
10.1.17.24      mon1
10.1.17.25      admin

sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo rpm --import 'https://download.ceph.com/keys/release.asc'
rpm -Uvh https://download.ceph.com/rpm-nautilus/el7/noarch/ceph-release-1-1.el7.noarch.rpm

 =================================================== Setup Ceph ==============================================================

# admin node
yum install ceph-deploy
# all node
yum install snappy leveldb gdisk python-argparse gperftools-libs
yum install ceph

# mon1 

# mon1 - ceph
vi /etc/sudoers.d/cephuser 
cephuser ALL = (root) NOPASSWD:ALL
cephuser ALL = (ceph) NOPASSWD:ALL

uuidgen
362118c6-6d4d-452b-84c1-467d6fc7965e
/etc/ceph/ceph.conf
[global]
fsid = 362118c6-6d4d-452b-84c1-467d6fc7965e
mon initial members = mon1 
mon host = 10.1.17.24
public network = 10.1.0.0/16
cluster network = 10.1.0.0/16
auth cluster required = cephx
auth service required = cephx
auth client required = cephx
osd journal size = 1024
osd pool default size = 3     # Write an object n times.
osd pool default min size = 2 # Allow writing n copies in a degraded state.
osd pool default pg num = 333 
osd pool default pgp num = 333
osd crush chooseleaf type = 1

# mon1 - mon 
sudo ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *';
sudo ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *';
sudo ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring --gen-key -n client.bootstrap-osd --cap mon 'profile bootstrap-osd' --cap mgr 'allow r';
sudo ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring;
sudo ceph-authtool /tmp/ceph.mon.keyring --import-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring

monmaptool --create --add mon1 10.1.17.24 --fsid 362118c6-6d4d-452b-84c1-467d6fc7965e /tmp/monmap;
sudo mkdir /var/lib/ceph/mon/ceph-mon1
sudo -u ceph ceph-mon --mkfs -i mon1 --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring

sudo systemctl start ceph-mon@mon1
sudo systemctl status ceph-mon@mon1

sudo ceph mon enable-msgr2
sudo systemctl restart ceph-mon@mon1


sudo ceph status

# mon1 - mgr
sudo ceph auth get-or-create mgr.mon1 mon 'allow profile mgr' osd 'allow *' mds 'allow *'
sudo -u ceph mkdir /var/lib/ceph/mgr/ceph-mon1/
sudo ceph auth get mgr.mon1 -o /var/lib/ceph/mgr/ceph-mon1/keyring

systemctl start ceph-mgr@mon1
systemctl status ceph-mgr@mon1
systemctl enable ceph-mgr@mon1

# mon1 - mgr - dashboard
https://docs.ceph.com/docs/nautilus/mgr/dashboard/#enabling
yum install ceph-mgr-dashboard
sudo ceph mgr module enable dashboard
sudo ceph dashboard create-self-signed-cert
sudo openssl req -new -nodes -x509 -subj "/O=IT/CN=ceph-mgr-dashboard" -days 3650 -keyout dashboard.key -out dashboard.crt -extensions v3_ca
sudo ceph config-key set mgr/dashboard/crt -i dashboard.crt;
sudo ceph config-key set mgr/dashboard/key -i dashboard.key
(
sudo ceph config-key set mgr/dashboard/ceph-mon1/crt -i dashboard.crt
sudo ceph config-key set mgr/dashboard/ceph-mon1/key -i dashboard.key
)
sudo ceph mgr module enable dashboard
[cephuser@mon1 ceph]$ sudo ceph mgr services
{
    "dashboard": "https://mon1:8443/"
}
sudo ceph dashboard ac-user-create admin admin123 administrator
sudo ceph mgr module ls

# osd1 - osd
sudo ceph auth get client.bootstrap-osd -o /var/lib/ceph/bootstrap-osd/ceph.keyring;
sudo ceph-volume lvm create --data /dev/sdb;
sudo ceph-volume lvm list
sudo ceph osd tree
sudo systemctl start ceph-osd@0
sudo systemctl status ceph-osd@0
sudo systemctl enable ceph-osd@0

sudo ceph-volume lvm create --data /dev/sdc;
sudo ceph-volume lvm list;
sudo ceph osd tree;
sudo systemctl start ceph-osd@3;
sudo systemctl status ceph-osd@3;
sudo systemctl enable ceph-osd@3

# osd2 - osd
sudo ceph auth get client.bootstrap-osd -o /var/lib/ceph/bootstrap-osd/ceph.keyring;
sudo ceph-volume lvm create --data /dev/sdb;
sudo ceph-volume lvm list
sudo ceph osd tree
sudo systemctl start ceph-osd@1;
sudo systemctl status ceph-osd@1;
sudo systemctl enable ceph-osd@1

sudo ceph-volume lvm create --data /dev/sdc;
sudo ceph-volume lvm list;
sudo ceph osd tree;
sudo systemctl start ceph-osd@4;
sudo systemctl status ceph-osd@4;
sudo systemctl enable ceph-osd@4
# osd3 - osd
sudo ceph auth get client.bootstrap-osd -o /var/lib/ceph/bootstrap-osd/ceph.keyring;
sudo ceph-volume lvm create --data /dev/sdb;
sudo ceph-volume lvm list
sudo ceph osd tree
sudo systemctl start ceph-osd@2;
sudo systemctl status ceph-osd@2;
sudo systemctl enable ceph-osd@2

sudo ceph-volume lvm create --data /dev/sdc;
sudo ceph-volume lvm list;
sudo ceph osd tree;
sudo systemctl start ceph-osd@5;
sudo systemctl status ceph-osd@5;
sudo systemctl enable ceph-osd@5

=================================================== Intergrate Ceph ==============================================================
https://gist.github.com/vanduc95/97c4110338e0319a11d4b8ab36c2134a
https://github.com/hocchudong/Ghichep-Storage/blob/master/ChienND/Ceph/Configure%20Block%20Ceph%20with%20OpenStack.md

sudo ceph auth get-or-create client.cinder mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rwx pool=images'
sudo ceph auth get-or-create client.glance mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=images'
sudo ceph auth get-or-create client.cinder-backup mon 'allow r' osd 'allow class-read object_prefix rbd_children, allow rwx pool=backups'

[cephuser@mon1 ceph]$ sudo ceph auth list
installed auth entries:

osd.0
        key: AQCSGEFdQ4hlOxAA3LKSDPGi8uuwixFFcjKcIA==
        caps: [mgr] allow profile osd
        caps: [mon] allow profile osd
        caps: [osd] allow *
osd.1
        key: AQAyHUFduEncAhAAy2mPsbLIi2zlQRtd1DeRvQ==
        caps: [mgr] allow profile osd
        caps: [mon] allow profile osd
        caps: [osd] allow *
osd.2
        key: AQCdHUFdNvaDEhAAe65RT2A6hGtbn1LFDUBnKg==
        caps: [mgr] allow profile osd
        caps: [mon] allow profile osd
        caps: [osd] allow *
osd.3
        key: AQBAQ0FdNXSfCBAAGPEzpghsROGvHNnuEO4GyA==
        caps: [mgr] allow profile osd
        caps: [mon] allow profile osd
        caps: [osd] allow *
osd.4
        key: AQCFQ0FdGQ6hFBAAm0oPpLDafTSBLAHHROGAGg==
        caps: [mgr] allow profile osd
        caps: [mon] allow profile osd
        caps: [osd] allow *
osd.5
        key: AQCyQ0FdLS7EOBAAvrtmrV0qwPg+YxQeuwlUug==
        caps: [mgr] allow profile osd
        caps: [mon] allow profile osd
        caps: [osd] allow *
client.admin
        key: AQD1GUBdoCGoMxAAupOhVEj7pOhWDIQxNcJ+2g==
        caps: [mds] allow *
        caps: [mgr] allow *
        caps: [mon] allow *
        caps: [osd] allow *
client.bootstrap-mds
        key: AQAE/0BdcQMgFxAARY1TaeQ96r89wqy4cZQJpA==
        caps: [mon] allow profile bootstrap-mds
client.bootstrap-mgr
        key: AQAE/0BdDxcgFxAADJf48NLxnPCNBm8qNYndgQ==
        caps: [mon] allow profile bootstrap-mgr
client.bootstrap-osd
        key: AQD1GUBdZd3VORAAD4A88M7DT7W4DAkigIqt9w==
        caps: [mgr] allow r
        caps: [mon] profile bootstrap-osd
client.bootstrap-rbd
        key: AQAE/0Bdbj8gFxAAgfNWRpRXg5wYm7ziSxEKWw==
        caps: [mon] allow profile bootstrap-rbd
client.bootstrap-rbd-mirror
        key: AQAE/0Bdw1IgFxAAwRAtoUr/vVutL2WjH6hMLw==
        caps: [mon] allow profile bootstrap-rbd-mirror
client.bootstrap-rgw
        key: AQAE/0BdVGkgFxAAhJguR6hzPJGw7b/TtjezAg==
        caps: [mon] allow profile bootstrap-rgw
client.cinder
        key: AQDDT0FdBH4qOBAAyrgmDM9GQEXFaxoBQVy1ug==
        caps: [mon] allow r
        caps: [osd] allow class-read object_prefix rbd_children, allow rwx pool=volumes, allow rwx pool=vms, allow rwx pool=images
client.cinder-backup
        key: AQAgUkFdkjKKLhAAJUvbI4PTmBYYzGcq1sajvw==
        caps: [mon] allow r
        caps: [osd] allow class-read object_prefix rbd_children, allow rwx pool=backups
client.glance
        key: AQAOUkFdMc0tGxAAWZ/1wIOS9VesnyrM0w/rqw==
        caps: [mon] allow r
        caps: [osd] allow class-read object_prefix rbd_children, allow rwx pool=images
mgr.admin
        key: AQCBHkFdcZ7lIRAAUcdwctHdgNZVjpv1aNo3PA==
        caps: [mds] allow *
        caps: [mon] allow profile mgr
        caps: [osd] allow *
mgr.mon1
        key: AQBUH0FdsIYwLhAA4QAhzwvz4feG1mzx+lwdGw==
        caps: [mds] allow *
        caps: [mon] allow profile mgr
        caps: [osd] allow *
		
ceph osd pool create volumes 128
ceph osd pool create images 128;
ceph osd pool create backups 128;
ceph osd pool create vms 128
		
# computes & controls
yum-config-manager --disable centos-ceph-luminous
sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
sudo rpm --import 'https://download.ceph.com/keys/release.asc'
rpm -Uvh https://download.ceph.com/rpm-nautilus/el7/noarch/ceph-release-1-1.el7.noarch.rpm

yum install -y python-rbd (Cho glance-api)
yum install -y ceph-common (Cho nova-compute, cinder-backup, cinder-volume)

scp /etc/ceph/ceph* control1:/etc/ceph
scp /etc/ceph/ceph* control2:/etc/ceph
scp /etc/ceph/ceph* control3:/etc/ceph
scp /etc/ceph/ceph* compute2:/etc/ceph
scp /etc/ceph/ceph* compute3:/etc/ceph


ceph auth get-or-create client.glance | tee /etc/ceph/ceph.client.glance.keyring; 
chown glance:glance /etc/ceph/ceph.client.glance.keyring;
ceph auth get-or-create client.cinder | tee /etc/ceph/ceph.client.cinder.keyring; 
chown cinder:cinder /etc/ceph/ceph.client.cinder.keyring;
ceph auth get-or-create client.cinder-backup | tee /etc/ceph/ceph.client.cinder-backup.keyring;
chown cinder:cinder /etc/ceph/ceph.client.cinder-backup.keyring

# control - cinder - rbd: volumes
yum --enablerepo=centos-openstack-rocky,epel -y install openstack-cinder 
systemctl start openstack-cinder-volume 
systemctl enable openstack-cinder-volume 

[root@control1 ~(keystone)]# openstack volume service list      
+------------------+----------------------+------+---------+-------+----------------------------+
| Binary           | Host                 | Zone | Status  | State | Updated At                 |
+------------------+----------------------+------+---------+-------+----------------------------+
| cinder-volume    | control1@ceph        | nova | enabled | up    | 2019-10-03T10:22:06.000000 |


[root@control1 ~(keystone)]# uuidgen
8e7fb7d7-e7ae-4401-a1f9-deeaf75ab4a4

vi /etc/cinder/cinder.conf
[DEFAULT]
...
enabled_backends=ceph
glance_api_version = 2
[ceph]
volume_backend_name=ceph
volume_driver=cinder.volume.drivers.rbd.RBDDriver
rbd_pool=volumes
rbd_ceph_conf=/etc/ceph/ceph.conf
rbd_flatten_volume_from_snapshot=false
rbd_max_clone_depth=5
rbd_store_chunk_size = 4
rados_connect_timeout = -1
rbd_user=cinder
rbd_secret_uuid=8e7fb7d7-e7ae-4401-a1f9-deeaf75ab4a4

systemctl restart openstack-nova-api.service;
systemctl restart openstack-cinder-api.service openstack-cinder-scheduler.service openstack-cinder-volume.service	

# compute - nova - rbd

# mon1
ceph auth get-or-create client.cinder | ssh root@compute2 sudo tee /etc/ceph/ceph.client.cinder.keyring
ceph auth get-or-create client.cinder | ssh root@compute3 sudo tee /etc/ceph/ceph.client.cinder.keyring
[client.cinder]
        key = AQDDT0FdBH4qOBAAyrgmDM9GQEXFaxoBQVy1ug==
ceph auth get-key client.cinder | ssh root@compute2 tee /root/client.cinder.key
ceph auth get-key client.cinder | ssh root@compute3 tee /root/client.cinder.key
AQDDT0FdBH4qOBAAyrgmDM9GQEXFaxoBQVy1ug==

# computes - rbd: vms
vi /etc/nova/nova.conf

[libvirt]
images_type = rbd
images_rbd_pool = vms
images_rbd_ceph_conf = /etc/ceph/ceph.conf
rbd_user = cinder
rbd_secret_uuid = 8e7fb7d7-e7ae-4401-a1f9-deeaf75ab4a4
disk_cachemodes="network=writeback"
hw_disk_discard = unmap 
live_migration_flag= "VIR_MIGRATE_UNDEFINE_SOURCE,VIR_MIGRATE_PEER2PEER,VIR_MIGRATE_LIVE,VIR_MIGRATE_PERSIST_DEST,VIR_MIGRATE_TUNNELLED"


cat > secret.xml <<EOF
<secret ephemeral='no' private='no'>
  <uuid>8e7fb7d7-e7ae-4401-a1f9-deeaf75ab4a4</uuid>
  <usage type='ceph'>
    <name>client.cinder secret</name>
  </usage>
</secret>
EOF

virsh secret-define --file secret.xml
Secret 8e7fb7d7-e7ae-4401-a1f9-deeaf75ab4a4 created

sudo virsh secret-set-value --secret 8e7fb7d7-e7ae-4401-a1f9-deeaf75ab4a4 --base64 $(cat /root/client.cinder.key)
systemctl restart libvirtd.service openstack-nova-compute.service
openstack volume type create --property volume_backend_name='ceph'  volume_from_ceph 

# check volumes
[root@mon1 ceph]# rbd -p vms ls
RBD images are thin-provisionned
04117f32-9c15-44f2-bd02-227e18f2e4e5_disk
[root@mon1 ceph]# rbd -p volumes ls
volume-288f892c-fcb0-46e4-91ef-3c8be9dd04a1
volume-697ff017-c39b-401e-ae46-9c65ba023b6d
volume-81816a8e-4892-4cfd-91d9-aa6663a17527

rbd diff volumes/volume-288f892c-fcb0-46e4-91ef-3c8be9dd04a1 | awk '{ SUM += $2 } END { print SUM/1024/1024 " MB" }'
1003.36 MB

rbd diff volumes/volume-288f892c-fcb0-46e4-91ef-3c8be9dd04a1 | awk '{ SUM += $2 } END { print SUM/1024/1024 " MB" }'
rbd diff volumes/04117f32-9c15-44f2-bd02-227e18f2e4e5_disk | awk '{ SUM += $2 } END { print SUM/1024/1024 " MB" }'



