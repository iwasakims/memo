======
Bigtop
======

.. contents::

toolchain and provisioner
=========================

applying toolchain manifests without installing JDK
---------------------------------------------------

JDK is needed to run ``./gradlew toolchain`` which installs JDK.
``puppet apply`` directly can be used
`as done in toolchain task <https://github.com/apache/bigtop/blob/rel/3.2.1/build.gradle#L225-L237>`_ .::

  $ sudo puppet apply --modulepath="/home/admin/srcs/bigtop:/etc/puppet/modules:/usr/share/puppet/modules:/etc/puppetlabs/code/modules:/etc/puppet/code/modules" -e "include bigtop_toolchain::installer"

setting up build environment on CentOS 7/CentOS 8
-------------------------------------------------

::

  sudo yum groupinstall 'Development Tools'
  git clone https://github.com/apache/bigtop
  cd bigtop
  sudo bigtop_toolchain/bin/puppetize.sh
  ./gradlew toolchain-puppetmodules
  ./gradlew toolchain

Docker for testing deployment and smoke-tests.::

  sudo yum install -y yum-utils
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo yum install docker-ce docker-ce-cli containerd.io
  sudo usermod -G docker centos
  sudo systemctl start docker


docker provisioner using local repository
-----------------------------------------

::

  $ cd provisioner/docker
  $ ./docker-hadoop.sh \
      --create 1 \
      --image bigtop/puppet:trunk-centos-8 \
      --memory 16g \
      --repo file:///bigtop-home/output \
      --disable-gpg-check \
      --stack hdfs,yarn,mapreduce


docker provisioner for cgroup v2 and docker compose plugin
----------------------------------------------------------

::

  $ cd provisioner/docker
  $ ./docker-hadoop.sh \
      --create 1 \
      --image bigtop/puppet:trunk-ubuntu-22.04 \
      --docker-compose-yml docker-compose-cgroupv2.yml \
      --docker-compose-plugin \
      --memory 16g \
      --repo file:///bigtop-home/output/apt \
      --disable-gpg-check \
      --stack hdfs,yarn,mapreduce


docker provisioner using published repository
---------------------------------------------

`bigtop::bigtop_repo_apt_key <https://github.com/apache/bigtop/blob/release-3.2.1-RC0/bigtop-deploy/puppet/hieradata/bigtop/repo.yaml#L2>`_
must match the public key used for packaging. Add ``--disable-gpg-check`` otherwise.


For DEB, available platforms are ``amd64``, ``aarch64`` and ``ppc64el``.
::

  $ cd provisioner/docker
  $ ./docker-hadoop.sh \
      --create 1 \
      --image bigtop/puppet:3.2.1-ubuntu-22.04 \
      --docker-compose-yml docker-compose-cgroupv2.yml \
      --docker-compose-plugin \
      --memory 16g \
      --repo http://repos.bigtop.apache.org/releases/3.2.1/ubuntu/22.04/amd64 \
      --stack hdfs,yarn,mapreduce

For RPM, available platforms are ``x86_64``, ``aarch64`` and ``ppc64le``.
::

  $ cd provisioner/docker
  $ ./docker-hadoop.sh \
      --create 1 \
      --image bigtop/puppet:3.1.1-rockylinux-8 \
      --docker-compose-yml docker-compose-cgroupv2.yml \
      --docker-compose-plugin \
      --memory 16g \
      --repo http://repos.bigtop.apache.org/releases/3.1.1/rockylinux/8/x86_64 \
      --stack hdfs,yarn,mapreduce,hbase


puppet versions
---------------

-  rockylinux-9: 7.27.0 (on ruby 3.0.7p220 (2024-04-23 revision 724a071175) [x86_64-linux])
-  openeuler-22.03: 7.22.0 (on ruby 3.0.3p157 (2021-11-24 revision 3fb7d2cadc) [x86_64-linux])
-  fedora-40: 8.5.1 (on ruby 3.3.7 (2025-01-15 revision be31f993d7) [x86_64-linux])
-  debian-12: 7.23.0 (on ruby 3.1.2p20 (2022-04-12 revision 4491bb740a) [x86_64-linux-gnu])
-  ubuntu-24.04: 8.4.0 (on ruby 3.2.3 (2024-01-18 revision 52bb2ac0a6) [x86_64-linux-gnu])


puppet versions(old)
--------------------

- rockylinux-8: 6.26.0
- fedora-38: 8.3.1
- ubuntu-22.04: 5.5.22
- debian-11: 5.5.22


debugging puppet expressions on command line
--------------------------------------------

