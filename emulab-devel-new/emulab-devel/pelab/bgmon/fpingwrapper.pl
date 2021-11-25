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


use strict;

my %params = (@ARGV);
my $execpath = "/tmp/fping";
my %ERRID = (  #kept the same as defined in libwanetmon for backwards compatibility
    unknown => -3,
    timeout => -1,
    unknownhost => -4,
    ICMPunreachable => -5
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
my $execargs = " -t $params{timeout} -s -r $params{retries} $params{target}";


#
# Execute testing application
#
#print "FPING WRAPPER... executing= $execpath $execargs\n";
my $raw = `sudo $execpath $execargs 2>&1`;
#print "FPING WRAPPER... parsing raw= $raw\n";

#
# Parse output
#
$_ = $raw;
my $measr = 0;
my $error = 0;

if( /^ICMP / )
{
    $error = $ERRID{ICMPunreachable};
}elsif( /address not found/ ){
    $error = $ERRID{unknownhost};
}elsif( /2 timeouts/ ){
    $error = $ERRID{timeout};
}elsif( /[\s]+([\S]*) ms \(avg round trip time\)/ ){
    $measr = "$1" if( $1 ne "0.00" );
}else{
    $error = $ERRID{unknown};
}


#print "MEASR=$measr, ERROR=$error\n";


#
# Output result
#
print "latency=$measr,error=$error\n";
