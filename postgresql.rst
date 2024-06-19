.. contents::


PostgreSQL
==========

replication quickstart (PostgreSQL 9.2 on Ubuntu)
-------------------------------------------------

::

  $ sudo apt install bison flex libreadline-dev
  $ git clone https://github.com/postgres/postgres
  $ cd postgres
  $ git checkout REL9_2_24
  $ CFLAGS='-ggdb -O0' ./configure --prefix=/usr/local/pgsql9224
  $ make
  $ sudo make install
  $ cd contrib/pgstattuple
  $ make
  $ sudo make install
  $ export PATH=/usr/local/pgsql9224/bin:$PATH
  
  
  
  $ initdb -D $HOME/pgdata1
  $ mkdir $HOME/pgdata1/arc
  
  $ vi $HOME/pgdata1/postgresql.conf
  (wal_level = hot_standby, archive_mode = on, archive_command = 'test ! -f /home/iwasakims/pgdata1/arc/%f && cp %p /home/iwasakims/pgdata1/arc/%f', max_wal_senders = 3)
  
  $ vi $HOME/pgdata1/pg_hba.conf
  (host    replication     iwasakims        127.0.0.1/32            trust)
  
  $ pg_ctl -D $HOME/pgdata1 -l $HOME/pgdata1/postgresql.log start
  
  
  $ pg_basebackup -h localhost -D $HOME/pgdata2 -U iwasakims -v -P --xlog-method=stream
  
  $ vi $HOME/pgdata2/postgresql.conf
  (port = 5433, hot_standby = on)
  
  $ vi $HOME/pgdata2/recovery.conf
  $ cat $HOME/pgdata2/recovery.conf
  standby_mode = on
  primary_conninfo = 'host=localhost port=5432 user=iwasakims'
  
  $ pg_ctl -D $HOME/pgdata2 -l $HOME/pgdata2/postgresql.log start
  
  $ psql -p 5432 postgres
  $ psql -p 5433 postgres


replication quickstart (PostgreSQL 13 on Rocky Linux 8)
-------------------------------------------------------

building with debug settings.::

  $ git clone https://github.com/postgres/postgres
  $ cd postgres
  $ git checkout REL13_5
  $ CFLAGS='-ggdb -O0' ./configure --prefix=/usr/local/pgsql135
  $ make -j $(nproc)
  $ sudo make install
  $ cd contrib/pgstattuple
  $ make
  $ sudo make install
  $ cd ..
  $ git clone https://github.com/ossc-db/pg_statsinfo
  $ cd pg_statsinfo
  $ git checkout 13.0
  $ make
  $ sudo make install
  
  $ export PATH=/usr/local/pgsql135/bin:$PATH

setting up db instance and starting primary server::

  $ initdb -D $HOME/pgdata1
  $ mkdir $HOME/pgdata1/arc
  
  $ vi $HOME/pgdata1/postgresql.conf
  (wal_level = replica, archive_mode = on, archive_command = 'test ! -f /home/rocky/pgdata1/arc/%f && cp %p /home/rocky/pgdata1/arc/%f', max_wal_senders = 3, synchronous_standby_names = '*')
  
  $ vi $HOME/pgdata1/pg_hba.conf
  (host    replication     all        127.0.0.1/32            trust)
  
  $ pg_ctl -D $HOME/pgdata1 -l $HOME/pgdata1/postgresql.log start

starting standby server from basebackup.::
  
  $ pg_basebackup -h localhost -D $HOME/pgdata2 -U $USER -v -P --wal-method=stream
  
  $ vi $HOME/pgdata2/postgresql.conf
  (port = 5433, hot_standby = on, archive_command = 'test ! -f /home/rocky/pgdata2/arc/%f && cp %p /home/rocky/pgdata2/arc/%f')

  $ echo -e "\nprimary_conninfo = 'host=localhost port=5432 user=rocky'\n" >> $HOME/pgdata2/postgresql.conf
  
  $ touch $HOME/pgdata2/standby.signal
  
  $ pg_ctl -D $HOME/pgdata2 -l $HOME/pgdata2/postgresql.log start

::
  
  $ psql -p 5432 postgres
  $ psql -p 5433 postgres

  $ pg_ctl -D $HOME/pgdata1 stop
  $ pg_ctl -D $HOME/pgdata2 stop

restarting standby server requires fresh basebackup.::

  $ cp $HOME/pgdata2/postgresql.conf /tmp/postgresql.conf.pgdata2
  $ rm -rf $HOME/pgdata2
  $ pg_basebackup -h localhost -D $HOME/pgdata2 -U $USER -v -P --wal-method=stream
  $ cp /tmp/postgresql.conf.pgdata2 $HOME/pgdata2/postgresql.conf
  $ touch $HOME/pgdata2/standby.signal
  $ pg_ctl -D $HOME/pgdata2 -l $HOME/pgdata2/postgresql.log start
