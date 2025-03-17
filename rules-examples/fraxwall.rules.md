#```makefile
# Example of a main rules file for a host named examples
# SYNTAX
# ------
#
# include = /path/file 
#
# includes file just as if where written here
#
#
# iptables = <string>
#
# specifys a custom iptables command, everything after '=' is passed as arguments to iptables
# Only use this parameter if you really know of what you are doing!
#
#
# [DEFINE]
#   <keyword> = <string>
#
# everywhere <keyword> appear as a value (except for NAME, INCLUDE & IPTABLES)
# it is replaced with the text <string>.
# <string> may include separators (like ';' & ',') and other defines.
#
# OBSERVE that definitions must be defined before they are used.
# 
#
# [<out-interface>]
#   NAME = <string>
#
#   ACCEPT =	<in-interface> ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; insert|append [ ; <chain> ] ]
#   REJECT =	<in-interface> ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; insert|append [ ; <chain> ] ]
#   DROP   =	<in-interface> ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; insert|append [ ; <chain> ] ]
#
#   NAT    =	<snat-addr>    ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; insert ]
#   DNAT   =	<dnat-addr>    ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; insert ]
#
#
# Keyword "ALL" can be used for interfaces, addresses, protocols & ports. 
# OBSERVE rules with ALL as <in-interface> is always executed before specific
# interface <-> interface rules, be carefule when using REJECT and/or DROP 
# with ALL as <in-interface>!
# 
# You can also specify groups of interfaces, addresses, protocols &
# ports by specifing a comma-spearated list.
# 
# End lines with \ for wrapping lines. Everything after a '#' on a line is
# considered a comment. You may comment wrapped lines.
# Lines with only whitespaces are ignored.
# 
#
# NAT sets up snat or masquerading for the specified sources and
# destination. Observe that it does NOT automatically setup netfiler
# (FORWARD) ACCEPT rules to the specified destination(s), so you can safely
# use ALL for dest-addr, protocol and dest-port, controlling the
# access with ACCEPT, REJECT and DROP instead.  
# If you specify ALL as <snat-addr> target MASQUERADE will be used
# instead of SNAT.
#
# The special interface '_FW_' means all interfaces on the firewall itself.
# When used as in-interface it will affect the OUTPUT chain, and when used
# as out-interface it will affect the INPUT chain. 
# It will NEVER affect the FORWARD chain.
#
# ORDER does matter, rules are appended (or inserted specified) in the
# order they appear. This is exactly how it works:
# The first time a <out-interface>,<in-interface> rule appears a chain for that
# interface combination is created. A rule for jumping to the that chain is
# appended, or inserted in case ALL is <in-interface>, to the
# appropiate default chain. All rules that have that exact combination of
# <out-interface>,<in-interface> will then be appended (or inserted if specified)
# to that chain. 
# If a <chain> is specified the rules are appended (inserted) to 
# <chain> instead. If it is the first time <chain> is used the chain
# named <chain> is created and jumped to according to the
# <in-interface>,<out-interface> combination in that rule.
# 
# 
# [PROXY]
#   PROXY =	<in-interface> ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> ; \
#		<proxy-addr> ; <proxy-port> [ ; insert ]
#   DIRECT =	<in-interface> ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; append ]
# 
# The PROXY parameter setup netfilter rules allowing sources from the
# in-interface access to the proxy server, and also nat rules for
# redirecting the traffic (transparent proxy).
# 
# Observe that this allows the source-addr full access to the proxy
# server on proxy-port, alowing the source-addr to bypass netfilter
# security for the protocols the proxy server supports.
# You will also have to set up the appropiate restrictions in the 
# proxy server's config.
# 
# If proxy-addr is 127.0.0.1, localhost or ALL, REDIRECT target is
# used, otherwise DNAT ...  thus, do not specify the address of one of
# the firewalls interfaces if you have the proxy on the firewall
# itself, use localhost or ALL instead.
#
# The DIRECT parameter overrides the PROXY parameter allowing direct
# (possibly NAT:ed) access to or from certain hosts if including the
# same ports as the PROXY parameter.
# Observe that DIRECT does NOT automatically setup netfiler
# (FORWARD) ACCEPT rules to the specified destination(s). You will have to
# do this using ACCEPT parameters for the appropiate interfaces.
# 


