#!/usr/bin/perl -w

#
# Copyright (c) 2000-2016 University of Utah and the Flux Group.
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

#
# module for controlling SuperMicro IPMI cards
# needs a working "/usr/local/bin/ipmitool" binary installed
# (try pkg_add -r ipmitool)
#
# supports new(ip), power(on|off|cyc[le]), status
#

package power_ipmi;

$| = 1; # Turn off line buffering on output

use strict;
use lib "@prefix@/lib";
use libdb;
use emutil;

$ENV{'PATH'} = '/bin:/usr/bin:/usr/local/bin'; # Required when using system() or backticks `` in combination with the perl -T taint checks

my $IPMITOOL = "/usr/local/bin/ipmitool";
my $KTYPE    = "ipmi";

# Constants for moonshot chassis support.
my $MS_MAXSLOT = 45;
my $MS_NODEBASEADDR = 0x72;
my $MS_NODEBRIDGEID = 0x7;
my $MS_CARTBASEADDR = 0x82;
my $MS_CARTBRIDGEID = 0x0;

sub new($$$;$$) {

    # The next two lines are some voodoo taken from perltoot(1)
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my $devicetype = shift;
    my $devicename = shift;
    my $debug = shift;
    my $withsdr = shift;

    if (!defined($debug)) {
        $debug = 0;
    }
    if (!defined($withsdr)) {
	$withsdr = 0;
    }

    if ($debug) {
        print "power_ipmi module initializing... debug level $debug\n";
    }

    my $self = {};

    $self->{DEBUG} = $debug;
    $self->{WITHSDR} = $withsdr;

    $self->{DEVICETYPE} = $devicetype;
    $self->{DEVICENAME} = $devicename;
    $self->{USERNAME}   = "ADMIN";              # default username
    $self->{PASSWORD}   = "ADMIN";              # default password
    $self->{KGKEY}      = "";

    # Fetch authentication credentials from the DB.
    my $res = DBQueryFatal("select key_role,key_uid,mykey,key_privlvl" . 
			   " from outlets_remoteauth" . 
			   " where node_id='$devicename'".
			   " and key_type='$KTYPE'");
    if (!defined($res) || !$res || $res->num_rows() == 0) {
	warn "No remote auth info for $devicename. Using defaults!\n";
    } else {
	while (my $row = $res->fetchrow_hashref()) {
	    my $role = $row->{'key_role'};
	    if ($role eq "ipmi-passwd") {
		$self->{USERNAME} = $row->{'key_uid'};
		$self->{PASSWORD} = $row->{'mykey'};
	        if ($row->{'key_privlvl'}) {
	            $self->{PRIVLVL} = $row->{'key_privlvl'};
	        }
	    } 
	    elsif ($role eq "ipmi-kgkey") {
		($self->{KGKEY} = $row->{'mykey'}) =~ s/^0x//;
	    }
	}
    }

    $self->{IPMICMD} = "$IPMITOOL -H $self->{DEVICENAME} -U $self->{USERNAME} -P '$self->{PASSWORD}'";
    if ($self->{KGKEY}) {
	$self->{IPMICMD} .= " -I lanplus -y '$self->{KGKEY}'";
    } elsif ($self->{DEVICETYPE} eq "ipmi-ms") {
	$self->{IPMICMD} .= " -I lanplus";
    }
    if ($self->{PRIVLVL}) {
        $self->{IPMICMD} .= " -L $self->{PRIVLVL}";
    }

    # Do a quick query, to see if it works
    system("$self->{IPMICMD} power status >/dev/null 2>\&1");
    if ( $? != 0 ) {                    # system() sets $? to a non-zero value in case of failure
        warn "ERROR: Unable to connect to $devicename via IPMI\n";
        return undef;
    }

    bless($self,$class);
    $self->_mkmsmap();

    return $self;
}

sub power($$@) {
    my $self = shift;
    my $op = shift;
    my @outlets = @_;
    my %status = ();

    my $errors = 0;
    my $force = 0;

    if    ($op eq "on")  { $op = "power on";    }
    elsif ($op eq "off") { $op = "power off";   }
    elsif ($op =~ /cyc/) {
	if ($op eq "forcecycle") {
	    $force = 1;
	}
	if ($self->{DEVICETYPE} eq "ipmi-ms") {
	    $op = "power cycle";
	} else {
	    $op = "power reset";
	}
    }

    $errors = $self->_execipmicmd($op, \@outlets, \%status, $force);
    if ($errors) {
        print STDERR $self->{DEVICENAME}, ": command '$op' failed for some/all outlets: @outlets\n";
    }

    return $errors;
}