::

  # puppet apply -e 'notice("foo.bar.baz".split("\\.")[1, -1].join("."))'
  Notice: Scope(Class[main]): bar.baz


Develpment
==========

Debugging dpkg
--------------

Setting environment variable DH_VERBOSE to non null makes dpkg-buildpackage more verbose.
For Bigtop, dpkg-buildpackage is called in the following part of packages.gradle::

    exec {
      workingDir DEB_BLD_DIR
      commandLine "dpkg-buildpackage -uc -us -sa -S".split(' ')
      environment "DH_VERBOSE", "1
    }


Debugging init script without systemctl redirect
------------------------------------------------

::

  $ sudo /bin/bash -x -c 'export SHELLOPTS && SYSTEMCTL_SKIP_REDIRECT=true /etc/init.d/hadoop-httpfs start'


Disabling dh_strip_nondeterminism
---------------------------------

dh_strip_nondeterminism takes quite long time on hadoop-deb packaging.
adding blank override_dh_strip_nondeterminism section to
bigtop-packages/src/deb/hadoop/rules makes it skipped::

  override_dh_strip_nondeterminism:


local apt repository
--------------------

adding local repository create by `./gradlew repo`::

  $ sudo bash -c 'echo "deb [trusted=yes] file:///home/admin/srcs/bigtop/output/apt bigtop contrib" > /etc/apt/sources.list.d/bigtop-home_output.list'
  $ sudo apt update


building and testing in container
---------------------------------

you can leverage Docker by ``*-pkg-ind`` and ``repo-ind`` task.::

  $ ./gradlew hadoop-pkg-ind repo-ind -POS=ubuntu-22.04 -Pprefix=trunk -Pdocker-run-option="--privileged" -Pmvn-cache-volume=true

- ``-Pdocker-run-option="--privileged"`` is needed on the Fedora-35 and Ubuntu-22.04 now (depending on the version of systemd).

- ``-Pmvn-cache-volume=true`` attaches docker volume to reuse local repository (~/.m2) to make repeatable build faster.

- We can not use ``-Dbuildwithdeps=true`` for invoking packging of hadoop dependencies (such as bigtop-utils and zookeeper) with `*-ind` task now.

You can deploy a cluster and run smoke-tests in container by docker provisioner which requires docker-compose.::

  $ cd provisioner/docker
  $ ./docker-hadoop.sh \
      --create 3 \
      --image bigtop/puppet:trunk-ubuntu-22.04 \
      --docker-compose-yml docker-compose-cgroupv2.yml \
      --docker-compose-plugin \
      --memory 8g \
      --repo file:///bigtop-home/output/apt \
      --disable-gpg-check \
      --stack hdfs,yarn,mapreduce \
      --smoke-tests hdfs,yarn,mapreduce

- ``--docker-compose-yml docker-compose-cgroupv2.yml`` is needed on cgroup v2.

- ``--docker-compose-plugin`` is for using ``docker compose`` instead of ``docker-compose``.

- use ``--repo file:///bigtop-home/output`` for RPM instead of DEB.

You can log in to the node and see files if you need.::

  $ ./docker-hadoop.sh -dcp --exec 1 /bin/bash


Enabling Kerberos security on running docker provisioner
--------------------------------------------------------

Kerberos authentication can be enabled by
`adding hiera variables to generated site.yaml< https://github.com/apache/bigtop/blob/rel/3.3.0/provisioner/docker/docker-hadoop.sh#L154-L162>`_
::

  $ git diff
  diff --git a/provisioner/docker/docker-hadoop.sh b/provisioner/docker/docker-hadoop.sh
  index 38ece152..feadd8f7 100755
  --- a/provisioner/docker/docker-hadoop.sh
  +++ b/provisioner/docker/docker-hadoop.sh
  @@ -172,6 +172,13 @@ bigtop::bigtop_repo_gpg_check: $gpg_check
   hadoop_cluster_node::cluster_components: $3
   hadoop_cluster_node::cluster_nodes: [$node_list]
   hadoop::common_yarn::yarn_resourcemanager_scheduler_class: org.apache.hadoop.yarn.server.resourcemanager.scheduler.capacity.CapacityScheduler
  +hadoop::hadoop_security_authentication: "kerberos"
  +kerberos::krb_site::domain: "bigtop.apache.org"
  +kerberos::krb_site::realm: "BIGTOP.APACHE.ORG"
  +kerberos::krb_site::kdc_server: "%{hiera('bigtop::hadoop_head_node')}"
  +kerberos::krb_site::kdc_port: "88"
  +kerberos::krb_site::admin_port: "749"
  +kerberos::krb_site::keytab_export_dir: "/var/lib/bigtop_keytabs"
   EOF
 }

