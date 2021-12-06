<?php
#
# Copyright (c) 2000-2018 University of Utah and the Flux Group.
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
include_once("profile_defs.php");
include_once("instance_defs.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Create Dataset";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
if (NOPROJECTMEMBERSHIP()) {
    return NoProjectMembershipError($this_user);
}
$this_idx  = $this_user->uid_idx();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("create",      PAGEARG_STRING,
				 "formfields",  PAGEARG_ARRAY);

#
# Spit the form
#
function SPITFORM($formfields, $errors)
{
    global $this_user, $projlist, $embedded, $this_idx;
    $button_label = "Create";
    $title        = "Create Dataset";

    SPITHEADER(1);

    # Place to hang the toplevel template.
    echo "<div id='main-body'></div>\n";

    # I think this will take care of XSS prevention?
    echo "<script type='text/plain' id='form-json'>\n";
    echo htmlentities(json_encode($formfields)) . "\n";
    echo "</script>\n";
    echo "<script type='text/plain' id='error-json'>\n";
    echo htmlentities(json_encode($errors));
    echo "</script>\n";

    #
    # Pass project list through. Need to convert to list without groups.
    # When editing, pass through a single value. The template treats a
    # a single value as a read-only field.
    #
    $plist = array();
    while (list($project) = each($projlist)) {
	$plist[] = $project;
    }
    echo "<script type='text/plain' id='projects-json'>\n";
    echo htmlentities(json_encode($plist));
    echo "</script>\n";

    if (!$embedded) {
        $query_result =
            DBQueryFatal("select uuid from apt_instances as a ".
                         "where creator_idx='$this_idx'");
        $instance_array = array();

        while ($row = mysql_fetch_array($query_result)) {
            $uuid         = $row["uuid"];
            $instance     = Instance::Lookup($uuid);
            $profile      = Profile::Lookup($instance->profile_id(),
                                            $instance->profile_version());
            $instance_array[] =
                array("uuid" => $uuid, "name" => $instance->name());
        }
        echo "<script type='text/plain' id='instances-json'>\n";
        echo htmlentities(json_encode($instance_array));
        echo "</script>\n";

        #
        # Ask the DB for the list of aggregates that do datasets.
        #
        $amlist = array();
        foreach (Aggregate::SupportsDatasetsList() as $aggregate) {
            $amlist[$aggregate->urn()] = $aggregate->nickname();
        }
	echo "<script type='text/plain' id='amlist-json'>\n";
	echo htmlentities(json_encode($amlist));
	echo "</script>\n";
    }
    
    # FS types.
    $fstypelist = array();
    $fstypelist["none"] = "none";
    $fstypelist["ext2"] = "ext2";
    $fstypelist["ext3"] = "ext3";
    $fstypelist["ext4"] = "ext4";
    $fstypelist["ufs"]  = "ufs";
    $fstypelist["ufs2"] = "ufs2";
    echo "<script type='text/plain' id='fstypes-json'>\n";
    echo htmlentities(json_encode($fstypelist));
    echo "</script>\n";

    echo "<link rel='stylesheet'
            href='css/jquery-ui.min.css'>\n";
    
    echo "<script type='text/javascript'>\n";
    echo "    window.AJAXURL  = 'server-ajax.php';\n";
    echo "    window.TITLE    = '$title';\n";
    echo "    window.EDITING  = false;\n";
    echo "    window.BUTTONLABEL = '$button_label';\n";
    echo "</script>\n";

    SPITREQUIRE_DATASET();
    AddTemplateList(array("create-dataset", "dataset-help", "oops-modal", "waitwait-modal"));
    SPITFOOTER();
}

#
# See what projects the user can do this in.
#
$projlist = $this_user->ProjectAccessList($TB_PROJECT_CREATEEXPT);

if (! isset($create)) {
    $errors   = array();
    $defaults = array();

    $defaults["dataset_type"]   = 'stdataset';
    $defaults["dataset_fstype"] = 'ext4';
    $defaults["dataset_read"]   = 'project';
    $defaults["dataset_modify"] = 'creator';
    $defaults["dataset_am"]     = '';
    # Default project.
    if (count($projlist) == 1) {
	list($project, $grouplist) = each($projlist);
	$defaults["dataset_pid"] = $project;
        reset($projlist);
    }

    SPITFORM($defaults, $errors);
    return;
}
SPITFORM($formfields, array());

?>
