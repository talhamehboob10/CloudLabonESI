#!/usr/bin/perl -w
#
# Copyright (c) 2000-2008 University of Utah and the Flux Group.
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
$ENV{'PATH'} = '/bin:/usr/bin:/usr/sbin:/usr/testbed/sbin';
delete @ENV{'IFS', 'CDPATH', 'ENV', 'BASH_ENV'};

$query_result =
    DBQueryFatal("select u.uid from users as u ".
		 "left join user_stats as s on s.uid_idx=u.uid_idx ".
		 "where u.status='active' and u.webonly=0 ".
		 "order by s.weblogin_last desc");

# Avoid blizzard of audit email.
$ENV{'TBAUDITON'} = 1;

while (($uid) = $query_result->fetchrow_array()) {
    print "Generating new emulab cert for $uid\n";
    system("withadminprivs mkusercert $uid >/dev/null") == 0
	or warn("Failed to create SSL cert for user $uid\n");
}
