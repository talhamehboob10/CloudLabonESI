<?php
#
# Copyright (c) 2000- 2020 University of Utah and the Flux Group.
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
include("lease_defs.php");
include("imageid_defs.php");
chdir("apt");
include("quickvm_sup.php");
include_once("dataset_defs.php");
include_once("instance_defs.php");
include_once("profile_defs.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Modify Dataset";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();

#
# Verify page arguments.
#
$optargs = RequiredPageArguments("uuid",        PAGEARG_UUID);
$optargs = OptionalPageArguments("create",      PAGEARG_STRING,
				 "formfields",  PAGEARG_ARRAY);

#
# Either a local lease or a remote dataset. 
#
if ($embedded) {
    $dataset = Lease::Lookup($uuid);
    if (!$dataset) {
        $dataset = ImageDataset::Lookup($uuid);
    }
}
else {
    $dataset = Dataset::Lookup($uuid);
    if (!$dataset) {
        $dataset = Lease::Lookup($uuid);
        if (!$dataset) {
            $dataset = ImageDataset::Lookup($uuid);
        }
    }
}
if (!$dataset) {
    SPITUSERERROR("No such dataset!");
}
if (!$dataset->AccessCheck($this_user, $LEASE_ACCESS_MODIFYINFO)) {
    SPITUSERERROR("Not enough permission!");
}

#
# Spit the form
#
function SPITFORM($formfields, $errors)
{
    global $this_user, $projlist, $embedded, $this_idx;
    $button_label = "Save";
    $title        = "Modify Dataset";
    $isadmin      = (ISADMIN() ? "true" : "false");

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

    if (!$embedded || $dataset->islocal()) {
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
                array("uuid" => $uuid, "name" => $profile->name());
        }
        echo "<script type='text/plain' id='instances-json'>\n";
        echo htmlentities(json_encode($instance_array));
        echo "</script>\n";
    }
    
    echo "<link rel='stylesheet'
            href='css/jquery-ui.min.css'>\n";
    
    echo "<script type='text/javascript'>\n";
    echo "    window.AJAXURL  = 'server-ajax.php';\n";
    echo "    window.TITLE    = '$title';\n";
    echo "    window.EDITING  = true;\n";
    echo "    window.ISADMIN  = $isadmin;\n";
    echo "    window.BUTTONLABEL = '$button_label';\n";
    echo "</script>\n";

    SPITREQUIRE_DATASET();
    AddTemplateList(array("create-dataset", "dataset-help", "oops-modal", "waitwait-modal"));
    SPITFOOTER();
}

if (! isset($create)) {
    $errors   = array();
    $fields   = array();

    $fields["dataset_type"]     = $dataset->type();
    $fields["dataset_pid"]      = $dataset->pid();
    $fields["dataset_gid"]      = $dataset->gid();
    $fields["dataset_name"]     = $dataset->id();
    $fields["dataset_size"]     = $dataset->size() . "MiB";
    $fields["dataset_fstype"]   = ($dataset->fstype() ?
				   $dataset->fstype() : "none");
    $fields["dataset_expires"]  = ($dataset->expires() ?
				   DateStringGMT($dataset->expires()) : "");
    $fields["dataset_uuid"]     = $uuid;
    $fields["dataset_read"]     = $dataset->read_access();
    $fields["dataset_modify"]   = $dataset->write_access();

    SPITFORM($fields, $errors);
    return;
}
SPITFORM($formfields, array());

?>