and adding ``kerberos`` to the list of stacks.::

  $ ./docker-hadoop.sh \
      --create 1 \
      --image bigtop/puppet:trunk-rockylinux-8 \
      --docker-compose-yml docker-compose-cgroupv2.yml \
      --docker-compose-plugin \
      --memory 16g \
      --repo http://repos.bigtop.apache.org/releases/3.0.1/centos/8/x86_64 \
      --stack kerberos,hdfs,yarn,mapreduce


Release process of Bigtop
=========================

preparation
-----------

for signing packages, private key must be imported.::

  # docker run -i -t -v releases:/releases bigtop/slaves:trunk-rockylinux-9 /bin/bash
  # dnf install rpm-sign pinentry
  # gpg --import path/to/your.private.key

for uploading signed packages to S3, permissions must be granted in ACL setting of the `repos.bigtop.apache.org` bucket
`as described in How to Release wiki <https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=27849974#Howtorelease-5.5.UploadtoS3>`_ .
since "canonical ID" is S3 specific, it can be seen in S3 console as bucket owner instead of IAM console.::

  # curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  # unzip awscliv2.zip
  # sudo ./aws/install
  # aws --profile iwasakims configure


download built packages then create Yum repository
--------------------------------------------------

Example of rockylinux-8 built by https://ci.bigtop.apache.org/job/Bigtop-3.2.1-aarch64/

BASEARCH is used as ``$basearch`` of Yum variables. Possible values are ``x86_64``, ``aarch64`` and ``ppc64le``. It is used as the name of Jenkins job too.

PLATFORM is label set to `agent of Jenkins <https://ci.bigtop.apache.org/computer/docker-slave-06/>`_. Possible values are ``amd64-slave``, ``aarch64-slave`` and ``ppc64le-slave`` here.

::

  $ export GPG_TTY=$(tty)
  $ export VERSION=3.5.0
  $ export OS=rockylinux
  $ export OSVER=9
  $ export BASEARCH=aarch64
  $ export PLATFORM=aarch64-slave

::

  $ mkdir -p releases/${VERSION}/${OS}/${OSVER}/${BASEARCH}
  $ cd releases/${VERSION}/${OS}/${OSVER}/${BASEARCH}
  $ for product in airflow bigtop-groovy bigtop-jsvc bigtop-select bigtop-utils alluxio flink hadoop hbase hive kafka livy phoenix ranger solr spark tez zeppelin zookeeper
    do
      echo ${product}
      rm -rf ${product} &&
      curl -L -o ${product}.zip https://ci.bigtop.apache.org/job/Bigtop-${VERSION}-${BASEARCH}/DISTRO=${OS}-${OSVER},PLATFORM=${PLATFORM},PRODUCT=${product}/lastSuccessfulBuild/artifact/*zip*/archive.zip &&
      jar xf ${product}.zip &&
      mv archive/output/${product} . &&
      rmdir -p archive/output &&
      rm -f ${product}.zip
    done

::

  $ find . -name '*.rpm' | xargs rpm --define '_gpg_name Masatake Iwasaki' --addsign

  $ rm -rf repodata
  $ createrepo .
  $ gpg --detach-sign --armor repodata/repomd.xml
  
  $ aws --profile iwasakims s3 sync --acl public-read . s3://repos.bigtop.apache.org/releases/${VERSION}/${OS}/${OSVER}/${BASEARCH}/


download built packages then create APT repository
--------------------------------------------------

Example of debian-11 built by https://ci.bigtop.apache.org/job/Bigtop-3.2.1-x86_64/

ARCH is used as ``$(ARCH)`` of deb. Possible values are ``amd64``, ``arm64`` and ``ppc64el`` as shown by ``dpkg-architecture -L``
It is ``ppc64el`` for Deb packaging while ``ppc64le`` is used for RPM packaging.

BASEARCH is used as ``$basearch`` of Yum variables. Possible values are ``x86_64``, ``aarch64`` and ``ppc64le``. Since it is used as the name of Jenkins jobs, it must be defined even on Deb packaging too.

PLATFORM is label set to `agent of Jenkins <https://ci.bigtop.apache.org/computer/docker-slave-06/>`_. Possible values are ``amd64-slave``, ``aarch64-slave`` and ``ppc64le-slave`` here.

::

  $ export GPG_TTY=$(tty)
  $ export VERSION=3.5.0
  $ export OS=debian
  $ export OSVER=12
  $ export ARCH=amd64
  $ export BASEARCH=x86_64
  $ export PLATFORM=amd64-slave
  $ export SIGN_KEY=36243EECE206BB0D

