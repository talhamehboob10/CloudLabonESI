#!/usr/bin/perl -w
#
# Copyright (c) 2000-2004 University of Utah and the Flux Group.
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
use English;

use lib "/usr/testbed/lib";
use libdb;
use libtestbed;

my $CLOSEPROJADMINLIST = "/usr/testbed/sbin/closeprojadminlist";

#
# Turn off line buffering on output
#
$| = 1;

my $gentopofile = "/usr/testbed/libexec/gentopofile";

#
# Untaint the path
# 
$ENV{'PATH'} = '/bin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

$query_result =
    DBQueryFatal("select pid from projects where approved");

while (($pid) = $query_result->fetchrow_array()) {
    print "Closing $pid-admin mailing list\n";
    system("$CLOSEPROJADMINLIST $pid") == 0 or
	    die("$CLOSEPROJADMINLIST $pid failed!");
}
