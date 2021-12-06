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
include_once("paramset_defs.php");

function TBvalid_rspec($token) {
    return TBcheck_dbslot($token, "apt_profiles", "rspec",
			  TBDB_CHECKDBSLOT_WARN|TBDB_CHECKDBSLOT_ERROR);
}

class Profile
{
    var	$profile;
    var $project;

    #
    # Constructor by lookup on unique index.
    #
    function Profile($token, $version = null) {
        $query_result = null;
        
	if (preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", $token)) {
	    #
	    # First look to see if the uuid is for the profile itself,
	    # which means current version. Otherwise look for a
	    # version with the uuid.
	    #
	    $query_result =
		DBQueryWarn("select i.*,v.*,i.uuid as profile_uuid, ".
			    "    i.hashkey as profile_hashkey, ".
                            "    i.disabled as profile_disabled, ".
                            "    i.nodelete as profile_nodelete ".
			    "  from apt_profiles as i ".
			    "left join apt_profile_versions as v on ".
			    "     v.profileid=i.profileid and ".
			    "     v.version=i.version ".
			    "where i.uuid='$token' and v.deleted is null");

	    if (!$query_result || !mysql_num_rows($query_result)) {
		$query_result =
		    DBQueryWarn("select i.*,v.*,i.uuid as profile_uuid, ".
                                "    i.hashkey as profile_hashkey, ".
                                "    i.disabled as profile_disabled, ".
                                "    i.nodelete as profile_nodelete ".
				"  from apt_profile_versions as v ".
				"left join apt_profiles as i on ".
				"     v.profileid=i.profileid ".
				"where v.uuid='$token' and ".
				"      v.deleted is null");
	    }
	}
        elseif (preg_match("/^\d+$/", $token)) {
            if (is_null($version)) {
                $query_result =
                    DBQueryWarn("select i.*,v.*,i.uuid as profile_uuid, ".
			    "    i.hashkey as profile_hashkey, ".
                            "    i.disabled as profile_disabled, ".
                            "    i.nodelete as profile_nodelete ".
			    "  from apt_profiles as i ".
			    "left join apt_profile_versions as v on ".
			    "     v.profileid=i.profileid and ".
			    "     v.version=i.version ".
			    "where i.profileid='$token'");
            }
            elseif (preg_match("/^\d+$/", $version)) {
                $query_result =
                    DBQueryWarn("select i.*,v.*,i.uuid as profile_uuid, ".
			    "    i.hashkey as profile_hashkey, ".
                            "    i.disabled as profile_disabled, ".
                            "    i.nodelete as profile_nodelete ".
			    "  from apt_profile_versions as v ".
			    "left join apt_profiles as i on ".
			    "     i.profileid=v.profileid ".
			    "where v.profileid='$token' and ".
			    "      v.version='$version' and ".
			    "      v.deleted is null");
            }
	}
	elseif (IsValidHash($token)) {
	    #
	    # First look to see if the hash is for the profile itself,
	    # which means current version. Otherwise look for a
	    # version with the hash
	    #
	    $query_result =
		DBQueryWarn("select i.*,v.*,i.uuid as profile_uuid, ".
			    "    i.hashkey as profile_hashkey, ".
                            "    i.disabled as profile_disabled, ".
                            "    i.nodelete as profile_nodelete ".
			    "  from apt_profiles as i ".
			    "left join apt_profile_versions as v on ".
			    "     v.profileid=i.profileid and ".
			    "     v.version=i.version ".
			    "where i.hashkey='$token' and v.deleted is null");

	    if (!$query_result || !mysql_num_rows($query_result)) {
		$query_result =
		    DBQueryWarn("select i.*,v.*,i.uuid as profile_uuid, ".
                                "    i.hashkey as profile_hashkey, ".
                                "    i.disabled as profile_disabled, ".
                                "    i.nodelete as profile_nodelete ".
				"  from apt_profile_versions as v ".
				"left join apt_profiles as i on ".
				"     v.profileid=i.profileid ".
				"where v.hashkey='$token' and ".
				"      v.deleted is null");
	    }
	}
	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->profile = null;
	    return;
	}
	$this->profile = mysql_fetch_array($query_result);

