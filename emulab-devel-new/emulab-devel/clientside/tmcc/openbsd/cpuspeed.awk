#!/usr/bin/awk -f
#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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

/^cpu0:.*\) (19|20)[0-9][0-9] MHz/ {
    print "2000";
    next
}
/^cpu0:.*\) 1[45][0-9][0-9] MHz/ {
    print "1500";
    next
}
/^cpu0:.*\) 8[0-9][0-9] MHz/ {
    print "850";
    next
}
/^cpu0:.*\) 6[0-9][0-9] MHz/ {
    print "600";
    next
}
/^cpu0:.*MHz/ {
    print "0";
    next
}
