<?php
#
# Copyright (c) 2000-2007 University of Utah and the Flux Group.
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

#
# Wrapper Wrapper script for cvsweb.cgi
#
chdir("../");
require("defs.php3");

# Must be logged in.
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify form arguments.
#
$optargs = OptionalPageArguments("template",   PAGEARG_TEMPLATE,
				 "project",    PAGEARG_PROJECT,
				 "embedded",   PAGEARG_BOOLEAN);
if (!isset($embedded)) {
    $embedded = 0;
}

#
# Form the real url.
#
$newurl  = preg_replace("/cvswebwrap/", "cvsweb", $_SERVER['REQUEST_URI']);
$newurl = preg_replace("/php3/","php3/",$newurl);

#
# Standard Testbed Header
#
PAGEHEADER("Emulab CVS Repository");

if (isset($project)) {
    ;
}
elseif (isset($template)) {
    echo $template->PageHeader();
}

echo "<div><iframe src='$newurl' class='outputframe' ".
	"id='outputframe' name='outputframe'></iframe></div>\n";
echo "</center><br>\n";

echo "<script type='text/javascript' language='javascript'>\n";
echo "SetupOutputArea('outputframe', false);\n"; 
echo "</script>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