Since bigtop-select supports only RPM, it is excluded from the list for DEB.::

  $ mkdir -p releases/${VERSION}/${OS}/${OSVER}/${ARCH}
  $ cd releases/${VERSION}/${OS}/${OSVER}/${ARCH}
  $ for product in airflow bigtop-groovy bigtop-jsvc bigtop-utils alluxio flink hadoop hbase hive kafka livy phoenix ranger solr spark tez zeppelin zookeeper
    do
      echo ${product}
      rm -rf ${product} &&
      curl -L -o ${product}.zip https://ci.bigtop.apache.org/job/Bigtop-${VERSION}-${BASEARCH}/DISTRO=${OS}-${OSVER},PLATFORM=${PLATFORM},PRODUCT=${product}/lastSuccessfulBuild/artifact/*zip*/archive.zip &&
      jar xf ${product}.zip &&
      mv archive/output/${product} . &&
      rmdir -p archive/output &&
      rm -f ${product}.zip
    done

`We used dpkg-sig for signing packages <https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=27849974#Howtorelease-5.4.SignDEBpackagesandaptrepos>`_
but
`the dpkg-sig was removed <https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=27849974#Howtorelease-5.4.SignDEBpackagesandaptrepos>`_
from recent distros such as Debian 12 and Ubuntu 24.04.
debsigs could be an alternative.::

  $ find . -name '*.deb' | xargs debsigs --sign=origin -k ${SIGN_KEY}

  $ rm -rf tmprepo
  
  $ mkdir -p conf
  
  $ cat > conf/distributions <<__EOT__
  Origin: Bigtop
  Label: Bigtop
  Suite: stable
  Codename: bigtop
  Version: ${VERSION}
  Architectures: ${ARCH} source
  Components: contrib
  Description: Apache Bigtop
  SignWith: ${SIGN_KEY}
  __EOT__
  
  $ cat > conf/options <<__EOT__
  verbose
  ask-passphrase
  __EOT__
  
  $ find . -name '*.deb' | xargs reprepro --ask-passphrase -Vb . includedeb bigtop
  $ mkdir tmprepo
  $ mv conf db dists pool tmprepo/
  
  $ aws --profile iwasakims s3 sync --acl public-read ./tmprepo s3://repos.bigtop.apache.org/releases/${VERSION}/${OS}/${OSVER}/${ARCH}/


Using Bigtop as test bed of Hadoop RC
=====================================

building Hadoop RPM with RC tarball then running smoke-tests
------------------------------------------------------------

