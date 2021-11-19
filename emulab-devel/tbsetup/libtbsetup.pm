#!/usr/bin/perl -w

#
# Copyright (c) 2000-2002 University of Utah and the Flux Group.
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

use POSIX;

package libtbsetup;
use Exporter;
@ISA = "Exporter";
@EXPORT =
    qw ( tbs_initdbi tbs_initlog tbs_prefix tbs_out tbs_exec );

# This has the common functionality for tbprerun/tbrun/tbend.

# tbs_initdbi(dbname) - Initializes a DBI connection to the testbed database
#                       Returns the database handle.
# tbs_prefix(s) - Returns the file prefix.  I.e. strips off \..+$ from the end.
# tbs_out(s) - Spits s out to stdout and LOGFILE.
# tbs_exec(s) - Acts like system except STDOUT and STDERR are both spat out
#               through tbs_out.  Returns 1 on failure and 0 on success.

my $LOGFILE;
my $logging = 0;
my $dostamp = 0;

sub tbs_initdbi {
    my($dbname) = $_[0];
    return DBI->connect("DBI:mysql:database=$dbname;host=localhost") 
	|| die "Could not connect to DB.\n";
};

sub tbs_initlog {
    my($logfile) = $_[0];

    # Turn off line buffering.
    $| = 1; 

    open(LOGFILE,">>$logfile") || do {
	print STDERR "Could not open $logfile for writing.\n";
	exit(1);
    };
    $logging = 1;
}

sub tbs_prefix {
    my($s) = $_[0];
    my($prefix);
    ($prefix) = ($s =~ /^(.+)\.[^.]+$/);
    return $prefix;
};

sub tbs_out {
    my($s) = $_[0];
    if ($dostamp) {
	my $t = ctime(time);
	print $t;
	if ($logging) {
	    print LOGFILE $t;
	}
    }
    print $s;
    if ($logging) {
	print LOGFILE $s;
    }
};

sub tbs_exec {
    my($cmd) = $_[0];
    open(EXEC,"$cmd 2>&1|") || return 1;
    while (<EXEC>) {
	&tbs_out($_);
    }
    close(EXEC) or
	return $! ? $! : $?;

    return 0;
};

1;
