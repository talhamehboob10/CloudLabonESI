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
include("webtask.php");
chdir("apt");
include("quickvm_sup.php");
$page_title = "List Images";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_uid  = $this_user->uid();

#
# Verify page arguments. Cluster is a domain that we turn into a URN.
#
$optargs = OptionalPageArguments("cluster",        PAGEARG_STRING,
                                 "target_user",    PAGEARG_USER,
                                 "target_project", PAGEARG_PROJECT);

SPITHEADER(1);

if (isset($target_user)) {
    if (!$target_user->SameUser($this_user) &&
        !(ISADMIN() || ISFOREIGN_ADMIN())) {
        SPITUSERERROR("Not enough permission to view this page!");
    }
}
elseif (isset($target_project)) {
    if (! ($target_project->IsLeader($this_user) ||
           $target_project->IsManager($this_user) ||
           ISADMIN() || ISFOREIGN_ADMIN())) {
        SPITUSERERROR("Not enough permission to view this page!");
    }
}
else {
    $target_user = $this_user;
}
$amlist = array();

if (isset($cluster)) {
    if (!preg_match("/^[\w\.]+$/", $cluster)) {
        PAGEARGERROR("Invalid cluster argument");
        exit();
    }
    $aggregate = Aggregate::LookupByNickname($cluster);
    if (!$aggregate) {
        SPITUSERERROR("No such cluster");
        exit();
    }    
    $amlist[$aggregate->nickname()] = $aggregate->urn();
}
else {
    # List of clusters.
    $ams     = Aggregate::DefaultAggregateList();
    $amlist  = array();
    while (list($index, $aggregate) = each($ams)) {
        $amlist[$aggregate->nickname()] = $aggregate->urn();
    }
}
echo "<script type='text/plain' id='amlist-json'>\n";
echo htmlentities(json_encode($amlist));
echo "</script>\n";

echo "<link rel='stylesheet'
            href='css/tablesorter-widget-grouping.css'>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'>
        <div id='spinner'>
          <center id='spinner'><img src='images/spinner.gif' /></center><br>
        </div>
        <div id='no-images-message' class='hidden'>
         <center>
          You have no images (clones or snapshots) yet.
         </center>
        </div>
        <div id='classic-images-div' class='hidden'></div>
      </div>\n";

# Place to hang the modals for now
echo "<div id='oops_div'></div>
      <div id='waitwait_div'></div>
      <div id='confirm_div'></div>
      <div id='image-format-modal_div'></div>\n";

echo "<script type='text/javascript'>\n";
if ($target_project) {
    echo "  window.TARGET_PROJECT = '" . $target_project->pid() . "';\n";
}
else {
    echo "  window.TARGET_USER = '" . $target_user->uid() . "';\n";
}
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER(array('js/lib/tablesorter/widgets/widget-grouping.js'));
AddTemplateList(array("image-list", "classic-image-list",
                      "confirm-delete-image", "image-format-modal",
                      "oops-modal", "waitwait-modal"));
SPITREQUIRE("js/list-images.js");
SPITFOOTER();
?>
