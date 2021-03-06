#!/usr/local/etc/emulab/nse

#
# Copyright (c) 2000-2004, 2006 University of Utah and the Flux Group.
# 
# {{{EMULAB-LICENSE
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software: you can redistribute it and/or modify it
# under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public
# License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

global CLIENTVARDIR
global CLIENTBINDIR
set CLIENTVARDIR /var/emulab
set CLIENTBINDIR /usr/local/etc/emulab
set EVENTSERVER  event-server
set PROJDIR	 /proj

# consults tmcc hostnames database to translate hostname to IP
# returns ip address of name
proc getipaddr {name} {

    set resolver [new TbResolver]
    set ip [$resolver lookup $name]
    delete $resolver
    if { $ip != {} } {
	return $ip	
    }

    set hostnamelist [split [exec tmcc hostnames] "\n"]
    foreach hostname $hostnamelist {
	if { $hostname == {} } {
	    continue
	}
	set ret1 [regexp -- {NAME=([-\w\.]+) } $hostname Matchvar hname]
	set ret2 [regexp -- {IP=([0-9\.]*) } $hostname Matchvar ip]
	set ret3 [regexp -- {ALIASES='([-\w\. ]*)'} $hostname Matchvar aliases]
	if { $ret == 0 || $ret1 == 0 || $ret2 == 0 } {
	    puts stderr "NSE: tmcc hostnames format has changed."
	    puts stderr "NSE: Contact testbed operations to fix this."
	    exit -1
	}
	set aliaslist [split $aliases " "]
	foreach alias $aliaslist {
	    if { $alias == $name } {
		return $ip
	    }
	}
    }
    puts stderr "NSE: Could not find ipaddress for $name"
    return ""
}

# Reads tmcc ifconfig output and constructs an array of
# IP address to MAC address mappings
proc readifconfig {} {
    global CLIENTVARDIR
    set tmccifconfig [open $CLIENTVARDIR/boot/tmcc.ifconfig r]
    set ifconf [read $tmccifconfig]
    close $tmccifconfig

    global tbiptomac
    global tbiptortabid
    set ifconfiglist [split $ifconf "\n"]
    foreach ifconfig $ifconfiglist {
	if { $ifconfig == {} } {
	    continue
	}
	set ret [regexp -- {IFACETYPE=(\w*) } $ifconfig Matchvar ifacetype]
	if { $ret == 0 } {
            puts stderr "NSE: tmcc ifconfig format has changed."
            puts stderr "NSE: Contact testbed operations to fix this."
	    exit -1
	}
	if { $ifacetype == "veth" } {
	    set ret [regexp -- {VMAC=(\w*) } $ifconfig Matchvar mac]
	} else {
	    set ret [regexp -- {MAC=(\w*) } $ifconfig Matchvar mac]
	}
	set ret1 [regexp -- {INET=([0-9\.]*) } $ifconfig Matchvar inet]
	set ret2 [regexp -- {MASK=([0-9\.]*) } $ifconfig Matchvar mask]
	set ret3 [regexp -- {RTABID=(\d*)} $ifconfig Matchvar rtabid]
	if { $ret == 0 || $ret1 == 0 || $ret2 == 0 || $ret3 == 0  } {
	    puts stderr "NSE: tmcc ifconfig format has changed."
	    puts stderr "NSE: Contact testbed operations to fix this."
	    exit -1
	}
	set tbiptomac($inet) $mac
	set tbiptortabid($inet) $rtabid
    }
}


# consults info from tmcc ifconfig and findif to find the interface name
# returns the interface name for ipaddr
proc getif {ipaddr} {
    global tbiptomac

    if { [info exists tbiptomac($ipaddr)] } {
	return [exec findif $tbiptomac($ipaddr)]
    }

    puts stderr "NSE: getif: Could not find the interface name for $ipaddr"
    return ""
}

# consults info from tmcc ifconfig and findif to find the interface name
# returns the interface name for ipaddr
proc getrtabid {ipaddr} {
    global tbiptortabid

    if { [info exists tbiptortabid($ipaddr)] } {
	return $tbiptortabid($ipaddr)
    }

    puts stderr "NSE: getrtabid: Could not find the rtabid for $ipaddr"
    return ""
}

