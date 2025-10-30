.. contents::

DRBD
====

virter
------

DRBDを手元で動かしてみるためのVMその他を、libvirtを使ってセットアップするためのツール。
Goで実装されていて、single binaryをダウンロードして実行することで使える。

preparing libvirt on Ubuntu 24.04::

  $ sudo apt install libvirt-daemon-system bridge-utils qemu-kvm libvirt-daemon
  $ sudo usermod -a -G libvirt,kvm iwasakims
  $ exit

  $ sudo mkdir -p /var/lib/libvirt/images
  $ sudo virsh pool-define-as --name default --type dir --target /var/lib/libvirt/images
  $ sudo virsh pool-build default
  $ sudo virsh pool-start default
  $ sudo virsh pool-autostart default

using virter::

  $ wget https://github.com/LINBIT/virter/releases/download/v0.28.1/virter-linux-amd64
  $ sudo mv virter-linux-amd64 /usr/local/bin/virter
  $ chmod a+x /usr/local/bin/virter
  
  $ virter image ls --available
  WARN[0000] could not look up storage pool default        error="Storage pool not found: no storage pool with matching name 'default'"
  INFO[0000] Builtin image registry does not exist, writing to /home/iwasakims/.local/share/virter/images.toml
  Name              URL
  alma-8            https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2
  alma-9            https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2
  amazonlinux-2     https://cdn.amazonlinux.com/os-images/2.0.20250305.0/kvm/amzn2-kvm-2.0.20250305.0-x86_64.xfs.gpt.qcow2
  amazonlinux-2023  https://cdn.amazonlinux.com/al2023/os-images/2023.6.20250303.0/kvm/al2023-kvm-2023.6.20250303.0-kernel-6.1-x86_64.xfs.gpt.qcow2
  centos-6          https://cloud.centos.org/centos/6/images/CentOS-6-x86_64-GenericCloud.qcow2
  centos-7          https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud.qcow2
  centos-8          https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2
  debian-10         https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2
  debian-11         https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2
  debian-12         https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
  debian-9          https://cdimage.debian.org/cdimage/openstack/current-9/debian-9-openstack-amd64.qcow2
  rocky-8           https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2
  rocky-9           https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2
  ubuntu-bionic     https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img
  ubuntu-focal      https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
  ubuntu-jammy      https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
  ubuntu-noble      https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
  ubuntu-xenial     https://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img

  $ virter image pull rocky-9
  
  $ virter vm run --name rocky-9-hello --id 11 --wait-ssh --disk "name=disk1,size=5GiB,format=qcow2,bus=virtio" rocky-9
  $ virter vm ssh rocky-9-hello

pulling old rocky-9 from vault::
  
  $ virter image pull rocky-92 https://dl.rockylinux.org/vault/rocky/9.2/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2
  $ virter vm run --name rocky-92-1 --id 11 --wait-ssh --disk "name=disk1,size=5GiB,format=qcow2,bus=virtio" rocky-92
  $ virter vm ssh rocky-92-1


building RPM on rocky-9
-----------------------

kmod-drbd::

  # dnf install git automake autoconf rpm-build kernel-devel kernel-headers kernel-rpm-macros kernel-abi-stablelists
  # git clone --recursive https://github.com/LINBIT/drbd
  # cd drbd
  # git checkout drbd-9.2.13
  # git submodule update

  # make tarball
  # export KDIR=/usr/src/kernels/5.14.0-503.33.1.el9_5.x86_64
  # make kmp-rpm

drbd-utils::

  # dnf install gcc-c++ selinux-policy-devel automake autoconf keyutils-libs-devel libxslt docbook-style-xsl
  # dnf --enablerepo=devel install rubygem-asciidoctor po4a
  # git clone --recursive https://github.com/LINBIT/drbd-utils
  # cd drbd-utils
  # git checkout v9.27.0
  # git submodule update
  # ./autogen.sh
  # ./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc
  # make tarball VERSION=9.27.0
  # mkdir -p ~/rpmbuild/SOURCES
  # cp drbd-utils-9.27.0.tar.gz  ~/rpmbuild/SOURCES/
  # ./configure --enable-spec
  # rpmbuild -bb drbd.spec --without sbinsymlinks --without heartbeat


building RPM on rocky-92
------------------------

::

  # cat > /etc/yum.repos.d/rocky-vault-92.repo <<'EOF'
  [base92]
  name=Rocky Linux 9.2 - base
  baseurl=https://dl.rockylinux.org/vault/rocky/9.2/BaseOS/x86_64/kickstart/
  gpgcheck=1
  enabled=0
  countme=1
  metadata_expire=6h
  gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
  
  [appstream92]
  name=Rocky Linux 9.2 - appstream
  baseurl=https://dl.rockylinux.org/vault/rocky/9.2/AppStream/x86_64/kickstart/
  gpgcheck=1
  enabled=0
  countme=1
  metadata_expire=6h
  gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
  
  [devel92]
  name=Rocky Linux 9.2 - devel
  baseurl=https://dl.rockylinux.org/vault/rocky/9.2/devel/x86_64/kickstart/
  gpgcheck=1
  enabled=0
  countme=1
  metadata_expire=6h
  gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
  EOF
  
