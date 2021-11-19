#!/usr/bin/perl -wT

#
# Copyright (c) 2004 University of Utah and the Flux Group.
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

# A little perl module to power cycle a ue attached to a console host -
# basically just a wrapper around the tbadb script.

package power_ue;

use Exporter;
@ISA = ("Exporter");
@EXPORT = qw( uectrl );

#
# Commands we run
#
my $TBROOT = '@prefix@';
my $TBADB = "$TBROOT/bin/tbadb";

# Turn off line buffering on output
$| = 1;

# usage: uectrl(cmd, devices)
# cmd = { "cycle" | "on" | "off" }
# devices = list of one or more physcial ue names.
#
# Returns 0 on success. Non-zero on failure.
# 
sub uectrl($@) {
    my ($cmd, @devices) = @_;
    my $tbadb_cmd;
    my $err = 0;

    #
    # Call TBADB as appropriate for device.  Note that we don't power down UE
    # nodes.  Instead, we reload them into "fastboot".
    #
    SWITCH: for ($cmd) {
	# Just reboot the device normally.  Presumably it is in
	# fastboot mode if we are "powering" it on.
	/^on$/i || /^cycle$/i and do {
	    $tbadb_cmd = "reboot";
	    last SWITCH;
	};
	# Put the device in "fastboot" mode.
	/^off$/i and do {
	    $tbadb_cmd = "reboot fastboot";
	    last SWITCH;
	};
	# DEFAULT
	print STDERR "power_ue: Unknown command: $cmd\n";
	return 1;
    }

    foreach my $dev (@devices) {
	if (system("$TBADB -n $dev $tbadb_cmd") != 0) {
	    print STDERR "power_ue: \"$cmd\" command failed for $dev\n";
	    $err = 1;
	}
    }

    return $err;
}

1;
