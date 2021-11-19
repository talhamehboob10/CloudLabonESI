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

#
# "true" pc850 reports:
#    Host bridge: Intel Corp. 440BX/ZX/DX - 82443BX/ZX/DX Host bridge (AGP disabled) (rev 3).
# upgraded pc600 reports:
#    Host bridge: Intel Corp. 440BX/ZX/DX - 82443BX/ZX/DX Host bridge (rev 3).
#

/^[ ]+Host bridge: Intel Corp.*[0-9][0-9][0-9][0-9][0-9]BX.*\(AGP disabled\)/ {
    print "BX";
    found = 1;
    exit
}
/^[ ]+Host bridge: Intel Corp.*[0-9][0-9][0-9][0-9][0-9]BX/ {
    print "BX-AGP";
    found = 1;
    exit
}
/^[ ]+Host bridge: Intel Corp.*[0-9][0-9][0-9][0-9][0-9]GX/ {
    print "GX";
    found = 1;
    exit
}
/^[ ]+PCI bridge: Intel Corp.*HI_C Virtual PCI-to-PCI Bridge/ {
    print "HI_C";
    found = 1;
    exit
}
/^[ ]+PCI bridge: Intel Corp.*HI_B Virtual PCI-to-PCI Bridge/ {
    print "HI_B";
    found = 1;
    exit
}
END {
    if (found == 0) {
	print "??";
    }
}