::

  # dnf --disablerepo='*' --enablerepo=base92,appstream92 install \
      git automake autoconf rpm-build kernel-devel kernel-headers kernel-rpm-macros kernel-abi-stablelists

  # curl -L -O https://linbit.gateway.scarf.sh//downloads/drbd/9/drbd-9.1.19.tar.gz
  # tar zxf drbd-9.1.19.tar.gz
  # cp drbd-9.1.19.tar.gz drbd-9.1.19/
  # cd drbd-9.1.19
  # export KDIR=/usr/src/kernels/5.14.0-284.11.1.el9_2.x86_64
  # make kmp-rpm
  # cd ..

::

  # dnf --disablerepo='*' --enablerepo=base92,appstream92,devel92 install \
      gcc-c++ selinux-policy-devel automake autoconf keyutils-libs-devel libxslt docbook-style-xsl rubygem-asciidoctor po4a
  
  # curl -L -O https://linbit.gateway.scarf.sh//downloads/drbd/utils/drbd-utils-9.27.0.tar.gz
  # mkdir -p ~/rpmbuild/SOURCES
  # cp drbd-utils-9.27.0.tar.gz  ~/rpmbuild/SOURCES/
  # tar zxf drbd-utils-9.27.0.tar.gz
  # cd drbd-utils-9.27.0
  # ./configure --prefix=/usr --localstatedir=/var --sysconfdir=/etc --enable-spec
  # rpmbuild -bb drbd.spec --without sbinsymlinks --without heartbeat
  # cd ..


Building kmod-drbd on RHEL 9 container using UBI
------------------------------------------------

Create Red Hat developer account on
`developers.redhat.com <https://developers.redhat.com/register>`_ .

Some required rpms (listed below) are not available in UBI.
Download them from
`Red Hat customer portarl <https://access.redhat.com/downloads/content/package-browser>`_ .

* bison
* elfutils-libelf-devel
* flex
* kernel-abi-stablelists
* kernel-devel
* kernel-headers
* kernel-rpm-macros
* libzstd-devel

Start container from UBI.::

    # docker login registry.redhat.io
    # docker pull registry.redhat.io/ubi9/ubi:9.2-489
    # docker run -i -t -v ./depts:/path/to/deps registry.redhat.io/ubi9/ubi:9.2-489 /bin/bash

