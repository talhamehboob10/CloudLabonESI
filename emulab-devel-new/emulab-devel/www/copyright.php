<?php
#
# Copyright (c) 2000-2010 University of Utah and the Flux Group.
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
require("defs.php3");

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
    PAGEHEADER("Emulab Copyright Notice");
}

if ($printable) {
    #
    # Need to spit out some header stuff.
    #
    echo "<html>
          <head>
          <title>Copyright Notice</title>
  	  <link rel='stylesheet' href='tbstyle-plain.css' type='text/css'>
          </head>
          <body>\n";
}
else {
    echo "<b><a href='copyright.php?printable=1'>
              Printable version of this document</a></b><br>\n";

    echo "<p><center><b>Copyright Notice</b></center><br>\n";
}

#
# Allow for a site specific copyright
#
$sitefile = "copyright-local.html";

if (!file_exists($sitefile)) {
    $sitefile = "copyright-standard.html";
}
readfile("$sitefile");

#
# Standard Testbed Footer
# 
if ($printable) {
    echo "</body>
          </html>\n";
}
else {
    PAGEFOOTER();
}

?>
