#!/usr/bin/perl -w
#
# Copyright (c) 2000-2015 University of Utah and the Flux Group.
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
use strict;
use Getopt::Std;
use English;

#
# Invoked by xmcreate script to configure experimental networks for a vnode.
#
sub usage()
{
    print "Usage: emulab-enet file ...\n";
    exit(1);
}

#
# Turn off line buffering on output
#
$| = 1;

# Drag in path stuff so we can find emulab stuff.
BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }

#
# Load the OS independent support library. It will load the OS dependent
# library and initialize itself. 
# 
use libsetup;
use libtmcc;
use libutil;
use libtestbed;
use libgenvnode;

my $lockdebug = 0;

print STDERR "@ARGV\n";
print STDERR $ENV{"vif"} . "\n";

my $script = shift(@ARGV);

my $vif = $ENV{"vif"};
my $op = $ARGV[0];
my $vnode_id = "??";
if ($script =~ m#vminfo/([^/]+)/enet#) {
    $vnode_id = $1;
}

#
# Oh jeez, iptables is about the dumbest POS I've ever seen;
# it fails if you run two at the same time. So we have to
# serialize the calls. Rather then worry about each call, just
# take a big lock here. 
#
TBDebugTimeStampsOn();
TBDebugTimeStampWithDate("$vnode_id ($vif) emulab-enet $op: called");

TBDebugTimeStamp("$vnode_id: emulab-enet: grabbing iptables lock")
    if ($lockdebug);
if (TBScriptLock("iptables", 0, 300) != TBSCRIPTLOCK_OKAY()) {
    print STDERR "Could not get the iptables lock after a long time!\n";
    return -1;
}
TBDebugTimeStamp("  got iptables lock")
    if ($lockdebug);

system("/bin/sh $script @ARGV");
my $ecode = $? >> 8;

TBDebugTimeStamp("  releasing iptables lock")
    if ($lockdebug);
TBScriptUnlock();

exit($ecode);

