#!/usr/bin/perl -w

#
# Copyright (c) 2013 University of Utah and the Flux Group.
# 
# {{{EMULAB-LGPL
# 
# This file is part of the Emulab network testbed software.
# 
# This file is free software; you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation; either version 2.1 of the License, or (at
# your option) any later version.
# 
# This file is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with this file.  If not, see <http://www.gnu.org/licenses/>.
# 
# }}}
#

# Simple test harness for the MLNX-gateway module.

use MLNX_XMLGateway;
use Getopt::Std;
use strict;

my @get_test1 = (
    ["name", "Basic 'get' Test #1"],
    ["get","/mlnxos/v1/api_version"],
    ["get","/mlnxos/v1/chassis/model"],
    ["get","/mlnxos/v1/chassis/pn"],
    ["get","/mlnxos/v1/chassis/fans/FAN/1/speed"],
    ["get","/mlnxos/v1/vsr/default_vsr/vlans/*"],
    ["submit"]
);

my @get_test2 = (
    ["name","Interface name 'get' Test #2"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces_by_name/*"],
    ["submit"]
);

my @pget_test1 = (
    ["name", "Port 'get' Test (Eth1/8) #1"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/enabled"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/type"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/mtu"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/pvid"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/mode"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/allowed/*"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/physical_location"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/supported_speed"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/configured_speed"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/actual_speed"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/lag/membership"],
    ["submit"]
);

my @pget_test2 = (
    ["name", "Port 'get' Test (Po1) #2"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/13826/enabled"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/13826/type"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/13826/vlans/pvid"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/13826/vlans/mode"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/13826/vlans/allowed/*"],
    ["submit"]
);

my @vlan_test1 = (
    ["name", "Vlan Creation Test #1"],
    ["action","/mlnxos/v1/vsr/default_vsr/vlans/add",{vlan_id => 666}],
    ["set-modify","/mlnxos/v1/vsr/default_vsr/vlans/666/name=testvlan"],
    ["get","/mlnxos/v1/vsr/default_vsr/vlans/*"],
    ["submit"],
    ["action","/mlnxos/v1/vsr/default_vsr/vlans/delete",{vlan_id => 666}],
    ["get","/mlnxos/v1/vsr/default_vsr/vlans/*"],
    ["submit"]
);


my @port_test1 = (
    ["name", "Port Toggle Test (Eth1/8) #1"],
    ["set-modify","/mlnxos/v1/vsr/default_vsr/interfaces/101/enabled=false"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/enabled"],
    ["submit"],
    ["set-modify","/mlnxos/v1/vsr/default_vsr/interfaces/101/enabled=true"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/enabled"],
    ["submit"]
);

my @vport_test1 = (
    ["name", "Vlan + Port Test (Eth1/8) #1"],
    ["action","/mlnxos/v1/vsr/default_vsr/vlans/add",{vlan_id => 666}],
    ["set-modify","/mlnxos/v1/vsr/default_vsr/vlans/666/name=testvlan"],
    ["set-modify","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/pvid=666"],
    ["get","/mlnxos/v1/vsr/default_vsr/vlans/*"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/pvid"],
    ["submit"],
    ["action","/mlnxos/v1/vsr/default_vsr/vlans/delete",{vlan_id => 666}],
    ["set-modify","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/pvid=53"],
    ["get","/mlnxos/v1/vsr/default_vsr/vlans/*"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/pvid"],
    ["submit"]
);

my @trunk_test1 = (
    ["name", "Trunk Test (Eth1/8) #1"],
    ["action","/mlnxos/v1/vsr/default_vsr/vlans/add",{vlan_id => 666}],
    ["set-modify","/mlnxos/v1/vsr/default_vsr/vlans/666/name=testvlan1"],
    ["action","/mlnxos/v1/vsr/default_vsr/vlans/add",{vlan_id => 777}],
    ["set-modify","/mlnxos/v1/vsr/default_vsr/vlans/666/name=testvlan2"],
    ["set-modify","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/mode=trunk"],
    ["action","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/allowed/add",{vlan_ids => "666"}],
    ["action","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/allowed/add",{vlan_ids => "777"}],
    ["submit"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/allowed/*"],
    ["get","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/mode"],
    ["submit"],
    ["action","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/allowed/delete",{vlan_ids => "666"}],
    ["action","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/allowed/delete",{vlan_ids => "777"}],
    ["set-modify","/mlnxos/v1/vsr/default_vsr/interfaces/101/vlans/mode=access"],
    ["action","/mlnxos/v1/vsr/default_vsr/vlans/delete",{vlan_id => 666}],
    ["action","/mlnxos/v1/vsr/default_vsr/vlans/delete",{vlan_id => 777}],
    ["submit"]
);

# List the tests to run here.
my @testsets = (\@pget_test1,);

my %opts = ();

if (!getopts("a:d:",\%opts)) {
    print "Usage: $0 -a <uri_auth_string> -d <level>\n";
    exit 1;
}

my $auth  = "";
my $debug = 0;
$auth  = $opts{'a'} or die "Must specify an auth string!";
$debug = $opts{'d'} if $opts{'d'};

my $gateway = MLNX_XMLGateway->new($auth);
$gateway->debug($debug) if $debug;

foreach my $tlist (@testsets) {
    my @cmdset  = ();
    my @results = ();
    my $testname = "unnamed";

    foreach my $cmd (@{$tlist}) {
        TESTSW1: for ((@{$cmd})[0]) {
	    /^name$/ && do {
		$testname = (@{$cmd})[1];
		print "========== Running Test: $testname ==========\n";
		last TESTSW1;
	    };
	
	    /^submit$/ && do {
		push @results, $gateway->call(\@cmdset);
		@cmdset = ();
		last TESTSW1;
	    };
      
	    # Default
	    push @cmdset, $cmd;
	}
    }

    print "--- Results:\n";
    my $i = 1;
    foreach my $reslist (@results) {
	print "* Submission $i:\n";
	foreach my $res (@$reslist) {
	    print "@$res\n";
	}
	++$i;
    }

    print "\n";
}