sub status($$@) {
    my $self = shift;
    my $statusp = shift;
    my @outlets = @_;
    my %status;

    my $errors = 0;
    my ($retval, $output);

    # Get power status (i.e. whether system is on/off)
    $retval = $self->_execipmicmd("power status", \@outlets, \%status, 0);
    if ( $retval != 0 ) {
        $errors++;
        print STDERR $self->{DEVICENAME}, ": could not get power status from device\n";
    }

    # Get Sensor Data Repository (sdr) entries and readings
    # XXX needs work
    if ($self->{WITHSDR}) {
	my %lstatus = ();

	$retval = $self->_execipmicmd("sdr", \@outlets, \%lstatus, 0);
	if ( $retval != 0 ) {
	    $errors++;
	    print STDERR $self->{DEVICENAME}, ": could not get sensor data from device\n";
	}
	else {
	    foreach my $outlet (@outlets) {
		my $oname = "outlet" . $outlet;

		$output = "UNKNOWN";
		if (exists($lstatus{$oname})) {
		    $output = $lstatus{$oname};
		}
		print("SDR data is:\n$output\n") if $self->{DEBUG};
		$status{'sdr'} = $output;
	    }
	}
    }

    if ($statusp) { %$statusp = %status; } # update passed-by-reference array
    return $errors;
}

#
# The returned status is expected to be:
#
#    $status{'outletN'} = <status string from command> (e.g., "on", "off")
#
# where N is the outlet number.
#
sub _execipmicmd($$$$$) {
    my ($self, $op, $outletsp, $statusp, $force) = @_;
    my $exitval = 0;
    my @results = ();

    if (!defined($outletsp)) {
	return 0;
    }
    
    my $isstatus = ($op eq "power status") ? 1 : 0;
    
    my $coderef = sub {
	my $outlet = shift;
	my $output = "";
	my $cmd;

	# Construct command based on device type.
	if ($self->{DEVICETYPE} eq "ipmi-ms") {
	    my $ipmiaddrstr = $self->_get_msaddr($outlet);
	    if ($ipmiaddrstr) {
		$cmd = "$self->{IPMICMD} $ipmiaddrstr $op";
	    } else {
		print STDERR "$self->{DEVICENAME}: invalid outlet: $outlet\n";
		return -1;
	    }
	} else {
	    $cmd = "$self->{IPMICMD} $op";
	}

      again:
	print STDERR "**** Executing $cmd\n"
	    if ($self->{DEBUG});
	$output = `$cmd 2>&1`;
	chomp ( $output );

	print STDERR "impitool output:\n$output\n"
	    if ($self->{DEBUG});

	if ($?) {
	    # XXX special case handling of node powered off
	    if ($output =~ /not supported in present state/) {
		if ($force) {
		    print "*** Cycle failed, trying power on instead.\n"
			if ($self->{DEBUG} > 1);
		    $cmd =~ s/power (cycle|reset)/power on/;
		    $force = 0;
		    goto again;
		}
	    }
	    print STDERR "*** power_ipmi: ipmitool returned non-zero: $?\n";
	    print STDERR "ipmitool output:\n$output\n";
	    return -1;
	}

	# for a status command we have to interpret the output
	if ($isstatus) {
	    if ($output =~ /power is (off|on)/i) {
		return ($1 eq "off") ? 0 : 1;
	    }
	    print STDERR "*** power_ipmi: unexpected power status:\n$output\n";
	    return -1;
	}

	return 0;
    };

    my @outlets = @$outletsp;
    if (ParRun(undef, \@results, $coderef, @outlets)) {
	print STDERR "*** power_ipmi: Internal error in ParRun()!\n";
	return -1;
    }
    #
    # Check the exit codes. 
    #
    for (my $ix = 0; $ix < @outlets; $ix++) {
	my $outlet = "outlet" . $outlets[$ix];
	my $rv = ($results[$ix] >> 8);
	$statusp->{$outlet} = $rv;
	if ($isstatus) {
	    ++$exitval
		if ($rv < 0);
	} else {
	    ++$exitval
		if ($rv != 0);
	}
    }

    return $exitval;
}

sub _mkmsmap() {
    my $self = shift;
    $self->{MS_OUTLETMAP} = [];
    foreach my $outlet (1 .. $MS_MAXSLOT) {
	my $cartaddr = $MS_CARTBASEADDR + 2*($outlet - 1);
	my $nodeaddr = $MS_NODEBASEADDR;
	my $vals = {
	    'cartaddr' => $cartaddr,
	    'cartbrid' => $MS_CARTBRIDGEID,
	    'nodeaddr' => $nodeaddr,
	    'nodebrid' => $MS_NODEBRIDGEID,
	    };
	$self->{MS_OUTLETMAP}->[$outlet] = $vals;
    }
}

sub _get_msaddr($$) {
    my ($self, $outlet) = @_;
    my $msaddrstr = "";

    return undef
	unless defined($self->{MS_OUTLETMAP}->[$outlet]);

    my $msaddr = $self->{MS_OUTLETMAP}->[$outlet];
    $msaddrstr = sprintf("-T 0x%x -B 0x%x -t 0x%x -b 0x%x", 
			  $msaddr->{'cartaddr'},
			  $msaddr->{'cartbrid'},
			  $msaddr->{'nodeaddr'},
			  $msaddr->{'nodebrid'});

    return $msaddrstr;
}

# End with true
1;

# vim: set ft=perl et sw=4 ts=8:
# Not sure what the (no)et sw=? ts=? rules should be in this file - they're kind of mixed.
# Seems like a leading tab in some places and then 4 expanded spaces.  Maybe et sw=4 ts=8.
