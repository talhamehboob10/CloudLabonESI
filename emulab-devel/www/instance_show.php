<?php
#
# Copyright (c) 2006, 2007 University of Utah and the Flux Group.
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
include("defs.php3");
include_once("template_defs.php");
require("Sajax.php");
sajax_init();
sajax_export("ModifyAnno");

#
# Only known and logged in users ...
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs  = RequiredPageArguments("instance",   PAGEARG_INSTANCE);
$optargs  = OptionalPageArguments("showhidden", PAGEARG_BOOLEAN);
$template = $instance->GetTemplate();
# Need these below.
$guid = $template->guid();
$vers = $template->vers();
$pid  = $template->pid();
$eid  = $instance->eid();

# Default to not showing hidden
if (!isset($showhidden)) {
     $showhidden = 0;
}

if (! $template->AccessCheck($this_user, $TB_EXPT_READINFO)) {
    USERERROR("You do not have permission to view experiment template ".
	      "$guid/$version!", 1);
}

#
# For the Sajax Interface
#
function ModifyAnno($newtext)
{
    global $this_user, $template, $instance;

    $instance->SetAnnotation($this_user, $newtext);
    return 0;
}

#
# See if this request is to the above function. Does not return
# if it is. Otherwise return and continue on.
#
sajax_handle_client_request();

#
# Standard Testbed Header after argument checking.
#
PAGEHEADER("Template Instance");

echo "<script type='text/javascript' language='javascript'>\n";
sajax_show_javascript();
echo "</script>\n";

echo $instance->PageHeader();
echo "<br><br>\n";
$instance->Show(1, 1, $showhidden);

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
