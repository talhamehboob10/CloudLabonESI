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
include("lease_defs.php");
include("imageid_defs.php");
chdir("apt");
include("quickvm_sup.php");
include_once("dataset_defs.php");
include_once("instance_defs.php");
include_once("profile_defs.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Show Dataset";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();
$this_uid  = $this_user->uid();
$isadmin   = (ISADMIN() ? 1 : 0);

#
# Verify page arguments.
#
$optargs = RequiredPageArguments("uuid", PAGEARG_UUID);

#
# Either a local lease or a remote dataset. 
#
if (!$embedded) {
    $dataset = Dataset::Lookup($uuid);
}
if (!$dataset) {
    $dataset = Lease::Lookup($uuid);
    if (!$dataset) {
        $dataset = ImageDataset::Lookup($uuid);
    }
}
if (!$dataset) {
    SPITUSERERROR("No such dataset!");
}
if (!$dataset->AccessCheck($this_user, $LEASE_ACCESS_READINFO)) {
    SPITUSERERROR("Not enough permission!");
}
$candelete  = (ISADMIN() ||
               $dataset->AccessCheck($this_user,
                                     $LEASE_ACCESS_DESTROY) ? 1 : 0);

# An admin can approve an unapproved lease.
$canapprove = ((ISADMIN() && !$dataset->locked() &&
                $dataset->state() == "unapproved") ? 1 : 0);

# Remote datasets can be refreshed.
$canrefresh = ($dataset->islocal() ? 0 : 1);

# Can an image backed dataset be updated.
$cansnapshot = ($dataset->type() == "imdataset" &&
                (ISADMIN() ||
                 $dataset->AccessCheck($this_user,
                                       $LEASE_ACCESS_MODIFY)) ? 1 : 0);

$fields = array();
if ($dataset->type() == "stdataset") {
    $fields["dataset_type_string"] = "short term";
}
elseif ($dataset->type() == "ltdataset") {
    $fields["dataset_type_string"] = "long term";
}
elseif ($dataset->type() == "imdataset") {
    $fields["dataset_type_string"] = "image backed";
}
$fields["dataset_type"]     = $dataset->type();
$fields["dataset_creator"]  = $dataset->owner_uid();
$fields["dataset_pid"]      = $dataset->pid();
$fields["dataset_gid"]      = $dataset->gid();
$fields["dataset_name"]     = $dataset->id();
$fields["dataset_size"]     = $dataset->size() ? $dataset->size() : "0";
$fields["dataset_fstype"]   = ($dataset->fstype() ?
			       $dataset->fstype() : "none");
$fields["dataset_created"]  = DateStringGMT($dataset->created());
$fields["dataset_updated"]  = ($dataset->updated() ?
			       DateStringGMT($dataset->updated()) : "");
$fields["dataset_expires"]  = ($dataset->expires() ?
			       DateStringGMT($dataset->expires()) : "");
$fields["dataset_lastused"] = ($dataset->last_used() ?
			       DateStringGMT($dataset->last_used()) : "");
$fields["dataset_uuid"]     = $uuid;
$fields["dataset_urn"]      = $dataset->URN();
$fields["dataset_read"]     = $dataset->read_access();
$fields["dataset_write"]    = $dataset->write_access();
if (ISADMIN()) {
    $fields["dataset_idx"]  = $dataset->idx();
}
if ($dataset->type() == "imdataset") {
    $fields["dataset_url"]  = $dataset->URL();
}

#
# The state is a bit of a problem, since local leases do not have
# an "allocating" state. For a remote dataset, we get set to busy.
# Need to unify this. But the main point is that we want to tell
# the user that the dataset is busy allocation.
#
if ($dataset->state() == "busy" ||
    ($dataset->state() == "unapproved" && $dataset->locked())) {
    $fields["dataset_state"] = "allocating";
}
else {
    $fields["dataset_state"] = $dataset->state();
}
SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

echo "<script type='text/plain' id='fields-json'>\n";
echo htmlentities(json_encode($fields)) . "\n";
echo "</script>\n";

#
# Instance list for image backed dataset.
#
if ($cansnapshot && !$embedded) {
    $query_result =
        DBQueryFatal("select uuid from apt_instances as a ".
                     "where creator_idx='$this_idx'");
    $instance_array = array();

    while ($row = mysql_fetch_array($query_result)) {
        $instance     = Instance::Lookup($row["uuid"]);
        $profile      = Profile::Lookup($instance->profile_id(),
                                        $instance->profile_version());
        if ($instance && $profile) {
            $instance_array[] =
                array("uuid" => $instance->uuid(),
                      "name" => $instance->name());
        }
    }
    echo "<script type='text/plain' id='instances-json'>\n";
    echo htmlentities(json_encode($instance_array));
    echo "</script>\n";
}

echo "<script type='text/javascript'>\n";
echo "    window.TITLE      = '$page_title';\n";
echo "    window.UUID       = '$uuid';\n";
echo "    window.CANDELETE  = $candelete;\n";
echo "    window.CANAPPROVE = $canapprove;\n";
echo "    window.CANREFRESH = $canrefresh;\n";
echo "    window.CANSNAPSHOT= $cansnapshot;\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_APTFORMS();
REQUIRE_IMAGE();
SPITREQUIRE("js/show-dataset.js",
            "<script src='js/lib/jquery-ui.js'></script>\n");            
# For progress bubbles in the imaging modal.
echo "<link rel='stylesheet' href='css/progress.css'>\n";
echo "<link rel='stylesheet' href='css/codemirror.css'>\n";

AddTemplateList(array("show-dataset", "snapshot-dataset", "oops-modal", "waitwait-modal"));
SPITFOOTER();

?>
