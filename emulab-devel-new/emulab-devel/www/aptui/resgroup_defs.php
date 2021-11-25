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
include_once("aggregate_defs.php");

#
# Reservation Groups
#
class ReservationGroup
{
    var	$resgroup;
    var $reservations;
    var $rfreservations;
    var $routereservations;
    
    #
    # Constructor by lookup by urn
    #
    function ReservationGroup($uuid) {
	$safe_uuid = addslashes($uuid);

	$query_result =
	    DBQueryWarn("select * from apt_reservation_groups ".
                        "where uuid='$safe_uuid'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->resgroup = null;
	    return;
	}
	$this->resgroup     = mysql_fetch_array($query_result);
        $this->reservations =
            ReservationGroupReservation::LookupForGroup($this);
        $this->rfreservations =
            ReservationGroupRFReservation::LookupForGroup($this);
        $this->routereservations =
            ReservationGroupRouteReservation::LookupForGroup($this);
    }
    # accessors
    function reservations()   { return $this->reservations; }
    function rfreservations() { return $this->rfreservations; }
    function routereservations() { return $this->routereservations; }
    function field($name) {
	return (is_null($this->resgroup) ? -1 : $this->resgroup[$name]);
    }
    function uuid()	    { return $this->field('uuid'); }
    function pid()	    { return $this->field('pid'); }
    function pid_idx()      { return $this->field('pid_idx'); }
    function creator_uid()  { return $this->field('creator_uid'); }
    function creator_idx()  { return $this->field('creator_idx'); }
    function start()        { return $this->field('start'); }
    function end()          { return $this->field('end'); }
    function created()      { return $this->field('created'); }
    function deleted()      { return $this->field('deleted'); }
    function locked()       { return $this->field('locked'); }
    function locker_pid()   { return $this->field('locker_pid'); }
    function reason()       { return $this->field('reason'); }
    function noidledetection() { return $this->field('noidledetection'); }

