#!/usr/bin/perl -w
#
# Copyright (c) 2006 University of Utah and the Flux Group.
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

# Script to test if data is being entered into the ops db properly.

use strict;
use English;
use Getopt::Std;
use lib '/usr/testbed/lib';
use libtbdb;
use libwanetmondb;

my $numMeas_ok = 100000;
my $numMeas_too_many = 5000000;
my $lastMeasTime_ok = time() - 60;  #last measurement must be within 60 seconds

my $query 
    = "select unixstamp from pair_data order by idx desc limit $numMeas_ok";

my @results = getRows($query);
if( scalar(@results) < $numMeas_ok ){
    print "fail: too few measurements in ops db\n";
    die -1;
}
if( scalar(@results) > $numMeas_too_many ){
    print "fail: too many measurements in ops db\n";
    die -1;
}
if( $results[0]->{unixstamp} < $lastMeasTime_ok ){
    print "fail: last measurement in ops db too old\n";
    die -2;
}
