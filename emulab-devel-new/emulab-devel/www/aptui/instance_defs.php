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

$geni_response_codes =
    array("Success",
          "Bad Arguments",
          "Error",
          "Forbidden",
          "Bad Version",
          "Server Error",
          "Too Big",
          "Refused",
          "Timed Out",
          "Database Error",
          "RPC Error",
          "Unavailable",
          "Search Failed",
          "Unsupported",
          "Busy",
          "Expired",
          "In Progress",
          "Already Exists",
          "Error 18",
          "Error 19",
          "Error 20",
          "Error 21",
          "Error 22",
          "No space left on device or over quota",
          "Vlan Unavailable",
          "Insufficient Bandwidth",
          "Insufficient Nodes",
          "Insufficient Memory",
          "No Mapping Possible",
    );
define("GENIRESPONSE_BADARGS",   	       1);
define("GENIRESPONSE_ERROR",       	       2);
define("GENIRESPONSE_REFUSED",                 7);
define("GENIRESPONSE_TIMEDOUT",                8);
define("GENIRESPONSE_RPCERROR",                10);
define("GENIRESPONSE_SEARCHFAILED",            12);
define("GENIRESPONSE_ALREADYEXISTS",           17);
define("GENIRESPONSE_NOSPACE",                 23);
define("GENIRESPONSE_VLAN_UNAVAILABLE",        24);
define("GENIRESPONSE_INSUFFICIENT_BANDWIDTH",  25);
define("GENIRESPONSE_INSUFFICIENT_NODES",      26);
define("GENIRESPONSE_INSUFFICIENT_MEMORY",     27);
define("GENIRESPONSE_NO_MAPPING",              28);
define("GENIRESPONSE_NO_CONNECT",              29);
define("GENIRESPONSE_MAPPING_IMPOSSIBLE",      30);
define("GENIRESPONSE_NETWORK_ERROR",           35);
define("GENIRESPONSE_STITCHER_ERROR",          101);
define("GENIRESPONSE_SETUPFAILURE_BOOTFAILED", 151);

class Instance
{
    var	$instance;
    
    #
    # Constructor by lookup on unique index.
    #
    function Instance($uuid) {
	$safe_uuid = addslashes($uuid);

	$query_result =
	    DBQueryWarn("select * from apt_instances ".
			"where uuid='$safe_uuid'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->instance = null;
	    return;
	}
	$this->instance  = mysql_fetch_array($query_result);
        $this->slivers   = InstanceSliver::LookupForInstance($this);
        if (!count($this->slivers) && $this->aggregate_urn()) {
            $this->slivers =
                array(InstanceSliver::Lookup($this, $this->aggregate_urn()));
        }
    }
    # accessors
    function slivers()      { return $this->slivers; }
    function field($name) {
	return (is_null($this->instance) ? -1 : $this->instance[$name]);
    }
    function uuid()	    { return $this->field('uuid'); }
    function name()	    { return $this->field('name'); }
    function slice_uuid()   { return $this->field('slice_uuid'); }
    function creator()	    { return $this->field('creator'); }
    function creator_idx()  { return $this->field('creator_idx'); }
    function creator_uuid() { return $this->field('creator_uuid'); }
    function created()	    { return $this->field('created'); }
    function started()	    { return $this->field('started'); }
    function start_at()     { return $this->field('start_at'); }
    function stop_at()      { return $this->field('stop_at'); }
    function profile_id()   { return $this->field('profile_id'); }
    function profile_version() { return $this->field('profile_version'); }
    function status()	    { return $this->field('status'); }
    function canceled()	    { return $this->field('canceled'); }
    function paniced()	    { return $this->field('paniced'); }
    function pid()	    { return $this->field('pid'); }
    function pid_idx()	    { return $this->field('pid_idx'); }
    function gid()	    { return $this->field('gid'); }
    function gid_idx()	    { return $this->field('gid_idx'); }
    function public_url()   { return $this->field('public_url'); }
    function logfileid()    { return $this->field('logfileid'); }
    function manifest()	    { return $this->field('manifest'); }
    function admin_lockdown() { return $this->field('admin_lockdown'); }
    function user_lockdown(){ return $this->field('user_lockdown'); }
    function extension_count()   { return $this->field('extension_count'); }
    function extension_days()    { return $this->field('extension_days'); }
    function extension_hours()   { return $this->field('extension_hours'); }
    function extension_reason()  { return $this->field('extension_reason'); }
    function extension_history() { return $this->field('extension_history'); }
    function extension_lockout() { return $this->field('extension_adminonly'); }
    function extension_disabled(){ return $this->field('extension_disabled'); }
    function extension_disabled_reason(){
        return $this->field('extension_disabled_reason');}
    function extension_requested(){return $this->field('extension_requested');}
    function extension_denied()  { return $this->field('extension_denied');}
    function extension_denied_reason(){
        return $this->field('extension_denied_reason');}
    function physnode_count()    { return $this->field('physnode_count'); }
    function virtnode_count()    { return $this->field('virtnode_count'); }
    function servername()   { return $this->field('servername'); }
    function aggregate_urn(){ return $this->field('aggregate_urn'); }
    function private_key()  { return $this->field('privkey'); }
    function webtask_id()   { return $this->field('webtask_id'); }
    function repourl()	    { return $this->field('repourl'); }
    function reporef()	    { return $this->field('reporef'); }
    function repohash()	    { return $this->field('repohash'); }
    function rspec()	    { return $this->field('rspec'); }
    function admin_notes()  { return $this->field('admin_notes'); }
    function isopenstack()  { return $this->field('isopenstack'); }
    function params()       { return $this->field('params'); }
    function paramdefs()    { return $this->field('paramdefs'); }
    function openstack_utilization() {
        return $this->field('openstack_utilization');
    }
    # Convenience
    function isActive()     { return 1; }
    function IsAPT() {
	return preg_match('/aptlab/', $this->servername());
    }
    function IsCloud() {
	return preg_match('/cloudlab/', $this->servername());
    }
    function IsPNet() {
	return preg_match('/phantomnet/', $this->servername());
    }

