<?php
#
# Copyright (c) 2006-2014 University of Utah and the Flux Group.
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

class OSinfo
{
    var	$osinfo;

    #
    # Constructor by lookup on unique ID
    #
    function OSinfo($id, $version = NULL) {
	if (is_null($version)) {
	    list($id,$version) = preg_split('/:/', $id);
	}
	$safe_id = addslashes($id);

	if (is_null($version)) {
	    $query_result =
		DBQueryWarn("select o.*,v.* from os_info as o ".
			    "left join os_info_versions as v on ".
			    "     v.osid=o.osid and v.vers=o.version ".
			    "where o.osid='$safe_id'");
	}
	else {
	    # This will get deleted images, but that is okay.
	    $safe_version = addslashes($version);
	    $query_result =
	        DBQueryWarn("select v.* from os_info_versions as v ".
			    "where v.osid='$safe_id' and ".
			    "      v.vers='$safe_version'");
	}

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->osinfo = NULL;
	    return;
	}
	$this->osinfo = mysql_fetch_array($query_result);
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->osinfo);
    }

    # Lookup by osid
    function Lookup($id, $version = NULL) {
	$foo = new OSinfo($id, $version);

	if (! $foo->IsValid())
	    return null;

	return $foo;
    }

    # Lookup by osname in a project. This returns the newest version.
    function LookupByName($project, $name) {
	if (is_a($project, "Project")) {
	    $pid = $project->pid();
	}
	else {
	    $pid = addslashes($project);
	}
	$safe_name = addslashes($name);
	
	$query_result =
	    DBQueryFatal("select osid from os_info ".
			 "where pid='$pid' and osname='$safe_name'");

	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	return OSInfo::Lookup($row["osid"]);
    }

    #
    # Refresh an instance by reloading from the DB.
    #
    function Refresh() {
	if (! $this->IsValid())
	    return -1;

	$osid = $this->osid();
	$vers = $this->vers();

	$query_result =
	    DBQueryWarn("select * from os_info_versions ".
			"where osid='$osid' and vers='$vers'");
    
	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->osinfo = NULL;
	    return -1;
	}
	$this->osinfo = mysql_fetch_array($query_result);
	return 0;
    }

    #
    # Class function to create new osid and return object.
    #
    function NewOSID($user, $project, $osname, $args, &$errors) {
	global $suexec_output, $suexec_output_array;

        #
        # Generate a temporary file and write in the XML goo.
        #
	$xmlname = tempnam("/tmp", "newosid");
	if (! $xmlname) {
	    TBERROR("Could not create temporary filename", 0);
	    $errors[] = "Transient error(1); please try again later.";
	    return null;
	}
	if (! ($fp = fopen($xmlname, "w"))) {
	    TBERROR("Could not open temp file $xmlname", 0);
	    $errors[] = "Transient error(2); please try again later.";
	    return null;
	}

	# Add these. Maybe caller should do this?
	$args["osname"]  = $osname;
	$args["pid"]     = $project->pid();

	fwrite($fp, "<osid>\n");
	foreach ($args as $name => $value) {
	    fwrite($fp, "<attribute name=\"$name\">");
	    fwrite($fp, "  <value>" . htmlspecialchars($value) . "</value>");
	    fwrite($fp, "</attribute>\n");
	}
	fwrite($fp, "</osid>\n");
	fclose($fp);
	chmod($xmlname, 0666);

	$retval = SUEXEC("nobody", "nobody", "webnewosid $xmlname",
			 SUEXEC_ACTION_IGNORE);

	if ($retval) {
	    if ($retval < 0) {
		$errors[] = "Transient error(3, $retval); please try again later.";
		SUEXECERROR(SUEXEC_ACTION_CONTINUE);
	    }
	    else {
		# unlink($xmlname);
		if (count($suexec_output_array)) {
		    for ($i = 0; $i < count($suexec_output_array); $i++) {
			$line = $suexec_output_array[$i];
			if (preg_match("/^([-\w]+):\s*(.*)$/",
				       $line, $matches)) {
			    $errors[$matches[1]] = $matches[2];
			}
			else
			    $errors[] = $line;
		    }
		}
		else
		    $errors[] = "Transient error(4, $retval); please try again later.";
	    }
	    return null;
	}

        #
        # Parse the last line of output. Ick.
        #
	unset($matches);
	
	if (!preg_match("/^OSID\s+([^\/]+)\/(\d+)\s+/",
			$suexec_output_array[count($suexec_output_array)-1],
			$matches)) {
	    $errors[] = "Transient error(5); please try again later.";
	    SUEXECERROR(SUEXEC_ACTION_CONTINUE);
	    return null;
	}
	$osid = $matches[2];
	$newosid = OSinfo::Lookup($osid);
	if (! $newosid) {
	    $errors[] = "Transient error(6); please try again later.";
	    TBERROR("Could not lookup new osid $osid", 0);
	    return null;
	}
	# Unlink this here, so that the file is left behind in case of error.
	# We can then create the osid by hand from the xmlfile, if desired.
	unlink($xmlname);
	return $newosid; 
    }

    #
    # Equality test.
    #
    function SameOS($osinfo) {
	return $this->osid() == $osinfo->osid();
    }

    # accessors
    function field($name) {
	return (is_null($this->osinfo) ? -1 : $this->osinfo[$name]);
    }
    function osname()		{ return $this->field("osname"); }
    function pid()		{ return $this->field("pid"); }
    function osid()		{ return $this->field("osid"); }
    function vers()		{ return $this->field("vers"); }
    function parent_osid()	{ return $this->field("parent_osid"); }
    function parent_vers()	{ return $this->field("parent_vers"); }
    function uuid()		{ return $this->field("uuid"); }
    function creator()		{ return $this->field("creator"); }
    function creator_idx()	{ return $this->field("creator_idx"); }
    function created()		{ return $this->field("created"); }
    function description()	{ return $this->field("description"); }
    function OS()		{ return $this->field("OS"); }
    function version()		{ return $this->field("version"); }
    function path()		{ return $this->field("path"); }
    function magic()		{ return $this->field("magic"); }
    function machinetype()	{ return $this->field("machinetype"); }
    function osfeatures()	{ return $this->field("osfeatures"); }
    function ezid()		{ return $this->field("ezid"); }
    function shared()		{ return $this->field("shared"); }
    function mustclean()	{ return $this->field("mustclean"); }
    function op_mode()		{ return $this->field("op_mode"); }
    function nextosid()		{ return $this->field("nextosid"); }
    function max_concurrent()	{ return $this->field("max_concurrent"); }
    function mfs()		{ return $this->field("mfs"); }
    function reboot_waittime()  { return $this->field("reboot_waittime"); }
    function def_parentosid()   { return $this->field("def_parentosid"); }

    function SetParent($parent_osid) {
	$osid = $this->osid();
	$vers = $this->vers();
	$safe_osid = addslashes($parent_osid);

	DBQueryFatal("update os_info_versions set def_parentosid='$safe_osid' ".
		     "where osid='$osid' and vers='$vers'");

	DBQueryFatal("replace into os_submap set ".
		     " parent_osid='$safe_osid', osid='$osid'");

	return 0;
    }

    #
    # Access Check, determines if $user can access $this record.
    # 
    function AccessCheck($user, $access_type) {
	global $TB_OSID_READINFO;
	global $TB_OSID_MODIFYINFO;
	global $TB_OSID_DESTROY;
	global $TB_OSID_MIN;
	global $TB_OSID_MAX;
	global $TBDB_TRUST_USER;
	global $TBDB_TRUST_LOCALROOT;
	$mintrust = $TB_OSID_READINFO;

	if ($access_type < $TB_OSID_MIN || $access_type > $TB_OSID_MAX) {
	    TBERROR("Invalid access type $access_type!", 1);
	}

        #
        # Admins do whatever they want!
        # 
	if (ISADMIN()) {
	    return 1;
	}

        #
        # No GIDs yet.
        #
	$pid    = $this->pid();
	$shared = $this->shared();
	$uid    = $user->uid();

        #
        # Global OSIDs can be read by anyone.
        # 
	if ($shared) {
	    if ($access_type == $TB_OSID_READINFO) {
		return 1;
	    }
	    return 0;
	}
    
        #
        # Otherwise must have proper trust in the project.
        # 
	if ($access_type == $TB_OSID_READINFO) {
	    $mintrust = $TBDB_TRUST_USER;
	}
	else {
	    $mintrust = $TBDB_TRUST_LOCALROOT;
	}

	#
	# Need the project object to complete this test.
	#
	if (! ($project = Project::Lookup($pid))) {
	    TBERROR("Could not map project $pid to its object", 1);
	}
	if (TBMinTrust($project->UserTrust($user), $mintrust)) {
	    return 1;
	}
	elseif (!$this->ezid()) {
	    return 0;
	}
	#
	# If this is an ez image, look in the image permissions.
        # First look for a user permission, then look for a group permission. 
	#
	$osid = $this->osid();
	$uid_idx = $user->uid_idx();
	$trust_none = TBDB_TRUSTSTRING_NONE;
	 
	$query_result = 
	    DBQueryFatal("select allow_write from image_permissions ".
			 "where imageid='$osid' and ".
			 "      permission_type='user' and ".
			 "      permission_idx='$uid_idx'");
	
	if (mysql_num_rows($query_result)) {
	    $row  = mysql_fetch_array($query_result);

            # Only allowed to read.
	    if ($access_type == $TB_OSID_READINFO) 
		return 1;
	}
	$trust_none = TBDB_TRUSTSTRING_NONE;
	$query_result = 
	    DBQueryFatal("select allow_write from group_membership as g ".
			 "left join image_permissions as p on ".
			 "     p.permission_type='group' and ".
			 "     p.permission_idx=g.gid_idx ".
			 "where g.uid_idx='$uid_idx' and ".
			 "      p.imageid='$osid' and ".
			 "      trust!='$trust_none'");

	if (mysql_num_rows($query_result)) {
            # Only allowed to read.
	    if ($access_type == $TB_OSID_READINFO)
		return 1;
	}
	return 0;
	
    }

    #
    # See if a feature is supported
    #
    function FeatureSupported($feature) {
	if ($this->osfeatures()) {
	    foreach (preg_split("/,/", $this->osfeatures()) as $f) {
		if ($feature == $f) {
		    return 1;
		}
	    }
	}
	return 0;
    }

    #
    # Spit out an OSID link in user format.
    #
    function SpitLink() {
	$osname = $this->osname();
	$url    = CreateURL("showosinfo", $this);
	
	echo "<a href='$url'>$osname</a>\n";
    }

    #
    # Show OS INFO record.
    #
    function Show() {
	$osid           = $this->osid();
	$vers           = $this->vers();
	$os_description = $this->description();
	$os_OS          = $this->OS();
	$os_version     = $this->version();
	$os_path        = $this->path();
	$os_magic       = $this->magic();
	$os_osfeatures  = $this->osfeatures();
	$os_op_mode     = $this->op_mode();
	$os_pid         = $this->pid();
	$os_shared      = $this->shared();
	$os_osname      = $this->osname();
	$creator        = $this->creator();
	$created        = $this->created();
	$mustclean      = $this->mustclean();
	$nextosid       = $this->nextosid();
	$def_parentosid = $this->def_parentosid();
	$max_concurrent = $this->max_concurrent();
	$reboot_waittime= $this->reboot_waittime();
	$uuid           = $this->uuid();
	$ezid           = $this->ezid();
	$mfs            = $this->mfs();

	if (! ($creator_user = User::Lookup($creator))) {
	    TBERROR("Error getting object for user $creator", 1);
	}
	$showuser_url = CreateURL("showuser", $creator_user);

	if (!$os_description)
	    $os_description = "&nbsp;";
	if (!$os_version)
	    $os_version = "&nbsp;";
	if (!$os_path)
	    $os_path = "&nbsp;";
	if (!$os_magic)
	    $os_magic = "&nbsp;";
	if (!$os_osfeatures)
	    $os_osfeatures = "&nbsp;";
	if (!$os_op_mode)
	    $os_op_mode = "&nbsp;";
	if (!$created)
	    $created = "N/A";
	if (!$reboot_waittime)
	    $reboot_waittime = "&nbsp;";

        #
        # Generate the table.
        #
	echo "<table align=center border=1>\n";

	echo "<tr>
                <td>Name: </td>
                <td class=\"left\">$os_osname</td>
              </tr>\n";

	echo "<tr>
                <td>Project: </td>
                <td class=\"left\">
                  <a href='showproject.php3?pid=$os_pid'>$os_pid</a></td>
              </tr>\n";

	echo "<tr>
                <td>Creator: </td>
                <td class=left>
                  <a href='$showuser_url'>$creator</a></td>
 	      </tr>\n";

	echo "<tr>
                <td>Created: </td>
                <td class=left>$created</td>
    	      </tr>\n";

	echo "<tr>
                <td>Description: </td>
                <td class=\"left\">$os_description</td>
              </tr>\n";

        echo "<tr>
                <td>Operating System: </td>
                <td class=\"left\">$os_OS</td>
              </tr>\n";

	echo "<tr>
                <td>Version: </td>
                <td class=\"left\">$os_version</td>
             </tr>\n";

	echo "<tr>
                <td>Path: </td>
                <td class=\"left\">$os_path</td>
              </tr>\n";

	echo "<tr>
                <td>Magic (uname -r -s): </td>
                <td class=\"left\">$os_magic</td>
              </tr>\n";

	echo "<tr>
                <td>Features: </td>
                <td class=\"left\">$os_osfeatures</td>
              </tr>\n";

	echo "<tr>
                <td>Operational Mode: </td>
                <td class=\"left\">$os_op_mode</td>
              </tr>\n";

	if (isset($max_concurrent) and $max_concurrent > 0) {
	    echo "<tr>
                    <td>Max Concurrent Usage: </td>
                    <td class=\"left\">$max_concurrent</td>
                  </tr>\n";
	}

	echo "<tr>
                <td>Reboot Waittime: </td>
                <td class=\"left\">$reboot_waittime</td>
              </tr>\n";

	echo "<tr>
                <td>Shared?: </td>
                <td class=left>" . YesNo($os_shared) . "</td>
              </tr>\n";

	echo "<tr>
                <td>Must Clean?: </td>
                <td class=left>" . YesNo($mustclean) . "</td>
              </tr>\n";

	if ($nextosid) {
	    if ($nextosid == 0) {
		echo "<tr>
		        <td>Next Osid: </td>
		        <td class=left>
			    Mapped via DB table: osid_map</td></tr>\n";
	    }
	    else {
		$nextosinfo = OSinfo::Lookup($nextosid);
	        $nextosname = $nextosinfo->osname();
		echo "<tr>
                        <td>Next Osid: </td>
                        <td class=left>
                            <a href='showosinfo.php3?osid=$nextosid'>
                                            $nextosname</a></td>
                      </tr>\n";
	    }
	}
	if ($def_parentosid) {
	    $nextosinfo = OSinfo::Lookup($def_parentosid);
	    $nextosname = $nextosinfo->osname();
	    echo "<tr>
                      <td>Parent Osid: </td>
                      <td class=left>
                          <a href='showosinfo.php3?osid=$def_parentosid'>
                                           $nextosname</a></td>
                  </tr>\n";
	}
	if ($ezid) {
		echo "<tr>
                        <td>Image Link: </td>
                        <td class=left>
                            <a href='showimageid.php3?imageid=$osid&version=$vers'>
                                            $os_osname</a></td>
                      </tr>\n";
	}
	if ($mfs) {
		echo "<tr>
                        <td>MFS: </td>
                        <td class=left>Yes</td>
                      </tr>\n";
	}

	echo "<tr>
                <td>Internal ID (Vers): </td>
                <td class=\"left\">$osid ($vers)</td>
              </tr>\n";

	echo "<tr>
                <td>UUID: </td>
                <td class=left>$uuid</td>
              </tr>\n";

	if ($def_parentosid) {
	    $parent_result =
		DBQueryFatal("select m.parent_osid,o.osname,o.pid ".
			     "   from os_submap as m ".
			     "left join os_info as o on o.osid=m.parent_osid ".
			     "where m.osid='$osid'");
	    
	    if (mysql_num_rows($parent_result)) {
		while ($prow = mysql_fetch_array($parent_result)) {
		    $posid   = $prow["parent_osid"];
		    $posname = $prow["osname"];

		    echo "<tr>";
		    echo "  <td>Parent $posid:</td>";
		    echo "  <td class=left>";
		    echo "   <a href='showosinfo.php3?osid=$posid'>";
		    echo "$posname</a></td>\n";
		    echo "</tr>\n";
		}
	    }
	}
	echo "</table>\n";
    }

    #
    # Display list of experiments using this osid.
    #
    function ShowExperiments($user) {
	global $TBOPSPID;
	global $TB_EXPT_READINFO;

	$uid = $user->uid();
	$pid = $this->pid();
	$osname = $this->osname();

        #
        # Due to the funny way we handle 'global' images in the emulab-ops 
        # project, we have to treat its images specially - namely, we 
        # have to make sure there is not an osname in that project, which 
        # takes priority over the global ones.
        #
	if ($pid == $TBOPSPID) {
	    $query_result =
		DBQueryFatal("select distinct v.pid,v.eid,e.state,".
			     "      e.expt_swapped " .
			     "   from virt_nodes as v ".
			     "left join os_info as o on " .
			     "     v.osname=o.osname and v.pid=o.pid ".
			     "left join experiments as e on v.pid=e.pid and ".
			     "     v.eid=e.eid " .
			     "where v.osname='$osname' and o.osname is NULL " .
			     "order by v.pid, v.eid, e.state");
	}
	else {
	    $query_result =
		DBQueryFatal("select distinct v.pid,v.eid,e.state,".
			     "    e.expt_swapped " .
			     "  from virt_nodes as v ".
			     "left join experiments as e " .
			     "     on v.pid=e.pid and v.eid=e.eid " .
			     "where v.pid='$pid' and v.osname='$osname' " .
			     "order by v.pid, v.eid, e.state");
	}

	if (mysql_num_rows($query_result) == 0) {
	    echo "<h4 align='center'>No experiments are using this OS</h3>";
	}
	else {
	    $other_exps = 0;

	    echo "<h3 align='center'>Experiments using this OS</h3>\n";
	    echo "<table align=center border=1>\n";
	    echo "  <tr> 
		        <th>PID</th>
   		        <th>EID</th>
		        <th>State</th>
		        <th>Last Swap</th>
		    </tr>\n";
	    while($row = mysql_fetch_array($query_result)) {
		$pid   = $row[0];
		$eid   = $row[1];
		$state = $row[2];
		$lswap = $row[3];
		if (!$lswap) {
		    $lswap = "Never";
		}

                #
	        # Gotta make sure that the user actually has the right to 
	        # see this experiment - summarize all the experiments that
	        # he/she cannot see at the bottom
	        #
		if (! ($experiment = Experiment::LookupByPidEid($pid, $eid))) {
		    continue;
		}
		if (! $experiment->AccessCheck($user, $TB_EXPT_READINFO)) {
		    $other_exps++;
		    continue;
		}
		$showexp_url = CreateURL("showexp", $experiment);

		echo "<tr>\n";
		echo "  <td>$pid</td>\n";
		echo "  <td><a href='$showexp_url'>$eid</td>\n";
		echo "  <td>$state</td>\n";
		echo "  <td>$lswap</td>\n";
		echo "</tr>\n";
	    }
	    if ($other_exps) {
		echo "<tr><td colspan=3>
                        $other_exps experiments in other projects</td></tr>\n";
	    }
	    echo "</table>\n";
	}
    }
}

#
# Spit out an OSID link in user format.
#
function SpitOSIDLink($osid, $vers)
{
    $osinfo = OSInfo::Lookup($osid, $vers);

    if ($osinfo) {
	$osname = $osinfo->osname();
	$url    = CreateURL("showosinfo", $osinfo);
	
	echo "<a href='$url'>$osname</a>\n";
    }
}
?>
