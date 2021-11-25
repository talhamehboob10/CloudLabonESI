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
include_once("geni_defs.php");
chdir("apt");
include("quickvm_sup.php");
include_once("instance_defs.php");
include_once("aggregate_defs.php");
include_once("resgroup_defs.php");
$page_title = "Reservations";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
if (NOPROJECTMEMBERSHIP()) {
    return NoProjectMembershipError($this_user);
}
$isadmin   = (ISADMIN() ? 1 : 0);
$isfadmin  = (ISFOREIGN_ADMIN() ? 1 : 0);

#
# Verify page arguments. Cluster is a domain that we turn into a URN.
#
$optargs = OptionalPageArguments("edit",     PAGEARG_BOOLEAN,
                                 "debug",    PAGEARG_BOOLEAN,
                                 "cluster",  PAGEARG_STRING,
                                 "project",  PAGEARG_PROJECT,
                                 "uuid",     PAGEARG_UUID,
                                 "force",    PAGEARG_BOOLEAN);

if ($edit) {
    if (! (isset($cluster) && isset($uuid))) {
        SPITUSERERROR("Missing arguments for edit mode");
        exit();
    }
    #
    # Check to see if this reservation is part of a reservation group. Mere
    # users no longer get access to this interface.
    #
    if (!$force) {
        $resgroup = ReservationGroup::LookupByMemberReservation($uuid);
        if ($resgroup) {
            header("Location: resgroup.php?edit=1&uuid=" . $resgroup->uuid());
            exit();
        }
    }
}
if (!$force || !($isadmin || $this_user->admin() || $this_user->stud())) {
    header("Location: resgroup.php");
    exit();
}
if (isset($cluster)) {
    $aggregate = Aggregate::LookupByNickname($cluster);
    if (!$aggregate) {
        SPITUSERERROR("No such cluster: $cluster");
        exit();
    }
}

SPITHEADER(1);

echo "<link rel='stylesheet'
            href='css/jquery-ui.min.css'>\n";
echo "<link rel='stylesheet'
            href='css/nv.d3.css'>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

# Place to hang the modals for now
echo "<div id='oops_div'></div>
      <div id='waitwait_div'></div>\n";

#
# See what projects the user can do this in.
#
$projlist = $this_user->ProjectAccessList($TB_PROJECT_CREATEEXPT);

#
# Pass project list through. Need to convert to list without groups.
# When editing, pass through a single value. The template treats a
# a single value as a read-only field.
#
$plist = array();
while (list($p) = each($projlist)) {
    $plist[] = $p;
}
if (ISADMIN() && isset($project)) {
    $plist[] = $project->pid();
}
echo "<script type='text/plain' id='projects-json'>\n";
echo htmlentities(json_encode($plist));
echo "</script>\n";

# List of clusters.
if ($edit || isset($aggregate)) {
    $ams = array($aggregate);
}
elseif (isset($debug) && $debug) {
    $ams = array(Aggregate::ThisAggregate());
}
else {
    $ams = Aggregate::SupportsReservations($this_user);
}
if (!count($ams)) {
    SPITUSERERROR("No clusters support reservations.");
    exit();
}
$amlist  = array();
while (list($index, $aggregate) = each($ams)) {
    $urn = $aggregate->urn();
    $am  = $aggregate->name();
    $reservable_nodes = $aggregate->ReservableNodes();
    $typeinfo = $aggregate->typeinfo;

    # Subtract out reservable nodes from the type count, do not want
    # to confuse users. 
    if ($reservable_nodes) {
        foreach ($reservable_nodes as $node_id => $type) {
            # There will not be a type extry if its zero (all nodes of
            # that type are "reservable nodes")
            if (array_key_exists($type, $typeinfo)) {
                $count = $typeinfo[$type]["count"];
                $typeinfo[$type]["count"] = $count - 1;
            }
        }
    }

    $amlist[$urn] = array("urn"      => $urn,
                          "name"     => $am,
                          "nickname" => $aggregate->nickname(),
                          "typeinfo" => $typeinfo,
                          "reservable_nodes" => $reservable_nodes);
}
echo "<script type='text/plain' id='amlist-json'>\n";
echo htmlentities(json_encode($amlist));
echo "</script>\n";

$defaults = array();
$defaults["pid"]   = '';
# Default project.
if (ISADMIN() && isset($project)) {
    $defaults["pid"]   = $project->pid();
}
elseif (count($plist) == 1) {
    $defaults["pid"] = $plist[0];
}
echo "<script type='text/plain' id='form-json'>\n";
echo htmlentities(json_encode($defaults)) . "\n";
echo "</script>\n";

echo "<script type='text/javascript'>\n";
if ($edit) {
    echo "   window.EDITING  = true;\n";
    echo "   window.CLUSTER  = '$cluster';\n";
    echo "   window.ISADMIN  = $isadmin;\n";
    echo "   window.UUID     = '$uuid';\n";
}
else {
    echo "   window.EDITING  = false;\n";
}
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_APTFORMS();
REQUIRE_TABLESORTER();
AddLibrary("js/resgraphs.js");
AddTemplateList(array("reserve-request", "reserve-faq", "reservation-graph",
                      "oops-modal", "waitwait-modal", "confirm-modal",
                      "resusage-graph"));
SPITREQUIRE("js/reserve.js",
            "<script src='js/lib/d3.v3.js'></script>\n".
            "<script src='js/lib/nv.d3.js'></script>\n".
            "<script src='js/lib/jquery-ui.js'></script>");
SPITFOOTER();
?>