    # Grab the webtask. Backwards compat mode, see if there is one associated
    # with the object, use that. Otherwise create a new one.
    function WebTask() {
        if ($this->webtask_id()) {
            return WebTask::Lookup($this->webtask_id());
        }
        $webtask = WebTask::LookupByObject($this->uuid());
        if (!$webtask) {
            $webtask = WebTask::CreateAnonymous();
            if (!$webtask) {
                return null;
            }
        }
        $uuid = $this->uuid();
        $webtask_id = $webtask->task_id();
        DBQueryFatal("update apt_instances set ".
                     "  webtask_id='$webtask_id' ".
                     "where uuid='$uuid'");
        return $webtask;
    }
    function aggregate_name() {
        global $urn_mapping;
        return $urn_mapping[$this->aggregate_urn()];
    }
    
    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->instance);
    }

    # URL to the status page.
    function StatusURL() {
        global $APTBASE;

        return $APTBASE . "/status.php?uuid=" . $this->uuid();
    }
    function AdminURL() {
        global $APTBASE;

        return $APTBASE . "/adminextend.php?uuid=" . $this->uuid();
    }

    # Lookup up an instance by idx. 
    function Lookup($idx) {
	$foo = new Instance($idx);

	if ($foo->IsValid()) {
            # Insert into cache.
	    return $foo;
	}	
	return null;
    }

    function LookupByCreator($token) {
	$safe_token = addslashes($token);

	$query_result =
	    DBQueryFatal("select uuid from apt_instances ".
			 "where creator_uuid='$safe_token'");

	if (! ($query_result && mysql_num_rows($query_result))) {
	    return null;
	}
	$row = mysql_fetch_row($query_result);
	$uuid = $row[0];
 	return Instance::Lookup($uuid);
    }

    function LookupBySlice($token) {
	$safe_token = addslashes($token);

	$query_result =
	    DBQueryFatal("select uuid from apt_instances ".
			 "where slice_uuid='$safe_token'");

	if (! ($query_result && mysql_num_rows($query_result))) {
	    return null;
	}
	$row = mysql_fetch_row($query_result);
	$uuid = $row[0];
 	return Instance::Lookup($uuid);
    }

    function LookupByName($project, $token) {
	$safe_token = addslashes($token);
        $pid_idx    = $project->pid_idx();

	$query_result =
	    DBQueryFatal("select uuid from apt_instances ".
			 "where pid_idx='$pid_idx' and name='$safe_token'");

	if (! ($query_result && mysql_num_rows($query_result))) {
	    return null;
	}
	$row = mysql_fetch_row($query_result);
	$uuid = $row[0];
 	return Instance::Lookup($uuid);
    }

    #
    # Refresh an instance by reloading from the DB.
    #
    function Refresh() {
	if (! $this->IsValid())
	    return -1;

	$uuid = $this->uuid();

	$query_result =
	    DBQueryWarn("select * from apt_instances where uuid='$uuid'");
    
	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->instance  = NULL;
	    return -1;
	}
	$this->instance = mysql_fetch_array($query_result);
	return 0;
    }

    # Project of instance.
    function Project() {
        return Project::Lookup($this->pid_idx());
    }
    # Group of instance.
    function Group() {
        return Group::Lookup($this->gid_idx());
    }
    # Profile version that was instantiated.
    function Profile() {
        return Profile::Lookup($this->profile_id(), $this->profile_version());
    }
    
    #
    # Class function to create a new Instance
    #
    function Instantiate($uuid, $creator, $options, $args, $webtask) {
	global $suexec_output, $suexec_output_array;

	#
        # Generate a temporary file and write in the XML goo. 
	#
	$xmlname = tempnam("/tmp", "quickvm");
	if (! $xmlname) {
	    TBERROR("Could not create temporary filename", 0);
            $webtask->output("Internal error creating experiment");
            $webtask->code(GENIRESPONSE_ERROR);
	    return null;
	}
	elseif (! ($fp = fopen($xmlname, "w"))) {
	    TBERROR("Could not open temp file $xmlname", 0);
            $webtask->output("Internal error creating experiment");
            $webtask->code(GENIRESPONSE_ERROR);
	    return null;
	}
	else {
	    fwrite($fp, "<quickvm>\n");
	    foreach ($args as $name => $value) {
		fwrite($fp, "<attribute name=\"$name\">");
		fwrite($fp, "  <value>" . htmlspecialchars($value) .
		       "</value>");
		fwrite($fp, "</attribute>\n");
	    }
	    fwrite($fp, "</quickvm>\n");
	    fclose($fp);
	    chmod($xmlname, 0666);
	}
	# 
	# With a real user, run as that user. 
	#
        if ($creator) {
            $uid = $creator->uid();
            $pid = $args["pid"];
        }
        else {
            $uid = "nobody";
            $pid = "nobody";
        }
	if (isset($_SERVER['REMOTE_ADDR'])) { 
	    putenv("REMOTE_ADDR=" . $_SERVER['REMOTE_ADDR']);
	}
	if (isset($_SERVER['SERVER_NAME'])) { 
	    putenv("SERVER_NAME=" . $_SERVER['SERVER_NAME']);
	}
        $options .= " -t " . $webtask->task_id();
        
	$retval = SUEXEC($uid, $pid,
			 "webcreate_instance $options -u $uuid $xmlname",
			 SUEXEC_ACTION_IGNORE);
	unlink($xmlname);

	if ($retval != 0) {
            $webtask->Refresh();

            # Did not get a clean exit.
            if (! $webtask->exited() || $retval < 0) {
		SUEXECERROR(SUEXEC_ACTION_CONTINUE);
                $webtask->output("Internal error creating experiment");
                $webtask->code(GENIRESPONSE_ERROR);
                return null;
            }
            # Error in the webtask for the caller.
            return null;
	}
	$instance = Instance::Lookup($uuid);
	if (!$instance) {
	    TBERROR("Could not lookup instance after create: $uuid", 0);
            $webtask->output("Internal error creating experiment");
            $webtask->code(GENIRESPONSE_ERROR);
	    return null;
	}
	return array($instance, $creator);
    }

    function UserHasInstances($user) {
	$uuid = $user->uuid();

	$query_result =
	    DBQueryFatal("select uuid from apt_instances ".
			 "where creator_uuid='$uuid'");

	return mysql_num_rows($query_result);
    }

    function SendEmail($to, $subject, $msg, $headers) {
	TBMAIL($to, $subject, $msg, $headers);
    }

    #
    # How many experiments has a guest user created
    #
    function GuestInstanceCount($geniuser) {
        $uid = $geniuser->uid();
        
        $query_result =
            DBQueryFatal("select count(h.uuid) from apt_instance_history as h ".
                         "left join geni.geni_users as u on ".
                         "     u.uuid=h.creator_uuid ".
                         "where h.creator='$uid' and u.email is not null");
        
	$row = mysql_fetch_row($query_result);
	return $row[0];
    }

    #
    # Number of active experiments a user or project has.
    #
    function CurrentInstanceCount($target) {
        if (get_class($target) == "Project") {
            $pid = $target->pid();
        
            $query_result =
                DBQueryFatal("select count(uuid) from apt_instances as i ".
                             "where i.pid='$pid'");
        }
        else {
            $uid = $target->uid();
        
            $query_result =
                DBQueryFatal("select count(uuid) from apt_instances as i ".
                             "where i.creator='$uid'");
        }
	$row = mysql_fetch_row($query_result);
	return $row[0];
    }

    #
    # Return aggregate based on the current user.
    #
    function DefaultAggregateList($user = null) {
        return Aggregate::DefaultAggregateList($user);
    }

    # helper
    function ParseURN($urn)
    {
        if (preg_match("/^[^+]*\+([^+]+)\+([^+]+)\+(.+)$/", $urn, $matches)) {
            return array($matches[1], $matches[2], $matches[3]);
        }
        return array();
    }
    function ValidURN($urn)
    {
        if (preg_match("/^[^+]*\+([^+]+)\+([^+]+)\+(.+)$/", $urn)) {
            return true;
        }
        return false;
    }

    function SetExtensionReason($reason)
    {
	$uuid = $this->uuid();
        $safe_reason = mysql_escape_string($reason);

        DBQueryWarn("update apt_instances set ".
                    "  extension_reason='$safe_reason' ".
                    "where uuid='$uuid'");
    }

    function SetAdminNotes($notes)
    {
	$uuid = $this->uuid();
        $safe_notes = mysql_escape_string($notes);

        DBQueryWarn("update apt_instances set ".
                    "  admin_notes='$safe_notes' ".
                    "where uuid='$uuid'");
    }

    function SetExtensionRequested($value)
    {
	$uuid = $this->uuid();

        DBQueryWarn("update apt_instances set ".
                    "  extension_requested='$value' ".
                    "where uuid='$uuid'");
    }

    function AddExtensionHistory($text)
    {
	$uuid = $this->uuid();
        $safe_text = mysql_escape_string($text);

        DBQueryWarn("update apt_instances set ".
                    "extension_history=CONCAT('$safe_text',".
                    "IFNULL(extension_history,'')) ".
                    "where uuid='$uuid'");
    }

    #
    # Permission check; does user have permission to view instance.
    #
    function CanView($user) {
	if ($this->creator_idx() == $user->uid_idx()) {
	    return 1;
	}
	# Otherwise a project membership test.
	$project = Project::Lookup($this->pid_idx());
	if (!$project) {
	    return 0;
	}
	$isapproved = 0;
	if ($project->IsMember($user, $isapproved) && $isapproved) {
	    return 1;
	}
	return 0;
    }
    function CanModify($user) {
	if ($this->creator_idx() == $user->uid_idx()) {
	    return 1;
	}
        return 0;
    }
    function CanTerminate($user) {
	global $TBDB_TRUST_GROUPROOT;

	if ($this->creator_idx() == $user->uid_idx()) {
	    return 1;
	}
	# Otherwise a project membership test.
	$project = Project::Lookup($this->pid_idx());
	if (!$project) {
	    return 0;
	}
        $uid = $user->uid();
        $pid = $project->pid();
        return TBMinTrust(TBGrpTrust($uid, $pid, $pid), $TBDB_TRUST_GROUPROOT);
    }
    function CanDoSSH($user) {
        global $PROTOGENI_HOLDINGPROJECT;
        
	if ($this->creator_idx() == $user->uid_idx()) {
	    return 1;
	}
        #
        # These are the guest projects.
        #
        $APT_HOLDINGPROJECT = "aptguests";
        
        if ($this->pid() == $APT_HOLDINGPROJECT ||
            $this->pid() == $PROTOGENI_HOLDINGPROJECT) {
            return 0;
        }
        
        # Otherwise a project membership test.
        $project = Project::Lookup($this->pid_idx());
        if (!$project) {
            return 0;
        }
        $isapproved = 0;
        if ($project->IsMember($user, $isapproved) && $isapproved) {
            return 1;
        }
        return 0;
    }

    #
    # Determine user current usage.
    #
    function CurrentUsage($target) {
        $pcount = 0;
        $phours = 0;

        if (get_class($target) == "User") {
            $user_idx = $target->idx();
            
            $query_result =
                DBQueryFatal("select sum(physnode_count), ".
                         " truncate(sum(physnode_count * ".
                         "  ((UNIX_TIMESTAMP(now()) - ".
                         "    UNIX_TIMESTAMP(started)) / 3600.0)),2) as phours".
                         "  from apt_instances ".
                         "where creator_idx='$user_idx' and physnode_count>0");
        }
        else {
            $pid_idx = $target->pid_idx();

            $query_result =
                DBQueryFatal("select sum(physnode_count), ".
                         " truncate(sum(physnode_count * ".
                         "  ((UNIX_TIMESTAMP(now()) - ".
                         "    UNIX_TIMESTAMP(started)) / 3600.0)),2) as phours".
                         "  from apt_instances ".
                         "where pid_idx='$pid_idx' and physnode_count>0");
        }

        $row = mysql_fetch_array($query_result);
        $pcount = $row[0] ? $row[0] : 0;
        $phours = $row[1] ? $row[1] : 0;
        return array($pcount, $phours);
    }

    #
    # Usage over the last week. Just phours, cause pcount is not very useful.
    #
    function WeeksUsage($target) {
        $weekago  = time() - (3600 * 24 * 7);
        $phours   = 0;
        $pcount   = 0;
        $clause   = "";

        if (get_class($target) == "User") {
            $user_idx = $target->idx();
            $clause = "creator_idx='$user_idx'";
        }
        else {
            $pid_idx = $target->pid_idx();
            $clause = "pid_idx='$pid_idx'";
        }

        #
        # This gets existing experiments back one week.
        #
        $query_result =
            DBQueryFatal("select physnode_count, ".
                         "    UNIX_TIMESTAMP(started) as started ".
                         "  from apt_instances ".
                         "where $clause and physnode_count>0");

	while ($row = mysql_fetch_array($query_result)) {
            $pnodes   = $row["physnode_count"];
            $created  = $row["started"];

            if ($created < $weekago)
                $diff = (3600 * 24 * 7);
            else
                $diff = time() - $created;

            $pcount += $pnodes;
            $phours += $pnodes * ($diff / 3600.0);
        }

        #
        # This gets experiments terminated in the last week.
        #
        $query_result =
            DBQueryFatal("select physnode_count,".
                         "       UNIX_TIMESTAMP(started) as started, ".
                         "       UNIX_TIMESTAMP(destroyed) as destroyed ".
                         "  from apt_instance_history ".
                         "where $clause and physnode_count>0 and " .
                         "      destroyed>DATE_SUB(curdate(), INTERVAL 1 WEEK)");

	while ($row = mysql_fetch_array($query_result)) {
            $pnodes    = $row["physnode_count"];
            $created   = $row["started"];
            $destroyed = $row["destroyed"];

            if ($created < $weekago)
                $diff = $destroyed - $weekago;
            else
                $diff = $destroyed - $created;

            if ($diff < 0)
                $diff = 0;

            $pcount += $pnodes;
            $phours += $pnodes * ($diff / 3600.0);
        }
        return array ($pcount, $phours);
    }

    #
    # Usage over the last months Just phours, cause pcount is not very useful.
    #
    function MonthsUsage($target, $group = null) {
        $monthago = time() - (3600 * 24 * 28);
        $pcount   = 0;
        $phours   = 0;
        $clause   = "";

        if (get_class($target) == "User") {
            $user_idx = $target->idx();
            $clause = "creator_idx='$user_idx'";
            #
            # Optional group target for user.
            #
            if ($group) {
                $pid = $group->pid();
                $gid = $group->gid();
                $clause .= " and pid='$pid' and gid='$gid' ";
            }
        }
        else {
            $pid_idx = $target->pid_idx();
            $clause = "pid_idx='$pid_idx'";
        }

        #
        # This gets existing experiments back one week.
        #
        $query_result =
            DBQueryFatal("select physnode_count,".
                         "    UNIX_TIMESTAMP(started) as started ".
                         "  from apt_instances ".
                         "where $clause and physnode_count>0");

	while ($row = mysql_fetch_array($query_result)) {
            $pnodes   = $row["physnode_count"];
            $created  = $row["started"];

            if ($created < $monthago)
                $diff = (3600 * 24 * 28);
            else
                $diff = time() - $created;

            $pcount += $pnodes;
            $phours += $pnodes * ($diff / 3600.0);
        }

        #
        # This gets experiments terminated in the last week.
        #
        $query_result =
            DBQueryFatal("select physnode_count,".
                         "       UNIX_TIMESTAMP(started) as started, ".
                         "       UNIX_TIMESTAMP(destroyed) as destroyed ".
                         "  from apt_instance_history ".
                         "where $clause and physnode_count>0 and " .
                         "      destroyed>DATE_SUB(curdate(), INTERVAL 1 MONTH)");

	while ($row = mysql_fetch_array($query_result)) {
            $pnodes    = $row["physnode_count"];
            $created   = $row["started"];
            $destroyed = $row["destroyed"];

            if ($created < $monthago)
                $diff = $destroyed - $monthago;
            else
                $diff = $destroyed - $created;

            if ($diff < 0)
                $diff = 0;

            $pcount += $pnodes;
            $phours += $pnodes * ($diff / 3600.0);
        }
        return array($pcount, $phours);
    }

    #
    # Ranking of usage over the last N days. Just by phours, cause pcount
    # is not very useful.
    #
    function Ranking($target, $days) {
        $rank     = null;
        $ranktotal= 0;

        if (get_class($target) == "User") {
            $which = "creator_idx";
            $who   = $target->uid_idx();
        }
        else {
            $which = "pid_idx";
            $who   = $target->pid_idx();
        }
        $query_result =
            DBQueryFatal("select $which,SUM(physnode_count) as physnode_count,".
                         "   SUM(phours) as phours from ".
                         " ((select $which,physnode_count,started,NULL, ".
                         "   physnode_count * (TIMESTAMPDIFF(HOUR, ".
                         "    IF(started > DATE_SUB(now(),INTERVAL $days DAY),".
                         "       started, DATE_SUB(now(), INTERVAL $days DAY)), now())) ".
                         "    as phours ".
                         "   from apt_instances ".
                         "   where physnode_count>0) ".
                         "  union ".
                         "  (select $which,physnode_count,started,destroyed, ".
                         "   physnode_count * (TIMESTAMPDIFF(HOUR, ".
                         "    IF(started > DATE_SUB(now(),INTERVAL $days DAY),".
                         "       started, DATE_SUB(now(), INTERVAL $days DAY)), destroyed)) ".
                         "    as phours ".
                         "   from apt_instance_history ".
                         "   where physnode_count>0 and ".
                         "         destroyed>DATE_SUB(now(),INTERVAL $days DAY)))".
                         "   as combined ".
                         "group by $which ".
                         "order by phours desc");

        $ranktotal = mysql_num_rows($query_result);
        $count = 1;
	while ($row = mysql_fetch_array($query_result)) {
            if ($who == $row[0]) {
                $rank = $count;
                break;
            }
            $count++;
        }
        return array($rank, $ranktotal);
    }

    #
    # Return Caching Token, either the latest commit hash
    # or the current time for development trees.
    #
    function CacheToken() {
      if (preg_match("/\/dev\//", $_SERVER["SCRIPT_NAME"]))
      {
        return date('Y-m-d-H:i:s');
      }
      else
      {
          $query_result =
              DBQueryFatal("select value from version_info ".
                           "where name='commithash'");
          
          if (!$query_result || !mysql_num_rows($query_result)) {
              return date('Y-m-d-H:i:s');
          }
          $row = mysql_fetch_array($query_result);
          return $row[0];
      }
    }

    #
    # Return a list of types not to show user.
    #
    function NodeTypePruneList($aggregate = null, $all = false) {
        global $ISEMULAB, $ISCLOUD, $ISAPT, $ISPNET, $ISPOWDER, $TBMAINSITE;
        global $DEFAULT_AGGREGATE_URN;
        $aggregate_urn = ($aggregate ? $aggregate->urn() : "");

        #
        # We never want to show these.
        #
        $skiptypes = array("dboxvm"    => true,
                           "d430k"     => true,
                           "d530"      => true,
                           "pcivy"     => true,
                           "pc2830qx2" => true,
                           "pc2400hp"  => true,
                           "d2100"     => true,
                           "faros_sfp" => true,
                           "e200-8d"   => true,
                           "e300-8d"   => true,
                           "sequoia-v8"=> true,
                           "pc2400w"   => true,
                           "nexus5"    => true,
                           "sdr"       => true,
                           "enodeb"    => true,
                           "nuc5300"   => true,
                           "nuc6260"   => true,
                           "nuc8650"   => true,
                           "nuc8559"   => true,
                           "nuc7100"   => true,
                           "x310"      => true,
                           "n310"      => true,
                           "mmimotmp1" => true,
                           "iris03"    => true,
                           "iris04"    => true,
        );

        #
        # If showing nodes from another cluster, then we show them
        # all (not sure how long this rule will last). Otherwise,
        # only the Powder/Phantom portals get to see all these types.
        #
        if ($TBMAINSITE && 
            !($ISPOWDER || $ISPNET) &&
            ($all || $aggregate_urn == $DEFAULT_AGGREGATE_URN)) {
            $skiptypes["nuc5300"]  = true;
            $skiptypes["iris030"]  = true;
            $skiptypes["d840"]     = true;
            $skiptypes["d740"]     = true;
            #
            # Grab all the local individually reservable nodes.
            #
            $query_result =
                DBQueryFatal("select node_id from nodes ".
                             "where reservable=1");

            while ($row = mysql_fetch_array($query_result)) {
                $skiptypes[$row["node_id"]]    = true;                
            }
        }
        return $skiptypes;
    }
    
    #
    # Return a list of frequency ranges in use.
    #
    # Used for the front page code!
    #
    function RFRangesUnUse()
    {
        global $PORTAL_HEALTH;
        $result = array();

        $query_result =
            DBQueryFatal("select freq_low,freq_high ".
                         "from apt_instance_rfranges");
	while ($row = mysql_fetch_array($query_result)) {
            $result[] = array("freq_low"  => $row["freq_low"],
                              "freq_high" => $row["freq_high"]);
        }
        return $result;
    }

    #
    # Most recent experiments for rerun.
    #
    function RecentExperiments($user, $profile = null)
    {
        $result = array();
        $uid_idx = $user->uid_idx();
        $clause  = "";

        if ($profile) {
            $profile_id = $profile->profileid();
            $clause = "and h.profile_id='$profile_id'";
        }

        $query_result =
            DBQueryFatal("select v.uuid,p.name,h.repohash, " .
                         "   h.name as expname,h.uuid as expuuid ".
                         " from apt_instance_history as h ".
                         "join apt_profiles as p on p.profileid=h.profile_id ".
                         "join apt_profile_versions as v on ".
                         "     v.profileid=p.profileid and ".
                         "     v.version=p.version ".
                         "where h.creator_idx='$uid_idx' $clause ".
                         "order by h.created desc limit 10");
        if (!mysql_num_rows($query_result)) {
            return null;
        }
	while ($row = mysql_fetch_array($query_result)) {
            $profile_name   = $row["name"];
            $profile_uuid   = $row["uuid"];
            $instance_uuid  = $row["expuuid"];
            $instance_name  = $row["expname"];
            $repohash       = $row["repohash"];
            $rerun_url = "instantiate.php?profile=${profile_uuid}" .
                       "&rerun_instance=${instance_uuid}";
            $result[] = array("profile_uuid"  => $profile_uuid,
                              "profile_name"  => $profile_name,
                              "instance_uuid" => $instance_uuid,
                              "instance_name" => $instance_name,
                              "rerun_url"     => $rerun_url,
            );
        }
        return $result;
    }
}

