#!/usr/bin/awk -f
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

/^cpu MHz.*(29[5-9][0-9]|30[0-4][0-9])\.[0-9]+$/ {
    print "3000";
    exit
}
/^cpu MHz.*(27[5-9][0-9]|28[0-4][0-9])\.[0-9]+$/ {
    print "2800";
    exit
}
/^cpu MHz.*(24[5-9][0-9]|25[0-4][0-9])\.[0-9]+$/ {
    print "2500";
    exit
}
/^cpu MHz.*(23[5-9][0-9]|24[0-4][0-9])\.[0-9]+$/ {
    print "2400";
    exit
}
/^cpu MHz.*(19[5-9][0-9]|20[0-4][0-9])\.[0-9]+$/ {
    print "2000";
    exit
}
/^cpu MHz.*(14[5-9][0-9]|15[0-4][0-9])\.[0-9]+$/ {
    print "1500";
    exit
}
/^cpu MHz.*8[0-9][0-9]\.[0-9]+$/ {
    print "850";
    exit
}
/^cpu MHz.*(72[0-9]|73[0-9])\.[0-9]+$/ {
    print "733";
    exit
}
/^cpu MHz.*6[0-9][0-9]\.[0-9]+$/ {
    print "600";
    exit
}
/^cpu MHz.*(29[0-9]|30[0-9])\.[0-9]+$/ {
    print "300";
    exit
}
/^cpu MHz.*/ {
    print "0";
    exit
}
