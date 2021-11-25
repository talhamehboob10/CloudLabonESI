#!/usr/bin/perl -w
#
# Copyright (c) 2003-2011 University of Utah and the Flux Group.
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

DBQueryFatal("lock tables reserved write, nodes write");

my $query_result =
    DBQueryFatal("select nodes.node_id from nodes ".
		 "left join reserved on nodes.node_id=reserved.node_id ".
		 "where reserved.node_id is null and ".
		 "      (nodes.type='pcvm' or nodes.type='pcplab')");

# Need to do this when we want to seek around inside the results.
$query_result = $query_result->WrapForSeek();

while (my ($vnodeid) = $query_result->fetchrow_array()) {
    DBQueryWarn("delete from reserved where node_id='$vnodeid'");
    DBQueryWarn("delete from nodes where node_id='$vnodeid'");
}

DBQueryFatal("unlock tables");

$query_result->dataseek(0);

while (my ($vnodeid) = $query_result->fetchrow_array()) {
    DBQueryWarn("delete from node_hostkeys where node_id='$vnodeid'");
    DBQueryWarn("delete from node_status where node_id='$vnodeid'");
    DBQueryWarn("delete from node_rusage where node_id='$vnodeid'");
}