class InstanceHistory
{
    var	$record;
    var $slivers;
    
    #
    # Constructor by lookup on unique index.
    #
    function InstanceHistory($uuid) {
	$safe_uuid = addslashes($uuid);

	$query_result =
	    DBQueryWarn("select h.*,f.exitmessage,f.exitcode ".
                        "  from apt_instance_history as h ".
                        "left join apt_instance_failures as f ".
                        "     on f.uuid=h.uuid ".
			"where h.uuid='$safe_uuid'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->record = null;
	    return;
	}
	$this->record  = mysql_fetch_array($query_result);

        #
        # Get the list of aggregate records. Early records do not have one.
        #
	$query_result =
	    DBQueryWarn("select * from apt_instance_aggregate_history ".
			"where uuid='$uuid'");
	if (!$query_result) {
	    $this->record = null;
	    return;
	}
        if (!mysql_num_rows($query_result)) {
            $this->slivers = array(
                array("uuid" => $this->record["uuid"],
                      "name" => $this->record["name"],
                      "aggregate_urn" => $this->record["aggregate_urn"],
                      "status" => $this->record["status"],
                      "public_url" => $this->record["public_url"],
                      "manifest" => $this->record["manifest"],
                ));
        }
        else {
            $this->slivers = array();

            while ($row = mysql_fetch_array($query_result)) {
                $this->slivers[] = $row;
            }
        }
    }
    # accessors
    function slivers()      { return $this->slivers; }
    function field($name) {
	return (is_null($this->record) ? -1 : $this->record[$name]);
    }
    function uuid()	    { return $this->field('uuid'); }
    function name()	    { return $this->field('name'); }
    function profile_id()   { return $this->field('profile_id'); }
    function profile_version() { return $this->field('profile_version'); }
    function slice_uuid()   { return $this->field('slice_uuid'); }
    function creator()	    { return $this->field('creator'); }
    function creator_idx()  { return $this->field('creator_idx'); }
    function creator_uuid() { return $this->field('creator_uuid'); }
    function pid()	    { return $this->field('pid'); }
    function pid_idx()	    { return $this->field('pid_idx'); }
    function gid()	    { return $this->field('gid'); }
    function gid_idx()	    { return $this->field('gid_idx'); }
    function aggregate_urn(){ return $this->field('aggregate_urn'); }
    function public_url()   { return $this->field('public_url'); }
    function logfileid()    { return $this->field('logfileid'); }
    function created()	    { return $this->field('created'); }
    function start_at()     { return $this->field('start_at'); }
    function stop_at()      { return $this->field('stop_at'); }
    function started()      { return $this->field('started'); }
    function destroyed()    { return $this->field('destroyed'); }
    function expired()      { return $this->field('expired'); }
    function extension_count()   { return $this->field('extension_count'); }
    function extension_days()    { return $this->field('extension_days'); }
    function extension_hours()   { return $this->field('extension_hours'); }
    function physnode_count()    { return $this->field('physnode_count'); }
    function virtnode_count()    { return $this->field('virtnode_count'); }
    function servername()   { return $this->field('servername'); }
    function repourl()	    { return $this->field('repourl'); }
    function reporef()	    { return $this->field('reporef'); }
    function repohash()	    { return $this->field('repohash'); }
    function rspec()	    { return $this->field('rspec'); }
    function script()	    { return $this->field('script'); }
    function params()	    { return $this->field('params'); }
    function manifest()	    { return $this->field('manifest'); }
    # Convenience
    function isActive()     { return 0; }
    function IsAPT() {
	return preg_match('/aptlab/', $this->servername());
    }
    function IsCloud() {
	return preg_match('/cloudlab/', $this->servername());
    }
    function IsPNet() {
	return preg_match('/phantomnet/', $this->servername());
    }
    # Project of instance.
    function Project() {
        return Project::Lookup($this->pid_idx());
    }
    # Profile version that was instantiated.
    function Profile() {
        return Profile::Lookup($this->profile_id(), $this->profile_version());
    }
    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->record);
    }
    # Lookup up an instance by uuid
    function Lookup($uuid) {
	$foo = new InstanceHistory($uuid);

	if ($foo->IsValid()) {
            # Insert into cache.
	    return $foo;
	}	
	return null;
    }
    function LookupBySlice($slice_uuid)
    {
	$safe_uuid = addslashes($slice_uuid);

	$query_result =
	    DBQueryWarn("select uuid from apt_instance_history ".
			"where slice_uuid='$safe_uuid'");

	if (!$query_result || !mysql_num_rows($query_result)) {
            return null;
	}
        $row = mysql_fetch_array($query_result);
        return InstanceHistory::Lookup($row[0]);
    }
    function SliceToUUID($slice_uuid)
    {
	$safe_uuid = addslashes($slice_uuid);

	$query_result =
	    DBQueryWarn("select uuid from apt_instance_history ".
			"where slice_uuid='$safe_uuid'");

	if (!$query_result || !mysql_num_rows($query_result)) {
            return null;
	}
        $row = mysql_fetch_array($query_result);
        return $row[0];
    }
    #
    # Permission check; does user have permission to view instance.
    #
    function CanView($user) {
	if ($this->creator_idx() == $user->uid_idx()) {
	    return 1;
	}
	# Otherwise a project membership test.
	$project = Project::Lookup($this->pid_idx());
	if (!$project) {
	    return 0;
	}
	$isapproved = 0;
	if ($project->IsMember($user, $isapproved) && $isapproved) {
	    return 1;
	}
	return 0;
    }
}

