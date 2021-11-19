#!/usr/bin/perl -w
#
# Copyright (c) 2006, 2007 University of Utah and the Flux Group.
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
# TODO: Watch iperf, and kill if a timeout (30 sec) is exceeded.
#

use strict;

my %params = (@ARGV);
my $execpath = "/tmp/iperf";
my %ERRID = ( #kept the same as defined in libwanetmon for backwards compatibility
    unknown => -3,
    timeout => -1,
    unknownhost => -4,
    iperfHostUnreachable => -6 
    );

#
# Check for existence of all required params
#
# TODO

#
# Add optional args, if they exist
#
my %optional_exec_args; #TODO

#
# Form arguments specific to this execuable
#
my $execargs = " -fk -c $params{target} -t $params{duration} -p $params{port}";

#
# Execute testing application
#
my $raw = `$execpath $execargs`;
#print "RAW = $raw\n";

#
# Parse output
#
$_ = $raw;
my $measr = 0;
my $error = 0;

if(    /connect failed: Connection timed out/ ){
    # this one shouldn't happen, if the timeout check done by
    # bgmon is set low enough.
    $error = $ERRID{timeout};
}elsif( /write1 failed:/ ){
    $error = $ERRID{iperfHostUnreachable};
}elsif( /error: Name or service not known/ ){
    $error = $ERRID{unknownhost};
}elsif( /\s+(\S*)\s+([MK])bits\/sec/ ){
    $measr = $1;
    if( $2 eq "M" ){
        $measr *= 1000;
    }
}else{
    $error = $ERRID{unknown};
}

#print "MEASR=$measr, ERROR=$error\n";


#
# Output result
#
print "bw=$measr,error=$error\n";
