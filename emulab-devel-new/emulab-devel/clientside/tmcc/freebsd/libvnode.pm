#!/usr/bin/perl -wT
#
# Copyright (c) 2013 University of Utah and the Flux Group.
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
# General vnode setup routines and helpers (FreeBSD)
#
package libvnode;
use Exporter;
@ISA    = "Exporter";
@EXPORT = qw(              
              forwardPort removePortForward
            );

use libutil;
use libgenvnode;
use libsetup;

#
# Magic control network config parameters.
#
my $PCNET_IP_FILE   = "/var/emulab/boot/myip";
my $PCNET_MASK_FILE = "/var/emulab/boot/mynetmask";
my $PCNET_GW_FILE   = "/var/emulab/boot/routerip";

# Other local constants

my $debug = 0;

sub setDebug($) {
    $debug = shift;
    print "libvnode: debug=$debug\n"
	if ($debug);
}

#
# Setup (or teardown) a port forward according to input hash containing:
# * ext_ip:   External IP address traffic is destined to
# * ext_port: External port traffic is destined to
# * int_ip:   Internal IP address traffic is redirected to
# * int_port: Internal port traffic is redirected to
#
# 'protocol' - a string; either "tcp" or "udp"
# 'remove'   - a boolean indicating whether or not to do a teardown.
#
# XXX: this is only a stub (2/14/2013)
#
sub forwardPort($;$) {
    my ($ref, $remove) = @_;
    
    my $int_ip   = $ref->{'int_ip'};
    my $ext_ip   = $ref->{'ext_ip'};
    my $int_port = $ref->{'int_port'};
    my $ext_port = $ref->{'ext_port'};
    my $protocol = $ref->{'protocol'};

    if (!(defined($int_ip) && 
	  defined($ext_ip) && 
	  defined($int_port) &&
	  defined($ext_port) && 
	  defined($protocol))
	) {
	print STDERR "WARNING: forwardPort: parameters missing!";
	return -1;
    }

    if ($protocol !~ /^(tcp|udp)$/) {
	print STDERR "WARNING: forwardPort: Unknown protocol: $protocol\n";
	return -1;
    }
    
    # Are we removing or adding the rule?
    my $op = (defined($remove) && $remove) ? "D" : "A";

    # XXX: finish implementation.
    return 0;
}

sub removePortForward($) {
    my $ref = shift;
    forwardPort($ref,1)
}

# silly Perl
1;