class InstanceSliver
{
    var	$sliver;
    
    #
    # Constructor by lookup on unique index.
    #
    function InstanceSliver($instance, $urn) {
        if (!$instance) {
            TBMAIL("stoller", "undefined instance", $urn);
	    $this->sliver = null;
	    return;
        }
	$uuid = $instance->uuid();
        $safe_urn = addslashes($urn);

	$query_result =
	    DBQueryWarn("select * from apt_instance_aggregates ".
			"where uuid='$uuid' and aggregate_urn='$safe_urn'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->sliver = null;
	    return;
	}
	$this->sliver = mysql_fetch_array($query_result);
    }
    # accessors
    function field($name) {
	return (is_null($this->sliver) ? -1 : $this->sliver[$name]);
    }
    function uuid()	    { return $this->field('uuid'); }
    function name()	    { return $this->field('name'); }
    function aggregate_urn(){ return $this->field('aggregate_urn'); }
    function status()	    { return $this->field('status'); }
    function public_url()   { return $this->field('public_url'); }
    function webtask_id()   { return $this->field('webtask_id'); }
    function prestage_data(){ return $this->field('prestage_data'); }
    function deferred()     { return $this->field('deferred'); }
    function deferred_reason(){ return $this->field('deferred_reason'); }
    function last_retry()   { return $this->field('last_retry'); }
    function retry_count()  { return $this->field('retry_count'); }
    function manifest()	    { return $this->field('manifest'); }
    function physnode_count() { return $this->field('physnode_count'); }
    function virtnode_count() { return $this->field('virtnode_count'); }
    function aggregate_name() {
        global $urn_mapping;
        return $urn_mapping[$this->aggregate_urn()];
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->sliver);
    }

    function Lookup($instance, $urn) {
	$foo = new InstanceSliver($instance, $urn);

	if ($foo->IsValid()) {
            return $foo;
        }
        #
        # Backwards compat for a while, create a fake one. 
        #
        $webtask_id = null;
        $webtask = WebTask::LookupByObject($instance->uuid());
        if ($webtask) {
            $webtask_id = $webtask->task_id();
        }
        $foo->sliver = array(
            "uuid" => $instance->uuid(),
            "name" => $instance->name(),
            "aggregate_urn" => $instance->aggregate_urn(),
            "status" => $instance->status(),
            "public_url" => $instance->public_url(),
            "manifest" => $instance->manifest(),
            "webtask_id" => $webtask_id,
        );
        return $foo;
    }

    #
    # Lookup all slivers for an instance
    #
    function LookupForInstance($instance) {
        $result = array();
        $uuid   = $instance->uuid();

        $query_result =
            DBQueryFatal("select aggregate_urn from apt_instance_aggregates ".
                         "where uuid='$uuid'");

	while ($row = mysql_fetch_array($query_result)) {
            $sliver = InstanceSliver::Lookup($instance, $row['aggregate_urn']);
            if ($sliver) {
                $result[] = $sliver;
            }
        }
        return $result;
    }

    #
    # Grab the list of sliver status rows. Turn this into a class at some point.
    #
    function StatusArray() {
        $result = array();
        $uuid   = $this->uuid();
        $urn    = $this->aggregate_urn();

        $query_result =
            DBQueryFatal("select * from apt_instance_sliver_status ".
                         "where uuid='$uuid' and aggregate_urn='$urn'");

	while ($row = mysql_fetch_array($query_result)) {
            if ($row["sliver_data"]) {
                $row["sliver_details"] = json_decode($row["sliver_data"], true);
                
                if ($row["frisbee_data"]) {
                    $frisbeestatus = json_decode($row["frisbee_data"], true);
                    $row["sliver_details"]["frisbeestatus"] = $frisbeestatus;
                }
            }
            $result[] = $row;
        }
        return $result;
    }

    # Grab the webtask. 
    function WebTask() {
        if ($this->webtask_id()) {
            return WebTask::Lookup($this->webtask_id());
        }
        return null;
    }
}