[DEFINE]
  # Some subnets to be considered trusted
  IFCWIRED    =	vlan100
  NETWIRED    =	10.100.100.0/25
  IFCWIFI     =	vlan101
  NETWIFI     =	10.100.100.128/25
  IFCSRVS     =	br0                
  NETSRVS     =	10.100.101.192/26

  # We also allow a few single hosts remote connect via wireguard
  IFCCVPN     =	wg1
  NETCVPN     =	10.100.101.0/28 # 0-15

  # We want many rules to be the same for all trusted subnets
  # so we group them like this:
  IFCsTRUSTED =	IFCWIRED,IFCWIFI,IFCSRVS,IFCCVPN
  NETsTRUSTED =	10.100.100.0/24,NETVM,NETCVPN

  # And we have a DMC with a minecraft (MC) server
  IFCDMZMC    =	br1
  NETDMZMC    =	10.100.101.252/30
  ADRMC       =	10.100.101.254
  ADRMCPUB    =	3.4.2.1

  # But we migth want to add more DMZs that should have some rules in common,
  # so let's add it to a "group" with, for now, only one member:
  IFCsDMZ     =	IFCDMZMC
  NETsDMZ     =	NETDMZMC

  # Some site-to-site VPNs
  IFCPARTNER     = ipsec0             # IpSec to our Partner
  ADRPEERPARTNER = 2.3.4.5	      # IPSec peer, Partner
  NETTUNPARTNER  = 169.254.0.1/30     # IpSec tunnel
  ADRSRCTUNPART  = 169.254.0.1        # IpSec tunnel Partner endpoint
  ADRDSTTUNPART  = 169.254.0.2        # IpSec tunnel self endpoint
  ADRNATPARTNER  = 192.168.111.1      # We will NAT all traffic to Partner
  ADRWEBPARTNER  = 10.100.101.195     # Web server our Partner should reach

  IFCBOFFICE     = wg0                # WireGuard to our Big office
  NETBOFFICE     = 10.200.100.0/22

  # We have two internet circuits
  IFCISP1     =	vlan601
  IFCISP2     =	vlan602
  INTERNET    =	IFCISP1,IFCISP2

  # General Networks / Addresses
  NETRFC1918  =	10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
  NETLLOCAL   = 169.254.0.0/16
  NETLOOP     =	127.0.0.0/8
  NETPRIVATE  = NETLLOCAL,NETRFC1918,NETLOOP

  # Services
  icmp_allow =  icmp ; source-quench, redirect, echo-request, time-exceeded, parameter-problem, destination-unreachable
  p_wg =	udp ; 51821 # our wireguard port
  p_minecraft = tcp ; 25565 # our dmz-server runs minecraft


# We can give the interfaces readable names to be used in iptables
# chains names, for better readbility doing 'iptables -L'.
# We set the names before defining the actual rules, not to
# have to consdider order due to naming when we define the rules.
[IFCDMZMC]
  NAME = minecraft
[IFCISP1]
  NAME = internet1
[IFCISP2]
  NAME = internet2
[IFCPARTNER]
  NAME = partner
[IFCBOFFICE]
  NAME = bigoffice
[IFCCVPN]
  NAME = vpn
[IFCWIRED]
  NAME = wired
[IFCWIFI]
  NAME = wifi
[IVVM]
  NAME = vms


### Rules
# [<out-interface>]
#   ACCEPT =	<in-interface> ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; insert|append [ ; <chain> ] ]
#   REJECT =	<in-interface> ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; insert|append [ ; <chain> ] ]
#   DROP   =	<in-interface> ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; insert|append [ ; <chain> ] ]
#   NAT    =	<snat-addr>    ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; insert ]
# 
# [<in-interface>]
#   DNAT   =	<dnat-addr>    ; <source-addr> ; <dest-addr> ; <protocol> ; <dest-port> [ ; insert ]
#   
# Traffic to ALL interfaces
[ALL]
  ACCEPT =	ALL		; ALL		; ALL		; icmp_allow		 # useful harmless icmp
  ACCEPT =	_FW_		; ALL		; ALL		; tcp,udp	; domain # allow self dns
  ACCEPT =	_FW_		; ALL		; ALL		; udp		; ntp	 # allow self ntp
  ACCEPT =	_FW_		; ALL		; ALL		; p_wg			 # allow self wireguard
  ACCEPT =	IFCDMZMC	; ALL		; ALL		; p_minecraft		 # minecraft outgoing (also to private)
  REJECT =	IFCsDMZ		; ALL		; NETPIVATE	; ALL		; ALL	 # Recject DMZs 2 private addrs

