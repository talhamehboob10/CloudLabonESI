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

BEGIN {
    found = 0;
}

/^CPU:.*\((29[5-9][0-9]|30[0-4][0-9])\.[0-9]+\-MHz/ {
    print "3000";
    found = 1;
    exit
}
/^CPU:.*\((27[5-9][0-9]|28[0-4][0-9])\.[0-9]+\-MHz/ {
    print "2800";
    found = 1;
    exit
}
/^CPU:.*\((24[5-9][0-9]|25[0-4][0-9])\.[0-9]+\-MHz/ {
    print "2500";
    found = 1;
    exit
}
/^CPU:.*\((23[5-9][0-9]|24[0-4][0-9])\.[0-9]+\-MHz/ {
    print "2400";
    found = 1;
    exit
}
/^CPU:.*\((19[5-9][0-9]|20[0-4][0-9])\.[0-9]+\-MHz/ {
    print "2000";
    found = 1;
    exit
}
/^CPU:.*\((17[5-9][0-9]|18[0-4][0-9])\.[0-9]+\-MHz/ {
    print "1800";
    found = 1;
    exit
}
/^CPU:.*\((14[5-9][0-9]|15[0-4][0-9])\.[0-9]+\-MHz/ {
    print "1500";
    found = 1;
    exit
}
/^CPU:.*\(8[0-9][0-9]\.[0-9]+\-MHz/ {
    print "850";
    found = 1;
    exit
}
/^CPU:.*\((72[0-9]|73[0-9])\.[0-9]+\-MHz/ {
    print "733";
    found = 1;
    exit
}
/^CPU:.*\(6[0-9][0-9]\.[0-9]+\-MHz/ {
    print "600";
    found = 1;
    exit
}
/^CPU:.*\((29[0-9]|30[0-9]|333)\.[0-9]+\-MHz/ {
    print "300";
    found = 1;
    exit
}

END {
    if (found == 0) {
	print "0";
    }
}