class ExtensionInfo
{
    var	$info;
    
    function ExtensionInfo($instance, $idx) {
	$uuid = $instance->uuid();
        $idx  = addslashes($idx);

	$query_result =
	    DBQueryWarn("select * from apt_instance_extension_info ".
			"where uuid='$uuid' and idx='$idx'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->info = null;
	    return;
	}
	$this->info = mysql_fetch_assoc($query_result);
        $this->info["reason"]  = trim($this->info["reason"]);
        $this->info["message"] = trim($this->info["message"]);

        #
        # Convert wanted/granted hours to handy 5D14H string.
        #
        $wdays  = intval($this->info["wanted"] / 24.0);
        $whours = $this->info["wanted"] % 24;
        $gdays  = intval($this->info["granted"] / 24.0);
        $ghours = $this->info["granted"] % 24;
        if ($wdays) {
            $wantstring = "${wdays}D" . "${whours}H";
        }
        else {
            $wantstring = "${whours}H";
        }
        if ($gdays) {
            $grantstring = "${gdays}D" . "${ghours}H";
        }
        elseif ($ghours) {
            $grantstring = "${ghours}H";
        }
        else {
            $grantstring = "0";
        }
        $this->info["wantedstring"]  = $wantstring;
        $this->info["grantedstring"] = $grantstring;
    }
    # accessors
    function field($name) {
	return (is_null($this->info) ? -1 : $this->info[$name]);
    }
    function uuid()	    { return $this->field('uuid'); }
    function name()	    { return $this->field('name'); }
    function idx()          { return $this->field('idx'); }
    function tstamp()       { return $this->field('tstamp'); }
    function uid()          { return $this->field('uid'); }
    function uid_idx()      { return $this->field('uid_idx'); }
    function action()       { return $this->field('action'); }
    function wanted()       { return $this->field('wanted'); }
    function granted()      { return $this->field('granted'); }
    function admin()        { return $this->field('admin'); }
    function needapproval() { return $this->field('needapproval'); }
    function reason()       { return $this->field('reason'); }
    function message()      { return $this->field('message'); }
    function autoapproved() { return $this->field('autoapproved'); }
    function autoapproved_reason() {
        return $this->field('autoapproved_reason');
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->info);
    }

    function Lookup($instance, $idx) {
	$foo = new ExtensionInfo($instance, $idx);

	if ($foo->IsValid()) {
            return $foo;
        }
        return $foo;
    }

    #
    # Lookup all extensions for an instance
    #
    function LookupForInstance($instance) {
        $result = array();
        $uuid   = $instance->uuid();

        $query_result =
            DBQueryFatal("select idx from apt_instance_extension_info ".
                         "where uuid='$uuid' order by idx desc");

	while ($row = mysql_fetch_array($query_result)) {
            $info = ExtensionInfo::Lookup($instance, $row['idx']);
            if ($info) {
                $result[] = $info;
            }
        }
        return $result;
    }
}

