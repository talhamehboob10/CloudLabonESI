<?php
#
# Copyright (c) 2006-2020 University of Utah and the Flux Group.
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

define("GLOBAL_PERM_ANON_RO_IDX",  1);
define("GLOBAL_PERM_USER_RO_IDX",  2);

class Lease
{
    var	$lease;
    var $attributes;
    var $project;

    #
    # Constructor by lookup on unique index.
    #
    function Lease($token) {
	$safe_token = addslashes($token);
	$query_result = null;

	if (preg_match("/^\d+$/", $token)) {
	    $query_result =
		DBQueryWarn("select * from project_leases ".
			    "where lease_idx='$safe_token'");
	}
	elseif (preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", $token)) {
	    $query_result =
		DBQueryWarn("select * from project_leases ".
			    "where uuid='$safe_token'");
	}
	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->lease = NULL;
	    return;
	}
	$this->lease = mysql_fetch_array($query_result);
	$lease_idx   = $this->lease_idx();

	#
	# Load the attributes.
	#
	$query_result =
	    DBQueryWarn("select attrkey,attrval ".
			"  from lease_attributes ".
			"  where lease_idx='$lease_idx'");
	if (!$query_result) {
	    $this->lease = NULL;
	    return;
	}
	$attrs = array();

	while ($row = mysql_fetch_array($query_result)) {
	    $key = $row["attrkey"];
	    $val = $row["attrval"];
	    $attrs[$key] = $val;
	}
	$this->attributes = $attrs;
	# Load lazily;
	$this->project    = null;
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->lease);
    }

    # Lookup.
    function Lookup($token) {
	$foo = new Lease($token);

	if (! $foo->IsValid()) {
	    return null;
	}
	return $foo;
    }
    # Lookup by name in a project
    function LookupByName($project, $name) {
	$pid       = $project->pid();
	$safe_name = addslashes($name);
	
	$query_result =
	    DBQueryFatal("select lease_idx from project_leases ".
			 "where pid='$pid' and lease_id='$safe_name'");

	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	return Lease::Lookup($row["lease_idx"]);
    }
    # Lookup for project
    function LookupAllByProject($project) {
	$pid    = $project->pid();
        $result = array();
	
	$query_result =
	    DBQueryFatal("select lease_idx from project_leases ".
			 "where pid='$pid'");
	while ($row = mysql_fetch_array($query_result)) {
            $lease = Lease::Lookup($row["lease_idx"]);
            if ($lease) {
                $result[] = $lease;
            }
        }
	return $result;
    }

    # accessors
    function field($name) {
	return (is_null($this->lease) ? -1 : $this->lease[$name]);
    } 
    function lease_idx()     { return $this->field("lease_idx"); }
    function idx()           { return $this->field("lease_idx"); }
    function lease_id()      { return $this->field("lease_id"); }
    function id()            { return $this->field("lease_id"); }
    function owner_uid()     { return $this->field("owner_uid"); }
    function uuid()          { return $this->field("uuid"); }
    function pid()           { return $this->field("pid"); }
    function gid()           { return $this->field("gid"); }
    function lease_type()    { return $this->field("type"); }
    function type()          { return $this->field("type"); }
    function inception()     { return NullDate($this->field("inception")); }
    function created()       { return $this->inception(); }
    function lease_end()     { return NullDate($this->field("lease_end")); }
    function expires()       { return $this->lease_end(); }
    function last_used()     { return NullDate($this->field("last_used")); }
    function state()	     { return $this->field("state"); }
    function locked()	     { return $this->field("locked"); }
    function locker_pid()    { return $this->field("locker_pid"); }
    function updated()       { return null; }

    function attribute($key) {
	if (array_key_exists($key, $this->attributes)) {
	    return $this->attributes[$key];
	}
	return null;
    }
    function size()	{ return $this->attribute("size"); }
    function fstype()	{ return $this->attribute("fstype"); }
    function islocal()  { return 1; }

    #
    # This is incomplete.
    #
    function AccessCheck($user, $access_type) {
        global $LEASE_ACCESS_READINFO;
        global $LEASE_ACCESS_MODIFYINFO;
        global $LEASE_ACCESS_READ;
        global $LEASE_ACCESS_MODIFY;
        global $LEASE_ACCESS_DESTROY;
        global $LEASE_ACCESS_MIN;
        global $LEASE_ACCESS_MAX;
	global $TBDB_TRUST_USER;
	global $TBDB_TRUST_GROUPROOT;
	global $TBDB_TRUST_LOCALROOT;

	$mintrust = $LEASE_ACCESS_READINFO;
        $read_access  = $this->read_access();
        $write_access = $this->write_access();
        
        #
        # Admins do whatever they want.
        # 
	if (ISADMIN()) {
	    return 1;
	}
	if ($this->owner_uid() == $user->uid()) {
	    return 1;
	}
        if ($read_access == "global") {
            if ($access_type == $LEASE_ACCESS_READINFO) {
                return 1;
            }
        }
        if ($write_access == "creator") {
            if ($access_type == $LEASE_ACCESS_MODIFY) {
                return 0;
            }
        }
	$pid    = $this->pid();
	$gid    = $this->gid();
	$uid    = $user->uid();
	$uid_idx= $user->uid_idx();
	$pid_idx= $user->uid_idx();
	$gid_idx= $user->uid_idx();
        
        #
        # Otherwise must have proper trust in the project.
        # 
	if ($access_type == $LEASE_ACCESS_READINFO) {
	    $mintrust = $TBDB_TRUST_USER;
	}
	elseif ($access_type == $LEASE_ACCESS_DESTROY ||
                $access_type == $LEASE_ACCESS_MODIFYINFO) {
	    $mintrust = $TBDB_TRUST_GROUPROOT;
	}
	else {
	    $mintrust = $TBDB_TRUST_LOCALROOT;
	}
	if (TBMinTrust(TBGrpTrust($uid, $pid, $gid), $mintrust) ||
	    TBMinTrust(TBGrpTrust($uid, $pid, $pid), $TBDB_TRUST_GROUPROOT)) {
	    return 1;
	}
	return 0;
    }

    function read_access() {
        $lease_idx = $this->lease_idx();
        $perm_idx  = GLOBAL_PERM_ANON_RO_IDX;

        $query_result =
            DBQueryFatal("select * from lease_permissions ".
                         "where lease_idx='$lease_idx' and ".
                         "      permission_idx='$perm_idx'");
        
	if (mysql_num_rows($query_result) == 0) {
	    return "project";
	}
        else {
            return "global";
        }
    }
    function write_access() {
        $lease_idx = $this->lease_idx();
        $pid       = $this->pid();

        $query_result =
            DBQueryFatal("select * from lease_permissions ".
                         "where lease_idx='$lease_idx' and ".
                         "      permission_id='$pid' and allow_modify=1");
        
	if (mysql_num_rows($query_result)) {
	    return "project";
	}
        else {
            return "creator";
        }
    }

    #
    # Form a URN for the dataset. No subgroup support yet.
    #
    function URN() {
	global $OURDOMAIN;
        $pid    = $this->pid();
        $gid    = $this->gid();
        $id     = $this->id();
        $type   = $this->type();
        $domain = $OURDOMAIN;
        $domain .= ":${pid}";
        if ($pid != $gid)
            $domain .= ":${gid}";
	
	return "urn:publicid:IDN+${domain}+${type}+${id}";
    }

    # We ignore webtasks for classic UI
    function deleteCommand($webtask) {
	return  "webdeletelease -f -b " . $this->pid() . "/" . $this->id();
    }
    function grantCommand($webtask) {
	return  "webgrantlease ";
    }

    function Project() {
	$pid = $this->pid();

	if ($this->project)
	    return $this->project;

	$this->project = Project::Lookup($pid);
	if (! $this->project) {
	    TBERROR("Could not lookup project $pid!", 1);
	}
	return $this->project;
    }
}

