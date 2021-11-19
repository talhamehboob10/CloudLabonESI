<?php
#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
include("defs.php3");
chdir("apt");
include("quickvm_sup.php");
include("profile_defs.php");
$page_title = "Activity";

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("target_user",    PAGEARG_USER,
				 "target_project", PAGEARG_PROJECT,
                                 "portalonly",     PAGEARG_BOOLEAN,
                                 "cluster",        PAGEARG_STRING,
                                 "min",            PAGEARG_INTEGER,
                                 "max",            PAGEARG_INTEGER);
#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$isadmin   = (ISADMIN() || ISFOREIGN_ADMIN() ? 1 : 0);
SPITHEADER(1);

if (!$isadmin) {
    if (isset($target_user)) {
        if (!$target_user->SameUser($this_user)) {
            SPITUSERERROR("Not enough permission to view this page!");
        }
    }
    elseif (isset($target_project)) {
        $approved = 0;
        
        if (!$target_project->IsMember($this_user, $approved) && $approved) {
            SPITUSERERROR("Not enough permission to view this page!");
        }
    }
    else {
        $target_user = $this_user;
    }
}
else {
    if (isset($cluster)) {
        $aggregate = Aggregate::LookupByNickname($cluster);
        if (!$aggregate) {
            SPITUSERERROR("No such cluster: $cluster");
            exit();
        }
    }
}    
#
# Allow for targeted searches
#
if (isset($target_user)) {
    $target_uid  = $target_user->uid();
}
elseif (isset($target_project)) {
    $target_pid   = $target_project->pid_idx();
}
# Lets default to last month if neither min or max provided
if (! (isset($min) || isset($max))) {
    $min = time() - (30 * 3600 * 24);
}

# Place to hang the toplevel template.
echo "<div id='page-body'>
        <div id='activity-body'></div>
        <div id='waitwait_div'></div>
        <div id='oops_div'></div>
      </div>\n";

echo "<script type='text/javascript'>\n";
echo "    window.AJAXURL  = 'server-ajax.php';\n";
echo "    window.ISADMIN  = $isadmin;\n";
if (isset($min)) {
    echo "    window.MIN  = $min;\n";
}
else {
    echo "    window.MIN  = null;\n";
}
if (isset($max)) {
    echo "    window.MAX  = $max;\n";
}
else {
    echo "    window.MAX  = null;\n";
}
if (isset($target_user)) {
    echo "    window.TARGET_USER = '$target_uid';\n";
}
elseif (isset($target_project)) {
    echo "    window.TARGET_PROJECT = '$target_pid';\n";
}
if (isset($aggregate)) {
    echo "    window.CLUSTER = '$cluster';\n";
}
if (isset($portalonly) && $portalonly) {
    echo "    window.PORTALONLY = true;\n";
}
echo "</script>\n";
echo "<link rel='stylesheet' href='css/jQRangeSlider.css'>\n";
echo "<script src='js/lib/jquery-ui.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSliderMouseTouch.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSliderDraggable.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSliderHandle.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSliderBar.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSliderLabel.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSlider.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQDateRangeSliderHandle.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQDateRangeSlider.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRuler.js'></script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
SPITREQUIRE("js/activity.js");

AddTemplateList(array("activity", "activity-table",
                      "waitwait-modal", "oops-modal"));

SPITFOOTER();
?>
