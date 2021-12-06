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
$reqargs = RequiredPageArguments("docname",    PAGEARG_STRING);
$optargs = OptionalPageArguments("printable",  PAGEARG_BOOLEAN);

#
# Need to sanity check the path! Allow only [word].html files
#
if (!preg_match("/^[-\w]+\.(html|txt)$/", $docname)) {
    USERERROR("Illegal document name: $docname!", 1, HTTP_400_BAD_REQUEST);
}

#
# Make sure the file exists
#
$fh = @fopen("$docname", "r");
if (!$fh) {
    USERERROR("Can't read document file: $docname!", 1, HTTP_404_NOT_FOUND);
}

if (!isset($printable))
    $printable = 0;

#
# Standard Testbed Header
#
if (!$printable) {
    PAGEHEADER("Emulab Hyperviewer");
}

if ($printable) {
    #
    # Need to spit out some header stuff.
    #
    echo "<html>
          <head>
  	  <link rel='stylesheet' href='../tbstyle-plain.css' type='text/css'>
          </head>
          <body>\n";
}
else {
	$REQUEST_URI = $_SERVER["REQUEST_URI"];
	echo "<b><a href=$REQUEST_URI&printable=1>
                 Printable version of this document</a></b><br>\n";
}

fpassthru($fh);
fclose($fh);

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