proc getmac {ipaddr} {
    global tbiptomac

    if { [info exists tbiptomac($ipaddr)] } {
	set mac $tbiptomac($ipaddr)
	set macaddrchars [split $mac ""]
	set i 0
	while { $i < [llength $macaddrchars] } {
	    lappend mac2chars "[lindex $macaddrchars $i][lindex $macaddrchars [expr $i + 1]]"
	    set i [expr $i + 2]
	}
	return [join $mac2chars ":"]
    }

    puts stderr "NSE: getmac: Could not find the interface name for $ipaddr"
    return ""
}

proc findcpuspeed {} {
    if { [catch {set speed [exec sysctl -n machdep.tsc_freq]}] == 0 && $speed != {} } {
         return $speed
    }
    set dmesgfd [open /var/run/dmesg.boot r]
    set dmesg [read $dmesgfd]
    close $dmesgfd

    set tscregret [regexp {TSC[\" \t]*frequency[ \t]*(\d+)[ \t]*Hz} $speed]
    set regret [regexp {CPU:\D*(\d+\.?\d*)-([MmGg][Hh][zZ])} $dmesg matchstr speed mghz]

    if { $tscregret == 1 } {
         return $speed
    } elseif { $regret == 1 } {
	
	if { [regexp -nocase {mhz} $mghz] == 1 } {
	    return [expr $speed * 1000000]
	} elseif { [regexp -nocase {ghz} $mghz] == 1 } {
	    return [expr $speed * 1000000000]
	} else {
	    return -1
	}

    } else {
	return -1
    }
}

proc readroutes {} {
    global CLIENTVARDIR
    set tmccroutelist [open $CLIENTVARDIR/boot/tmcc.routelist r]
    set routeliststr [read $tmccroutelist]
    close $tmccroutelist

    global tbroutes
    
    set routelist [split $routeliststr \n]
    unset routeliststr
    foreach route $routelist {
	if { $route == {} } {
	    continue
	}
	set ret [scan $route "ROUTE NODE=%s SRC=%s DEST=%s DESTTYPE=%s DESTMASK=%s NEXTHOP=%s COST=%s" \
		              node src dst dsttype dstmask nexthop cost]
	# we ensure that by expecting all 7 conversions in scan to happen for correct lines
	# probably a ROUTERTYPE line if the conversion fails
	if { $ret == 7 } {
	    lappend tbroutes($node) "$dst:$dstmask:$nexthop"
	}
    }
}

proc readtrafgens {} {
    global CLIENTVARDIR
    global tbtrafgens

    set tmcctrafgens [open $CLIENTVARDIR/boot/tmcc.trafgens r]
    set tmcctraf [read $tmcctrafgens]
    close $tmcctrafgens

    set trafgenlist [split $tmcctraf "\n"]
    set formatstr {TRAFGEN=%s MYNAME=%s MYPORT=%u PEERNAME=%s PEERPORT=%u PROTO=%s ROLE=%s GENERATOR=%s}
    foreach trafgen $trafgenlist {
	if { $trafgen == {} } {
	    continue
	}
	
	scan $trafgen $formatstr traf myname myport peername peerport proto role gen
	if { $gen != "NSE" || $proto != "tcp" } {
	    continue
	}
	set tbtrafgens($traf) "$myname:$myport:$peername:$peerport"
    }
}

# call it after evaluating nseconfigs
# This will parse tmcc routelist and
# store a list of routes for all source nodes that are
# in this simulation

set tmccnseconfigs [open $CLIENTVARDIR/boot/tmcc.nseconfigs r]
set nseconfig [read $tmccnseconfigs]
close $tmccnseconfigs

# If there is no nseconfig associated with this
# node, then we just give up
if { $nseconfig == {} } {
   exit 0
}

set nsetrafgen_present 0
set simcode_present 0

# since we ran the original script through NSE (without running the simulation),
# we can ignore all sorts of errors.
# XXX: Hmm not true anymore. Need to fix this later.
if { [catch {eval $nseconfig} errMsg] == 1 } {
    puts stderr "NSE: syntax error evaluating script: $errMsg"
}

# ifconfig
readifconfig

# Routes
readroutes

# Traffic Generators used only if NSE based traffic generators are present
readtrafgens

# the name of the simulator instance variable might not
# always be 'ns', coming from the TB parser
set ns [Simulator instance]

# we only need 1 RAW IP socket for introducing packets into the network
set ipnetcommon [new Network/IP]
$ipnetcommon open writeonly

# configuring NSE FullTcp traffic generators
if { $nsetrafgen_present == 1 } {

    # The following nodes are present 
    set n0_FullTcp [$ns node]

    # set sysctl tcp blackhole to 2
    exec sysctl -w net.inet.tcp.blackhole=2

    lappend tcpclasses "Agent/TCP/FullTcp"
    foreach tcpsubclass [Agent/TCP/FullTcp info subclass] {
	lappend tcpclasses $tcpsubclass
    }
    
    # for each entry in `tmcc trafgens` that has NSE as the generator
    # configure that object to connect to a newly created
    # TCPTap along with the required Live and RAW IP objects. Set the filter and interface
    # after learning it from tmcc commands and other scripts in /var/emulab
    
    set i 0
    foreach tcpclass $tcpclasses {
	set tcpobjs [$tcpclass info instances]
	
	foreach tcpobj $tcpobjs {
	    
	    # objname is a instance variable that was put
	    # by TB parser on objects instantiated by it.
	    # we are concerned only with those. the rest
	    # of the FullTcp objects could be created as
	    # as a result of a combined simulation and
	    # emulation scenario
	    set tcptbname [$tcpobj set tbname]
	    if { $tcptbname != {} } {
		$ns attach-agent $n0_FullTcp $tcpobj

		set trafrecord [split $tbtrafgens($tcptbname) ":"]
		set myname [lindex $trafrecord 0]
		set myport [lindex $trafrecord 1]
		set peername [lindex $trafrecord 2]
		set peerport [lindex $trafrecord 3]

		# convert myname and peername to corresponding ipaddresses
		# using the getipaddr helper subroutine
		set myipaddr [getipaddr $myname]
		set peeripaddr [getipaddr $peername]
	    
		# find interface name with a helper subroutine
		set interface [getif $myipaddr]

		# one TCPTap object per TCP class that we have instantiated
		set tcptap($i) [new Agent/TCPTap]
		$tcptap($i) nsipaddr $myipaddr
		$tcptap($i) nsport $myport
		$tcptap($i) extipaddr $peeripaddr 
		$tcptap($i) extport $peerport
	    
		# open the bpf, set the filter for capturing incoming packets towards
		# the current tcp object
		set bpf_tcp($i) [new Network/Pcap/Live]
		set dev_tcp($i) [$bpf_tcp($i) open readonly $interface]
		$bpf_tcp($i) filter "tcp and dst $myipaddr and dst port $myport and src $peeripaddr and src port $peerport"
	    
		# associate the 2 network objects in the TCPTap object
		$tcptap($i) network-incoming $bpf_tcp($i)
		$tcptap($i) network-outgoing $ipnetcommon
	    
		# attach the TCPTap agent to node n1_FullTcp
		$ns attach-agent $n0_FullTcp $tcptap($i)
	    
		# connect this tap and the particular tcp agent
		$ns connect $tcpobj $tcptap($i)

		incr i
	    }
	}
    }
}

if { $simcode_present == 1 } {

    exec sysctl -w net.inet.ip.forwarding=0 net.inet.ip.fastforwarding=0
    
    # Disabling and Enabling interfaces so that routes are all
    # flushed and we can start cleanly
    if { [file exists $CLIENTVARDIR/boot/rc.ifc] } { 
    	exec $CLIENTVARDIR/boot/rc.ifc disable
	exec $CLIENTVARDIR/boot/rc.ifc enable
    }
    
    # Now, we configure IPTaps for links between real and simulated nodes
    set i 0    
    
    foreach nodeinst [concat [Node info instances] [Node/MobileNode info instances]] {

	if { [$nodeinst info vars tbname] != {} } {
	    set tbnodename [$nodeinst set tbname]

	    if { [info exists tbroutes($tbnodename)] } {
		foreach route $tbroutes($tbnodename) {
		    set rt [split $route ":"]
		    # format is dst:dstmask:nexthop
		    # add-route-to-ip ip nhopip mask
		    $nodeinst add-route-to-ip [lindex $rt 0] [lindex $rt 2] [lindex $rt 1]
		    # We dont really consider the case where different routes
		    # have different masks. A complete longest prefix match
		    # implementation that is also efficient for nse may
		    # have to be done in the future
		}
	    }
	}
    }

    # Perhaps create the veths right here
    foreach rlink [Rlink info instances] {
	if { $rlink == {} } {
	    continue
	}
	set iptap [$rlink target]
	set ip [$rlink srcipaddr]
	set iface [getif $ip] 
	set rtabid [getrtabid $ip]
	$iptap ipaddr $ip

	# except for the current host itself
	set bpf_ip [new Network/Pcap/Live]
	set devname [$bpf_ip open readonly $iface]
	set mac [getmac $ip]
	if { $mac != {} } {
	    $bpf_ip filter "ip and not ether src $mac"
	} else {
	    $bpf_ip filter "ip"
	}
	# associate the 2 network objects in the IPTap object
	$iptap network-incoming $bpf_ip

	set srcnode [$rlink src]
	if { [info exists ipnet($srcnode)] } {
	    $iptap network-outgoing $ipnet($srcnode)
	    $iptap icmpagent $icmpagt($srcnode)
	} else {
	    set ipnet($srcnode) [new Network/IP]
	    $ipnet($srcnode) open writeonly	    
	    $ipnet($srcnode) setrtabid $rtabid
	    $iptap network-outgoing $ipnet($srcnode)

	    set icmpagt($srcnode) [new Agent/IcmpAgent]
	    $ns attach-agent $srcnode $icmpagt($srcnode)
	    $iptap icmpagent $icmpagt($srcnode)

	    if { [$srcnode info vars tbname] != {} } {
		set tbnodename [$srcnode set tbname]

		if { [info exists tbroutes($tbnodename)] } {
		    foreach route $tbroutes($tbnodename) {
			set rt [split $route ":"]
			set ip [lindex $rt 0]
			set nhopip [lindex $rt 2]
			set mask [lindex $rt 1]
			# Need to add routes for nodes that have
			# rlinks so that packets that leave the
			# pnode will be routed by the kernel.
			# We will use the "route" command to
			# add routes. Since we are already
			# running as root, no need to run sudo.
			# Also, if a route add fails, it is probably
			# due to the nexthop being a sim node on the
			# this pnode for which the nexthop IP is not
			# attached to any interface and the kernel does
			# not know how to route to it. But that's ok
			# coz we have added a route already in the sim
			if { $rtabid > 0 } {
			    catch {exec route add -rtabid $rtabid $ip $nhopip $mask}
			} else {
			    catch {exec route add $ip $nhopip $mask}
			}
		    }
		}
	    }
	}

	# No need to attach the iptap to the node coz it was
	# done when an rlink got created
    }
}

# get some params to configure the event system interface

set pideidlist [split [exec hostname] "."]
set vnode [lindex $pideidlist 0]
set eid [lindex $pideidlist 1]
set pid [lindex $pideidlist 2]
set logpath "$PROJDIR/$pid/exp/$eid/logs/nse-$vnode.log"
set simobjname [$ns set tbname]
set nseswap_cmdline "$CLIENTBINDIR/tevc -s $EVENTSERVER -e $pid/$eid now $simobjname NSESWAP SIMHOST=$vnode"

set pktrate_logpath "$PROJDIR/$pid/exp/$eid/logs/nse-vnodepktrate-$vnode.log"

# Configuring the Scheduler to monitor the event system
set evsink [new TbEventSink]
$evsink event-server "elvin://$EVENTSERVER"
$evsink nseswap_cmdline $nseswap_cmdline
$evsink logfile $logpath
[$ns set scheduler_] tbevent-sink $evsink

set cpuspeed [findcpuspeed]
if { $cpuspeed != -1 } {
    [$ns set scheduler_] cpuspeed $cpuspeed
}

# Releasing memory that is not needed so that
# the simulation run might get them
if { [info exists tbroutes] } {
    unset tbroutes
}

# Adding an event to send an ISUP event to the testbed
# Note that the actual events specified by the user will
# come from the event system after a little while. So, this
# first event at 0.0 will ensure that the simulator scheduler
# has subscribed to the event system and is processing the
# first event
$ns at 0.0 {exec echo "Informing the testbed that we're up and running ..." > /dev/console}
$ns at 0.0 "exec $CLIENTBINDIR/tmcc state ISUP"

proc write-vnode-pktrate {} {
    global pktrate_logpath
    set f [open $pktrate_logpath w]
    foreach nodeinst [concat [Node info instances] [Node/MobileNode info instances]] {

	if { [$nodeinst info vars tbname] == {} } {
	    continue
	}
	set tbnodename [$nodeinst set tbname]
	set pktrate [$nodeinst get-pktrate]
	puts $f "$tbnodename=$pktrate"
    }
    close $f
}

$ns run