Install build dependencies.::

    # cd /path/to/deps
    # dnf install \
        git automake autoconf rpm-build kernel-devel kernel-headers kernel-rpm-macros kernel-abi-stablelists \
        kmod \
        ./*.rpm

Build rpm by invoking kmp-rpm target.::

    # tar zxf drbd-9.1.19.tar.gz
    # cp drbd-9.1.19.tar.gz drbd-9.1.19/
    # cd drbd-9.1.19
    # export KDIR=/usr/src/kernels/5.14.0-284.11.1.el9_2.x86_64
    # make kmp-rpm


basic operations
----------------

installing built packages::

  # cd ~/rpmbuild/RPMS/x86_64/
  # rpm -ivh drbd-selinux-9.27.0-1.el9.x86_64.rpm \
             drbd-utils-9.27.0-1.el9.x86_64.rpm \
             drbd-pacemaker-9.27.0-1.el9.x86_64.rpm \
             kmod-drbd-9.1.19_5.14.0_284.11.1-1.x86_64.rpm 

configure and load drbd on both nodes.::

  # vi /etc/drbd.d/global_common.conf
  # vi /etc/drbd.d/r0.res
  # drbdadm create-md all
  # drbdadm up all
  # drbdadm status all

(example)::

  # cat /etc/drbd.d/r0.res
  resource r0 {
      volume 0 {
          meta-disk internal;
          device /dev/drbd0;
          disk /dev/vdb;
      }
      handlers {
          fence-peer "/usr/lib/drbd/crm-fence-peer.9.sh --timeout=45 --logfacility=syslog";
          unfence-peer "/usr/lib/drbd/crm-unfence-peer.9.sh --logfacility=syslog";
          }
      on rocky-92-1 {
          address 192.168.122.11:7790;
      }
      on rocky-92-2 {
          address 192.168.122.12:7790;
      }
  }

make one node primary::

  # drbdadm primary --force all
  # drbdadm status all
  # mkfs -t xfs /dev/drbd0
  # mkdir -p /mnt/test
  # mount /dev/drbd0 /mnt/test

make the node secondary::

  # umount /mnt/test
  # drbdadm secondary all

stop drbd on both nodes::

  # drbdadm down all


changelog
---------

- `genl2` implies
  `GENL_MAGIC_VERSION is 2 <https://github.com/LINBIT/drbd-headers/blob/8d6501934c2a36fcf38440df9144b2748eb4008d/linux/drbd_genl_api.h#L36>`_
  while genl means
  `generic netlink <https://github.com/LINBIT/drbd-headers/blob/8d6501934c2a36fcf38440df9144b2748eb4008d/linux/drbd_genl.h>`_
  .

- `proto:86-101,118-122` shows range of
  `protocol version <https://github.com/LINBIT/drbd/blob/drbd-9.1/drbd/linux/drbd_config.h#L13-L17>`_
   which which the version can communicate.

- `transport:19` seems to imply
  `the version of transport <https://github.com/LINBIT/drbd-headers/blob/8d6501934c2a36fcf38440df9144b2748eb4008d/drbd_transport.h>`_


pacemaker on rocky-92
---------------------

on both nodes::

  # cat >> /etc/yum.repos.d/rocky-vault-92.repo <<'EOF'
  
  [ha92]
  name=Rocky Linux 9.2 - ha
  baseurl=https://dl.rockylinux.org/vault/rocky/9.2/HighAvailability/x86_64/kickstart/
  gpgcheck=1
  enabled=0
  countme=1
  metadata_expire=6h
  gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-Rocky-9
  EOF
  
  # systemctl start pcsd.service
  # passwd hacluster
  # dnf --disablerepo=appstream --enablerepo=appstream92 --enablerepo=ha92 install pcs pacemaker fence-agents-all

on one of the node::

  # pcs host auth srv01 addr=192.168.122.11 srv02 addr=192.168.122.12
  # pcs cluster setup hacluster srv01 addr=192.168.122.11 srv02 addr=192.168.122.12
  # pcs cluster start --all

  # pcs property set stonith-enabled=false
  # pcs resource create pingd ocf:pacemaker:ping host_list="192.168.122.1" clone

  # pcs cluster cib drbdcluster
  # pcs -f drbdcluster resource create res_drbd_r0 ocf:linbit:drbd drbd_resource=r0
  # pcs -f drbdcluster resource create res_fsmnt Filesystem device=/dev/drbd0 directory=/mnt/test fstype=xfs op start timeout=100s op monitor interval=100s timeout=100s
  # pcs -f drbdcluster resource promotable res_drbd_r0 master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true
  # pcs -f drbdcluster constraint colocation add res_fsmnt with res_drbd_r0-clone INFINITY with-rsc-role=Master
  # pcs -f drbdcluster constraint order promote res_drbd_r0-clone then start res_fsmnt
  # pcs -f drbdcluster resource
  # pcs cluster cib-push drbdcluster


::

  # pcs status --full
  Cluster name: hacluster
  Status of pacemakerd: 'Pacemaker is running' (last updated 2025-10-30 11:57:56Z)
  Cluster Summary:
    * Stack: corosync
    * Current DC: srv02 (2) (version 2.1.5-7.el9-a3f44794f94) - partition with quorum
    * Last updated: Thu Oct 30 11:57:57 2025
    * Last change:  Thu Oct 30 11:29:46 2025 by hacluster via crmd on srv01
    * 2 nodes configured
    * 5 resource instances configured
  
  Node List:
    * Node srv01 (1): online, feature set 3.16.2
    * Node srv02 (2): online, feature set 3.16.2
  
  Full List of Resources:
    * Clone Set: pingd-clone [pingd]:
      * pingd     (ocf:pacemaker:ping):    Started srv01
      * pingd     (ocf:pacemaker:ping):    Started srv02
    * res_fsmnt   (ocf:heartbeat:Filesystem):      Started srv01
    * Clone Set: res_drbd_r0-clone [res_drbd_r0] (promotable):
      * res_drbd_r0       (ocf:linbit:drbd):       Promoted srv01
      * res_drbd_r0       (ocf:linbit:drbd):       Unpromoted srv02
  
  Node Attributes:
    * Node: srv01 (1):
      * master-res_drbd_r0                : 10000
      * pingd                             : 1
    * Node: srv02 (2):
      * master-res_drbd_r0                : 10000
      * pingd                             : 1
  
  Migration Summary:
  
  Tickets:
  
  PCSD Status:
    srv01: Online
    srv02: Online
  
  Daemon Status:
    corosync: active/disabled
    pacemaker: active/disabled
    pcsd: active/disabled
  
::

  # drbdadm status all
  r0 role:Primary
    disk:UpToDate
    rocky-92-2 role:Secondary
      peer-disk:UpToDate
