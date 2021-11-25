<?php
#
# Copyright (c) 2006-2018 University of Utah and the Flux Group.
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
function GetDBLink($authority)
{
    if ($authority == "cm")
	$authority = "geni-cm";
    
    if ($authority == "sa" || $authority == "geni-sa")
	$authority = "geni";
    
    if ($authority == "ch")
	$authority = "geni-ch";
    
    return DBConnect($authority);
}

class GeniSlice
{
    var	$slice;
    var $dblink;

    #
    # Constructor lookup.
    #
    function GeniSlice($authority, $token) {
	$safe_token = addslashes($token);
	$dblink     = GetDBLink($authority);
	$idx        = null;

	if (! $dblink) {
	    $this->slice = null;
	    return;
	}

	if (preg_match("/^\d+$/", $token)) {
	    $idx = $token;
	}
	elseif (preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", $token)) {
	    $query_result =
		DBQueryWarn("select idx from geni_slices ".
			    "where uuid='$safe_token'",
			    $dblink);

	    if ($query_result && mysql_num_rows($query_result)) {
		$row = mysql_fetch_row($query_result);
		$idx = $row[0];
	    }
	}
	elseif (preg_match("/^[-\w\.]*$/", $token)) {
	    $query_result =
		DBQueryWarn("select idx from geni_slices ".
			    "where hrn='$safe_token'",
			    $dblink);

	    if ($query_result && mysql_num_rows($query_result)) {
		$row = mysql_fetch_row($query_result);
		$idx = $row[0];
	    }
	}
	if (is_null($idx)) {
	    $this->slice = null;
	    return;
	}

	$query_result =
	    DBQueryWarn("select * from geni_slices where idx='$idx'",
			$dblink);

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->slice = null;
	    return;
	}
	$this->dblink = $dblink;
	$this->slice  = mysql_fetch_array($query_result);
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->slice);
    }

    # Lookup.
    function Lookup($authority, $token) {
	$foo = new GeniSlice($authority, $token);

	if ($foo->IsValid()) {
	    return $foo;
	}
	return null;
    }
    # accessors
    function field($name) {
	return (is_null($this->slice) ? -1 : $this->slice[$name]);
    }
    function idx()	    { return $this->field('idx'); }
    function hrn()	    { return $this->field('hrn'); }
    function uuid()	    { return $this->field('uuid'); }
    function publicid()	    { return $this->field('publicid'); }
    function exptidx()	    { return $this->field('exptidx'); }
    function created()	    { return $this->field('created'); }
    function expires()	    { return $this->field('expires'); }
    function shutdown()	    { return $this->field('shutdown'); }
    function locked()	    { return $this->field('locked'); }
    function creator_uuid() { return $this->field('creator_uuid'); }
    function name()	    { return $this->field('name'); }
    function sa_uuid()	    { return $this->field('sa_uuid'); }
    function needsfirewall(){ return $this->field('needsfirewall'); }
    function monitor_pid()  { return $this->field('monitor_pid'); }
    function expiration_max()  { return $this->field('expiration_max'); }
    function speaksfor_urn(){ return $this->field('speaksfor_urn'); }
    function renew_limit()  { return $this->field('renew_limit'); }
    function portal_tag()   { return $this->field('portal_tag'); }
    function portal_url()   { return $this->field('portal_url'); }

    #
    # Class function to return a list of all slices.
    #
    function AllSlices($authority) {
	$result     = array();
	$dblink     = GetDBLink($authority);

	if (! $dblink) {
	    return null;
	}
	$query_result =
	    DBQueryFatal("select idx from geni_slices", $dblink);

	if (! ($query_result && mysql_num_rows($query_result))) {
	    return null;
	}
    
	while ($row = mysql_fetch_array($query_result)) {
	    $idx = $row["idx"];

	    if (! ($slice = GeniSlice::Lookup($authority, $idx))) {
		TBERROR("GeniSlice::AllSlices: ".
			"Could not load slice $idx!", 1);
	    }
	    $result[] = $slice;
	}
	return $result;
    }

    function LookupByExperiment($authority, $experiment) {
	$dblink     = GetDBLink($authority);
	$exptidx    = $experiment->idx();

	if (! $dblink) {
	    return null;
	}
	$query_result =
	    DBQueryFatal("select idx from geni_slices ".
			 "where exptidx=$exptidx",
			 $dblink);

	if (! ($query_result && mysql_num_rows($query_result))) {
	    return null;
	}
	$row = mysql_fetch_row($query_result);
	$idx = $row[0];
 	return GeniSlice::Lookup($authority, $idx);
    }

    function LookupByPublicID($authority, $publicid) {
	$dblink     = GetDBLink($authority);
	$safeid     = addslashes($publicid);

	if (! $dblink) {
	    return null;
	}
	$query_result =
	    DBQueryFatal("select idx from geni_slices ".
			 "where publicid='$safeid'",
			 $dblink);

	if (! ($query_result && mysql_num_rows($query_result))) {
	    return null;
	}
	$row = mysql_fetch_row($query_result);
	$idx = $row[0];
 	return GeniSlice::Lookup($authority, $idx);
    }

    function GetManifest() {
	$slice_uuid = $this->uuid();
	
	$query_result =
	    DBQueryFatal("select manifest from geni_manifests ".
			 "where slice_uuid='$slice_uuid'",
			 $this->dblink);

	if ($query_result && mysql_num_rows($query_result)) {
	    $row = mysql_fetch_row($query_result);
	    return $row[0];
	}
	return null;
    }
    #
    # The urn is stored in the certificate.
    #
    function urn() {
	$slice_uuid = $this->uuid();
	
	$query_result =
	    DBQueryFatal("select urn from geni_certificates ".
			 "where uuid='$slice_uuid'",
			 $this->dblink);

	if ($query_result && mysql_num_rows($query_result)) {
	    $row = mysql_fetch_row($query_result);
	    return $row[0];
	}
	return null;
    }
}