# Allow all trusted network full access to each other
[IFCsTRUSTED]
  ACCEPT =	IFCsTRUSTED	; NETsTRUSTED	; ALL		; ALL		; ALL

# Allow partner access to single web server
[IFCSRVS]
  ACCEPT =	IFCPARTNER	ALL		; ADRWEBPARTNER	; tcp		; http,https

# NAT all Traffic to Partner, apart from tunnel enpoints talking to each other, DNAT webserver
[IFCPARTNER]
  NAT    =	ADRNATPARTNER	; ALL		; ALL		; ALL		; ALL
  NAT    =	0		; ADRSRCTUNPART ; ADRDSTTUNPART	; ALL		; ALL	       ; insert
 DNAT    =	ADRNATPARTNER	; ALL		; ADRWEBPARTNER	; tcp		; http,https

# Traffic to all our DMZs
[IFCsDMZ]
  ACCEPT =	IFCsTRUSTED	; NETsTRUSTED	; ALL		; tcp		; ssh	 # allow ssh from trusted networks

# Traffic to the minecraft DMZ
[IFCDMZMC]
  ACCEPT =	ALL		; ALL		; ALL		; p_minecraft		 # minecraft

# DNAT minecraft server's minecraft ports on ISP1
[ISP1]
  DNAT =	ADRMC		; ALL		; ADRMCPUB	; p_minecraft		 # minecraft public

# Internet-bound traffic
[INTERNET]
  REJECT =	_FW_ 		; NETPRIVATE	; ALL		; ALL		; ALL	 # reject privat addr to Internet	 
  ACCEPT =	_FW_		; ALL		; ALL		; ALL		; ALL	 # self to internet
  ACCEPT =	IFCsTRUSTED	; NETsTRUSTED	; ALL		; ALL		; ALL	 # trusted have full internet access
  NAT =		ALL		; NETRFC1918	; ALL		; ALL		; ALL	 # MASQUERADE RFC1918 addrs


  DROP   =	INTERNET		; NETLOOP,NETRFC1918     ; ALL		; ALL		; ALL		# drop priv from ext (obs priv over IPSec)

# Traffic to self
[lo]
  ACCEPT =	_FW_		; ALL		; ALL		; ALL		; ALL 		# loopback