    # Project of resgroup.
    function Project() {
        return Project::Lookup($this->pid_idx());
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->resgroup);
    }

    # Lookup up by uuid,
    function Lookup($uuid) {
	$foo = new ReservationGroup($uuid);

	if ($foo->IsValid()) {
	    return $foo;
	}	
	return null;
    }

    # Lookup for a user.
    function LookupForUser($user)
    {
        $uid_idx = $user->uid_idx();
        $result = array();
        
        $query_result = DBQueryFatal("select uuid from apt_reservation_groups ".
                                     "where creator_idx='$uid_idx'");
	while ($row = mysql_fetch_array($query_result)) {
            $reservation = ReservationGroup::Lookup($row["uuid"]);
            if ($reservation) {
                $result[] = $reservation;
            }
        }
        return $result;
    }

    # Lookup for a project.
    function LookupForProject($project)
    {
        $pid_idx = $project->pid_idx();
        $result = array();
        
        $query_result = DBQueryFatal("select uuid from apt_reservation_groups ".
                                     "where pid_idx='$pid_idx'");
	while ($row = mysql_fetch_array($query_result)) {
            $reservation = ReservationGroup::Lookup($row["uuid"]);
            if ($reservation) {
                $result[] = $reservation;
            }
        }
        return $result;
    }

    # Lookup all (admin)
    function LookupAll()
    {
        $result = array();
        
        $query_result = DBQueryFatal("select uuid from apt_reservation_groups");
	while ($row = mysql_fetch_array($query_result)) {
            $reservation = ReservationGroup::Lookup($row["uuid"]);
            if ($reservation) {
                $result[] = $reservation;
            }
        }
        return $result;
    }

    #
    # Lookup group by a member of the group
    #
    function LookupByMemberReservation($remote_uuid)
    {
        $safe_uuid = addslashes($remote_uuid);
        
	$query_result =
	    DBQueryFatal("select uuid from apt_reservation_group_reservations ".
                         "where remote_uuid='$safe_uuid'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
        return ReservationGroup::Lookup($row["uuid"]);
    }

    #
    # Convert reservations to a list of aggregates.
    #
    function AggregateList()
    {
        $uuid   = $this->uuid();
        $result = array();
        $query_result =
            DBQueryFatal("select distinct aggregate_urn ".
                         "  from apt_reservation_group_reservations ".
                         "where uuid='$uuid'");

	while ($row = mysql_fetch_array($query_result)) {
            $aggregate = Aggregate::Lookup($row["aggregate_urn"]);
            if ($aggregate) {
                $result[] = $aggregate;
            }
        }
        return $result;
    }

    # Find specific reservation.
    function Reservation($uuid) {
        foreach ($this->reservations() as $reservation) {
            if ($reservation->remote_uuid() == $uuid) {
                return $reservation;
            }
        }
        foreach ($this->rfreservations() as $reservation) {
            if ($reservation->freq_uuid() == $uuid) {
                return $reservation;
            }
        }
        foreach ($this->routereservations() as $reservation) {
            if ($reservation->route_uuid() == $uuid) {
                return $reservation;
            }
        }
        return null;
    }

    # Are any of the reservation approved
    function PartiallyApproved()
    {
        foreach ($this->reservations() as $reservation) {
            if ($reservation->approved()) {
                return 1;
            }
        }
        foreach ($this->rfreservations() as $reservation) {
            if ($reservation->approved()) {
                return 1;
            }
        }
        foreach ($this->routereservations() as $reservation) {
            if ($reservation->approved()) {
                return 1;
            }
        }
        return 0;
    }

    function Active()
    {
        $start = strtotime($this->start());
        $end   = strtotime($this->end());
        
        if (time() > $start && time() < $end) {
            return 1;
        }
        return 0;
    }

    function Blob()
    {
        $resgroup = $this;
        $details  = array();
        # Compute a status column based on reservations.
        $status   = "approved";
        $project  = Project::Lookup($resgroup->pid_idx());
    
        $details["uuid"]       = $resgroup->uuid();
        $details["pid"]        = $resgroup->pid();
        $details["pid_idx"]    = $resgroup->pid_idx();
        $details["notes"]      = $resgroup->reason();
        $details["created"]    = DateStringGMT($resgroup->created());
        $details["start"]      = DateStringGMT($resgroup->start());
        $details["end"]        = DateStringGMT($resgroup->end());
        $details["approved"]   = 0;
        $details["pending"]    = 0;
        $details["canceled"]   = 0;
        $details["uid"]        = $resgroup->creator_uid();
        $details["uid_idx"]    = $resgroup->creator_idx();
        $details["idledetection"] = $resgroup->noidledetection() ? false : true;
        $details["portal"]     = ($project->portal() ?
                                  $project->portal() : "emulab");
        $clusters = array();
        foreach ($resgroup->reservations() as $reservation) {
            $blob = array(
                "type"        => $reservation->type(),
                "count"       => intval($reservation->count()),
                "cluster_id"  => $reservation->Aggregate()->nickname(),
                "cluster_urn" => $reservation->Aggregate()->urn(),
                "remote_uuid" => $reservation->remote_uuid(),
                "submitted"   => DateStringGMT($reservation->submitted()),
                "approved"    => DateStringGMT($reservation->approved()),
                "canceled"    => DateStringGMT($reservation->canceled()),
                "deleted"     => DateStringGMT($reservation->deleted()),
                "jsondata"    => $reservation->jsondata(),
                "using"       => null,
                "utilization" => null,
                "approved_pushed" => DateStringGMT(
                    $reservation->approved_pushed()),
                "canceled_pushed" => DateStringGMT(
                    $reservation->canceled_pushed()),
                "cancel_canceled" => DateStringGMT(
                    $reservation->cancel_canceled()),
                "deleted_pushed"  => DateStringGMT(
                    $reservation->deleted_pushed())
            );
            if (!is_null($reservation->using())) {
                $blob["using"] = intval($reservation->using());
            }
            if (!is_null($reservation->utilization())) {
                $blob["utilization"] = intval($reservation->utilization());
            }
            if (time() > strtotime($resgroup->start()) &&
                $reservation->approved()) {
                $blob["active"] = true;
            }
            else {
                $blob["active"] = false;
            }
            $clusters[$reservation->remote_uuid()] = $blob;

            if (! $reservation->approved()) {
                $status = "pending";
                $details["pending"] += 1;
            }
            elseif ($reservation->canceled()) {
                $status = "canceled";
                $details["canceled"] += 1;
            }
            elseif ($reservation->approved()) {
                $details["approved"] += 1;
            }
        }
        $ranges = array();
        foreach ($resgroup->rfreservations() as $reservation) {
            $blob = array(
                "freq_uuid"   => $reservation->freq_uuid(),
                "freq_low"    => $reservation->freq_low(),
                "freq_high"   => $reservation->freq_high(),
                "submitted"   => DateStringGMT($reservation->submitted()),
                "approved"    => DateStringGMT($reservation->approved()),
                "canceled"    => DateStringGMT($reservation->canceled()));
            
            if (time() > strtotime($resgroup->start()) &&
                $reservation->approved()) {
                $blob["active"] = true;
            }
            else {
                $blob["active"] = false;
            }
            $ranges[$reservation->freq_uuid()] = $blob;

            if (! $reservation->approved()) {
                $status = "pending";
                $details["pending"] += 1;
            }
            else {
                $details["approved"] += 1;
            }
        }
        $routes = array();
        foreach ($resgroup->routereservations() as $reservation) {
            $blob = array(
                "route_uuid"  => $reservation->route_uuid(),
                "routename"   => $reservation->routename(),
                "routeid"     => $reservation->routeid(),
                "submitted"   => DateStringGMT($reservation->submitted()),
                "approved"    => DateStringGMT($reservation->approved()),
                "canceled"    => DateStringGMT($reservation->canceled()));
            
            if (time() > strtotime($resgroup->start()) &&
                $reservation->approved()) {
                $blob["active"] = true;
            }
            else {
                $blob["active"] = false;
            }
            $routes[$reservation->route_uuid()] = $blob;

            if (! $reservation->approved()) {
                $status = "pending";
                $details["pending"] += 1;
            }
            else {
                $details["approved"] += 1;
            }
        }
        $details["status"] = $status;
        if (time() > strtotime($resgroup->start()) &&
            ($status == "approved" || $details["pending"] > 0)) {
            $details["active"] = true;
        }
        else {
            $details["active"] = false;
        }
        $details["clusters"] = $clusters;
        $details["ranges"]   = $ranges;
        $details["routes"]   = $routes;
        return $details;
    }
}