class GeniUser
{
    var	$user;
    var $dblink;

    #
    # Constructor lookup.
    #
    function GeniUser($authority, $token) {
	$safe_token = addslashes($token);
	$dblink     = GetDBLink($authority);
	$idx        = null;

	if (! $dblink) {
	    $this->user = null;
	    return;
	}

	if (preg_match("/^\d+$/", $token)) {
	    $idx = $token;
	}
	elseif (preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", $token)) {
	    $query_result =
		DBQueryWarn("select idx from geni_users ".
			    "where uuid='$safe_token'",
			    $dblink);

	    if ($query_result && mysql_num_rows($query_result)) {
		$row = mysql_fetch_row($query_result);
		$idx = $row[0];
	    }
	}
	elseif (preg_match("/^[-\w\.]*$/", $token)) {
	    $query_result =
		DBQueryWarn("select idx from geni_users ".
			    "where hrn='$safe_token'",
			    $dblink);

	    if ($query_result && mysql_num_rows($query_result)) {
		$row = mysql_fetch_row($query_result);
		$idx = $row[0];
	    }
	}
	if (is_null($idx)) {
	    $this->user = null;
	    return;
	}

	$query_result =
	    DBQueryWarn("select * from geni_users where idx='$idx'",
			$dblink);

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->user = null;
	    return;
	}
	$this->dblink = $dblink;
	$this->user  = mysql_fetch_array($query_result);