# $amlist, $fedlist, and $status are all output arrays
function CalculateAggregateStatus(&$amlist, &$fedlist, &$status,
                                  $extended = false, $user = null,
                                  $frontpage = false) {
    global $TBMAINSITE, $DEFAULT_AGGREGATE_URN, $CHECKLOGIN_USER;
    $am_array = Aggregate::DefaultAggregateList($user, $frontpage);

    #
    # If not the Cloudlab Portal then we get local status only.
    #
    if (!$TBMAINSITE) {
        $aggregate = $am_array[$DEFAULT_AGGREGATE_URN];
        $urn = $aggregate->urn();
        $am  = $aggregate->name();
        if ($extended) {
            $typelist = array();
            $types = $aggregate->TypeList();

            foreach ($types as $type => $ignore) {
                $typelist[$type] = $aggregate->TypeAttributes($type);
            }
            $amlist[$urn] =
                array("urn"      => $urn,
                      "name"     => $am,
                      "nickname" => $aggregate->nickname(),
                      "typelist" => $typelist,
                      "typeinfo" => $aggregate->typeinfo,
                      "reservable_nodes" => $aggregate->ReservableNodes());
        }
        else {
            $amlist[$urn] = $am;
        }
        $freevms = $vmcount = 0;
        TBVMCounts($vmcount, $freevms);

        $status[$urn] = array(
            "rawPCsAvailable"  => TBFreePCs($CHECKLOGIN_USER),
            "rawPCsTotal"      => TBTotalPCs(),
            "VMsAvailable"     => $freevms,
            "VMsTotal"         => $vmcount,
            "health"           => 100,
            "status"           => "SUCCESS");
        return;
    }
    while (list($ignore, $aggregate) = each($am_array)) {
        $urn = $aggregate->urn();
        $am  = $aggregate->name();
        if ($extended) {
            $typelist = array();
            $types = $aggregate->TypeList();

            foreach ($types as $type => $ignore) {
                $typelist[$type] = $aggregate->TypeAttributes($type);
            }
            $amlist[$urn] = array("urn"      => $urn,
                                  "name"     => $am,
                                  "isFE"     => $aggregate->isFE(),
                                  "ismobile" => $aggregate->ismobile(),
                                  "nickname" => $aggregate->nickname(),
                                  "typelist" => $typelist,
                                  "typeinfo" => $aggregate->typeinfo);
        }
        else {
            $amlist[$urn] = $am;
        }
        #
        # We need to mark federated sites for the cluster dropdown.
        #
        if ($aggregate->isfederate()) {
            $fedlist[] = "'" . $aggregate->name() . "'";
        }
        #
        # generate the status blob.
        #
        if ($aggregate->status()) {
            $status[$urn] = array(
                "rawPCsAvailable"  => $aggregate->pfree(),
                "rawPCsTotal"      => $aggregate->pcount(),
                "VMsAvailable"     => $aggregate->vfree(),
                "VMsTotal"         => $aggregate->vcount(),
                "health"           => ($aggregate->status() == "up" ? 100 :
                                       ($aggregate->status() == "down" ?
                                        0 : 50)),
                "status"           => ($aggregate->status() != "down" ?
                                       "SUCCESS" : "FAILED"));
        }
    }
}

