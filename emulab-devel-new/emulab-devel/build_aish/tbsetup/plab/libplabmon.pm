#!/usr/bin/perl -wT
#
# Copyright (c) 2005, 2006 University of Utah and the Flux Group.
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
package libplabmon;

use strict;
use Exporter;
use vars qw(@ISA @EXPORT);

@ISA    = "Exporter";
@EXPORT = qw (MIN TimeStamp getLA OpenLog Log STATUSLOG STATUSLOGPATH);

# Must come after package declaration!
use lib '/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/lib';
use libdb;
use libtestbed;
use English;
use IO::File;

# Configure variables
my $TB		= "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish";
my $BOSSNODE    = "boss.cloudlab.umass.edu";

# package consts
my $UPTIME       = "/usr/bin/uptime";

# package vars
my %logs = ();

sub STATUSLOG { 
    my $log = shift || '';
    return "StatusLog-$log";
}
sub STATUSLOGPATH { 
    my $log = shift || '';
    return "$TB/log/plabnodestatus-$log.log";
}

sub MIN($$) {
    my ($a, $b) = @_;

    my $res =  $a < $b ? $a : $b;

    return $res;
}

sub TimeStamp() {
    return POSIX::strftime("%m/%d/%y %H:%M:%S", localtime());
}

sub getLA() {
    my ($LAstr) = `$UPTIME` =~ /load averages:\s+([\d\.]+),/;
    return int($LAstr);
}

#
# Open a log file for writing
#
sub OpenLog($$) {
    my $loghandlename = shift;
    my $logfile = shift;
    my $loghandle = new IO::File;

    if (exists($logs{$loghandlename})) {
        return 1;
    }

    if (!open ($loghandle, ">> $logfile")) {
        print STDERR "Unable to open logfile $logfile for append!";
        return 0;
    }
    $logs{$loghandlename} = $loghandle;
    return 1;
}

#
# Print out a timestamped log entry to a particular file.
#
sub Log($$) {
    my $loghandlename = shift;
    my $logmsg = shift;

    if (!exists($logs{$loghandlename})) {
        print STDERR "Log $loghandlename is not open!\n";
        return;
    }
    my $loghandle = $logs{$loghandlename};
    print $loghandle TimeStamp() . ": "  . $logmsg . "\n";
    return;
}

# Make perl happy
1;
