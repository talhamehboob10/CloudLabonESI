<?php
#
# Copyright (c) 2006-2021 University of Utah and the Flux Group.
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
chdir("..");
include_once("node_defs.php");
chdir("apt");

# Set this variable when fetching health status of portal
# aggregates instead of using them.
$PORTAL_HEALTH = 0;

#
# This needs to go into the DB.
#
class Aggregate
{
    var	$aggregate;
    var $typeinfo;
    var $statusinfo;
    
    #
    # Constructor by lookup by urn
    #
    function Aggregate($urn) {
	$safe_urn = addslashes($urn);

	$query_result =
	    DBQueryWarn("select * from apt_aggregates where urn='$safe_urn'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->aggregate = null;
	    return;
	}
	$this->aggregate = mysql_fetch_array($query_result);
        $this->typeinfo  = array();

        #
        # Get the type info
        #
        $query_result =
            DBQueryWarn("select * from apt_aggregate_nodetypes ".
                        "where urn='$safe_urn'");
	while ($row = mysql_fetch_array($query_result)) {
	    $type = $row["type"];
            $this->typeinfo[$type] = array("count" => $row["count"],
                                           "free"  => $row["free"]);
        }

        #
        # And the status info.
        #
        $query_result =
            DBQueryWarn("select * from apt_aggregate_status ".
                        "where urn='$safe_urn'");
	if ($query_result || mysql_num_rows($query_result)) {
            $this->statusinfo = mysql_fetch_array($query_result);
        }
    }
    # accessors
    function field($name) {
	return (is_null($this->aggregate) ? -1 : $this->aggregate[$name]);
    }
    function name()	    { return $this->field('name'); }
    function nickname()	    { return $this->field('nickname'); }
    function urn()	    { return $this->field('urn'); }
    function abbreviation() { return $this->field('abbreviation'); }
    function ismobile()     { return $this->field('ismobile'); }
    function isFE()         { return $this->field('isFE'); }
    function disabled()     { return $this->field('disabled'); }
    function adminonly()    { return $this->field('adminonly'); }
    function has_datasets() { return $this->field('has_datasets'); }
    function reservations() { return $this->field('reservations'); }
    function nomonitor()    { return $this->field('nomonitor'); }
    function nolocalimages(){ return $this->field('nolocalimages'); }
    function prestageimages(){ return $this->field('prestageimages'); }
    function precalcmaxext(){ return $this->field('precalcmaxext'); }
    function portals()      { return $this->field('portals'); }
    function canuse_feature(){ return $this->field('canuse_feature'); }
    function latitude()      { return $this->field('latitude'); }
    function longitude()     { return $this->field('longitude'); }