function CalculateWirelessStatus(&$result) {
    $query_result =
        DBQueryFatal( "SELECT COUNT(DISTINCT w.node_id1) AS c FROM wires AS w " .
		      "LEFT OUTER JOIN reserved AS r1 ON " .
		      "w.node_id1=r1.node_id LEFT OUTER JOIN reserved AS r2 " .
		      "ON w.node_id2=r2.node_id WHERE w.node_id1 LIKE 'nuc%' " .
		      "AND w.node_id2 LIKE 'ue%' AND (w.external_wire IS NULL " .
		      "OR w.external_wire='') AND r1.pid IS NULL AND r2.pid IS NULL" );
    $row = mysql_fetch_array( $query_result );
    $radiated1 = $row[ 'c' ];

    $query_result =
        DBQueryFatal( "SELECT COUNT(DISTINCT w.node_id2) AS c FROM wires AS w " .
		      "LEFT OUTER JOIN reserved AS r1 ON " .
		      "w.node_id1=r1.node_id LEFT OUTER JOIN reserved AS r2 " .
		      "ON w.node_id2=r2.node_id WHERE w.node_id2 LIKE 'nuc%' " .
		      "AND w.node_id1 LIKE 'ue%' AND (w.external_wire IS NULL " .
		      "OR w.external_wire='') AND r1.pid IS NULL AND r2.pid IS NULL" );
    $row = mysql_fetch_array( $query_result );
    $radiated2 = $row[ 'c' ];

    $query_result =
        DBQueryFatal( "SELECT COUNT(DISTINCT w.node_id1) AS c FROM wires AS w " .
		      "LEFT OUTER JOIN reserved AS r1 ON " .
		      "w.node_id1=r1.node_id LEFT OUTER JOIN reserved AS r2 " .
		      "ON w.node_id2=r2.node_id WHERE w.node_id1 LIKE 'nuc%' " .
		      "AND w.node_id2 LIKE 'ue%' AND w.external_wire != ''" .
		      "AND r1.pid IS NULL AND r2.pid IS NULL" );
    $row = mysql_fetch_array( $query_result );
    $controlled1 = $row[ 'c' ];

    $query_result =
        DBQueryFatal( "SELECT COUNT(DISTINCT w.node_id2) AS c FROM wires AS w " .
		      "LEFT OUTER JOIN reserved AS r1 ON " .
		      "w.node_id1=r1.node_id LEFT OUTER JOIN reserved AS r2 " .
		      "ON w.node_id2=r2.node_id WHERE w.node_id2 LIKE 'nuc%' " .
		      "AND w.node_id1 LIKE 'ue%' AND w.external_wire != ''" .
		      "AND r1.pid IS NULL AND r2.pid IS NULL" );
    $row = mysql_fetch_array( $query_result );
    $controlled2 = $row[ 'c' ];

    $result["radiated"] = $radiated1 + $radiated2;
    $result["controlled"] = $controlled1 + $controlled2;
}
    