#
# This is basically a wrapper around an image acting as a dataset.
#
class ImageDataset
{
    var	$image;
    var $project;

    #
    # Constructor by lookup on unique index.
    #
    function ImageDataset($token) {
        $image = Image::LookupByUUID($token);
        if (!$image || !$image->isdataset()) {
	    $this->image = NULL;
	    return;
        }
        $this->image = $image;
	# Load lazily;
	$this->project = null;
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->image);
    }

    # Lookup by uuid.
    function Lookup($token) {
        $image = Image::LookupByUUID($token);
        if (!$image || !$image->isdataset()) {
            return null;
        }
	return new ImageDataset($token);
    }
    # Lookup by name in a project
    function LookupByName($project, $name) {
        $image = Image::LookupByName($project, $name);
        If (!$image || !$image->isdataset()) {
            return null;
        }
	return ImageDataset::Lookup($image->image_uuid());
    }

    # accessors
    function idx()           { return $this->image->imageid(); }
    function dataset_id()    { return $this->image->imagename(); }
    function id()            { return $this->dataset_id(); }
    function creator_uid()   { return $this->image->creator(); }
    function owner_uid()     { return $this->image->creator(); }
    # Use the image uuid here.
    function uuid()          { return $this->image->image_uuid(); }
    function pid()           { return $this->image->pid(); }
    function pid_idx()       { return $this->image->pid_idx(); }
    function gid()           { return $this->image->pid(); }
    function aggregate_urn() { return ""; }
    function type()          { return "imdataset"; }
    function fstype()        { return "unknown"; }
    function created()       { return NullDate($this->image->created()); }
    function expires()       { return ""; }
    function last_used()     { return ""; }
    function locked()	     { return $this->image->locked(); }
    function locker_pid()    { return $this->image->locker_pid(); }
    function islocal()       { return 1; }
    function updated()       { return $this->image->updated(); }

    #
    # Convert to mebi.
    #
    function size() {
        return intval((($this->image->lba_high() -
                        $this->image->lba_low() + 1) *
                       $this->image->lba_size()) /
                      pow(2, 20));
    }

    function state() {
        return ($this->image->locked() ? "imaging" :
                $this->image->size() ? "valid" : "allocated");
    }

    #
    # This is incomplete.
    #
    function AccessCheck($user, $access_type) {
        global $LEASE_ACCESS_READINFO;
        global $LEASE_ACCESS_MODIFYINFO;
        global $LEASE_ACCESS_READ;
        global $LEASE_ACCESS_MODIFY;
        global $LEASE_ACCESS_DESTROY;
        global $LEASE_ACCESS_MIN;
        global $LEASE_ACCESS_MAX;
	global $TBDB_TRUST_USER;
	global $TBDB_TRUST_GROUPROOT;
	global $TBDB_TRUST_LOCALROOT;

	$mintrust = $LEASE_ACCESS_READINFO;
        $read_access  = $this->read_access();
        $write_access = $this->write_access();
        #
        # Admins do whatever they want.
        # 
	if (ISADMIN()) {
	    return 1;
	}
	if ($this->creator_uid() == $user->uid()) {
	    return 1;
	}
        if ($read_access == "global") {
            if ($access_type == $LEASE_ACCESS_READINFO) {
                return 1;
            }
        }
        if ($write_access == "creator") {
            if ($access_type == $LEASE_ACCESS_MODIFY) {
                return 0;
            }
        }
	$pid    = $this->pid();
	$gid    = $this->gid();
	$uid    = $user->uid();
	$uid_idx= $user->uid_idx();
	$pid_idx= $user->uid_idx();
	$gid_idx= $user->uid_idx();
        
        #
        # Otherwise must have proper trust in the project.
        # 
	if ($access_type == $LEASE_ACCESS_READINFO) {
	    $mintrust = $TBDB_TRUST_USER;
	}
	elseif ($access_type == $LEASE_ACCESS_DESTROY ||
                $access_type == $LEASE_ACCESS_MODIFYINFO) {
	    $mintrust = $TBDB_TRUST_GROUPROOT;
	}
	else {
	    $mintrust = $TBDB_TRUST_LOCALROOT;
	}
	if (TBMinTrust(TBGrpTrust($uid, $pid, $gid), $mintrust) ||
	    TBMinTrust(TBGrpTrust($uid, $pid, $pid), $TBDB_TRUST_GROUPROOT)) {
	    return 1;
	}
	return 0;
    }

    function read_access() {
	if ($this->image->isglobal()) {
	    return "global";
	}
        else {
            return "project";
        }
    }
    function write_access() {
        $imageid = $this->image->imageid();
        $pid     = $this->pid();

        $query_result =
            DBQueryFatal("select * from image_permissions ".
                         "where imageid='$imageid' and ".
                         "      permission_id='$pid' and allow_write=1");
        
	if (mysql_num_rows($query_result)) {
	    return "project";
	}
        else {
            return "creator";
        }
    }

    #
    # Form a URN for the dataset.
    #
    function URN() {
	global $OURDOMAIN;
        $pid    = $this->pid();
        $gid    = $this->gid();
        $id     = $this->id();
        $type   = $this->type();
        $domain = $OURDOMAIN;
        $domain .= ":${pid}";
        if ($pid != $gid)
            $domain .= ":${gid}";
	
	return "urn:publicid:IDN+${domain}+${type}+${id}";
    }
    function URL() {
        global $TBBASE;
        $uuid     = $this->uuid();

        return "$TBBASE/image_metadata.php?uuid=$image_uuid";
    }
    
    # We ignore webtasks for classic UI
    function deleteCommand($webtask) {
	return  "webdelete_image -F -p " . $this->image->imageid();
    }
    function grantCommand($webtask) {
	return  "webgrantimage ";
    }
    function Project() {
	$pid = $this->pid();

	if ($this->project)
	    return $this->project;

	$this->project = Project::Lookup($pid);
	if (! $this->project) {
	    TBERROR("Could not lookup project $pid!", 1);
	}
	return $this->project;
    }
}

?>