	#
	# And get the urn.
	#
	$uuid = $this->user['uuid'];
	$query_result =
	    DBQueryWarn("select urn from geni_certificates where uuid='$uuid'",
			$dblink);
	if ($query_result && mysql_num_rows($query_result)) {
	    $foo = mysql_fetch_array($query_result);
	    $this->user['urn'] = $foo['urn'];
	    return;
	}
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->user);
    }

    # Lookup.
    function Lookup($authority, $token) {
	$foo = new GeniUser($authority, $token);

	if ($foo->IsValid()) {
	    return $foo;
	}
	return null;
    }
    function LookupByEmail($authority, $token) {
	$dblink     = GetDBLink($authority);
	$safe_token = addslashes($token);

	if (! $dblink) {
	    return null;
	}
	$query_result =
	    DBQueryFatal("select idx from geni_users ".
			 "where email='$safe_token'",
			 $dblink);

	if (! ($query_result && mysql_num_rows($query_result))) {
	    return null;
	}
	$row = mysql_fetch_row($query_result);
	$idx = $row[0];
 	return GeniUser::Lookup($authority, $idx);
    }
    
    # accessors
    function field($name) {
	return (is_null($this->user) ? -1 : $this->user[$name]);
    }
    function idx()	    { return $this->field('idx'); }
    function uid()	    { return $this->field('uid'); }
    function hrn()	    { return $this->field('hrn'); }
    function urn()	    { return $this->field('urn'); }
    function uuid()	    { return $this->field('uuid'); }
    function exptidx()	    { return $this->field('exptidx'); }
    function created()	    { return $this->field('created'); }
    function expires()	    { return $this->field('expires'); }
    function locked()	    { return $this->field('locked'); }
    function status()	    { return $this->field('status'); }
    function name()	    { return $this->field('name'); }
    function email()	    { return $this->field('email'); }
    function sa_uuid()	    { return $this->field('sa_uuid'); }
    function auth_token()   { return $this->field('auth_token'); }
    function IsActive()     { return $this->status() == 'active' ? 1 : 0; }

    function SSHKey() {
	$uuid = $this->uuid();
	
	$query_result =
	    DBQueryFatal("select `key` from geni_userkeys ".
			 "where uuid='$uuid' and internal=0",
			 $this->dblink);

	if ($query_result && mysql_num_rows($query_result)) {
	    $row = mysql_fetch_row($query_result);
	    return $row[0];
	}
	return null;
    }
}

class ClientSliver
{
    var	$sliver;
    var $dblink;

    #
    # Constructor lookup.
    #
    function ClientSliver($token) {
	$safe_token = addslashes($token);
	$dblink     = GetDBLink("sa");
	$idx        = null;

	if (! $dblink) {
	    $this->sliver = null;
	    return;
	}

	if (preg_match("/^\d+$/", $token)) {
	    $idx = $token;
	}
	if (is_null($idx)) {
	    $this->sliver = null;
	    return;
	}

	$query_result =
	    DBQueryWarn("select * from client_slivers where idx='$idx'",
			$dblink);

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->sliver = null;
	    return;
	}
	$this->dblink = $dblink;
	$this->sliver  = mysql_fetch_array($query_result);
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->sliver);
    }

    # Lookup.
    function Lookup($token) {
	$foo = new ClientSliver($token);

	if ($foo->IsValid()) {
	    return $foo;
	}
	return null;
    }
    # accessors
    function field($name) {
	return (is_null($this->sliver) ? -1 : $this->sliver[$name]);
    }
    function idx()	    { return $this->field('idx'); }
    function urn()	    { return $this->field('urn'); }
    function slice_idx()    { return $this->field('slice_idx'); }
    function manager_urn()  { return $this->field('manager_urn'); }
    function creator_idx()  { return $this->field('creator_idx'); }
    function created()	    { return $this->field('created'); }
    function expires()	    { return $this->field('expires'); }
    function locked()	    { return $this->field('locked'); }
    function manifest()	    { return $this->field('manifest'); }

    #
    # Class function to return a list of all slivers for a slice
    #
    function SliverList($slice) {
	$result     = array();
	$dblink     = GetDBLink("sa");
	$slice_idx  = $slice->idx();

	if (! $dblink) {
	    return null;
	}
	$query_result =
	    DBQueryFatal("select idx from client_slivers ".
			 "where slice_idx='$slice_idx'",
			 $dblink);

	if (! ($query_result && mysql_num_rows($query_result))) {
	    return null;
	}
    
	while ($row = mysql_fetch_array($query_result)) {
	    $idx = $row["idx"];

	    if (! ($sliver = ClientSliver::Lookup($idx))) {
		TBERROR("ClientSliver::SliverList: ".
			"Could not load client sliver $idx!", 1);
	    }
	    $result[] = $sliver;
	}
	return $result;
    }
}