class ReservationGroupReservation
{
    var $reservation;
    
    #
    # Constructor to lookup a single reservation in a group.
    #
    function ReservationGroupReservation($group, $urn, $type) {
	$uuid = $group->uuid();
        $safe_urn  = addslashes($urn);
        $safe_type = addslashes($type);

	$query_result =
	    DBQueryWarn("select * from apt_reservation_group_reservations ".
			"where uuid='$uuid' and ".
                        "      aggregate_urn='$safe_urn' and ".
                        "      type='$safe_type'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->reservation = null;
	    return;
	}
	$this->reservation = mysql_fetch_array($query_result);
    }
    # accessors
    function field($name) {
	return (is_null($this->reservation) ? -1 : $this->reservation[$name]);
    }
    function uuid()	    { return $this->field('uuid'); }
    function aggregate_urn(){ return $this->field('aggregate_urn'); }
    function remote_uuid()  { return $this->field('remote_uuid'); }
    function type()	    { return $this->field('type'); }
    function count()	    { return $this->field('count'); }
    function using()	    { return $this->field('using'); }
    function utilization()  { return $this->field('utilization'); }
    function submitted()    { return $this->field('submitted'); }
    function approved()     { return $this->field('approved'); }
    function deleted()	    { return $this->field('deleted'); }
    function canceled()     { return $this->field('canceled'); }
    function jsondata()     { return $this->field('jsondata'); }
    function approved_pushed()     { return $this->field('approved_pushed'); }
    function canceled_pushed()     { return $this->field('canceled_pushed'); }
    function cancel_canceled()     { return $this->field('cancel_canceled'); }
    function deleted_pushed()      { return $this->field('deleted_pushed'); }
    
    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->reservation);
    }

    function Lookup($group, $urn, $type) {
	$foo = new ReservationGroupReservation($group, $urn, $type);

	if ($foo->IsValid()) {
            return $foo;
        }
        return null;
    }

    #
    # Lookup all reservations for a group
    #
    function LookupForGroup($group) {
        $result = array();
        $uuid   = $group->uuid();

        $query_result =
            DBQueryFatal("select type,aggregate_urn ".
                         "  from apt_reservation_group_reservations ".
                         "where uuid='$uuid'");

	while ($row = mysql_fetch_array($query_result)) {
            $res = ReservationGroupReservation::Lookup($group,
                                                        $row['aggregate_urn'],
                                                        $row['type']);
            if ($res) {
                $result[] = $res;
            }
        }
        return $result;
    }

    function Aggregate() {
        return Aggregate::Lookup($this->aggregate_urn());
    }
}
class ReservationGroupRFReservation
{
    var $reservation;
    
