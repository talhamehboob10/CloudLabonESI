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

class Paramset
{
    var	$paramset;
    var $profile;
    var $project;

    function Paramset($token) {
        $query_result = null;
        
	if (preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", $token)) {
            $query_result = DBQueryFatal("select * from apt_parameter_sets ".
                                         "where uuid='$token'");
        }
        elseif (IsValidHash($token)) {
            $query_result = DBQueryFatal("select * from apt_parameter_sets ".
                                         "where hashkey='$token'");
        }
	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->paramset = null;
	    return;
	}
	$this->paramset = mysql_fetch_array($query_result);
        $this->project  = null;
        $this->profile  = null;
    }
    # accessors
    function field($name) {
	return (is_null($this->paramset) ? -1 : $this->paramset[$name]);
    }
    function uuid()	    { return $this->field('uuid'); }
    function uid()          { return $this->field('uid'); }
    function uid_idx()      { return $this->field('uid_idx'); }
    function created()	    { return $this->field('created'); }
    function name()	    { return $this->field('name'); }
    function description()  { return $this->field('description'); }
    function public()	    { return $this->field('public'); }
    function global()	    { return $this->field('global'); }
    function profileid()    { return $this->field('profileid'); }
    function version_uuid() { return $this->field('version_uuid'); }
    function reporef()	    { return $this->field('reporef'); }
    function repohash()	    { return $this->field('repohash'); }
    function bindings()	    { return $this->field('bindings'); }
    function hashkey()	    { return $this->field('hashkey'); }

    # Profile of paramset
    function Profile() {
        if ($this->profile) {
            return $this->profile;
        }
        $this->profile = Profile::Lookup($this->profileid);
        return $this->profile;
    }
    # Project of paramset
    function Project() {
        if ($this->project) {
            return $this->project;
        }
        $profile = $this->Profile();
        if (!$profile) {
            return null;
        }
        $this->project = Project::Lookup($profile->pid_idx());
        return $this->project;
    }
    function IsBound() {
	return $this->version_uuid() ? 1 : 0;
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->paramset);
    }

    # Lookup up a single paramset
    function Lookup($token) {
	$foo = new Paramset($token);

	if ($foo->IsValid()) {
            # Insert into cache.
	    return $foo;
	}	
	return null;
    }

    #
    # Permission check; does user have permission use the set
    #
    function CanUse($user) {
	$uuid = $this->uuid();

        if (ISADMIN()) {
            return 1;
        }
	if ($this->public() || $this->isCreator($user)) {
	    return 1;
	}
	# Otherwise a project membership test.
	$project = $this->Project();
	if (!$project) {
	    return 0;
	}
	$isapproved = 0;
	if ($project->IsMember($user, $isapproved) && $isapproved) {
	    return 1;
	}
	return 0;
    }
    function CanEdit($user) {
	$uuid = $this->uuid();

        if (ISADMIN()) {
            return 1;
        }
        if ($this->isCreator($user)) {
	    return 1;
	}
        return 0;
    }
    function CanDelete($user) {
        if ($this->CanEdit($user)) {
            return 1;
        }
        $project = $this->Project();
	if (!$project) {
	    return 0;
	}
        if ($project->IsLeader($user)) {
	    return 1;
        }
        return 0;
    }
    function isCreator($user) {
        if ($user->uid_idx() == $this->uid_idx()) {
	    return 1;
        }
        return 0;
    }

    #
    # The second arg is to avoid looking up same profile repeatedly. 
    #
    function Blob($user, $profile = null)
    {
        if (!$profile) {
            if ($this->version_uuid()) {
                $profile = Profile::Lookup($this->version_uuid());
            }
            else {
                $profile = Profile::Lookup($this->profileid());
            }
            if (!$profile) {
                return null;
            }
        }
        $blob = array(
            "uuid"                 => $this->uuid(),
            "name"                 => $this->name(),
            "description"          => $this->description(),
            "public"               => $this->public(),
            "global"               => $this->global(),
            "version_uuid"         => $this->version_uuid(),
            "bound"                => $this->version_uuid() ? true : false,
            "created"              => DateStringGMT($this->created()),
            "bindings"             => json_decode($this->bindings()),
            "profile_uuid"         => $profile->profile_uuid(),
            "profile_version_uuid" => $profile->uuid(),
            "profile_name"         => $profile->name(),
            "profile_version"      => $profile->version(),
            "repourl"              => $profile->repourl(),
            "reporef"              => $profile->reporef(),
            "repohash"             => $profile->repohash(),
        );
        $runurl = "instantiate.php?profile=";
	  
        if ($this->version_uuid()) {
	    if ($profile->repourl()) {
                $runurl .= $profile->profile_uuid();
	    }
	    else {
                $runurl .= $this->version_uuid();
	    }
        }
        else {
	    $runurl .= $profile->profile_uuid();
        }
        $runurl .= "&rerun_paramset=" . $this->uuid();
        $blob["run_url"] = $runurl;
        
        if ($profile->creator_idx() == $user->uid_idx()) {
            #
            # Try and figure out a share URL. To make this simple, not going
            # to provide a share link if the paramset is for a non-public
            # profile that belongs to another user.
            #
            if ($this->version_uuid()) {
                # Bound paramset
                $url = $profile->URL();
            }
            else {
                $url = $profile->ProfileURL();
            }
            $url .= preg_match("\?", $url) ? "&" : "?";
            $url .= "rerun_paramset=";
            
            if ($this->public()) {
                $url .= $this->uuid();
            }
            else {
                $url .= $this->hashkey();
            }
            $blob["share_url"] = $url;
        }
        return $blob;
    }
}
?>