class QuickVM
{
    var	$quickvm;
    var $dblink;

    #
    # Constructor lookup.
    #
    function QuickVM($uuid) {
	$safe_uuid  = addslashes($uuid);
	$dblink     = GetDBLink("sa");
	$idx        = null;

	if (! $dblink) {
	    $this->quickvm = null;
	    return;
	}
	if (! preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", $uuid)) {
	    $this->quickvm = null;
	    return;
	}

	$query_result =
	    DBQueryWarn("select * from quickvms where uuid='$safe_uuid'",
			$dblink);

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->quickvm = null;
	    return;
	}
	$this->dblink  = $dblink;
	$this->quickvm = mysql_fetch_array($query_result);
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->quickvm);
    }

    # Lookup.
    function Lookup($token) {
	$foo = new QuickVM($token);

	if ($foo->IsValid()) {
	    return $foo;
	}
	return null;
    }
    # accessors
    function field($name) {
	return (is_null($this->quickvm) ? -1 : $this->quickvm[$name]);
    }
    function uuid()	    { return $this->field('uuid'); }
    function slice_uuid()   { return $this->field('slice_uuid'); }
    function creator_uuid() { return $this->field('creator_uuid'); }
    function name()	    { return $this->field('name'); }
    function status()	    { return $this->field('status'); }
    function profile()	    { return $this->field('profile'); }
    function manifest()	    { return $this->field('manifest'); }
    function extension_code() { return $this->field('extension_code'); }

    function LookupByName($token) {
	$dblink     = GetDBLink("sa");
	$safe_token = addslashes($token);

	if (! $dblink) {
	    return null;
	}
	$query_result =
	    DBQueryFatal("select uuid from quickvms ".
			 "where name='$safe_token'",
			 $dblink);

	if (! ($query_result && mysql_num_rows($query_result))) {
	    return null;
	}
	$row = mysql_fetch_row($query_result);
	$uuid = $row[0];
 	return QuickVM::Lookup($uuid);
    }
    function LookupByCreator($token) {
	$dblink     = GetDBLink("sa");
	$safe_token = addslashes($token);

	if (! $dblink) {
	    return null;
	}
	$query_result =
	    DBQueryFatal("select uuid from quickvms ".
			 "where creator_uuid='$safe_token'",
			 $dblink);

	if (! ($query_result && mysql_num_rows($query_result))) {
	    return null;
	}
	$row = mysql_fetch_row($query_result);
	$uuid = $row[0];
 	return QuickVM::Lookup($uuid);
    }
}

#
# Generate a Portal URL.
#
function GenPortalURL($active, $urn, $slice_uuid)
{
    global $OURDOMAIN, $TBBASE;
    
    if (! (preg_match("/^[^+]*\+([^+]+)\+([^+]+)\+(.+)$/",
                      $urn, $matches) &&
           ($matches[1] == $OURDOMAIN || $matches[1] == "emulab.net"))) {
        return null;
    }
    $domain = $matches[1];
    if ($domain == $OURDOMAIN) {
        $portal_url = "$TBBASE/portal/";
    }
    else {
        $portal_url = "https://www.emulab.net/portal/";
    }
    if ($active) {
        $portal_url .= "status.php?slice_uuid=$slice_uuid";
    }
    else {
        $portal_url .= "memlane.php?slice_uuid=$slice_uuid";
    }
    return $portal_url;
}
?>