tweak file name and download site of source tarball.::

  $ git clone https://github.com/apache/bigtop
  $ cd bigtop 
  $ vi bigtop.bom
  $ git diff .
  diff --git a/bigtop.bom b/bigtop.bom
  index ff6d4e1..d4ce521 100644
  --- a/bigtop.bom
  +++ b/bigtop.bom
  @@ -144,12 +144,12 @@ bigtop {
       'hadoop' {
         name    = 'hadoop'
         relNotes = 'Apache Hadoop'
  -      version { base = '2.7.3'; pkg = base; release = 1 }
  +      version { base = '2.7.4'; pkg = base; release = 1 }
         tarball { destination = "${name}-${version.base}.tar.gz"
  -                source      = "${name}-${version.base}-src.tar.gz" }
  +                source      = "${name}-${version.base}-RC0-src.tar.gz" }
         url     { download_path = "/$name/common/$name-${version.base}"
  -                site = "${apache.APACHE_MIRROR}/${download_path}"
  -                archive = "${apache.APACHE_ARCHIVE}/${download_path}" }
  +                site = "http://home.apache.org/~shv/hadoop-2.7.4-RC0/"
  +                archive = "" }
       }
       'ignite-hadoop' {
         name    = 'ignite-hadoop'

build with depended components then run smoke-tests.::

  $ ./gradlew hadoop-rpm yum -Dbuildwithdeps=true
  $ ./docker-hadoop.sh \
      --create 3 \
      --image bigtop/puppet:trunk-centos-8 \
      --memory 8g \
      --repo file:///bigtop-home/output \
      --disable-gpg-check \
      --stack hdfs,yarn,mapreduce \
      --smoke-tests hdfs,yarn,mapreduce


systemd
=======

running systemd services inside container
-----------------------------------------

systemd 237 or above
`checks the pid and the permission of PID file of non-root service as a fix for CVE-2018-16888 <https://github.com/systemd/systemd/pull/7816/files>`_ .
/sys/fs/cgroups must be mounted to run service via systemd inside containers.

`The article of Red Hat <https://developers.redhat.com/blog/2016/09/13/running-systemd-in-a-non-privileged-container>`_
elaborate the workaround.

`BIGTOP-3302 <https://issues.apache.org/jira/browse/BIGTOP-3302>`_
addressed the issue.


runuser must be used instead of su
----------------------------------

CVE-2018-16888 affects init script run via systemd.
runuser must be used instead of su (without `-` or `-l`)
to pass the check of pid file.

See
`BIGTOP-3302 <https://issues.apache.org/jira/browse/BIGTOP-3302>`_
for details.


debugging units
---------------

::

  # systemctl cat hadoop-mapreduce-historyserver.service

  # systemctl list-dependencies hadoop-mapreduce-historyserver.service

  # SYSTEMD_LOG_LEVEL=debug systemctl status hadoop-mapreduce-historyserver.service



openEuler
=========

assuming 22.03 LTS SP3.


Docker
------

https://docs.openeuler.org/en/docs/22.03_LTS/docs/Container/installation-and-deployment-3.html

docker-engine package provides all required resources.::

  $ sudo dnf install docker-engine
  $ sudo usermod -aG docker openeuler
  $ sudo systemctl start docker

standalone docker-compose can be used as usual.::

  $ sudo curl -SL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-aarch64 -o /usr/local/bin/docker-compose
  $ sudo chmod a+x /usr/local/bin/docker-compose
  $ sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
  $ docker-compose --version


Development on  maxOS arm64
===========================

::

  % docker volume create mvn-cache
  % docker run -i -t --name openeuler2203 -v /Users/iwasakims/srcs/bigtop:/bigtop-home -v mvn-cache:/root/.m2 bigtop/slaves:trunk-openeuler-22.03-aarch64 /bin/bash
  
  $ cd /bigtop-home
  $ ./gradlew spark-pkg -Dbuildwithdeps=true repo

Since `uname -m` returns `arm64`, aliasing the docker image for running docker provisioner.::

  % docker pull bigtop/puppet:trunk-openeuler-22.03-aarch64
  % docker tag bigtop/puppet:trunk-openeuler-22.03-aarch64 bigtop/puppet:trunk-openeuler-22.03-arm64
  % cd provisioner/docker
  % ./docker-hadoop.sh --create 1 --memory 12g --image bigtop/puppet:trunk-openeuler-22.03 --repo file:///bigtop-home/output --disable-gpg-check --stack hdfs,yarn,mapreduce,spark


Manually installing pre-built packages
======================================

rockylinux-9::

  $ sudo curl -L -o /etc/yum.repos.d/bigtop.repo https://downloads.apache.org/bigtop/bigtop-3.5.0/repos/rockylinux-9/bigtop.repo
  $ sudo rpm --import https://downloads.apache.org/bigtop/bigtop-3.5.0/repos/GPG-KEY-bigtop
  $ sudo dnf install airflow bigtop-utils
  $ /usr/lib/airflow/bin/airflow version


ubuntu-24.04::

  curl -o /etc/apt/sources.list.d/bigtop.list https://downloads.apache.org/bigtop/bigtop-3.5.0/repos/ubuntu-24.04/bigtop.list
  curl -s https://downloads.apache.org/bigtop/bigtop-3.5.0/repos/GPG-KEY-bigtop | sudo apt-key add -
  sudo apt-get update
  sudo apt-get install airflow bigtop-utils


Manually applying Puppet manifest for pseudo distributed cluster
================================================================

ubuntu-24.04::

  $ cat > bigtop-deploy/puppet/hieradata/site.yaml <<EOF
  bigtop::hadoop_head_node: "$(hostname --fqdn)"
  hadoop_cluster_node::cluster_nodes: ["$(hostname --fqdn)"]
  hadoop_cluster_node::cluster_components: ["bigtop-utils", "airflow"]
  EOF
  
  $ cat >> bigtop-deploy/puppet/hieradata/site.yaml <<'EOF'
  bigtop::bigtop_repo_uri: http://repos.bigtop.apache.org/releases/3.5.0/ubuntu/24.04/$(ARCH)
  EOF
  
  $ cp -r bigtop-deploy/puppet/hiera* /etc/puppet/
  
  $ puppet apply \
      --hiera_config=/etc/puppet/hiera.yaml \
      --modulepath=./bigtop-deploy/puppet/modules:/usr/share/puppet/modules:etc/puppet/code/modules \
      ./bigtop-deploy/puppet/manifests

bigtop_repo_url for rockylinux-9::

  bigtop::bigtop_repo_uri: http://repos.bigtop.apache.org/releases/3.5.0/rockylinux/9/$basearch
