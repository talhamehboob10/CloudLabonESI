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
use English;

use lib "/usr/testbed/lib";
use libdb;
use libtestbed;

#
# Untaint the path
# 
$ENV{'PATH'} = '/bin:/usr/bin:/usr/sbin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

#
# Fill the new vinterfaces table using info from veth_interfaces and
# IPaliases from the interfaces table.
#

# First, veth_interfaces...
DBQueryFatal("insert into vinterfaces select ".
	     "node_id,veth_id,mac,IP,mask,'veth',iface,rtabid,vnode_id ".
	     "from veth_interfaces");

# Now, IPalias info from the interfaces table...
my $query_result =
    DBQueryFatal("select node_id,mac,IP,IPaliases,mask,iface from interfaces ".
		 "where IPaliases is not NULL and IPaliases!=''");

while (my ($node,$mac,$IP,$aliases,$mask,$iface) = $query_result->fetchrow_array()) {
    my @alist = split(',', $aliases);
    foreach my $alias (@alist) {
	DBQueryFatal("insert into vinterfaces (node_id,IP,mask,type,iface) ".
		     "values ('$node','$alias','$mask','alias','$iface')");
    }
}

#
# Everything is peachy, remove the old info.
# We are leaving the veth_interfaces table around for now.
#
DBQueryFatal("update interfaces set IPaliases=NULL ".
	     "where IPaliases is not NULL");
DBQueryFatal("delete from veth_interfaces");

exit(0);
