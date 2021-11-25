#!/usr/bin/perl -wT
#
# Copyright (c) 2008-2014, 2017 University of Utah and the Flux Group.
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
# OS-independent vnode definitions, helpers, etc.
#
package libgenvnode;
use Exporter;
@ISA    = "Exporter";
@EXPORT = qw( VNODE_STATUS_RUNNING VNODE_STATUS_STOPPED VNODE_STATUS_BOOTING 
              VNODE_STATUS_INIT VNODE_STATUS_STOPPING VNODE_STATUS_UNKNOWN
	      VNODE_STATUS_MOUNTED
              VNODE_PATH
              VNODE_POLL_ERROR VNODE_POLL_STOP VNODE_POLL_CONTINUE
              findVirtControlNet
            );

# Drag in path stuff
BEGIN { require "/etc/emulab/paths.pm"; import emulabpaths; }

sub VNODE_STATUS_RUNNING() { return "running"; }
sub VNODE_STATUS_STOPPED() { return "stopped"; }
sub VNODE_STATUS_MOUNTED() { return "mounted"; }
sub VNODE_STATUS_BOOTING() { return "booting"; }
sub VNODE_STATUS_INIT()    { return "init"; }
sub VNODE_STATUS_STOPPING(){ return "stopping"; }
sub VNODE_STATUS_PAUSED(){ return "paused"; }
sub VNODE_STATUS_UNKNOWN() { return "unknown"; }

#
# Valid constants that can be returned by vnodePoll.
#
sub VNODE_POLL_ERROR() { return -1 }
sub VNODE_POLL_STOP() { return 1; }
sub VNODE_POLL_CONTINUE() { return 0; }

# VM path stuff
my $VMPATH     = "$VARDIR/vminfo";
sub VNODE_PATH(;$) { 
    my $vnode_id = shift;
    return 
	$VMPATH . 
	(defined($vnode_id) ? "/$vnode_id" : "") . 
	"/";
}

#
# Magic control network config parameters.
#
my $VCNET_NET	    = "172.16.0.0";
my $VCNET_MASK      = "255.240.0.0";
my $VCNET_GW	    = "172.16.0.1";
my $VCNET_SLASHMASK = "12";

#
# Find virtual control net iface info.  Returns:
# (net,mask,GW)
#
sub findVirtControlNet()
{
    return ($VCNET_NET, $VCNET_MASK, $VCNET_GW, $VCNET_SLASHMASK);
}
