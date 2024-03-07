Network settings on Docker host
===============================

firewalld rules on CentOS 8
---------------------------

On CentOS 8, nftables rules activated by firewalld drops inter-container packets.

`nft` command shows the rules.::

    $ sudo nft -a list ruleset | less

We can not use `trusted` zone here because masquerade are enabled.::

    $ sudo firewall-cmd --info-zone=trusted
    trusted
      target: ACCEPT
      icmp-block-inversion: no
      interfaces: 
      sources: 
      services: 
      ports: 
      protocols: 
      masquerade: yes
      forward-ports: 
      source-ports: 
      icmp-blocks: 
      rich rules: 
    
    $ sudo nft -a list chain nat_POST_trusted_allow
    
            chain nat_POST_trusted_allow { # handle 39
                    oifname != "lo" masquerade # handle 46
            }
  
Adding new zone targeted to ACCEPT and assign docker interfaces to it should work.::

    $ sudo firewall-cmd --permanent --new-zone=docker
    $ sudo firewall-cmd --permanent --zone=docker --set-target=ACCEPT
    $ sudo firewall-cmd --permanent --zone=docker --add-interface=docker0
    $ sudo firewall-cmd --permanent --zone=docker --add-interface=br-ab1b9c795ab1
    $ sudo firewall-cmd --reload
    $ sudo firewall-cmd --info-zone=docker
    docker (active)
      target: ACCEPT
      icmp-block-inversion: no
      interfaces: br-ab1b9c795ab1 docker0
      sources: 
      services: 
      ports: 
      protocols: 
      masquerade: no
      forward-ports: 
      source-ports: 
      icmp-blocks: 