function SpitAggregateStatus($extended = false, $user = null) {
    $amlist     = array();
    $fedlist    = array();
    $status     = array();
    CalculateAggregateStatus($amlist, $fedlist, $status, $extended, $user);
    echo "<script type='text/plain' id='amlist-json'>\n";
    echo htmlentities(json_encode($amlist));
    echo "</script>\n";
    echo "<script type='text/plain' id='amstatus-json'>\n";
    echo htmlentities(json_encode($status));
    echo "</script>\n";
    echo "<script type='text/javascript'>\n";
    echo "    window.FEDERATEDLIST  = [". implode(",", $fedlist) . "];\n";
    echo "</script>\n";
}

#
# Find usage info for user for the epoch, rather then looking up per
# profile. Much faster.
#
function UserUsageInfo($user) {
    $user_idx    = $user->idx();
    $results     = array();

    $query_result =
        DBQueryFatal("select profile_id,count(profile_id) as count, ".
                     "       max(UNIX_TIMESTAMP(started)) as lastused ".
                     "  from apt_instances ".
                     " where creator_idx='$user_idx' ".
                     " group by profile_id");

    while ($row = mysql_fetch_array($query_result)) {
        $profile_id = $row["profile_id"];
        $count      = $row["count"];
        $lastused   = $row["lastused"];

        $results[$profile_id] = array("count"    => $count,
                                      "lastused" => $lastused);
    }
    $query_result =
        DBQueryFatal("select profile_id,count(profile_id) as count, ".
                     "       max(UNIX_TIMESTAMP(started)) as lastused ".
                     "  from apt_instance_history ".
                     " where creator_idx='$user_idx' ".
                     " group by profile_id");

    while ($row = mysql_fetch_array($query_result)) {
        $profile_id = $row["profile_id"];
        $count      = $row["count"];
        $lastused   = $row["lastused"];

        if (!array_key_exists($profile_id, $results)) {
            $results[$profile_id] = array("count"    => $count,
                                          "lastused" => $lastused);
        }
        else {
            $result = $results[$profile_id];
            $result["count"] += $count;
            if ($lastused > $result["lastused"]) {
                $result["lastused"] = $lastused;
            }
        }
    }
    return $results;
}

?>