    # accessors for the status info.
    function sfield($name) {
	return (is_null($this->statusinfo) ? null : $this->statusinfo[$name]);
    }
    function status()       { return $this->sfield('status'); }
    function last_success() { return $this->sfield('last_success'); }
    function last_attempt() { return $this->sfield('last_attempt'); }
    function pcount()       { return $this->sfield('pcount'); }
    function pfree()        { return $this->sfield('pfree'); }
    function vcount()       { return $this->sfield('vcount'); }
    function vfree()        { return $this->sfield('vfree'); }
    function last_error()   { return $this->sfield('last_error'); }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->aggregate);
    }

    # The weburl typically uses boss since that is the canonical name.
    # Lets change that to www instead. 
    function weburl() {
        $url = preg_replace("/boss\./i", "www.", $this->field('weburl'));
        return $url;
    }

    # Powder Portal, Emulab is not a "federate", all others are.
    function isfederate() {
        global $PORTAL_GENESIS;
        if ($PORTAL_GENESIS == "powder") {
            if ($this->nickname() == "Emulab") {
                return 0;
            }
            return 1;
        }
        return $this->field('isfederate');
    }

    # Lookup up by urn,
    function Lookup($urn) {
	$foo = new Aggregate($urn);

	if ($foo->IsValid()) {
	    return $foo;
	}	
	return null;
    }

    function LookupByNickname($nickname) {
	$safe_nickname = addslashes($nickname);

	$query_result =
            DBQueryWarn("select urn from apt_aggregates ".
                        "where nickname='$safe_nickname'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	$urn = $row['urn'];

        return Aggregate::Lookup($urn);
    }
    #
    # Lookup using the short auth name (emulab.net).
    #
    function LookupByDomain($domain) {
        if (! preg_match("/^[-\w\.]+$/", $domain)) {
            return null;
        }
        $query_result =
            DBQueryWarn("select urn from apt_aggregates ".
                        "where urn like 'urn:publicid:IDN+${domain}+%'");
	if (!$query_result || !mysql_num_rows($query_result)) {
            return null;
        }
	$row = mysql_fetch_array($query_result);
	$urn = $row['urn'];

        return Aggregate::Lookup($urn);
    }

    #
    # Generate the free nodes URL from the web url.
    #
    function FreeNodesURL() {
        return $this->weburl() . "/node_usage/freenodes.svg";
    }

    #
    # Return a list of aggregates supporting datasets.
    #
    function SupportsDatasetsList() {
        global $PORTAL_GENESIS;
	$result  = array();

	$query_result =
	    DBQueryFatal("select urn from apt_aggregates ".
			 "where has_datasets!=0 and disabled=0 and ".
                         "      FIND_IN_SET('$PORTAL_GENESIS', portals)");
        
	while ($row = mysql_fetch_array($query_result)) {
	    $urn = $row["urn"];

	    if (! ($aggregate = Aggregate::Lookup($urn))) {
		TBERROR("Aggregate::SupportsDatasetsList: ".
			"Could not load aggregate $urn!", 1);
	    }
            if ($aggregate->adminonly() && !(ISADMIN() || STUDLY())) {
                continue;
            }
            # Hack for Mike.
            if ($aggregate->nickname() == "APT" && !ISADMIN()) {
                continue;
            }
	    $result[] = $aggregate;
	}
        return $result;
    }

    #
    # Return a list of aggregates supporting reservations,
    #
    function SupportsReservations($user = null) {
	$ordered   = array();
        $unordered = array();
        global $PORTAL_GENESIS;

        $query_result =
            DBQueryFatal("select urn from apt_aggregates ".
                         "where disabled=0 and reservations=1 and ".
                         "      FIND_IN_SET('$PORTAL_GENESIS', portals) ".
                         ($PORTAL_GENESIS != "powder" ?
                          "order by isfederate,name" : "order by nickname"));
        
	while ($row = mysql_fetch_array($query_result)) {
	    $urn = $row["urn"];
            $allowed = 1;

	    if (! ($aggregate = Aggregate::Lookup($urn))) {
		TBERROR("Aggregate::SupportsReservations: ".
			"Could not load aggregate $urn!", 1);
	    }
            # Admins always see everything.
            if (ISADMIN()) {
                $allowed = 1;
            }
            elseif ($aggregate->adminonly() && !(ISADMIN() || STUDLY())) {
                $allowed = 0;
            }
            elseif ($user && $aggregate->canuse_feature()) {
                $allowed = 0;
                $feature = $PORTAL_GENESIS . "-" . $aggregate->canuse_feature();

                # Does the user have the feature?
                if (FeatureEnabled($feature, $user, null, null)) {
                    $allowed = 1;
                }
                else {
                    # If not, see if in a project that has it enabled.
                    $projects = $user->ProjectMembershipList();
                    foreach ($projects as $project) {
                        $approved = 0;
                        $group    = $project->DefaultGroup();
                        
                        if ($project->approved() &&
                            !$project->disabled() &&
                            # Must be approved in the project.
                            $project->IsMember($user, $approved) && $approved &&
                            FeatureEnabled($feature, null, $group, null)) {
                            $allowed = 1;
                            break;
                        }
                    }
                }
            }
            if ($allowed) {
                $ordered[] = $aggregate;
                $unordered[$aggregate->nickname()] = $aggregate;
            }
	}
        #
        # Ick, Powder ordering. Need a better way to deal with this.
        #
        if ($PORTAL_GENESIS == "powder") {
            $ordered = array();
            $ordered[] = $unordered["Emulab"];
            $ordered[] = $unordered["Utah"];
            foreach ($unordered as $aggregate) {
                if ($aggregate->nickname() != "Emulab" &&
                    $aggregate->nickname() != "Utah") {
                    $ordered[] = $aggregate;
                }
            }
        }
        return $ordered;
    }

    #
    # Return the list of allowed aggregates based on the portal in use.
    #
    function DefaultAggregateList($user = null, $frontpage = false) {
        global $PORTAL_GENESIS, $PORTAL_HEALTH, $TBMAINSITE;
	$am_array = array();

        if ($frontpage && $PORTAL_HEALTH) {
            $query_result =
                DBQueryFatal("select urn from apt_aggregates ".
                             "where disabled=0 and adminonly=0");
        
            while ($row = mysql_fetch_array($query_result)) {
                $urn = $row["urn"];

                if (! ($aggregate = Aggregate::Lookup($urn))) {
                    TBERROR("Aggregate::DefaultAggregateList: ".
                            "Could not load aggregate $urn!", 1);
                }
                $am_array[$urn] = $aggregate;
            }
            return $am_array;
        }
        $query_result =
            DBQueryFatal("select urn from apt_aggregates ".
                         "where disabled=0 and ".
                         "      FIND_IN_SET('$PORTAL_GENESIS', portals)");
        
	while ($row = mysql_fetch_array($query_result)) {
            $urn       = $row["urn"];
            $allowed   = 1;

	    if (! ($aggregate = Aggregate::Lookup($urn))) {
		TBERROR("Aggregate::DefaultAggregateList: ".
			"Could not load aggregate $urn!", 1);
	    }
            # Admins always see everything.
            if (ISADMIN()) {
                $allowed = 1;
            }
            # For the frontpage code, send everything.
            elseif ($frontpage || $PORTAL_HEALTH) {
                $allowed = 1;
            }
            elseif ($aggregate->adminonly() && !ISADMIN()) {
                $allowed = 0;
            }
            elseif ($user && $aggregate->canuse_feature()) {
                $allowed = 0;
                $feature = $PORTAL_GENESIS . "-" . $aggregate->canuse_feature();

                # Does the user have the feature?
                if (FeatureEnabled($feature, $user, null, null)) {
                    $allowed = 1;
                }
                else {
                    # If not, see if in a project that has it enabled.
                    $projects = $user->ProjectMembershipList();
                    foreach ($projects as $project) {
                        $approved = 0;
                        $group    = $project->DefaultGroup();
                        
                        if ($project->approved() &&
                            !$project->disabled() &&
                            # Must be approved in the project.
                            $project->IsMember($user, $approved) && $approved &&
                            FeatureEnabled($feature, null, $group, null)) {
                            $allowed = 1;
                            break;

                        }
                    }
                }
            }
            elseif ($user && $TBMAINSITE) {
                $project = Project::Lookup("OCTatMGHPCC");
                if ($project && $project->IsMember($user, $approved) &&
                    !$project->IsLeader($user)) {
                    if ($aggregate->nickname() == "Mass") {
                        $allowed = 1;
                    }
                    else {
                        $allowed = 0;
                    }
                }
            }
            if ($allowed) {
                $am_array[$urn] = $aggregate;
            }
        }
        return $am_array;
    }

    #
    # All aggregates
    #
    function AllAggregatesList() {
        $am_array = array();

        $query_result =
             DBQueryFatal("select urn from apt_aggregates");
        
	while ($row = mysql_fetch_array($query_result)) {
            $urn       = $row["urn"];
	    if (! ($aggregate = Aggregate::Lookup($urn))) {
		TBERROR("Aggregate::SupportsReservations: ".
			"Could not load aggregate $urn!", 1);
	    }
	    $am_array[$urn] = $aggregate;
        }
        return $am_array;
    }

    function ThisAggregate()
    {
        global $DEFAULT_AGGREGATE_URN;

        if (! ($aggregate = Aggregate::Lookup($DEFAULT_AGGREGATE_URN))) {
            TBERROR("Aggregate::SupportsReservations: ".
                    "Could not load aggregate $urn!", 1);
        }
        return $aggregate;
    }

    #
    # List of types available at this aggregate. For now we just want
    # the type names.
    #
    function TypeList()
    {
        $result = array();

        foreach ($this->typeinfo as $type => $info) {
            $result[$type] = $type;
        }
        return $result;
    }

    #
    # Array of type attributes for the specified type.
    #
    function TypeAttributes($type)
    {
        $result = array();
        $urn    = $this->urn();

        $query_result =
            DBQueryFatal("select attrkey,attrvalue from ".
                         "  apt_aggregate_nodetype_attributes ".
                         "where type='$type' and urn='$urn'");

        if (!mysql_num_rows($query_result)) {
            return null;
        }
        while ($row = mysql_fetch_array($query_result)) {
            $result[$row["attrkey"]] = $row["attrvalue"];
        }
        return $result;
    }

    #
    # Reservable nodes.
    #
    function ReservableNodes($extended = 0)
    {
        $result = array();
        $urn    = $this->urn();

        $query_result =
            DBQueryFatal("select * from ".
                         "  apt_aggregate_reservable_nodes ".
                         "where urn='$urn'");

        if (!mysql_num_rows($query_result)) {
            return null;
        }
        while ($row = mysql_fetch_array($query_result)) {
            if ($extended) {
                $blob = array("urn"       => $row["urn"],
                              "type"      => $row["type"],
                              "updated"   => DateStringGMT($row["updated"]),
                              "available" => intval($row["available"]));
                $result[$row["node_id"]] = $blob;
            }
            else {
                $result[$row["node_id"]] = $row["type"];
            }
        }
        return $result;
    }

    #
    # Radio types. Eventually need to get this from the advertisement.
    # For now all clusters have the same set of radiotypes.
    #
    function RadioTypes()
    {
        #
        # Return this for all Portals, at the moment the JS
        # code decides if it needs it for the current portal.
        #
        if ($this->nickname() == "Emulab") {
            return array("iris030" => true,
                         "nexus5"  => true,
                         "nuc5300" => true,
                         "enodeb"  => true,
                         "x310"    => true,
                         "n310"    => true,
                         "sdr"     => true,
                         "faros_sfp" => true);
        }
        return null;
    }

    # Class method.
    function RadioInfo()
    {
        $blob = array();

        $query_result =
            DBQueryFatal("select i.*,r.available from ".
                         "  apt_aggregate_radioinfo as i ".
                         "join apt_aggregate_reservable_nodes as r on ".
                         "  r.urn=i.aggregate_urn and r.node_id=i.node_id");

        while ($row = mysql_fetch_array($query_result)) {
            $urn      = $row["aggregate_urn"];
            $node_id  = $row["node_id"];
            $alive    = true;

            #
            # Grab the aggregate. We use the status info to determine if the
            # aggregate is alive (reachable).
            #
            if ($aggregate = Aggregate::Lookup($urn)) {
                if (!array_key_exists($urn, $blob)) {
                    $blob[$urn] = array();
                }
                if ($row["installation_type"] == "BS") {
                    #
                    # The CNUC determines if a base station is alive.
                    #
                    $cnuc = Node::Lookup($row["cnuc_id"]);
                    if ($cnuc && $cnuc->RealNodeStatus() != "up") {
                        $alive = false;
                    }
                }
                elseif ($aggregate->status() != "up" || $aggregate->disabled()){
                    $alive = false;
                }
                $row["alive"] = $alive;
                $row["reachable"] = $alive;
                $blob[$urn][$node_id] = $row;
            }
        }
        return $blob;
    }
    function RadioInfoNew()
    {
        $blob = array();

        $query_result =
            DBQueryFatal("select *,r.available ".
                         " from apt_aggregate_radio_locations as l ".
                         "left join apt_aggregate_radio_info as i on ".
                         "  i.aggregate_urn=l.aggregate_urn and ".
                         "  i.location=l.location ".
                         "join apt_aggregate_reservable_nodes as r on ".
                         "  r.urn=i.aggregate_urn and r.node_id=i.node_id ".
                         "order by itype desc, l.location asc");

        while ($row = mysql_fetch_array($query_result)) {
            $urn      = $row["aggregate_urn"];
            $node_id  = $row["node_id"];
            $alive    = true;

            #
            # Grab the aggregate. We use the status info to determine if the
            # aggregate is alive (reachable).
            #
            if ($aggregate = Aggregate::Lookup($urn)) {
                if (!array_key_exists($urn, $blob)) {
                    $blob[$urn] = array();
                }
                # Backwards compat for the frontpage.
                $row["installation_type"] = $row["itype"];
                
                if ($row["itype"] == "BS") {
                    #
                    # The CNUC determines if a base station is alive.
                    #
                    $cnuc = Node::Lookup($row["cnuc_id"]);
                    if ($cnuc && $cnuc->RealNodeStatus() != "up") {
                        $alive = false;
                    }
                }
                elseif ($aggregate->status() != "up" || $aggregate->disabled()){
                    $alive = false;
                }
                $row["alive"]     = $alive;
                $row["reachable"] = $alive;
                $row["frontends"] = array();

                #
                # Grab the frontend info for the radio.
                #
                $frontend_result =
                    DBQueryFatal("select * from apt_aggregate_radio_frontends ".
                                 "where aggregate_urn='$urn' and ".
                                 "      node_id='$node_id'");
                while ($frow = mysql_fetch_array($frontend_result)) {
                    #
                    # At the moment iface/frontend is one-to-one. I guess
                    # there is a future plan to be able to switch between
                    # multiple frontends on the same TX channel but not
                    # going to worry about that now.
                    #
                    #
                    # If no frontend notes, use the radio notes
                    #
                    if (!$frow["notes"]) {
                        $frow["notes"] = $row["notes"];
                    }
                    $iface = $frow["iface"];
                    $row["frontends"][$iface] = $frow;
                }
                $blob[$urn][$node_id] = $row;
            }
        }
        return $blob;
    }

    # Class method to get info about Phantomnet matrix nodes. 
    function MatrixInfo()
    {
        $blob = array();

        $query_result =
            DBQueryFatal("select f.node_id,w1.node_id2,w2.node_id1 ".
                         "  from node_features as f ".
                         "left join nodes as n on n.node_id=f.node_id ".
                         "left join wires as w1 on ".
                         "   w1.node_id1=f.node_id and ".
                         "   w1.external_wire is not null ".
                         "left join wires as w2 on ".
                         "   w2.node_id2=f.node_id and ".
                         "   w2.external_wire is not null ".
                         "where f.feature='rf-controlled' and ".
                         "      n.node_id is not null");

        if (!mysql_num_rows($query_result)) {
            return $blob;
        }
        while ($row = mysql_fetch_array($query_result)) {
            $node_id  = $row["node_id"];
            $node_id1 = $row["node_id1"];
            $node_id2 = $row["node_id2"];

            if (!array_key_exists($node_id, $blob)) {
                $blob[$node_id] = array("node_id" => $node_id,
                                        "wires"   => array());
            }
            if ($node_id1) {
                $blob[$node_id]["wires"][] = $node_id1;
            }
            else {
                $blob[$node_id]["wires"][] = $node_id2;
            }
        }
        return $blob;
    }
}

#
# We use this in a lot of places, so build it all the time.
#
$urn_mapping = array();

$query_result =
    DBQueryFatal("select urn,abbreviation from apt_aggregates");
while ($row = mysql_fetch_array($query_result)) {
    $urn_mapping[$row["urn"]] = $row["abbreviation"];
}

?>