[_FW_]
  ACCEPT =	lo		; ALL		  ; ALL		; ALL		; ALL 		# loopback
  DROP	 = 	INTERNET	; ALL		  ; ALL		; ALL		; ALL 		# by default droop

  ACCEPT =	INTERNET	; ADRPEERPARTNER  ; ALL		; udp		; 500,4500	# Partner IPSec IKE
  ACCEPT =	INTERNET	; ADRPEERPARTNER  ; ALL		; 50		; ALL		# Partner IPSec ESP


  ACCEPT =	INTERNET		; ANSAX 	  ; ALL		; icmp		; ALL		# icmp from ns.axnet.nu 
  ACCEPT =	INTERNET		; ANSAX 	  ; ALL		; tcp		; 22,5001,5201	# ssh & iperf from ns.axnet.nu 
  ACCEPT =	INTERNET		; ANSAX 	  ; ALL		; tcp,udp	; domain	# dns (notifies) from ns.axnet.nu 
  ACCEPT =	INTERNET		; 93.95.224.6 	  ; ALL		; tcp,udp	; domain	# dns (notifies) from axfr.1984.is
  #ACCEPT =	ALL		; ALL  		  ; ALL		; tcp		; 6996		# sk8cry
  #ACCEPT =	ALL		; ALL  		  ; ALL		; tcp		; 80		# sk8cry
  ACCEPT =	IFCsTRUSTED		; NETsTRUSTED		  ; ALL		; tcp		; ssh		# int ssh
  ACCEPT =	IVPNAXNS	; NVPNAXNS	  ; ALL		; tcp		; ssh		# own vpn ssh 
  ACCEPT =	IVPNAXNS	; NVPNAXNS	  ; ALL		; tcp,udp	; domain	# own vpn dns
  ACCEPT =	IVPNAXNS	; NVPNAXNS	  ; ALL		; udp		; ntp		# own vpn ntp
  ACCEPT =	IFCsTRUSTED	; NETsTRUSTED	  ; ALL		; icmp		; ALL		# int icmp
  ACCEPT =	IVPNAXNS	; NETRFC1918		  ; ALL		; icmp		; ALL		# own vpn icmp
  ACCEPT =	ALL		; AFRAXU	  ; ALL		; icmp		; ALL		# own laptop on unity icmp
  ACCEPT =	ALL		; AFRAXU	  ; ALL		; tcp,udp	; domain	# own laptop on unity dns
  ACCEPT =	IFCsTRUSTED		; ALL		  ; ALL		; tcp,udp	; domain,5201	# locals dns and iperf3
  ACCEPT =	IFCsTRUSTED		; ALL		  ; ALL		; udp		; bootps,ntp	# locals dhcp+ntp
  ACCEPT =	IFCsDMZ		; NETsDMZ		  ; ALL		; tcp,udp	; domain	# dmzs dns
  ACCEPT =	ALL		; ALL		  ; ALL		; p_wg				# WireGuard VPN
  #ACCEPT =	ALL		; ALL		  ; ALL		; p_minecraft			# Minecraft (not needed as it's DNAT:ed before hitting this rule)

  # Silently drop other multi- and broadcasts
  iptables = --table filter --append INPUT --destination 224.0.0.0/4 --jump DROP
  iptables = --table filter --append INPUT --destination 10.46.254.127 --jump DROP
  iptables = --table filter --append INPUT --destination 10.46.254.255 --jump DROP
  iptables = --table filter --append INPUT --destination 255.255.255.255 --jump DROP
  iptables = --table filter --append INPUT --destination 46.162.103.255 --jump DROP

  # REJECT (instead of DROP) packages from internal networks (silently drop multi- and broadcasts before)
  iptables = --table filter --append int-FW --destination 224.0.0.0/4 --jump DROP	
  iptables = --table filter --append int-FW --destination 10.46.254.255 --jump DROP	
  iptables = --table filter --append int-FW --destination 10.46.254.127 --jump DROP	
  iptables = --table filter --append int-FW --destination 255.255.255.255 --jump DROP	
  iptables = --table filter --append int-FW --in-interface vlan16 ! --source 10.46.254.0/25 --jump LOG_REJECT
  iptables = --table filter --append int-FW --in-interface vlan116 ! --source 10.46.254.128/25 --jump LOG_REJECT
  iptables = --table filter --append INPUT --in-interface bond0.116 ! --source 10.46.254.128/25 --jump LOG_REJECT
  iptables = --table filter --append INPUT --in-interface eth16 ! --source 10.46.254.128/25 --jump LOG_REJECT
  REJECT =	IFCsTRUSTED		; ALL		; ALL		; ALL		; ALL
  REJECT =	IVPNAXNS	; ALL		; ALL		; ALL		; ALL


[IFCWIFI]
# NAT =	<snat-addr>    ; <source-addr> ; <dest-addr>                               ; <protocol> ; <dest-port> [ ; insert ]
  # Nat towards APs to be able to manage them
  NAT = 10.46.254.129  ; NETWIRED	       ; 10.46.254.225,10.46.254.226,10.46.254.227 ; ALL        ; ALL           ; insert

[IFCsTRUSTED]
  # my devices @ unity 
  ACCEPT =	ALL		; AFRAXU	; ALL		; ALL		; ALL

  # get to fraxhue01 from Unity by portforwarding
  #ACCEPT =	IVPNU		; AFRAXU	; 10.46.254.12	; tcp		; http
  #iptables = --table nat --insert PREROUTING --in-interface tun0 --destination 10.9.1.53 --protocol tcp --destination-port 80 --jump DNAT --to-destination 10.46.254.12:80
  #iptables = --table nat --insert POSTROUTING --out-interface eth0 --protocol tcp --source 10.45.0.0/16 --destination 10.46.254.12 --destination-port 80  --jump SNAT --to-source 10.46.254.2

#  iptables = --table filter --append FORWARD --in-interface vlan16 ! --source 10.46.254.0/25 --jump LOG_REJECT
#  iptables = --table filter --append FORWARD --in-interface vlan116 ! --source 10.46.254.128/25 --jump LOG_REJECT
#  iptables = --table filter --append FORWARD --in-interface bond0.116 ! --source 10.46.254.128/25 --jump LOG_REJECT
#  iptables = --table filter --append FORWARD --in-interface eth16 ! --source 10.46.254.128/25 --jump LOG_REJECT


```