    #
    # Constructor to lookup a single reservation in a group.
    #
    function ReservationGroupRFReservation($group, $freq_uuid) {
	$uuid = $group->uuid();
        $safe_uuid  = addslashes($freq_uuid);

	$query_result =
	    DBQueryWarn("select * from apt_reservation_group_rf_reservations ".
			"where uuid='$uuid' and ".
                        "      freq_uuid='$safe_uuid'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->reservation = null;
	    return;
	}
	$this->reservation = mysql_fetch_array($query_result);
    }
    # accessors
    function field($name) {
	return (is_null($this->reservation) ? -1 : $this->reservation[$name]);
    }
    function uuid()	    { return $this->field('uuid'); }
    function freq_uuid()    { return $this->field('freq_uuid'); }
    function freq_low()	    { return $this->field('freq_low'); }
    function freq_high()    { return $this->field('freq_high'); }
    function submitted()    { return $this->field('submitted'); }
    function approved()     { return $this->field('approved'); }
    function canceled()     { return $this->field('canceled'); }
    
    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->reservation);
    }

    function Lookup($group, $uuid) {
	$foo = new ReservationGroupRFReservation($group, $uuid);

	if ($foo->IsValid()) {
            return $foo;
        }
        return null;
    }

    #
    # Lookup all reservations for a group
    #
    function LookupForGroup($group) {
        $result = array();
        $uuid   = $group->uuid();

        $query_result =
            DBQueryFatal("select freq_uuid ".
                         "  from apt_reservation_group_rf_reservations ".
                         "where uuid='$uuid'");

	while ($row = mysql_fetch_array($query_result)) {
            $res = ReservationGroupRFReservation::Lookup($group,
                                                         $row['freq_uuid']);
            if ($res) {
                $result[] = $res;
            }
        }
        return $result;
    }
}
class ReservationGroupRouteReservation
{
    var $reservation;
    
    #
    # Constructor to lookup a single reservation in a group.
    #
    function ReservationGroupRouteReservation($group, $route_uuid) {
	$uuid = $group->uuid();
        $safe_uuid  = addslashes($route_uuid);

	$query_result =
	    DBQueryWarn("select * from ".
                        "   apt_reservation_group_route_reservations ".
			"where uuid='$uuid' and ".
                        "      route_uuid='$safe_uuid'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->reservation = null;
	    return;
	}
	$this->reservation = mysql_fetch_array($query_result);
    }
    # accessors
    function field($name) {
	return (is_null($this->reservation) ? -1 : $this->reservation[$name]);
    }
    function uuid()	    { return $this->field('uuid'); }
    function route_uuid()   { return $this->field('route_uuid'); }
    function routename()    { return $this->field('routename'); }
    function routeid()      { return $this->field('routeid'); }
    function submitted()    { return $this->field('submitted'); }
    function approved()     { return $this->field('approved'); }
    function canceled()     { return $this->field('canceled'); }
    
    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->reservation);
    }

    function Lookup($group, $uuid) {
	$foo = new ReservationGroupRouteReservation($group, $uuid);

	if ($foo->IsValid()) {
            return $foo;
        }
        return null;
    }

    #
    # Lookup all reservations for a group
    #
    function LookupForGroup($group) {
        $result = array();
        $uuid   = $group->uuid();

        $query_result =
            DBQueryFatal("select route_uuid ".
                         "  from apt_reservation_group_route_reservations ".
                         "where uuid='$uuid'");

	while ($row = mysql_fetch_array($query_result)) {
            $res = ReservationGroupRouteReservation::Lookup($group,
                                                            $row['route_uuid']);
            if ($res) {
                $result[] = $res;
            }
        }
        return $result;
    }
}

?>
