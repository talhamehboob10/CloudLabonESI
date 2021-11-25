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
# A cache of groups to avoid lookups. Indexed by pid_idx;
#
$project_cache = array();

class Project
{
    var	$project;
    var $group;
    var $_grouplist;		# All subgroups
    var $tempdata;		# For temporary data values ...

    #
    # Constructor by lookup on unique index.
    #
    function Project($pid_idx) {
	$safe_pid_idx = addslashes($pid_idx);

	$query_result =
	    DBQueryWarn("select * from projects ".
			"where pid_idx='$safe_pid_idx'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->project = NULL;
	    return;
	}
	$this->project   = mysql_fetch_array($query_result);
	$this->group     = null;
	$this->_grouplist = null;
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->project);
    }

    # Lookup by pid_idx.
    function Lookup($pid_idx) {
	global $project_cache;

        # Look in cache first
	if (array_key_exists("$pid_idx", $project_cache))
	    return $project_cache["$pid_idx"];
	
	$foo = new Project($pid_idx);

	if (! $foo->IsValid()) {
	    # Try lookup by plain uid.
	    $foo = Project::LookupByPid($pid_idx);
	    
	    if (!$foo || !$foo->IsValid())
		return null;

	    # Return here, already in the cache.
	    return $foo;
	}
	# Insert into cache.
	$project_cache["$pid_idx"] = $foo;
	return $foo;
    }

    # Backwards compatable lookup by pid. Will eventually flush this.
    function LookupByPid($pid) {
	$safe_pid = addslashes($pid);
	global $project_cache;

        # Look in cache first
	if (array_key_exists($pid, $project_cache))
	    return $project_cache[$pid];
	
	$query_result =
	    DBQueryWarn("select pid_idx from projects where pid='$safe_pid'");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	$idx = $row['pid_idx'];

	$foo = new Project($idx); 

	if ($foo->IsValid()) {
            # Insert into cache.
            $project_cache[$pid] = $foo;
	    return $foo;
        }
	
	return null;
    }
    
    #
    # Refresh an instance by reloading from the DB.
    #
    function Refresh() {
	if (! $this->IsValid())
	    return -1;

	$pid_idx = $this->pid_idx();

	$query_result =
	    DBQueryWarn("select * from projects where pid_idx='$pid_idx'");
    
	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->project = NULL;
	    return -1;
	}
	$this->project   = mysql_fetch_array($query_result);

	if ($this->group) {
	    $foo = $this->group;
	    $foo->Refresh();
	}
	$this->_grouplist = null;
	return 0;
    }

    # accessors
    function field($name) {
	return (is_null($this->project) ? -1 : $this->project[$name]);
    }
    function pid_idx()	     { return $this->field("pid_idx"); }
    function gid_idx()	     { return $this->field("pid_idx"); }
    function pid()	     { return $this->field("pid"); }
    function created()       { return $this->field("created"); }
    function expires()       { return $this->field("expires"); }
    function nagged()        { return $this->field("nagged"); }
    function name()          { return $this->field("name"); }
    function URL()           { return $this->field("URL"); }
    function funders()       { return $this->field("funders"); }
    function addr()          { return $this->field("addr"); }
    function head_uid()      { return $this->field("head_uid"); }
    function head_idx()      { return $this->field("head_idx"); }
    function num_members()   { return $this->field("num_members"); }
    function num_pcs()       { return $this->field("num_pcs"); }
    function num_sharks()    { return $this->field("num_sharks"); }
    function num_pcplab()    { return $this->field("num_pcplab"); }
    function num_ron()       { return $this->field("num_ron"); }
    function why()           { return $this->field("why"); }
    function control_node()  { return $this->field("control_node"); }
    function approved()      { return $this->field("approved"); }
    function disabled()      { return $this->field("disabled"); }
    function inactive()      { return $this->field("inactive"); }
    function date_inactive() { return $this->field("date_inactive"); }
    function ispublic()      { return $this->field("public"); }
    function public_whynot() { return $this->field("public_whynot"); }
    function expt_count()    { return $this->field("expt_count"); }
    function expt_last()     { return $this->field("expt_last"); }
    function pcremote_ok()   { return $this->field("pcremote_ok"); }
    function default_user_interface()
	                     { return $this->field("default_user_interface"); }
    function reservations_disabled()
	                     { return $this->field("reservations_disabled"); }
    function linked_to_us()  { return $this->field("linked_to_us"); }
    function forClass()      { return $this->field("forClass"); }
    function industry()      { return $this->field("industry"); }
    function consortium()    { return $this->field("consortium"); }
    function cvsrepo_public(){ return $this->field("cvsrepo_public"); }
    function allow_workbench(){ return $this->field("allow_workbench"); }
    function nonlocal_id()   { return $this->field("nonlocal_id"); }
    function portal()	     { return $this->field("portal"); }
    function bound_portal()  { return $this->field("bound_portal"); }
    function expert_mode()   { return $this->field("expert_mode"); }
    function isAPT()	     { return ($this->portal() &&
                                       $this->portal() == "aptlab" ? 1 : 0); }
    function isCloud()	     { return ($this->portal() &&
                                       $this->portal() == "cloudlab" ? 1 : 0); }
    function isPNet()	     { return ($this->portal() &&
                                       $this->portal() == "phantomnet" ? 1 :0);}
    function isPowder()	     { return ($this->portal() &&
                                       $this->portal() == "powder" ? 1 : 0);}
    function isEmulab()	     { return ($this->portal() &&
                                       $this->portal() == "emulab" ? 1 : 0); }
    # Not via the Portal interface.
    function isClassic()     { return ($this->portal() ? 0 : 1); }
    
    function IsNonLocal() {
	return ($this->field("nonlocal_id") ? 1 : 0);
    }

    function wwwBase() {
	global $TBBASE;
	
	return ($this->isAPT() ? "https://www.aptlab.net" :
		($this->isCloud() ? "https://www.cloudlab.us" : 
		 ($this->isPNet() ? "https://www.phantomnet.org" :
                  ($this->isPowder() ? "https://www.powderwireless.net" :
                   $TBBASE))));
    }
    function ApprovalEmailAddress() {
	global $TBMAILADDR_APPROVAL;

	return ($this->isAPT() ? "aptlab-approval@aptlab.net" :
		($this->isCloud() ? "cloudlab-approval@cloudlab.us" :
		 ($this->isPNet() ? "phantomnet-approval@phantomnet.org" :
                  ($this->isPowder() ? "powder-approval@powderwireless.net" :
                   $TBMAILADDR_APPROVAL))));
    }
    function EmailTag() {
	global $THISHOMEBASE;
	
	return ($this->isAPT() ? "aptlab.net" :
		($this->isCloud() ? "cloudlab.us" : 
		 ($this->isPNet() ? "phantomnet.org" :
                  ($this->isPowder() ? "powderwireless.net" :
                   $THISHOMEBASE))));
    }

    function unix_gid() {
	$group = $this->DefaultGroup();
	
	return $group->unix_gid();
    }
    function unix_name() {
	$group = $this->DefaultGroup();

	return $group->unix_name();
    }
    # Temporary data storage ... useful.
    function SetTempData($value) {
	$this->tempdata = $value;
    }
    function GetTempData() {
	return $this->tempdata;
    }

    #
    # At some point we will stop passing pid and start using pid_idx.
    # Use this function to avoid having to change a bunch of code twice.
    #
    function URLParam() {
	return $this->pid();
    }

    #
    # Class function to create new project and return object.
    #
    function NewProject($pid, $leader, $args) {
	global $TBBASE, $TBMAIL_APPROVAL, $TBMAIL_AUDIT, $TBMAIL_WWW;
	
	#
	# The array of inserts is assumed to be safe already. Generate
	# a list of actual insert clauses to be joined below.
	#
	$insert_data = array();
	
	foreach ($args as $name => $value) {
	    $insert_data[] = "$name='$value'";
	}

	# First create the underlying default group for the project.
	if (! ($newgroup = Group::NewGroup(null, $pid, $leader,
					   'Default Group', $pid))) {
	    return null;
	}

	# Every project gets a new unique index, which comes from the group.
	$pid_idx = $newgroup->gid_idx();

	# Now tack on other stuff we need.
	$insert_data[] = "pid='$pid'";
	$insert_data[] = "pid_idx='$pid_idx'";
	$insert_data[] = "head_uid='" . $leader->uid() . "'";
	$insert_data[] = "head_idx='" . $leader->uid_idx() . "'";
	$insert_data[] = "created=now()";

	# Insert into DB. Should probably lock the table ...
	if (!DBQuerywarn("insert into projects set ".
			 implode(",", $insert_data))) {
	    $newgroup->Delete();
	    return null;
	}

	if (! DBQueryWarn("insert into project_stats (pid, pid_idx) ".
			  "values ('$pid', $pid_idx)")) {
	    $newgroup->Delete();
	    DBQueryFatal("delete from projects where pid_idx='$pid_idx'");
	    return null;
	}
	$newproject = Project::Lookup($pid_idx);
	if (! $newproject)
	    return null;

	#
	# The creator of a group is not automatically added to the group,
	# but we do want that for a new project. 
	#
	if ($newgroup->AddNewMember($leader) < 0) {
	    $newgroup->Delete();
	    DBQueryWarn("delete from project_stats where pid_idx=$pid_idx");
	    DBQueryWarn("delete from projects where pid_idx=$pid_idx");
	    return null;
	}

	return $newproject;
    }

    function NewNewProject($args, &$error) {
	global $suexec_output, $suexec_output_array;

        #
        # Generate a temporary file and write in the XML goo.
        #
	$xmlname = tempnam("/tmp", "newproj");
	if (! $xmlname) {
	    TBERROR("Could not create temporary filename", 0);
	    $error = "Transient error(1); please try again later.";
	    return null;
	}
	if (! ($fp = fopen($xmlname, "w"))) {
	    TBERROR("Could not open temp file $xmlname", 0);
	    $error = "Transient error(2); please try again later.";
	    return null;
	}

	fwrite($fp, "<project>\n");
	foreach ($args as $name => $value) {
	    fwrite($fp, "<attribute name=\"$name\">");
	    fwrite($fp, "  <value>" . htmlspecialchars($value) . "</value>");
	    fwrite($fp, "</attribute>\n");
	}
	fwrite($fp, "</project>\n");
	fclose($fp);
	chmod($xmlname, 0666);

	$retval = SUEXEC("nobody", "nobody", "webnewproj $xmlname",
			 SUEXEC_ACTION_IGNORE | SUEXEC_ACTION_MAIL_TBLOGS);

	if ($retval) {
	    if ($retval < 0) {
		$error = "Transient error(3, $retval); please try again later.";
		SUEXECERROR(SUEXEC_ACTION_CONTINUE);
	    }
	    else {
		$error = $suexec_output;
	    }
	    return null;
	}

        #
        # Parse the last line of output. Ick.
        #
	unset($matches);
	
	if (!preg_match("/^Project\s+([-\w]+)\/(\d+)\s+/",
			$suexec_output_array[count($suexec_output_array)-1],
			$matches)) {
	    $error = "Transient error(4, $retval); please try again later.";
	    SUEXECERROR(SUEXEC_ACTION_CONTINUE);
	    return null;
	}
	$pid_idx = $matches[2];
	$newproj = Project::Lookup($pid_idx);
	if (! $newproj) {
	    $error = "Transient error(5); please try again later.";
	    TBERROR("Could not lookup new project $pid_idx", 0);
	    return null;
	}
	# Unlink this here, so that the file is left behind in case of error.
	# We can then create the project by hand from the xmlfile, if desired.
	unlink($xmlname);
	return $newproj;
    }

    #
    # Class function to return a list of pending (unapproved) projects.
    #
    function PendingProjectList() {
	$result     = array();

	$query_result =
	    DBQueryFatal("select pid_idx, ".
			 " DATE_FORMAT(created, '%m/%d/%y') as day_created ".
			 " from projects ".
			 "where approved='0' order by created desc");
			     
	while ($row = mysql_fetch_array($query_result)) {
	    $pid_idx = $row["pid_idx"];
	    $created = $row["day_created"];

	    if (! ($project = Project::Lookup($pid_idx))) {
		TBERROR("Project::PendingProjectList: ".
			"Could not load project $pid_idx!", 1);
	    }
	    $project->SetTempData($created);
	    
	    $result[] = $project;
	}
	return $result;
    }
    
    function AccessCheck($user, $access_type) {
	$group = $this->DefaultGroup();
	
	return $group->AccessCheck($user, $access_type);
    }

    # Can the user delete the target user.
    function CanDeleteUser($user, $target_user) {
        global $TB_PROJECT_DELUSER;
        
        # Not allowed to delete yourself from a group.
        if ($user->SameUser($target_user)) {
            return 0;
        }
        if (! $this->AccessCheck($user, $TB_PROJECT_DELUSER) ||
            $this->UserTrust($target_user) >= $this->UserTrust($user)) {
            return 0;
        }
        return 1;
    }

    # Return the user trust within the project, which is really for the
    # default group.
    function UserTrust($user) {
	$group = $this->DefaultGroup();
	
	return $group->UserTrust($user);
    }

    # Return membership info in the default group.
    function MemberShipInfo($user) {
	$group = $this->DefaultGroup();

        return $group->MemberShipInfo($user);
    }

    #
    # Load the default group for a project lazily.
    #
    function LoadDefaultGroup() {
	if ($this->group) {
	    return $this->group;
	}
	
	# Note: pid_idx=gid_idx for the default group
	$gid_idx = $this->pid_idx();

	if (! ($group = Group::Lookup($gid_idx))) {
	    TBERROR("Project::LoadDefaultGroup: ".
		    "Could not load group $gid_idx!", 1);
	}
	$this->group = $group;
	return $group;
    }
    function DefaultGroup() { return $this->LoadDefaultGroup(); }
    function Group()        { return $this->DefaultGroup(); }

    #
    # Lookup a project subgroup by its name.
    #
    function LookupSubgroupByName($name) {
	$pid = $this->pid();

	return Group::LookupByPidGid($pid, $name);
    }

    #
    # Load all subgroups for this project.
    #
    function LoadSubGroups() {
	if ($this->_grouplist)
	    return 0;
	
	$pid_idx = $this->pid_idx();
	$result  = array();

	$query_result =
	    DBQueryFatal("select gid_idx from groups ".
			 "where pid_idx='$pid_idx'");

	while ($row = mysql_fetch_array($query_result)) {
	    $gid_idx = $row["gid_idx"];

	    if (! ($group = Group::Lookup($gid_idx))) {
		TBERROR("Project::LoadSubGroups: ".
			"Could not load group $gid_idx!", 1);
	    }
	    $result[] = $group;
	}
	$this->_grouplist = $result;
	return 0;
    }
    function SubGroups() {
	$this->LoadSubGroups();
	return $this->_grouplist;
    }

    #
    # Return user object for leader.
    #
    function GetLeader() {
	$head_idx = $this->head_idx();

	if (! ($leader = User::Lookup($head_idx))) {
	    TBERROR("Could not find user object for $head_idx", 1);
	}
	return $leader;
    }
    # Boolean test.
    function IsLeader($user) {
        $leader = $this->GetLeader();
        if ($user->SameUser($leader)) {
            return 1;
        }
        return 0;
    }
    function IsManager($user) {
        global $TBDB_TRUST_GROUPROOT;
        
	$pid = $this->pid();
	$uid = $user->uid();

        if (TBMinTrust(TBGrpTrust($uid, $pid, $pid), $TBDB_TRUST_GROUPROOT)) {
            return 1;
        }
        return 0;
    }

    #
    # Add *new* member to project group; starts out with trust=none.
    #
    function AddNewMember($user, $trust = TBDB_TRUSTSTRING_NONE) {
	$group = $this->DefaultGroup();

	return $group->AddNewMember($user, $trust);
    }

    #
    # Delete.
    #  
    function DeleteMember($user) {
	$group = $this->DefaultGroup();

	return $group->DeleteMember($user);
    }

    #
    # Check if user is a member of this project (well, group)
    #
    function IsMember($user, &$approved) {
	$group = $this->DefaultGroup();

	return $group->IsMember($user, $approved);
    }

    #
    # Lookup an experiment within a project.
    #
    function LookupExperiment($eid) {
	return Experiment::LookupByPidEid($this->pid(), $eid);
    }

    #
    # How many PCs is project using. 
    #
    function PCsInUse() {
	$pid = $this->pid();
	
	$query_result =
	    DBQueryFatal("select count(r.node_id) from reserved as r ".
			 "left join nodes as n on n.node_id=r.node_id ".
			 "left join node_types as nt on nt.type=n.type ".
			 "where nt.class='pc' and r.pid='$pid'");
    
	if (mysql_num_rows($query_result) == 0) {
	    return 0;
	}
	$row = mysql_fetch_row($query_result);
	return $row[0];
    }
    
    #
    # Member list for a group.
    #
    function MemberList() {
	$pid_idx = $this->pid_idx();
	$result  = array();

	$query_result =
	    DBQueryFatal("select uid_idx from group_membership ".
			 "where pid_idx='$pid_idx' and gid_idx=pid_idx");

	while ($row = mysql_fetch_array($query_result)) {
	    $uid_idx = $row["uid_idx"];

	    if (! ($user = User::Lookup($uid_idx))) {
		TBERROR("Project::MemberList: ".
			"Could not load user $uid_idx!", 1);
	    }
	    $result[] = $user;
	}
	return $result;
    }

    #
    # Return an array of any users in the project who are admins.
    #
    function GetAdmins() {
	$pid_idx = $this->pid_idx();
	$result  = array();
	$query_result =
	    DBQueryFatal("select distinct u.uid_idx from users as u".
			 " left join group_membership as gm on ".
			 "      u.uid_idx=gm.uid_idx".
			 " where gm.pid_idx='$pid_idx' and u.admin=1");

	while ($row = mysql_fetch_array($query_result)) {
	    $uid_idx = $row["uid_idx"];

	    if (! ($user = User::Lookup($uid_idx))) {
		TBERROR("Project::GetAdmins: ".
			"Could not load user $uid_idx!", 1);
	    }
	    $result[] = $user;
	}
	return $result;
    }

    #
    # List of subgroups for a project member (not including default group).
    #
    function GroupList($user) {
	$pid_idx = $this->pid_idx();
	$uid_idx = $user->uid_idx();
	$result  = array();

	$query_result =
	    DBQueryFatal("select gid_idx from group_membership ".
			 "where pid_idx='$pid_idx' and pid_idx!=gid_idx and ".
			 "      uid_idx='$uid_idx'");

	while ($row = mysql_fetch_array($query_result)) {
	    $gid_idx = $row["gid_idx"];

	    if (! ($group = Group::Lookup($gid_idx))) {
		TBERROR("Project::GroupList: ".
			"Could not load group $gid_idx!", 1);
	    }
	    $result[] = $group;
	}
	return $result;
    }

    #
    # List of experiments for a project, or just the count.
    #
    function ExperimentList($listify = 1) {
	$group = $this->DefaultGroup();

	return $group->ExperimentList($listify);
    }

    #
    # Change the leader for a project. Done *only* before project is
    # approved.
    #
    function ChangeLeader($leader) {
	$group   = $this->DefaultGroup();
	$idx     = $this->pid_idx();
	$uid     = $leader->uid();
	$uid_idx = $leader->uid_idx();

	DBQueryFatal("update projects set ".
		     "  head_uid='$uid',head_idx='$uid_idx' ".
		     "where pid_idx='$idx'");

	$this->project["head_uid"] = $uid;
	$this->project["head_idx"] = $uid_idx;
	return $group->ChangeLeader($leader);
    }
    
    #
    # Change various fields.
    #
    function SetApproved($approved) {
	$idx   = $this->pid_idx();

	if ($approved)
	    $approved = 1;
	else
	    $approved = 0;
	
	DBQueryFatal("update projects set approved='$approved' ".
		     "where pid_idx='$idx'");

	$this->project["approved"] = $approved;
	return 0;
    }
    function SetRemoteOK($ok) {
	$idx    = $this->pid_idx();
	$safeok = addslashes($ok);

	DBQueryFatal("update projects set pcremote_ok='$safeok' ".
		     "where pid_idx='$idx'");

	$this->project["pcremote_ok"] = $ok;
	return 0;
    }

    function SetCVSRepoPublic($public) {
	$idx    = $this->pid_idx();
	$public = ($public ? 1 : 0);

	DBQueryFatal("update projects set cvsrepo_public='$public' ".
		     "where pid_idx='$idx'");

	return 0;
    }
    function SetAllowWorkbench($onoff) {
	$idx    = $this->pid_idx();
	$onoff  = ($onoff ? 1 : 0);

	DBQueryFatal("update projects set allow_workbench='$onoff' ".
		     "where pid_idx='$idx'");

	return 0;
    }
    function SetDisabled($onoff) {
	$idx    = $this->pid_idx();
	$onoff  = ($onoff ? 1 : 0);

	DBQueryFatal("update projects set disabled='$onoff' ".
		     "where pid_idx='$idx'");

	$this->project["disabled"] = $onoff;
	return 0;
    }
    function SetResDisabled($onoff) {
	$idx    = $this->pid_idx();
	$onoff  = ($onoff ? 1 : 0);

	DBQueryFatal("update projects set reservations_disabled='$onoff' ".
		     "where pid_idx='$idx'");

	$this->project["disabled"] = $onoff;
	return 0;
    }
    function SetforClass($onoff) {
	$idx    = $this->pid_idx();
	$onoff  = ($onoff ? 1 : 0);

	DBQueryFatal("update projects set forClass='$onoff' ".
		     "where pid_idx='$idx'");

	$this->project["forClass"] = $onoff;
	return 0;
    }
    function SetIndustry($onoff) {
	$idx    = $this->pid_idx();
	$onoff  = ($onoff ? 1 : 0);

	DBQueryFatal("update projects set industry='$onoff' ".
		     "where pid_idx='$idx'");

	$this->project["industry"] = $onoff;
	return 0;
    }
    function SetConsortium($onoff) {
	$idx    = $this->pid_idx();
	$onoff  = ($onoff ? 1 : 0);

	DBQueryFatal("update projects set consortium='$onoff' ".
		     "where pid_idx='$idx'");

	$this->project["consortium"] = $onoff;
	return 0;
    }
    function SetBoundPortal($onoff) {
	$idx    = $this->pid_idx();
	$onoff  = ($onoff ? 1 : 0);

	DBQueryFatal("update projects set bound_portal='$onoff' ".
		     "where pid_idx='$idx'");

	$this->project["bound_portal"] = $onoff;
	return 0;
    }
    function SetExpertMode($onoff) {
	$idx    = $this->pid_idx();
	$onoff  = ($onoff ? 1 : 0);

	DBQueryFatal("update projects set expert_mode='$onoff' ".
		     "where pid_idx='$idx'");

	$this->project["expert_mode"] = $onoff;
	return 0;
    }

    function Show() {
	global $WIKISUPPORT, $CVSSUPPORT, $TBPROJ_DIR, $TBCVSREPO_DIR;
	global $MAILMANSUPPORT, $OPSCVSURL, $USERNODE;

	$group = $this->DefaultGroup();

	$pid                    = $this->pid();
	$proj_idx		= $this->pid_idx();
	$proj_created		= $this->created();
	$proj_name		= $this->name();
	$proj_URL		= $this->URL();
	$proj_public		= YesNo($this->ispublic());
	$proj_funders		= $this->funders();
	$proj_head_idx		= $this->head_idx();
	$proj_members		= $this->num_members();
	$proj_pcs		= $this->num_pcs();
        # These are now booleans, not actual counts.
	$proj_linked		= YesNo($this->linked_to_us());
	$proj_why		= nl2br($this->why());
	$approved		= YesNo($this->approved());
	$expt_count		= $this->expt_count();
	$expt_last		= $this->expt_last();
	$wikiname		= $group->wikiname();
	$cvsrepo_public		= $this->cvsrepo_public();
	$allow_workbench	= $this->allow_workbench();
	$portal                 = $this->portal();
        $nonlocal_id            = $this->nonlocal_id();

	# Before project approval, display ron/plab request status.
	if ($this->approved()) {
	    $proj_ronpcs   =
		YesNo(strpos($this->pcremote_ok(), "pcron") !== false);
	    $proj_plabpcs  = 
		YesNo(strpos($this->pcremote_ok(), "pcplabphys") !== false);
	}
	else {
	    $proj_ronpcs   = YesNo($this->num_ron());
	    $proj_plabpcs  = YesNo($this->num_pcplab());
	}

	if (! ($head_user = User::Lookup($proj_head_idx))) {
	    TBERROR("Could not lookup object for user $proj_head_idx", 1);
	}
	$showuser_url  = CreateURL("showuser", $head_user);
	$showproj_url  = CreateURL("showproject", $this);
	$proj_head_uid = $head_user->uid();

	if (!$expt_last) {
	    $expt_last = "&nbsp;";
	}

	echo "<center>
              <h3>Project Profile</h3>
              </center>
              <table align=center cellpadding=2 border=1>\n";
    
        #
        # Generate the table.
        # 
	echo "<tr>
                  <td>Name: </td>
                  <td class=\"left\">
                      <a href='$showproj_url'>$pid ($proj_idx)</a></td>
              </tr>\n";
    
        if ($nonlocal_id) {
            echo "<tr>
                      <td>Nonlocal ID:</td>
                      <td>$nonlocal_id</td>
                      </tr>\n";
        }
    
	echo "<tr>
                  <td>Description: </td>
                  <td class=\"left\">$proj_name</td>
              </tr>\n";
    
	echo "<tr>
                  <td>Project Head: </td>
                  <td class=\"left\">
                      <a href='$showuser_url'>$proj_head_uid</a></td>
              </tr>\n";
    
	echo "<tr>
              <td>URL: </td>
                  <td class=\"left\">
                      <a href='$proj_URL'>$proj_URL</a></td>
              </tr>\n";

	if (isset($portal)) {
	    echo "<tr>
                  <td>Portal: </td>
                  <td class=\"left\">$portal</td>
              </tr>\n";
	}

	if ($WIKISUPPORT && isset($wikiname)) {
	    $wikiurl = "gotowiki.php3?redurl=$wikiname/WebHome";
	
	    echo "<tr>
                      <td>Project Wiki:</td>
                      <td class=\"left\">
                          <a href='$wikiurl'>$wikiname</a></td>
                  </tr>\n";
	}
	if ($CVSSUPPORT) {
	    $cvsdir = "$TBCVSREPO_DIR/$pid";
	    $cvsurl = "cvsweb/cvswebwrap.php3?pid=$pid";
	
	    echo "<tr>
                      <td>Project CVS Repository:</td>
                      <td class=\"left\">
                          $cvsdir <a href='$cvsurl'>(CVSweb)</a></td>
                  </tr>\n";

	    $YesNo = YesNo($cvsrepo_public);
	    $flip  = ($cvsrepo_public ? 0 : 1);
	    echo "<tr>
                      <td>CVS Repository Publically Readable?:</td>
                      <td><a href='toggle.php?pid=$pid&type=cvsrepo_public".
		          "&value=$flip'>$YesNo</a> (Click to toggle)</td>
                  </tr>\n";

	    if ($cvsrepo_public) {
		$puburl  = "$OPSCVSURL/?cvsroot=$pid";
		$pserver = ":pserver:anoncvs@$USERNODE:/cvsrepos/$pid";
		
		echo "<tr>
                          <td>Public CVSWeb Address:</td>
                          <td><a href=$puburl>" .
		                 htmlspecialchars($puburl) . "</a></td>
                      </tr>\n";

		echo "<tr>
                          <td>CVS pserver Address:</td>
                          <td>" . htmlspecialchars($pserver) . "</td>
                      </tr>\n";
	    }
	}

	if ($MAILMANSUPPORT) {
	    $mmurl   = "gotommlist.php3?pid=$pid";

	    echo "<tr>
                      <td>Project Mailing List:</td>
                      <td class=\"left\">
                          <a href='$mmurl'>${pid}-users</a> ";
	    if (ISADMIN()) {
		$mmurl .= "&wantadmin=1";
		echo "<a href='$mmurl'>(admin access)</a>";
	    }
	    echo "    </td>
                  </tr>\n";

	    if (ISADMIN()) {
		$mmurl   = "gotommlist.php3?listname=${pid}-admin&asadmin=1";

		echo "<tr>
                         <td>Project Admin Mailing List:</td>
                         <td class=\"left\">
                             <a href='$mmurl'>${pid}-admin</a> ";
		$mmurl   = "gotommlist.php3?listname=${pid}-admin&wantadmin=1";
		echo "<a href='$mmurl'>(admin access)</a>";
		echo "    </td>
                     </tr>\n";
	    }
	}

	echo "<tr>
                  <td>Publicly Visible: </td>
                  <td class=\"left\">$proj_public</td>
              </tr>\n";
    
	echo "<tr>
                  <td>Link to Us?: </td>
                  <td class=\"left\">$proj_linked</td>
              </tr>\n";
    
	echo "<tr>
                  <td>Funders: </td>
                  <td class=\"left\">$proj_funders</td>
              </tr>\n";

	echo "<tr>
                  <td>#Project Members: </td>
                  <td class=\"left\">$proj_members</td>
              </tr>\n";
    
	echo "<tr>
                  <td>#PCs: </td>
                  <td class=\"left\">$proj_pcs</td>
              </tr>\n";
    
	echo "<tr>
                  <td>Planetlab Access: </td>
                  <td class=\"left\">$proj_plabpcs</td>
              </tr>\n";
    
	echo "<tr>
                  <td>RON Access: </td>
                  <td class=\"left\">$proj_ronpcs</td>
              </tr>\n";

	# Fine-grained Datapository access: show node_ids over all sub-groups.
	# Should probably do likewise in individual sub-group pages.
	# "dp_projects" node_attributes are lists of group gid_idxs.
        $query_result =
	    DBQueryFatal("select distinct g.gid_idx, a.node_id ".
			 "  from groups as g, node_attributes as a ".
			 "where g.pid_idx='$proj_idx' ".
			 "  and a.attrkey='dp_projects' ".
                         "  and FIND_IN_SET(g.gid_idx, a.attrvalue) ".
			 "order by g.gid_idx, a.node_id");
	$proj_dp_nodes = "";
	while ($row = mysql_fetch_array($query_result)) {
	    $node_id = $row["node_id"];

	    if ($proj_dp_nodes) $proj_dp_nodes .= ", ";
	    $proj_dp_nodes .= $node_id;
	}
	if ($proj_dp_nodes) {
	    echo "<tr>
		      <td>Datapository Access: </td>
		      <td class=\"left\">$proj_dp_nodes</td>
		  </tr>\n";
	}

	echo "<tr>
                  <td>Created: </td>
                  <td class=\"left\">$proj_created</td>
              </tr>\n";
    
	echo "<tr>
                  <td>Experiments Created:</td>
                  <td class=\"left\">$expt_count</td>
              </tr>\n";
    
	echo "<tr>
                  <td>Date of last experiment:</td>
                  <td class=\"left\">$expt_last</td>
              </tr>\n";
    
	echo "<tr>
                  <td>Approved?: </td>
                  <td class=\"left\">$approved</td>
	      </tr>\n";

	if (ISADMIN()) {
	    $YesNo = YesNo($allow_workbench);
	    $flip  = ($allow_workbench ? 0 : 1);
	    
	    echo "<tr>
                      <td>Allow Workbench:</td>
                      <td><a href='toggle.php?pid=$pid&type=workbench".
		          "&value=$flip'>$YesNo</a> (Click to toggle)</td>
                  </tr>\n";
	}

	echo "<tr>
                  <td colspan='2'>Why?:</td>
              </tr>\n";
    
	echo "<tr>
                  <td colspan='2' width=600>$proj_why</td>
              </tr>\n";
    
	echo "</table>\n";
    }

    function ShowGroupList() {
	$groups    = $this->SubGroups();

	echo "<center><h3>Project Groups</h3></center>\n";
	echo "<table id='grouplist' align=center border=1>\n";
	echo "<thead class='sort'>";
	echo "<tr>
               <th>GID</th>
               <th>Description</th>
               <th>Leader</th>
              </tr></thead>\n";

	foreach ($groups as $group) {
	    $gid         = $group->gid();
	    $desc        = $group->description();
	    $leader      = $group->leader();
	    $leader_user = $group->GetLeader();

	    $showuser_url  = CreateURL("showuser", $leader_user);
	    $showgroup_url = CreateURL("showgroup", $group);

	    echo "<tr>
                   <td><A href='$showgroup_url'>$gid</a></td>
                   <td>$desc</td>
                   <td><A href='$showuser_url'>$leader</A></td>
                 </tr>\n";
	}
	echo "</table>\n";

        echo "<script type='text/javascript' language='javascript'>
	       sorttable.makeSortable(getObjbyName('grouplist'));
             </script>\n";
    }

    function ShowStats() {
	$pid_idx  = $this->pid_idx();

	$query_result =
	    DBQueryFatal("select * from project_stats ".
			 "where pid_idx='$pid_idx'");

	if (! mysql_num_rows($query_result)) {
	    return;
	}
	$row = mysql_fetch_assoc($query_result);

        #
        # Not pretty printed yet.
        #
	echo "<table align=center border=1>\n";
    
	foreach($row as $key => $value) {
	    echo "<tr>
                      <td>$key:</td>
                      <td>$value</td>
                  </tr>\n";
	}
	echo "</table>\n";
    }

    #
    # Return license status for all licenses.
    #
    function LicenseStatus() {
	$pid_idx = $this->pid_idx();
        $result  = array();

        $query_result =
            DBQueryFatal("select l.*,pl.pid,pl.accepted from licenses as l ".
                         "left join project_licenses as pl on ".
                         "   pl.license_idx=l.license_idx and ".
                         "   pl.pid_idx='$pid_idx'");

	while ($row = mysql_fetch_array($query_result)) {
            $result[] = $row;
        }
        return $result;
    }

    #
    # 
    #
    function AddNSFAward($award, $supplement) {
	$pid_idx = $this->pid_idx();
	$pid     = $this->pid();

        DBQueryFatal("replace into project_nsf_awards set ".
                     "  idx=null,pid='$pid',pid_idx='$pid_idx', ".
                     "  award='$award',supplement='$supplement'");
        return 0;
    }
    function nsf_awards() {
	$pid_idx = $this->pid_idx();
        $result  = array();

	$query_result =
	    DBQueryWarn("select * from project_nsf_awards ".
			"where pid_idx='$pid_idx'");

	if ($query_result && mysql_num_rows($query_result)) {
            while ($row = mysql_fetch_array($query_result)) {
                $idx = $row["idx"];
                $result[$idx] = $row;
            }
	}
        return $result;
    }
}
?>
