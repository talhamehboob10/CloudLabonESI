<?php
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
$page_title = "Reservation Group";

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
$isstud    = (STUDLY() ? 1 : 0);

#
# Verify page arguments. Cluster is a domain that we turn into a URN.
#
$optargs = OptionalPageArguments("edit",     PAGEARG_BOOLEAN,
                                 "debug",    PAGEARG_BOOLEAN,
                                 "cluster",  PAGEARG_STRING,
                                 "project",  PAGEARG_PROJECT,
                                 "fromrspec",PAGEARG_BOOLEAN,
                                 "uuid",     PAGEARG_UUID);
if (!isset($fromrspec)) {
    $fromrspec = 0;
}

if ($edit) {
    if (!isset($uuid)) {
        SPITUSERERROR("Missing arguments for edit mode");
        exit();
    }
    if (!($resgroup = ReservationGroup::Lookup($uuid))) {
        SPITUSERERROR("No such reservation group");
        exit();
    }
    if (! (ISADMIN() ||
           $this_user->idx() == $resgroup->creator_idx() ||
           $resgroup->Project()->UserTrust($this_user) >=
           $TBDB_TRUST_GROUPROOT)) {
        SPITUSERERROR("Not enough permission");
        exit();
    }
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
echo "<link rel='stylesheet'
            href='https://fonts.googleapis.com/css?family=Muli'>\n";
echo "<link rel='stylesheet'
            href='css/visavail.css'>\n";
echo "<link rel='stylesheet'
            href='https://use.fontawesome.com/releases/v5.0.12/css/all.css'>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

# Place to hang the modals for now
echo "<div id='oops_div'></div>
      <div id='confirm_div'></div>
      <div id='waitwait_div'></div>\n";

# Reservations now have to start next business day at 9am (unless expert).
$bisdaysonly = $this_user->expert_mode() ? 0 : 1;
# Ditto
$routesokay  = $isadmin;

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
    if (!$isadmin) {
        $ptmp = Project::LookupByPid($p);
        if ($ptmp && $ptmp->expert_mode()) {
            $bisdaysonly = 0;
        }
    }
    if ($ISPOWDER && !$isadmin) {
        if ($ptmp && FeatureEnabled("powder-routes-allowed", null, $ptmp)) {
            $routesokay = 1;
        }
    }
}
echo "<script type='text/plain' id='projects-json'>\n";
echo htmlentities(json_encode($plist));
echo "</script>\n";

# List of clusters.

if (isset($aggregate)) {
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

    # Lets not show mobile nodes on this page.
    if ($aggregate->ismobile()) {
        continue;
    }
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
    #
    # Each cluster should have its own set of types to skip depending
    # on the Portal and the phases of the moon, but that is not what
    # we got. 
    #
    $prunelist = Instance::NodeTypePruneList($aggregate);
    
    $amlist[$urn] = array("urn"      => $urn,
                          "name"     => $am,
                          "nickname" => $aggregate->nickname(),
                          "typeinfo" => $typeinfo,
                          "prunelist"=> $prunelist,
                          "radiotypes"       => $aggregate->RadioTypes(),
                          "abbreviation"     => $aggregate->nickname(),
                          "reservable_nodes" => $reservable_nodes,
                          "isME"             => $aggregate->ismobile(),
                          "isFE"             => $aggregate->isFE());
                          
}
echo "<script type='text/plain' id='amlist-json'>\n";
echo htmlentities(json_encode($amlist, JSON_NUMERIC_CHECK));
echo "</script>\n";
if ($ISPOWDER) {
    $radioinfo = Aggregate::RadioInfoNew();
    echo "<script type='text/plain' id='radioinfo-json'>\n";
    echo htmlentities(json_encode($radioinfo, JSON_NUMERIC_CHECK));
    echo "</script>\n";
    $matrixinfo = Aggregate::MatrixInfo();
    echo "<script type='text/plain' id='matrixinfo-json'>\n";
    echo htmlentities(json_encode($matrixinfo, JSON_NUMERIC_CHECK));
    echo "</script>\n";

    # Spit out the route list.
    $query_result =
        DBQueryFatal("select * from apt_mobile_bus_routes");
    $routelist = array();
    while ($row = mysql_fetch_array($query_result)) {
        $routename = $row["description"];
        $routeid   = $row["routeid"];
        $routelist[$routename] = array(
            "routename" => $routename,
            "routeid"   => $routeid,
        );
    }
    echo "<script type='text/plain' id='routelist-json'>\n";
    echo htmlentities(json_encode($routelist, JSON_NUMERIC_CHECK));
    echo "</script>\n";
}

$default_pid = "";
# Default project.
if (isset($project)) {
    $default_pid = $project->pid();
}
elseif (count($plist) == 1) {
    $default_pid = $plist[0];
}
echo "<script type='text/javascript'>\n";
if ($edit) {
    echo "   window.EDITING  = true;\n";
    echo "   window.UUID     = '$uuid';\n";
    echo "   window.ISGROUP  = true;\n";
}
else {
    echo "   window.EDITING  = false;\n";
    echo "   window.PID      = '$default_pid';\n";
    echo "   window.FROMRSPEC= $fromrspec;\n";
}
echo "   window.ISADMIN  = $isadmin;\n";
echo "   window.ISSTUD   = $isstud;\n";
echo "   window.HOMETZ   = '$OURTIMEZONE';\n";
echo "   window.BISONLY  = $bisdaysonly;\n";
echo "   window.DOROUTES = $routesokay;\n";

echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_MOMENTTIMEZONE();
REQUIRE_APTFORMS();
REQUIRE_TABLESORTER();
AddLibrary("js/resgraphs.js");
AddTemplateList(array("resgroup", "reserve-faq", "reservation-graph",
                      "range-list", "route-list",
                      "oops-modal", "waitwait-modal", "confirm-modal",
                      "resusage-list", "resusage-graph",
                      "confirm-something", "resusage-graph", "visavail-graph"));
SPITREQUIRE("js/resgroup.js",
            "<script src='js/lib/d3.v3.js'></script>\n".
            "<script src='js/lib/d3.v5.js'></script>\n".
            "<script src='js/lib/nv.d3.js'></script>\n".
            "<script src='js/lib/visavail.js'></script>\n".
            "<script src='js/lib/jquery-ui.js'></script>");
SPITFOOTER();
?>
