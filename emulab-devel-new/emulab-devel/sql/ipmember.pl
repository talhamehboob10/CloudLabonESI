#!/usr/bin/perl -w
#
# Copyright (c) 2003-2006 University of Utah and the Flux Group.
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
use Errno;

use lib "/usr/testbed/lib";
use libdb;
use libtestbed;

my $allexp_result =
    DBQueryFatal("select pid,eid from experiments");

while (my ($pid,$eid) = $allexp_result->fetchrow_array) {
    my %ips = ();
    
    my $query_result =
	DBQueryFatal("select vname,ips from virt_nodes ".
		     "where pid='$pid' and eid='$eid'");
		     
    while (my ($vnode,$ips) = $query_result->fetchrow_array) {
	# Take apart the IP list.
	foreach $ipinfo (split(" ", $ips)) {
	    my ($port,$ip) = split(":",$ipinfo);

	    $ips{"$vnode:$port"} = $ip;
	}
    }

    $query_result =
	DBQueryFatal("select vname,member from virt_lans ".
		     "where pid='$pid' and eid='$eid'");
		     
    while (my ($vname,$member) = $query_result->fetchrow_array) {
	my ($vnode,$port) = split(":", $member);
	my $ip = $ips{$member};

	DBQueryFatal("update virt_lans set ".
		     "vnode='$vnode',ip='$ip',vport='$port' ".
		     "where pid='$pid' and eid='$eid' and ".
		     "vname='$vname' and member='$member'");
    }
}



