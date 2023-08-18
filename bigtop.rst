Bigtop
======

Setting up build environment on CentOS 7/CentOS 8
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
      --stack hdfs,yarn,mapreduce \
      --repo file:///bigtop-home/output \
      --disable-gpg-check


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
      --stack hdfs,yarn,mapreduce \
      --repo file:///bigtop-home/output/apt \
      --disable-gpg-check


docker provisioner using published repository
---------------------------------------------

::

  $ cd provisioner/docker
  $ ./docker-hadoop.sh \
      --create 1 \
      --image bigtop/puppet:trunk-ubuntu-22.04 \
      --docker-compose-yml docker-compose-cgroupv2.yml \
      --docker-compose-plugin \
      --memory 16g \
      --stack hdfs,yarn,mapreduce \
      --repo http://repos.bigtop.apache.org/releases/3.2.1/ubuntu/22.04/amd64


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


download built packages then create Yum repository
--------------------------------------------------

Example of rockylinux-8 built by https://ci.bigtop.apache.org/job/Bigtop-3.2.1-aarch64/

BASEARCH is used as ``$basearch`` of Yum variables. Bigtop is using ``x86_64``, ``aarch64`` and ``ppc64le``. It is used as the name of Jenkins job too.

PLATFORM is label set to `agent of Jenkins <https://ci.bigtop.apache.org/computer/docker-slave-06/>`_. Possible values are ``amd64-slave``, ``aarch64-slave`` and ``ppc64el-slave`` here.

::

  $ export GPG_TTY=$(tty)
  $ export VERSION=3.2.1
  $ export OS=rockylinux
  $ export OSVER=8
  $ export BASEARCH=aarch64
  $ export PLATFORM=aarch64-slave

::

  $ mkdir -p releases/${VERSION}/${OS}/${OSVER}/${BASEARCH}
  $ cd releases/${VERSION}/${OS}/${OSVER}/${BASEARCH}
  $ for product in alluxio ambari bigtop-ambari-mpack bigtop-groovy bigtop-jsvc bigtop-utils flink gpdb hadoop hbase hive kafka livy oozie phoenix solr spark tez ycsb zeppelin zookeeper
    do
      rm -rf ${product} &&
      curl -L -o ${product}.zip https://ci.bigtop.apache.org/job/Bigtop-${VERSION}-${BASEARCH}/DISTRO=${OS}-${OSVER},PLATFORM=${PLATFORM},PRODUCT=${product}/lastSuccessfulBuild/artifact/*zip*/archive.zip &&
      jar xf ${product}.zip &&
      mv archive/output/${product} . &&
      find ${product} -name '*.rpm' | xargs rpm --define '_gpg_name Masatake Iwasaki' --addsign
      rmdir -p archive/output &&
      rm ${product}.zip
    done

::

  $ rm -rf repodata   
  $ createrepo .
  $ gpg --detach-sign --armor repodata/repomd.xml
  
  $ aws --profile iwasakims s3 sync --acl public-read . s3://repos.bigtop.apache.org/releases/${VERSION}/${OS}/${OSVER}/${BASEARCH}/


download built packages then create APT repository
--------------------------------------------------

Example of debian-11 built by https://ci.bigtop.apache.org/job/Bigtop-3.2.1-x86_64/

ARCH is used as ``$(ARCH)`` of deb. Bigtop is using ``amd64``, ``arm64`` and ``ppc64el``. Possible values are shown by ``dpkg-architecture -L``. ``ppc64el`` instead of ``ppc64le`` here.

BASEARCH is used as ``$basearch`` of Yum variables. Bigtop is using ``x86_64``, ``aarch64`` and ``ppc64le``. It is used as the name of Jenkins job too.

PLATFORM is label set to `agent of Jenkins <https://ci.bigtop.apache.org/computer/docker-slave-06/>`_. Possible values are ``amd64-slave``, ``aarch64-slave`` and ``ppc64el-slave`` here.

::

  $ export GPG_TTY=$(tty)
  $ export VERSION=3.2.1
  $ export OS=debian
  $ export OSVER=11
  $ export ARCH=amd64
  $ export BASEARCH=x86_64
  $ export PLATFORM=amd64-slave
  $ export SIGN_KEY=36243EECE206BB0D

::

  $ mkdir -p releases/${VERSION}/${OS}/${OSVER}/${ARCH}
  $ cd releases/${VERSION}/${OS}/${OSVER}/${ARCH}
  $ for product in alluxio ambari bigtop-ambari-mpack bigtop-groovy bigtop-jsvc bigtop-utils flink gpdb hadoop hbase hive kafka livy oozie phoenix solr spark tez ycsb zeppelin zookeeper
    do
      rm -rf ${product} &&
      curl -L -o ${product}.zip https://ci.bigtop.apache.org/job/Bigtop-${VERSION}-${BASEARCH}/DISTRO=${OS}-${OSVER},PLATFORM=${PLATFORM},PRODUCT=${product}/lastSuccessfulBuild/artifact/*zip*/archive.zip &&
      jar xf ${product}.zip &&
      mv archive/output/${product} . &&
      find ${product} -name '*.deb' | xargs dpkg-sig --cache-passphrase --sign builder --sign-changes force_full &&
      rmdir -p archive/output &&
      rm ${product}.zip
    done

::

  
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


tarballからhadoopのrpmをビルドしてsmoke-testを流してみる
--------------------------------------------------------

bigtopのソースツリーをダウンロードする。::

  $ git clone https://github.com/apache/bigtop
  $ cd bigtop 

bigtop.bomを修正し、source tarballのdownload URLを差し替える。::

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

必要なrpmをビルドする。::

  $ gradle bigtop-groovy-rpm
  $ gradle bigtop-groovy-rpm
  $ gradle bigtop-jsvc-rpm
  $ gradle bigtop-tomcat-rpm
  $ gradle bigtop-utils-rpm
  $ gradle hadoop-rpm

ビルドしたrpmでyum repositoryを作る。(./outputにそのままリポジトリが作成される。)::

  $ gradle yum

Dockerを使ってクラスタをデプロイする。
config.yamlを修正し、上記で作成したyumリポジトリを使ってパッケージインストールを行う設定に変更する。::

  $ cd provisioner/docker
  $ vi config.yaml
  $ git diff .
  diff --git a/provisioner/docker/config_centos-7.yaml b/provisioner/docker/config_centos-7.yaml
  index 6cdd7cf..342f860 100644
  --- a/provisioner/docker/config_centos-7.yaml
  +++ b/provisioner/docker/config_centos-7.yaml
  @@ -20,5 +20,5 @@ docker:
   repo: "http://bigtop-repos.s3.amazonaws.com/releases/1.2.0/centos/7/x86_64"
   distro: centos
   components: [hdfs, yarn, mapreduce]
  -enable_local_repo: false
  +enable_local_repo: true
   smoke_test_components: [hdfs, yarn, mapreduce]

以下の例では3ノードのクラスタがデプロイされる。::
  
  $ ./docker-hadoop.sh --create 3
  
  $ ./docker-hadoop.sh --exec 1 rpm -q hadoop
  WARNING: The DOCKER_IMAGE variable is not set. Defaulting to a blank string.
  WARNING: The MEM_LIMIT variable is not set. Defaulting to a blank string.
  hadoop-2.7.4-1.el7.centos.x86_64

smoke testを実行する。::

  ./docker-hadoop.sh --smoke-tests


