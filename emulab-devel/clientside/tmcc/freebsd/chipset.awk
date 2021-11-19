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
#    pcib0: <Intel 82443BX host to PCI bridge (AGP disabled)> on motherboard
# upgraded pc600 reports:
#    pcib0: <Intel 82443BX (440 BX) host to PCI bridge> on motherboard
#
/^pcib0: <Intel [0-9][0-9][0-9][0-9][0-9]BX host.*\(AGP disabled\)/ {
    print "BX";
    found = 1;
    exit
}
/^pcib0: <Intel [0-9][0-9][0-9][0-9][0-9]BX \(440 BX\) host/ {
    print "BX-AGP";
    found = 1;
    exit
}
/^pcib0: <Intel [0-9][0-9][0-9][0-9][0-9]GX / {
    print "GX";
    found = 1;
    exit
}

#
# pc850 under FreeBSD 5.x
#
/^acpi0: <INTEL  TR440BXA> on motherboard/ {
    print "BX";
    found = 1;
    exit
}

#
# aero:    pcib1: <PCI to PCI bridge (vendor=8086 device=2545)> ... Intel HI_C
# rutgers: pcib1: <PCI to PCI bridge (vendor=8086 device=2543)> ... Intel HI_B
#
/^pcib1: <PCI to PCI bridge \(vendor=8086 device=2545\)>/ {
    print "HI_C";
    found = 1;
    exit
}
/^pcib1: <PCI to PCI bridge \(vendor=8086 device=2543\)>/ {
    print "HI_B";
    found = 1;
    exit
}

END {
    if (found == 0) {
	print "??";
    }
}
