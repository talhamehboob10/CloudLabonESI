#!/usr/bin/perl
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

#
# kill processes associated with wanetmon on ops
#

use strict;

sub kill_pid($){
    my ($pid) = @_;
    `kill $pid`;
    my $successresult = `ps -a -o pid | grep $pid`;

    if( $successresult ne "" ){
        print "failresult = $successresult\n";
        return 0;
    }else{
        return 1;
    }
}


my ($pid, $command);

###########################################
($pid, $command) = split(" ",
    `ps -a -o pid,command | grep "perl automanagerclient.pl" | grep -v "grep"`,
                            2);
chomp $command;

print "stopping: ($pid,$command)\n";
if( kill_pid($pid) ){
    print "success!\n";
}else{
    print "FAILURE of killing pid=$pid\n";
}

###########################################


($pid, $command) = split(" ",
    `ps -a -o pid,command | grep "perl manager.pl" | grep -v "grep"`,
                            2);
chomp $command;

print "stopping: ($pid,$command)\n";
if( kill_pid($pid) ){
    print "success!\n";
}else{
    print "FAILURE of killing pid=$pid\n";
}
###########################################


($pid, $command) = split(" ",
    `ps -a -o pid,command | grep "perl opsrecv.pl" | grep -v "grep"`,
                            2);
chomp $command;

print "stopping: ($pid,$command)\n";
if( kill_pid($pid) ){
    print "success!\n";
}else{
    print "FAILURE of killing pid=$pid\n";
}
###########################################

