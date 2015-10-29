===========================================
NTPでサーバと同期できない場合の原因の調べ方
===========================================


.. _`RFC 5905`: http://www.ietf.org/rfc/rfc5905.txt


ntpdcコマンドでshowpeerを実行すると、
指定されたNTPサーバとのやりとりの状態についての情報が表示される。::

  # ntpdc -c 'showpeer ntp01.example.com'
  remote 192.168.1.2, local 192.168.1.27
  hmode client, pmode unspec, stratum 2, precision -14
  leap 00, refid [211.10.62.120], rootdistance 0.00043, rootdispersion 0.02351
  ppoll 7, hpoll 7, keyid 0, version 4, association 7327
  reach 377, unreach 0, flash 0x0000, boffset 0.00400, ttl/mode 0
  timer 0s, flags system_peer, config, bclient
  reference time:      d39b72aa.10ab2b8e  Mon, Jul  2 2012 10:06:50.065
  originate timestamp: d39b7467.cbca1c07  Mon, Jul  2 2012 10:14:15.796
  receive timestamp:   d39b7467.cc617aad  Mon, Jul  2 2012 10:14:15.798
  transmit timestamp:  d39b7467.c9ed3704  Mon, Jul  2 2012 10:14:15.788
  filter delay:  0.00948  0.01120  0.00647  0.00862 
                 0.00996  0.01051  0.00835  0.01031 
  filter offset: 0.002431 0.002457 0.001153 0.000966
                 0.001899 0.001535 0.004866 -0.00045
  filter order:  2        6        3        0       
                 4        7        5        1       
  offset 0.001153, delay 0.00647, error bound 0.05579, filter error 0.04134

上記の出力の5行目あたりに、 "flash 0x0000" という4桁の16進数が表示されている部分がある。
これは、どういうチェックで失敗しているかを示すフラグになっている。
どういう内容のチェックなのかはntp.confのコメントを読むとざっくり分かる。
より詳しく調べたい場合は、これらのマクロが使われている部分をソース中から探せばよい。
だいたい、ntpd/ntp_proto.cの中にある感じがする。include/ntp.h::

  /*                                                                                                                      
   * Define flasher bits (tests 1 through 11 in packet procedure)                                                         
   * These reveal the state at the last grumble from the peer and are                                                     
   * most handy for diagnosing problems, even if not strictly a state                                                     
   * variable in the spec. These are recorded in the peer structure.                                                      
   *                                                                                                                      
   * Packet errors                                                                                                        
   */
  #define TEST1           0X0001  /* duplicate packet */
  #define TEST2           0x0002  /* bogus packet */
  #define TEST3           0x0004  /* protocol unsynchronized */
  #define TEST4           0x0008  /* access denied */
  #define TEST5           0x0010  /* authentication error */
  #define TEST6           0x0020  /* bad synch or stratum */
  #define TEST7           0x0040  /* bad header data */
  #define TEST8           0x0080  /* autokey error */
  #define TEST9           0x0100  /* crypto error */
  #define PKT_TEST_MASK   (TEST1 | TEST2 | TEST3 | TEST4 | TEST5 |\
                          TEST6 | TEST7 | TEST8 | TEST9)
  /*                                                                                                                      
   * Peer errors                                                                                                          
   */
  #define TEST10          0x0200  /* peer bad synch or stratum */
  #define TEST11          0x0400  /* peer distance exceeded */
  #define TEST12          0x0800  /* peer synchronization loop */
  #define TEST13          0x1000  /* peer unreacable */
  
  #define PEER_TEST_MASK  (TEST10 | TEST11 | TEST12 | TEST13)


}}}
