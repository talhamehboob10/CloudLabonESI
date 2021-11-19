<?php
#
# Copyright (c) 2004-2013 University of Utah and the Flux Group.
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
chdir("..");
require("defs.php3");
chdir("hyperviewer");

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("printable",  PAGEARG_BOOLEAN);

if (!isset($printable))
    $printable = 0;

#
# Standard Testbed Header
#
if (!$printable) {
    PAGEHEADER("Emulab Hyperviewer");
}

if (!$printable) {
    $REQUEST_URI = $_SERVER["REQUEST_URI"];
    echo "<b><a href=$REQUEST_URI?printable=1>
             Printable version of this document</a></b><br>\n";
}

readfile("index.html");

#
# Standard Testbed Footer
# 
if (!$printable) {
    PAGEFOOTER();
}
?>