	# Load lazily;
	$this->project    = null;
    }
    # accessors
    function field($name) {
	return (is_null($this->profile) ? -1 : $this->profile[$name]);
    }
    function name()	    { return $this->field('name'); }
    function profileid()    { return $this->field('profileid'); }
    function version()      { return $this->field('version'); }
    function creator()	    { return $this->field('creator'); }
    function creator_idx()  { return $this->field('creator_idx'); }
    function updater()	    { return $this->field('updater'); }
    function updater_idx()  { return $this->field('updater_idx'); }
    function pid()	    { return $this->field('pid'); }
    function pid_idx()	    { return $this->field('pid_idx'); }
    function created()	    { return $this->field('created'); }
    function published()    { return $this->field('published'); }
    function deleted()	    { return $this->field('deleted'); }
    function uuid()	    { return $this->field('uuid'); }
    function profile_uuid() { return $this->field('profile_uuid'); }
    function ispublic()	    { return $this->field('public'); }
    function shared()	    { return $this->field('shared'); }
    function listed()	    { return $this->field('listed'); }
    function rspec()	    { return $this->field('rspec'); }
    function script()	    { return $this->field('script'); }
    function paramdefs()    { return $this->field('paramdefs'); }
    function locked()	    { return $this->field('status'); }
    function status()	    { return $this->field('locked'); }
    function topdog()	    { return $this->field('topdog'); }
    function disabled()	    { return $this->field('disabled'); }
    function nodelete()	    { return $this->field('nodelete'); }
    function project_write(){ return $this->field('project_write'); }
    function repourl()	    { return $this->field('repourl'); }
    function reponame()	    { return $this->field('reponame'); }
    function reporef()	    { return $this->field('reporef'); }
    function repohash()	    { return $this->field('repohash'); }
    function repokey()	    { return $this->field('repokey'); }
    function webtask_id()   { return $this->field('webtask_id'); }
    function lastused()     { return $this->field('lastused'); }
    function usecount()     { return $this->field('usecount'); }
    function hashkey()       { return $this->field('hashkey'); }
    function profile_hashkey()     { return $this->field('profile_hashkey'); }
    function profile_disabled()    { return $this->field('profile_disabled'); }
    function parent_profileid()    { return $this->field('parent_profileid'); }
    function parent_version()      { return $this->field('parent_version'); }
    function profile_nodelete()    { return $this->field('profile_nodelete'); }
    function portal_converted()    { return $this->field('portal_converted'); }
    function examples_portals()    { return $this->field('examples_portals'); }

    # Project of profile
    function Project() {
        if ($this->project) {
            return $this->project;
        }
        $this->project = Project::Lookup($this->pid_idx());
        return $this->project;
    }
    # Private means only in the same project.
    function IsPrivate() {
	return !($this->ispublic() || $this->shared());
    }
    # PP profiles have parameter defs.
    function isParameterized() {
	return ($this->paramdefs() != "" ? 1 : 0);
    }
    # A profile is disabled if version is disabled or entire profile is disabled
    function isDisabled() {
	return ($this->disabled() || $this->profile_disabled());
    }
    # Ditto nodelete.
    function isLocked() {
	return ($this->nodelete() || $this->profile_nodelete());
    }
    # Grab the webtask. Backwards compat mode, see if there is one associated
    # with the object, use that. Otherwise create a new one.
    function WebTask() {
        if ($this->webtask_id()) {
            $webtask = WebTask::Lookup($this->webtask_id());
            if ($webtask) {
                return $webtask;
            }
        }
        $webtask = WebTask::LookupByObject($this->uuid());
        if (!$webtask) {
            $webtask = WebTask::CreateAnonymous();
            if (!$webtask) {
                return null;
            }
        }
        $profileid  = $this->profileid();
        $webtask_id = $webtask->task_id();
        DBQueryFatal("update apt_profiles set ".
                     "  webtask_id='$webtask_id' ".
                     "where profileid='$profileid'");
        return $webtask;
    }
    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->profile);
    }

    # Lookup up a single profile by idx. 
    function Lookup($token, $version = null) {
	$foo = new Profile($token, $version);

	if ($foo->IsValid()) {
            # Insert into cache.
	    return $foo;
	}	
	return null;
    }

    function LookupByName($project, $name, $version = null) {
        if (is_object($project)) {
            $pid = $project->pid();
        }
        else {
            $pid = addslashes($project);
        }
	$safe_name = addslashes($name);
        
	if (preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", $name)) {
	    return Profile::Lookup($name);
	}
	elseif (is_null($version)) {
	    $query_result =
		DBQueryWarn("select i.profileid,i.version ".
			    "  from apt_profiles as i ".
			    "left join apt_profile_versions as v on ".
			    "     v.profileid=i.profileid and ".
			    "     v.version=i.version ".
			    "where i.pid='$pid' and ".
			    "      i.name='$safe_name'");
	}
	else {
	    $safe_version = addslashes($version);
	    $query_result =
		DBQueryWarn("select i.profileid,v.version ".
			    "  from apt_profiles as i ".
			    "left join apt_profile_versions as v on ".
			    "     v.profileid=i.profileid ".
			    "where i.pid='$pid' and ".
			    "      i.name='$safe_name' and ".
			    "      v.version='$safe_version'");
	}
	if ($query_result && mysql_num_rows($query_result)) {
	    $row = mysql_fetch_row($query_result);
	    return Profile::Lookup($row[0], $row[1]);
	}
	return null;
    }

    #
    # Lookup the most recently published version of a profile.
    #
    function LookupMostRecentPublished() {
	$profileid = $this->profileid();

	$query_result = 
	    DBQueryWarn("select version from apt_profile_versions as v ".
			"where v.profileid='$profileid' and ".
			"      published is not null and ".
			"      deleted is null ".
			"order by published desc limit 1");

	if (!$query_result || !mysql_num_rows($query_result)) {
	    return null;
	}
	$row = mysql_fetch_row($query_result);
	return Profile::Lookup($profileid, $row[0]);
    }

    #
    # Refresh an instance by reloading from the DB.
    #
    function Refresh() {
	if (! $this->IsValid())
	    return -1;

	$profileid = $this->profileid();
	$version   = $this->version();

	$query_result =
	    DBQueryWarn("select * from apt_profile_versions ".
			"where profileid='$profileid' and version='$version'");
    
	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->profile    = NULL;
	    $this->project    = null;
	    return -1;
	}
	$this->profile    = mysql_fetch_array($query_result);
	$this->project    = null;
	return 0;
    }

    function UserHasProfiles($user) {
	$uid = $user->uid();

	$query_result =
	    DBQueryFatal("select profileid from apt_profile_versions ".
			 "where creator='$uid' and deleted is null");

	return mysql_num_rows($query_result);
    }

    #
    # URL. To the specific version of the profile.
    #
    function URL() {
        global $APTBASE, $ISVSERVER, $ISAPT;

        # Repo based profiles are always to the profile not version.
        if ($this->repourl()) {
            return $this->ProfileURL();
        }
	$uuid = $this->uuid();
	$hash = $this->hashkey();
        $url  = "$APTBASE";

	if ($this->ispublic() || (!$ISAPT && $this->shared())) {
	    $pid  = $this->pid();
	    $name = $this->name();
	    $vers = $this->version();
	    if ($ISVSERVER) {
                $url .= "/p/$pid/$name/$vers";
            }
            else {
                $url .= "/instantiate.php?profile=$name".
                     "&project=$pid&version=$vers";
            }
	}
	else {
	    if ($ISVSERVER) {
		$url .= "/p/$hash";
            }
            else {
                $url .= "/instantiate.php?profile=$hash";
            }
	}
        return $url;
    }
    # And the URL of the profile itself.
    function ProfileURL() {
        global $APTBASE, $ISVSERVER, $ISAPT;
	
	$uuid = $this->profile_uuid();
	$hash = $this->profile_hashkey();
        $url  = "$APTBASE";

	if ($this->ispublic() || (!$ISAPT && $this->shared())) {
	    $pid  = $this->pid();
	    $name = $this->name();
	    if ($ISVSERVER) {
		$url .= "/p/$pid/$name";
            }
            else {
                $url .= "/instantiate.php?profile=$name&project=$pid";
            }
	}
	else {
	    if ($ISVSERVER) {
		$url .= "/p/$hash";
            }
            else {
                $url .= "/instantiate.php?profile=$hash";
            }
	}
        return $url;
    }

    #
    # Is this profile the highest numbered version.
    # 
    function IsHead() {
	$profileid = $this->profileid();

	$query_result =
	    DBQueryWarn("select max(version) from apt_profile_versions ".
			"where profileid='$profileid' and deleted is null");
	if (!$query_result || !mysql_num_rows($query_result)) {
	    return -1;
	}
	$row = mysql_fetch_row($query_result);
	return ($this->version() == $row[0] ? 1 : 0);
    }
    #
    # Does this profile have more then one version (history).
    # 
    function HasHistory() {
	$profileid = $this->profileid();

	$query_result =
	    DBQueryWarn("select count(*) from apt_profile_versions ".
			"where profileid='$profileid'");
	if (!$query_result || !mysql_num_rows($query_result)) {
	    return -1;
	}
	$row = mysql_fetch_row($query_result);
	return ($row[0] > 1 ? 1 : 0);
    }
    #
    # A profile can be published if it is a > version then the most
    # recent published profile. 
    # 
    function CanPublish() {
	$profileid = $this->profileid();

	# Already published. Might support unpublish at some point.
	if ($this->published())
	    return 0;

	$query_result =
	    DBQueryWarn("select version from apt_profile_versions ".
			"where profileid='$profileid' and ".
			"      published is not null ".
			"order by version desc limit 1");
	if (!$query_result || !mysql_num_rows($query_result)) {
	    return -1;
	}
	$row = mysql_fetch_row($query_result);
	$vers = $row[0];
	
	return ($this->version() > $row[0] ? 1 : 0);
    }
    #
    # A profile can be modified if it is a >= version then the most
    # recent published profile. 
    # 
    function CanModify() {
	$profileid = $this->profileid();

	$query_result =
	    DBQueryWarn("select version from apt_profile_versions ".
			"where profileid='$profileid' and ".
			"      published is not null ".
			"order by version desc limit 1");
	if (!$query_result || !mysql_num_rows($query_result)) {
	    return -1;
	}
	$row = mysql_fetch_row($query_result);
	$vers = $row[0];
	
	return ($this->version() >= $row[0] ? 1 : 0);
    }
    #
    # Has a profile been instantiated?
    #
    function HasActivity($user) {
	$profileid = $this->profileid();
        $clause    = "";

        if (!ISADMIN()) {
            $clause = "and creator_idx='" . $user->uid_idx() . "'";
        }

	$query_result =
	    DBQueryWarn("select count(uuid) from apt_instance_history ".
			"where profile_id='$profileid' $clause");

	if (!$query_result) {
	    return 0;
	}
	if (mysql_num_rows($query_result)) {
	    $row = mysql_fetch_row($query_result);
	    if ($row[0] > 0) {
		return 1;
	    }
	}
	$query_result =
	    DBQueryWarn("select count(uuid) from apt_instances ".
			"where profile_id='$profileid' $clause");

	if (!$query_result) {
	    return 0;
	}
	if (mysql_num_rows($query_result)) {
	    $row = mysql_fetch_row($query_result);
	    if ($row[0] > 0) {
		return 1;
	    }
	}
	return 0;
    }

    #
    # Permission check; does user have permission to instantiate the
    # profile. At the moment, view/instantiate are the same.
    #
    function CanInstantiate($user) {
	$profileid = $this->profileid();

        if (ISADMIN()) {
            return 1;
        }
	if ($this->shared() || $this->ispublic() ||
	    $this->creator_idx() == $user->uid_idx()) {
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
    function CanView($user) {
	return $this->CanInstantiate($user);
    }
    function CanClone($user) {
	return $this->CanInstantiate($user);
    }
    function CanEdit($user) {
        if ($this->creator_idx() == $user->uid_idx() || ISADMIN()) {
            return 1;
        }
	$project = Project::Lookup($this->pid_idx());
	if (!$project) {
	    return 0;
	}
        if ($user->uid_idx() == $project->GetLeader()->uid_idx()) {
	    return 1;
        }
        if ($this->project_write()) {
            $approved = 0;
            if ($project->IsMember($user, $approved) && $approved) {
                return 1;
            }
        }
        return 0;
    }
    function CanDelete($user) {
        if ($this->nodelete()) {
            return 0;
        }
	# Want to know if the project is APT or Cloud/Emulab. APT projects
        # may not delete profiles (yet).
	$project = Project::Lookup($this->pid_idx());
	if (!$project) {
	    return 0;
	}
        if ($project->isAPT()) {
            return 0;
        }
        if ($this->creator_idx() == $user->uid_idx() || ISADMIN() ||
            $user->uid_idx() == $project->GetLeader()->uid_idx()) {
	    return 1;
        }
        return 0;
    }
    function isLeader($user) {
	$project = Project::Lookup($this->pid_idx());
	if (!$project) {
	    return 0;
	}
        if ($user->uid_idx() == $project->GetLeader()->uid_idx()) {
	    return 1;
        }
        return 0;
    }
    function isCreator($user) {
        if ($user->uid_idx() == $this->creator_idx()) {
	    return 1;
        }
        return 0;
    }
    function anonCreator() {
        $creator = User::Lookup($this->creator_idx());
        if (!$creator) {
            return "";
        }
        $tokens = preg_split("/\s+/", $creator->name());
        if (count($tokens) == 1) {
            return $tokens[0];
        }
        return $tokens[0] . " " . substr(end($tokens), 0 , 1);
    }

    function UsageInfo($user) {
        $profile_id  = $this->profileid();
        $userclause  = "";

        if ($user) {
            $creator_idx = $user->idx();
            $userclause  = "and creator_idx='$creator_idx' ";
        }

        #
        # This is last used.
        #
        $query_result =
            DBQueryFatal("select max(UNIX_TIMESTAMP(started)) as started ".
                         "  from apt_instances ".
                         "where profile_id='$profile_id' ".
                         $userclause);
        $row = mysql_fetch_row($query_result);
        if (!$row["started"]) {
            $query_result =
                DBQueryFatal("select max(UNIX_TIMESTAMP(started)) as started ".
                             "  from apt_instance_history ".
                             "where profile_id='$profile_id' ".
                             $userclause);
            $row = mysql_fetch_row($query_result);
        }
        if (!$row["started"]) {
            return array(0, 0);
        }
        $lastused = $row[0];

        #
        # Now we want number of times used.
        #
        $count = 0;
        $query_result =
            DBQueryFatal("select ".
                         "(select count(profile_id) ".
                         "   from apt_instances ".
                         " where profile_id='$profile_id' ".
                           $userclause . ") as count1, ".
                         "(select count(profile_id) ".
                         "   from apt_instance_history ".
                         " where profile_id='$profile_id' ".
                           $userclause . ") as count2");
        if (mysql_num_rows($query_result)) {
            $row   = mysql_fetch_row($query_result);
            $count = ($row[0] ? $row[0] : 0) + ($row[1] ? $row[1] : 0);
        }
        return array($lastused, $count);
    }

    function isFavorite($user) {
        if (!$user) {
            return 0;
        }
        $profile_id  = $this->profileid();
        $user_idx    = $user->idx();

        $query_result =
            DBQueryFatal("select * from apt_profile_favorites ".
                         "where uid_idx='$user_idx' and ".
                         "      profileid='$profile_id'");

        return mysql_num_rows($query_result);
    }

    function MarkFavorite($user) {
        $profile_id  = $this->profileid();
        $user_uid    = $user->uid();
        $user_idx    = $user->idx();

        if (!DBQueryWarn("replace into apt_profile_favorites set ".
                         "  uid='$user_uid',uid_idx='$user_idx', ".
                         "  profileid='$profile_id',marked=now()")) {
            return -1;
        }
        return 0;
    }

    function ClearFavorite($user) {
        $profile_id  = $this->profileid();
        $user_uid    = $user->uid();
        $user_idx    = $user->idx();

        if (!DBQueryWarn("delete from apt_profile_favorites ".
                         "where uid_idx='$user_idx' and ".
                         "      profileid='$profile_id'")) {
            return -1;
        }
        return 0;
    }

    function BestAggregate($rspec = null) {
        return null;
    }

    function GenerateFormFragment($json_data = null) {
        if (is_null($json_data)) {
            $json_data = $this->paramdefs();
        }
	if (!$json_data || $json_data == "") {
	    return "";
	}
	$fields    = json_decode($json_data);
	$defaults  = array();
	$formBasic    = "";
	$formAdvanced = "";
	$formGroups   = "";

	while (list ($name, $val) = each ($fields)) {
	    $form    = "";
	    $type    = $val->type;
	    $prompt  = $val->description;
	    $defval  = $val->defaultValue;
	    $options = $val->legalValues;
	    $longhelp  = $val->longDescription;
	    $advanced  = $val->advanced;
	    $groupId   = $val->groupId;
	    $groupName = $val->groupName;
	    $hasGroup = false;
	    $data_help_string = "";
	    $advanced_attr = "";

	    $defaults[$name] = $defval;
	    if (!isset($prompt) || !$prompt) {
		$prompt = $name;
	    }
	    if (!isset($advanced)) {
		$advanced = false;
	    }
            # Let advanced-tagged params dominate groupId; we don't generate groupId yet anyway.
	    if ($advanced) {
		$advanced_attr = " pp-param-group='advanced' pp-param-group-name='Advanced Parameters'";
	    }
	    else if (isset($groupId) && $groupId && isset($groupName) && $groupName) {
		$advanced_attr = " pp-param-group='$groupId' pp-param-group-name='$groupName'";
		$hasGroup = true;
	    }
	    if (isset($longhelp) && $longhelp) {
		$data_help_string = "data-help='$longhelp'";
	    }

	    if ($type == "boolean") {
		$form .=
		    "<input name='$name' ".
		    "      <%- formfields.${name} %> ".
		    "      style='margin: 0px; height: 34px;' ".
		    "      class='format-me' ".
		    "      data-key='$name' ".
		    "      data-label='$prompt' ".
		    "      $data_help_string $advanced_attr".
		    "      value='checked' ".
		    "      type='checkbox'>";
		if ($defval) {
		    $defaults[$name] = "checked";
		}
		else {
		    $defaults[$name] = "";
		}
	    }
	    elseif ($options) {
		$form .=
		    "<select name='$name' ".
		    "       class='form-control format-me' ".
		    "       data-key='$name' ".
		    "       data-label='$prompt' ".
		    "       $data_help_string $advanced_attr".
		    "       placeholder='Please Select'> ";
		foreach ($options as $option) {
		    if (gettype($option) == "array") {
			$oval = $option[0];
			$okey = $option[1];
		    }
		    else {
			$okey = $oval = $option;
		    }
		    $form .= "<option";
		    $form .= 
			"<% if (_.has(formfields, '$name') && ".
			"       formfields.${name} == '$oval') { %> ".
			"   selected ".
			"<% } %> ".
			"value='$oval'>$okey</option>";
		}
		$form .= "</select>";
	    }
	    elseif ($type == "image") {
	        $form .=
		    "<div class='format-me' ".
		    "data-key='$name' ".
		    "data-label='$prompt' ".
		    "data-type='$type' ".
		    "$data_help_string $advanced_attr >".

		    "<div class='input-group'>".

		    "<input id='image-display' ".
		    "type='text' readonly ".
		    "class='form-control' ".
		    "value='<% var label = formfields.${name}; var sp = label.split('+'); var image_display; if (sp.length >= 4){ if (sp[3].substr(0, 12) == 'emulab-ops//') { image_display = sp[3].substr(12) } else { image_display = sp[3] } } else { image_display = formfields.${name} } %><%- image_display %>' >".


		    "<span class='input-group-btn'><button class='btn btn-success' id='image-select' ".
		    "style='height: 34px' ".
		    "type='button' ".
		    "$data_help_string $advanced_attr ".
		    "><span class='glyphicon glyphicon-pencil'></span></button></span> ".

		    "</div>".
		    
		    "<input id='image-value' ".
		    "name='$name' type='hidden' ".
		    "value='<%- formfields.${name} %>' >".

		    "</div>";
	    }
	    else {
		$form .=
		    "<input name='$name' ".
		    "value='<%- formfields.${name} %>' ".
		    "class='form-control format-me' ".
		    "data-key='$name' ".
		    "data-label='$prompt' ".
		    "$data_help_string $advanced_attr".
		    "type='text'>";
	    }

	    if ($advanced) {
		$formAdvanced .= $form;
	    }
	    else if ($hasGroup) {
		$formGroups .= $form;
	    }
	    else {
		$formBasic .= $form;
	    }
	}

	$finalForm = $formBasic . $formAdvanced . $formGroups;

	return array($finalForm, $defaults);
    }

    function RecentExperiments($user)
    {
        return Instance::RecentExperiments($user, $this);
    }

    function HasParamsets($user)
    {
        $uid_idx    = $user->uid_idx();
        $profile_id = $this->profileid();

        $query_result = 
            DBQueryFatal("select s.uuid from apt_parameter_sets as s ".
                         "where s.uid_idx='$uid_idx' and ".
                         "      s.profileid='$profile_id' ");
        
        return mysql_num_rows($query_result);
    }

    function ParameterSets($user) {
        return $this->Paramsets($user);
    }
    
    function Paramsets($user)
    {
        $uid_idx    = $user->uid_idx();
        $profile_id = $this->profileid();

        #
        # Watch for version specific parameter set, switch the profile_uuid
        # to that version. Note that repo based profiles are always version
        # zero, we have to add another argument to the url instead.
        #
        $query_result =
            DBQueryFatal("select s.uuid from apt_parameter_sets as s ".
                         "where (s.uid_idx='$uid_idx' or ".
                         "       (s.uid_idx!='$uid_idx' and s.global=1)) and ".
                         "      s.profileid='$profile_id' ".
                         "order by s.name,s.created");
        
        if (! mysql_num_rows($query_result)) {
            return null;
        }

        $owner  = array();
        $global = array();
        
        while ($row = mysql_fetch_array($query_result)) {
            $paramset = Paramset::Lookup($row["uuid"]);
            if (!$paramset) {
                continue;
            }
            if ($paramset->version_uuid()) {
                $profile = Profile::Lookup($paramset->version_uuid());
                if (!$profile) {
                    continue;
                }
            }
            else {
                $profile = $this;
            }
            $blob = $paramset->Blob($user, $profile);
            if (!$blob) {
                continue;
            }
            if ($paramset->global() && $paramset->uid_idx() != $uid_idx) {
                $global[] = $blob;
            }
            else {
                $owner[] = $blob;
            }
        }
        return array(
            "owner"  => $owner,
            "global" => $global,
        );
    }

    #
    # Temporary hack to control who gets the new genilib code.
    #
    function UseNewGeniLib()
    {
        return 1;
    }
}
?>
