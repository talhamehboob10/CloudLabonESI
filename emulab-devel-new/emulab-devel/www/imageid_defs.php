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
include_once("osinfo_defs.php");	# For SpitOSIDLink() below.

# Default architectures.
$image_architectures		= array();
$image_architectures["i386"]	= "i386";
$image_architectures["x86_64"]	= "x86_64";
$image_architectures["aarch64"]	= "aarch64";

class Image
{
    var	$image;
    var $types;
    var $group;
    var $project;

    #
    # Constructor by lookup on unique ID
    #
    function Image($id, $version = NULL) {
	if (is_null($version)) {
	    list($id,$version) = preg_split('/:/', $id);
	}
	$safe_id = addslashes($id);

	if (is_null($version)) {
	    $query_result =
		DBQueryWarn("select i.*,v.*,i.uuid as image_uuid,".
                            "   i.locked as image_locked ".
			    "  from images as i ".
			    "left join image_versions as v on ".
			    "     v.imageid=i.imageid and v.version=i.version ".
			    "where i.imageid='$safe_id'");
	}
	else {
	    # This will get deleted images, but that is okay.
	    $safe_version = addslashes($version);
	    $query_result =
	        DBQueryWarn("select i.*,v.*,i.uuid as image_uuid,".
                            "  i.locked as image_locked".
			    "  from image_versions as v ".
			    "left join images as i on ".
			    "     i.imageid=v.imageid ".
			    "where v.imageid='$safe_id' and ".
			    "      v.version='$safe_version'");
	}

	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->image = NULL;
	    return;
	}
	$this->image = mysql_fetch_array($query_result);

	# Load lazily;
	$this->group      = null;
	$this->project    = null;
    }

    # Hmm, how does one cause an error in a php constructor?
    function IsValid() {
	return !is_null($this->image);
    }

    # Lookup by imageid
    function Lookup($id, $version = NULL) {
	$foo = new Image($id,$version);

	if (! $foo->IsValid())
	    return null;

	return $foo;
    }

    # Lookup by imagename in a project
    function LookupByName($project, $name) {
	$pid       = $project->pid();
	$safe_name = addslashes($name);
	
	$query_result =
	    DBQueryFatal("select imageid from images ".
			 "where pid='$pid' and imagename='$safe_name'");

	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	return Image::Lookup($row["imageid"]);
    }

    # Look for most recent unreleased version.
    function LookupUnreleased() {
	global $DOPROVENANCE;
	if (!$DOPROVENANCE) {
	    return $this;
	}
	$imageid   = $this->imageid();
	
	$query_result =
	    DBQueryFatal("select version from image_versions ".
			 "where imageid='$imageid' and released=0 and ".
			 "      deleted is null ".
			 "order by version desc limit 1");

	# If no unreleased version, just return $this. Might mean that
	# provenance is not turned on for the project cause of a feature.
	if (mysql_num_rows($query_result) == 0) {
	    return $this;
	}
	$row = mysql_fetch_array($query_result);
	return Image::Lookup($imageid, $row["version"]);
    }

    # Lookup next higher version of the image.
    function LookupNextVersion() {
	global $DOPROVENANCE;
	if (!$DOPROVENANCE) {
	    return $this;
	}
	$imageid = $this->imageid();
        $version = $this->version();
	
	$query_result =
	    DBQueryFatal("select version from image_versions ".
			 "where imageid='$imageid' and version>$version and ".
                         "      deleted is null ".
			 "order by version asc limit 1");

	if (mysql_num_rows($query_result) == 0) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	return Image::Lookup($imageid, $row["version"]);
    }

    function LookupByUUID($uuid, $version = NULL) {
	$safe_uuid = addslashes($uuid);

	#
	# First look to see if the uuid is for the image itself,
	# which means current version. Otherwise look for a
	# version with the uuid.
	#
	$query_result =
	    DBQueryFatal("select i.imageid,i.version from images as i ".
			 "where i.uuid='$safe_uuid'");
	if (mysql_num_rows($query_result)) {
	    if (!is_null($version)) {
		#
		# Specific version, but using the image UUID.
		# Note that you cannot lookup a deleted image this way.
		# Must have the version specific UUID.
		#
		$row = mysql_fetch_array($query_result);
		return Image::Lookup($row["imageid"], $version);
	    }
	}
	else {
	    $query_result =
		DBQueryWarn("select imageid,version from image_versions ".
			    "where uuid='$safe_uuid' and ".
			    "      deleted is null");
	}
	if (!$query_result || mysql_num_rows($query_result) == 0) {
	    return null;
	}
	$row = mysql_fetch_array($query_result);
	return Image::Lookup($row["imageid"], $row["version"]);
    }
    
    #
    # Refresh an instance by reloading from the DB.
    #
    function Refresh() {
	if (! $this->IsValid())
	    return -1;

	$imageid    = $this->imageid();
	$version    = $this->version();
	$image_uuid = $this->image_uuid();
	
	$query_result =
            DBQueryWarn("select i.*,v.*,i.uuid as image_uuid,".
                        "  i.locked as image_locked".
                        "  from image_versions as v ".
                        "left join images as i on ".
                        "     i.imageid=v.imageid ".
                        "where v.imageid='$safe_id' and ".
                        "      v.version='$safe_version'");
    
	if (!$query_result || !mysql_num_rows($query_result)) {
	    $this->imageid = NULL;
	    return -1;
	}
	$this->image = mysql_fetch_array($query_result);
	return 0;
    }

    #
    # Check for the image tracker.
    #
    function UseImageTracker()
    {
        if (! TBSiteVarExists("protogeni/use_imagetracker")) {
            return 0;
        }
        return TBGetSiteVar("protogeni/use_imagetracker");
    }

    #
    # Class function to create a new image descriptor.
    #
    function NewImageId($ez, $imagename, $args, $creator, $group,
			$target, &$errors) {
	global $suexec_output, $suexec_output_array;

        #
        # Generate a temporary file and write in the XML goo.
        #
	$xmlname = tempnam("/tmp", $ez ? "newimageid_ez" : "newimageid");
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
	$args["imagename"] = $imagename;

	fwrite($fp, "<image>\n");
	foreach ($args as $name => $value) {
	    fwrite($fp, "<attribute name=\"$name\">");
	    fwrite($fp, "  <value>" . htmlspecialchars($value) . "</value>");
	    fwrite($fp, "</attribute>\n");
	}
	fwrite($fp, "</image>\n");
	fclose($fp);
	chmod($xmlname, 0666);
	$opt = ($target ? "-t " . escapeshellarg($target) : "");

	$script = "webnewimageid" . ($ez ? "_ez" : "");
	$retval = SUEXEC($creator->uid(),
			 $group->pid() . "," . $group->unix_gid(),
			 "$script $opt $xmlname",
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
	
	if (!preg_match("/^IMAGE\s+([^\/]+)\/(\d+)\s+/",
			$suexec_output_array[count($suexec_output_array)-1],
			$matches)) {
	    $errors[] = "Transient error(5); please try again later.";
	    SUEXECERROR(SUEXEC_ACTION_CONTINUE);
	    return null;
	}
	$image = $matches[2];
	$newimage = image::Lookup($image);
	if (! $newimage) {
	    $errors[] = "Transient error(6); please try again later.";
	    TBERROR("Could not lookup new image $image", 0);
	    return null;
	}

	# Unlink this here, so that the file is left behind in case of error.
	# We can then create the image by hand from the xmlfile, if desired.
	unlink($xmlname);
	return $newimage; 
    }

    #
    # Flip global bit. If making it global, turn off shared.
    # Also, if an EZ image, flip the bit on the os_info entry too.
    #
    function SetGlobal($mode) {
	$imageid  = $this->imageid();
	$version  = $this->version();
	$mode     = ($mode ? 1 : 0);
	$extra    = ($mode ? ",shared=0" : "");

	DBQueryFatal("update image_versions set global='$mode' $extra ".
		     "where imageid='$imageid' and version='$version'");

	if ($this->ezid()) {
	    DBQueryFatal("update os_info_versions set shared='$mode' ".
			 "where osid='$imageid' and vers='$version'");
	}
	return 0;
    }

    #
    # Set Shared/Global. Caller did the error checking.
    #
    function SetSharedGlobal($shared, $global) {
	$imageid  = $this->imageid();
	$version  = $this->version();
        $shared   = ($shared ? 1 : 0);
	$global   = ($global ? 1 : 0);

        if (!DBQueryWarn("update image_versions set ".
                         "  global='$global',shared='$shared' ".
                         "where imageid='$imageid' and version='$version'")) {
            return -1;
        }
	if ($this->ezid()) {
            if (!DBQueryWarn("update os_info_versions set shared='$shared' ".
                             "where osid='$imageid' and vers='$version'")) {
                return -1;
            }
	}
	return 0;
    }

    #
    # Clear the web task.
    #
    function ClearWebtask() {
	$imageid  = $this->imageid();

	DBQueryWarn("update images set webtask_id=NULL ".
		     "where imageid='$imageid'");

	return 0;
    }

    #
    # Class function to edit an image descriptor.
    #
    function EditImageid($image, $args, &$errors) {
	global $suexec_output, $suexec_output_array;

        #
        # Generate a temporary file and write in the XML goo.
        #
	$xmlname = tempnam("/tmp", "editimageid");
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
	$args["imageid"] = $image->imageid();
	$args["version"] = $image->version();

	fwrite($fp, "<image>\n");
	foreach ($args as $name => $value) {
	    fwrite($fp, "<attribute name=\"$name\">");
	    fwrite($fp, "  <value>" . htmlspecialchars($value) . "</value>");
	    fwrite($fp, "</attribute>\n");
	}
	fwrite($fp, "</image>\n");
	fclose($fp);
	chmod($xmlname, 0666);

	$retval = SUEXEC("nobody", "nobody", "webeditimageid $xmlname",
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

	# There are no return value(s) to parse at the end of the output.

	# Unlink this here, so that the file is left behind in case of error.
	# We can then create the image by hand from the xmlfile, if desired.
	unlink($xmlname);
	return true;
    }

    #
    # Equality test.
    #
    function SameImage($image) {
	return $image->imageid() == $this->imageid();
    }

    # accessors
    function field($name) {
	return (is_null($this->image) ? -1 : $this->image[$name]);
    }
    function imagename()	{ return $this->field("imagename"); }
    function version()		{ return $this->field("version"); }
    function architecture()	{ return $this->field("architecture"); }
    function pid()		{ return $this->field("pid"); }
    function gid()		{ return $this->field("gid"); }
    function pid_idx()		{ return $this->field("pid_idx"); }
    function gid_idx()		{ return $this->field("gid_idx"); }
    function imageid()		{ return $this->field("imageid"); }
    function parent_imageid()	{ return $this->field("parent_imageid"); }
    function parent_version()	{ return $this->field("parent_version"); }
    function image_uuid()	{ return $this->field("image_uuid"); }
    function uuid()		{ return $this->field("uuid"); }
    function creator()		{ return $this->field("creator"); }
    function creator_idx()	{ return $this->field("creator_idx"); }
    function creator_urn()	{ return $this->field("creator_urn"); }
    function created()		{ return $this->field("created"); }
    function deleted()		{ return $this->field("deleted"); }
    function description()	{ return $this->field("description"); }
    function loadpart()		{ return $this->field("loadpart"); }
    function loadlength()	{ return $this->field("loadlength"); }
    function part1_osid()	{ return $this->field("part1_osid"); }
    function part2_osid()	{ return $this->field("part2_osid"); }
    function part3_osid()	{ return $this->field("part3_osid"); }
    function part4_osid()	{ return $this->field("part4_osid"); }
    function part1_vers()	{ return $this->field("part1_vers"); }
    function part2_vers()	{ return $this->field("part2_vers"); }
    function part3_vers()	{ return $this->field("part3_vers"); }
    function part4_vers()	{ return $this->field("part4_vers"); }
    function default_osid()	{ return $this->field("default_osid"); }
    function default_vers()	{ return $this->field("default_vers"); }
    function path()		{ return $this->field("path"); }
    function magic()		{ return $this->field("magic"); }
    function ezid()		{ return $this->field("ezid"); }
    function shared()		{ return $this->field("shared"); }
    function isglobal()		{ return $this->field("global"); }
    function listed()		{ return $this->field("listed"); }
    function updated()		{ return $this->field("updated"); }
    function updater()		{ return $this->field("updater"); }
    function updater_urn()	{ return $this->field("updater_urn"); }
    function mbr_version()	{ return $this->field("mbr_version"); }
    function hash()		{ return $this->field("hash"); }
    function metadata_url()	{ return $this->field("metadata_url"); }
    function imagefile_url()	{ return $this->field("imagefile_url"); }
    function origin_uuid()	{ return $this->field("origin_uuid"); }
    function origin_name()	{ return $this->field("origin_name"); }
    function origin_urn()	{ return $this->field("origin_urn"); }
    function logfileid()	{ return $this->field("logfileid"); }
    function noexport()		{ return $this->field("noexport"); }
    function ready()		{ return $this->field("ready"); }
    function isdataset()	{ return $this->field("isdataset"); }
    function nodelta()		{ return $this->field("nodelta"); }
    function released()		{ return $this->field("released"); }
    function notes()		{ return $this->field("notes"); }
    function locked()		{ return $this->field("image_locked"); }
    function size()		{ return $this->field("size"); }
    function lba_low()		{ return $this->field("lba_low"); }
    function lba_high()		{ return $this->field("lba_high"); }
    function lba_size()		{ return $this->field("lba_size"); }
    function nodetypes()	{ return $this->field("nodetypes"); }
    function webtask_id()	{ return $this->field("webtask_id"); }
    function deprecated()	{ return $this->field("deprecated"); }
    function deprecated_iserror(){ return $this->field("deprecated_iserror"); }
    function deprecated_message(){ return $this->field("deprecated_message"); }
    function ims_reported()	{ return $this->field("ims_reported"); }
    function ims_noreport()	{ return $this->field("ims_noreport"); }
    function ims_update()	{ return $this->field("ims_update"); }

    # Return the DB data.
    function DBData()		{ return $this->image; }
    # and the types array
    function Types()		{ return $this->TypeList(); }

    # Concat id/vers.
    function versid() { return $this->imageid() . ":" . $this->version(); }

    #
    # Access Check, determines if $user can access $this record.
    # 
    function AccessCheck($user, $access_type) {
	global $TB_IMAGEID_READINFO;
	global $TB_IMAGEID_MODIFYINFO;
	global $TB_IMAGEID_DESTROY;
	global $TB_IMAGEID_ACCESS;
	global $TB_IMAGEID_EXPORT;
	global $TB_IMAGEID_MIN;
	global $TB_IMAGEID_MAX;
	global $TBDB_TRUST_USER;
	global $TBDB_TRUST_GROUPROOT;
	global $TBDB_TRUST_LOCALROOT;
	$mintrust = $TB_IMAGEID_READINFO;

	if ($access_type < $TB_IMAGEID_MIN || $access_type > $TB_IMAGEID_MAX) {
	    TBERROR("Invalid access type $access_type!", 1);
	}

        #
        # Admins do whatever they want!
        # 
	if (ISADMIN()) {
	    return 1;
	}

	$shared = $this->shared();
	$global = $this->isglobal();
	$imageid= $this->imageid();
	$pid    = $this->pid();
	$gid    = $this->gid();
	$uid    = $user->uid();
	$uid_idx= $user->uid_idx();
	$pid_idx= $user->uid_idx();
	$gid_idx= $user->uid_idx();

        #
        # Global ImageIDs can be read by anyone but written with permission.
        # 
	if ($global) {
	    if ($access_type == $TB_IMAGEID_READINFO) {
		return 1;
	    }
	}

        #
        # Otherwise must have proper trust in the project.
        # 
	if ($access_type == $TB_IMAGEID_READINFO) {
	    $mintrust = $TBDB_TRUST_USER;
            #
            # Shared imageids are readable by anyone in the project.
            #
	    if ($shared)
		$gid = $pid;
	}
	else {
	    $mintrust = $TBDB_TRUST_LOCALROOT;
	}

	if (TBMinTrust(TBGrpTrust($uid, $pid, $gid), $mintrust) ||
	    TBMinTrust(TBGrpTrust($uid, $pid, $pid), $TBDB_TRUST_GROUPROOT)) {
	    return 1;
	}
        # No point in looking further; never allowed.
	if ($access_type == $TB_IMAGEID_EXPORT) {
	    return 0;
	}
	
	#
	# Look in the image permissions. First look for a user permission,
	# then look for a group permission.
	#
	$query_result = 
	    DBQueryFatal("select allow_write from image_permissions ".
			 "where imageid='$imageid' and ".
			 "      permission_type='user' and ".
			 "      permission_idx='$uid_idx'");
	
	if (mysql_num_rows($query_result)) {
	    $row  = mysql_fetch_array($query_result);

            # Only allowed to read.
	    if ($access_type == $TB_IMAGEID_READINFO ||
		$access_type == $TB_IMAGEID_ACCESS)
		return 1;
	}
	$trust_none = TBDB_TRUSTSTRING_NONE;
	$query_result = 
	    DBQueryFatal("select allow_write from group_membership as g ".
			 "left join image_permissions as p on ".
			 "     p.permission_type='group' and ".
			 "     p.permission_idx=g.gid_idx ".
			 "where g.uid_idx='$uid_idx' and ".
			 "      p.imageid='$imageid' and ".
			 "      trust!='$trust_none'");

	if (mysql_num_rows($query_result)) {
            # Only allowed to read.
	    if ($access_type == $TB_IMAGEID_READINFO ||
		$access_type == $TB_IMAGEID_ACCESS)
		return 1;
	}
	return 0;
    }

    #
    # Load the project object for an experiment.
    #
    function Project() {
	$pid_idx = $this->pid_idx();

	if ($this->project)
	    return $this->project;

	$this->project = Project::Lookup($pid_idx);
	if (! $this->project) {
	    TBERROR("Could not lookup project $pid_idx!", 1);
	}
	return $this->project;
    }
    #
    # Load the group object for an experiment.
    #
    function Group() {
	$gid_idx = $this->gid_idx();

	if ($this->group)
	    return $this->group;

	$this->group = Group::Lookup($gid_idx);
	if (! $this->group) {
	    TBERROR("Could not lookup group $gid_idx!", 1);
	}
	return $this->group;
    }

    #
    # Last used stamp.
    #
    function LastUsed() {
	$imageid = $this->imageid();
        
	$usage_result =
	    DBQueryFatal("select FROM_UNIXTIME(stamp) as lastused ".
			 "  from image_history ".
			 "where action='os_setup' and imageid='$imageid' ".
			 "order by stamp desc limit 1");
	if (!mysql_num_rows($usage_result)) {
            return null;
        }
        $urow = mysql_fetch_array($usage_result);
        return $urow['lastused'];
    }

    function Show($showperms = 0) {
	global $TBBASE, $DOPROVENANCE;
	
	$imageid	= $this->imageid();
	$imagename	= $this->imagename();
	$version	= $this->version();
	$pid		= $this->pid();
	$gid		= $this->gid();
	$description	= $this->description();
	$loadpart	= $this->loadpart();
	$loadlength	= $this->loadlength();
	$part1_osid	= $this->part1_osid();
	$part2_osid	= $this->part2_osid();
	$part3_osid	= $this->part3_osid();
	$part4_osid	= $this->part4_osid();
	$part1_vers	= $this->part1_vers();
	$part2_vers	= $this->part2_vers();
	$part3_vers	= $this->part3_vers();
	$part4_vers	= $this->part4_vers();
	$default_osid	= $this->default_osid();
	$default_vers	= $this->default_vers();
	$path		= $this->path();
	$shared		= $this->shared();
	$globalid	= $this->isglobal();
	$creator	= $this->creator();
	$creator_urn	= $this->creator_urn();
	$created	= $this->created();
	$updated	= $this->updated();
	$updater	= $this->updater();
	$updater_urn	= $this->updater_urn();
	$uuid           = $this->uuid();
	$image_uuid     = $this->image_uuid();
	$mbr_version    = $this->mbr_version();
	$hash           = $this->hash();
	$notes          = $this->notes();
	$isdataset      = $this->isdataset();
        
	#
	# An imported image has a metadata_url, and at the moment I
	# do want to worry about exporting an imported image.
	#
	$imagefile_url  = $this->imagefile_url();
	$metadata_url   = $this->metadata_url();

	if (!$description)
	    $description = "&nbsp;";
	if (!$path)
	    $path = "&nbsp;";
	if (!$created)
	    $created = "N/A";
	if (!strcmp($notes, ""))
	    $notes = "&nbsp;";
    
        #
        # Generate the table.
        #
	echo "<table align=center border=2 cellpadding=2 cellspacing=2>\n";

	echo "<tr>
                <td>Image Name: </td>
                <td class=\"left\">$imagename</td>
              </tr>\n";

	echo "<tr>
                <td>Description: </td>
                <td class=left>\n";
	echo "$description";
	echo "   </td>
 	      </tr>\n";

	echo "<tr>
                <td>Project: </td>
                <td class=\"left\">
                  <a href='showproject.php3?pid=$pid'>$pid</a></td>
              </tr>\n";

	echo "<tr>
                  <td>Group: </td>
                  <td class=\"left\">
                    <a href='showgroup.php3?pid=$pid&gid=$gid'>$gid</a></td>
              </tr>\n";
    
	echo "<tr>
                <td>Created: </td>
                <td class=left>$created</td>
 	      </tr>\n";

	echo "<tr>
                <td>Creator: </td>
                <td class=left>$creator</td>
     	      </tr>\n";

	if ($creator_urn) {
	    echo "<tr>
                    <td>Creator URN: </td>
                    <td class=left>$creator_urn</td>
         	  </tr>\n";
	}
	    
	if ($updated) {
	    echo "<tr>
                    <td>Updated: </td>
                    <td class=left>$updated</td>
     	          </tr>\n";
	    echo "<tr>
                    <td>Updated By: </td>
                    <td class=left>$updater</td>
     	          </tr>\n";
	    if ($updater_urn) {
		echo "<tr>
                        <td>Updater URN: </td>
                        <td class=left>$updater_urn</td>
         	          </tr>\n";
	    }
	}
	$deleted = $this->deleted();
	if (isset($deleted)) {
	    
	    echo "<tr>
                    <td><font color=red>Deleted: </font></td>
                    <td class=left><font color=red>$deleted</font></td>
     	          </tr>\n";
	}

	#
	# Find the last time this image was used. 
	#
	$usage_result =
	    DBQueryFatal("select FROM_UNIXTIME(stamp) as lastused ".
			 "  from image_history ".
			 "where action='os_setup' and imageid='$imageid' ".
			 "order by stamp desc limit 1");
	if (mysql_num_rows($usage_result)) {
	    $urow = mysql_fetch_array($usage_result);
	    $lastused = $urow['lastused'];

	    echo "<tr>
                    <td>Last Used: </td>
                    <td class=\"left\">$lastused</td>
                  </tr>\n";
	}

        if ($isdataset) {
            echo "<tr>
                    <td>Dataset?: </td>
                    <td class=\"left\">Yes</td>
                  </tr>\n";
        }
        else {
            echo "<tr>
                    <td>Load Partition: </td>
                    <td class=\"left\">$loadpart</td>
                  </tr>\n";
            
            echo "<tr>
                    <td>Load Length: </td>
                    <td class=\"left\">$loadlength</td>
                  </tr>\n";
        }

	if ($part1_osid) {
	    echo "<tr>
                     <td>Partition 1 OS: </td>
                     <td class=\"left\">";
	    SpitOSIDLink($part1_osid, $part1_vers);
	    echo "   </td>
                  </tr>\n";
	}

	if ($part2_osid) {
	    echo "<tr>
                     <td>Partition 2 OS: </td>
                     <td class=\"left\">";
	    SpitOSIDLink($part2_osid, $part2_vers);
	    echo "   </td>
                  </tr>\n";
	}

	if ($part3_osid) {
	    echo "<tr>
                     <td>Partition 3 OS: </td>
                     <td class=\"left\">";
	    SpitOSIDLink($part3_osid, $part3_vers);
	    echo "   </td>
                  </tr>\n";
	}

	if ($part4_osid) {
	    echo "<tr>
                     <td>Partition 4 OS: </td>
                     <td class=\"left\">";
	    SpitOSIDLink($part4_osid, $part4_vers);
	    echo "   </td>
                  </tr>\n";
	}

	if ($default_osid) {
	    echo "<tr>
                     <td>Boot OS: </td>
                     <td class=\"left\">";
	    SpitOSIDLink($default_osid, $default_vers);
	    echo "   </td>
                  </tr>\n";
	}

	echo "<tr>
                <td>Filename: </td>
                <td class=left>\n";
	echo "$path";
	echo "  </td>
              </tr>\n";

        if (!$isdataset) {
            if ($this->architecture()) {
                echo "<tr>
                        <td>Architecture: </td>
                        <td class=left>" . $this->architecture();
                echo "  </td>
                     </tr>\n";
            }
            echo "<tr>
                      <td>Types: </td>
                      <td class=left>\n";
            echo "&nbsp;";
            foreach ($this->Types() as $type) {
                echo "$type &nbsp; ";
            }
            echo "  </td>
                  </tr>\n";
        }

	echo "<tr>
                <td>Shared?: </td>
                <td class=left>\n";
	if ($shared)
	    echo "Yes";
	else
	    echo "No";
    
	echo "  </td>
              </tr>\n";

	echo "<tr>
                <td>Global?: </td>
                <td class=left>\n";

	$globalflip = ($globalid ? 0 : 1);
	$globalval  = ($globalid ? "Yes" : "No");
	echo "$globalval (<a href='toggle.php?imageid=$imageid".
	    "&type=imageglobal&value=$globalflip'>Toggle</a>)";
	echo "  </td>
              </tr>\n";

	echo "<tr>
                <td>Internal ID (Vers): </td>
                <td class=left>$imageid ($version)</td>
              </tr>\n";

	if ($this->parent_imageid()) {
	    $p_imageid   = $this->parent_imageid();
	    $p_version   = $this->parent_version();
	    $p_image     = Image::Lookup($p_imageid, $p_version);
	    # On an elabinelab we will not have the previous version.
	    # if it came in at creation time.
	    if ($p_image) {
		$p_imagename = $p_image->imagename();
		$p_url       = CreateURL("showimageid", $p_image,
					 "version", $p_version);
	    
		echo "<tr>
                        <td>Derived from: </td>
                        <td class=left><a href='$p_url'>
                          ${p_imagename}:${p_version}</a></td>
                     </tr>\n";
	    }
	}
	if ($this->version() > 0 &&
	    (is_null($this->parent_imageid()) ||
	     ($this->parent_imageid() &&
	      $this->parent_imageid() != $this->imageid()))) {
	    $p_version   = $this->version() - 1;
	    $p_url       = CreateURL("showimageid", $this,
				     "version", $p_version);
	    echo "<tr>
                    <td>Previous Vers: </td>
                    <td class=left>
                        <a href='$p_url'>${imagename}:${p_version}</a></td>
                  </tr>\n";
	}

	# Look for an unreleased version of this image.
	$unreleased = $this->LookupUnreleased();
	if ($unreleased && $unreleased->version() != $this->version()) {
	    $u_version = $unreleased->version();
	    $u_url     = CreateURL("showimageid", $this, "version", $u_version);

	    echo "<tr>
                    <td>Unreleased Vers: </td>
                    <td class=left>
                         <a href='$u_url'>${imagename}:${u_version}</a></td>
                  </tr>\n";
	}
	if ($DOPROVENANCE) {
	    $released = $this->released();
	    $ready    = $this->ready();
	    $isdelta  = $this->size() ? 0 : 1;
	    $nodelta  = $this->nodelta();
	    
	    echo "<tr>
                    <td>Rdy/Rel/Delta/NoD: </td>
                    <td class=left>$ready/$released/$isdelta/$nodelta</td>
                  </tr>\n";
	}

	echo "<tr>
                <td>MBR Version: </td>
                <td class=left>$mbr_version</td>
              </tr>\n";

	# Until I change the schema.
	if ($mbr_version == 99) {
	    echo "<tr>
                    <td>XEN Package: </td>
                    <td class=left>Yes</td>
                  </tr>\n";
	}
	if ($this->ezid()) {
	    $doesxen = 0;
	    $osinfo = $this->OSinfo();
	    if ($osinfo && $osinfo->def_parentosid()) {
		$parentosinfo = OSinfo::Lookup($osinfo->def_parentosid());
		if ($parentosinfo &&
		    $parentosinfo->FeatureSupported("xen-host")) {
		    $doesxen = 1;
		}
	    }
	    $xenval  = ($doesxen ? "Yes" : "No");
	    $xenflip = ($doesxen ? 0 : 1);

	    echo "<tr>
                  <td>XEN Capable?:</td>
   	          <td class=left>
                     $xenval (<a href='toggle.php?imageid=$imageid".
		          "&type=imagedoesxen&value=$xenflip'>Toggle</a>
                      if you know this image can run
               as a XEN guest. More info
               <a target=_blank
                  href='https://wiki.emulab.net/wiki/Emulab/wiki/xen'>here</a>)
              </td>
             </tr>\n";
	}

	if ($hash) {
	    echo "<tr>
                    <td>SHA1 Hash: </td>
                    <td class=left>$hash</td>
                  </tr>\n";
	}

	echo "<tr>
                <td>Version UUID: </td>
                <td class=left>$uuid</td>
              </tr>\n";

	echo "<tr>
                <td>Image UUID: </td>
                <td class=left>$image_uuid</td>
              </tr>\n";

	if ($metadata_url) {
            echo "<tr>
                <td>Metadata URL: </td>
                <td class=left><a href='$metadata_url'>https:// ...</a></td>
              </tr>\n";
        }
        else {
	    $version_url = "$TBBASE/image_metadata.php?uuid=$uuid";
	    $image_url   = "$TBBASE/image_metadata.php?uuid=$image_uuid";
            echo "<tr>
                     <td>Version URL: </td>
                     <td class=left><a href='$version_url'>https:// ...</a></td>
                  </tr>\n";
            echo "<tr>
                     <td>ImageURL: </td>
                     <td class=left><a href='$image_url'>https:// ...</a></td>
                  </tr>\n";
	}

        echo "<tr>
                 <td>Notes: </td>
                 <td class=left>
                     <textarea rows=4 cols=60 readonly>" .
			    str_replace("\r", "", $notes) .
	              "</textarea></td>
              </tr>\n";

	if ($imagefile_url) {
	    echo "<tr>
                   <td>Image File URL: </td>
                   <td class=left><a href='$imagefile_url'>https:// ...</a></td>
                  </tr>\n";
	}

	#
	# Show who all can access this image outside the project.
	#
	if ($showperms) {
	    $query_result =
		DBQueryFatal("select distinct * from image_permissions ".
			     "where imageid='$imageid' ".
			     "order by permission_type,permission_id");
	    if (mysql_num_rows($query_result)) {
		echo "<tr>
                      <td align=center colspan=2>
                      External permissions
                      </td>
                  </tr>\n";

		while ($row = mysql_fetch_array($query_result)) {
		    $perm_type = $row['permission_type'];
		    $perm_idx  = $row['permission_idx'];
		    $writable  = $row['allow_write'];

		    if ($writable) {
			$writable = "(read/write)";
		    }
		    else {
			$writable = "(read only)";
		    }

		    if ($perm_type == "user") {
			$user = User::Lookup($perm_idx);
			if (isset($user)) {
			    $uid = $user->uid();
			    echo "<tr>
                                    <td>User: </td>
                                    <td class=left>$uid $writable</td>
                                  </tr>\n";
			}
		    }
		    elseif ($perm_type == "group") {
			$group = Group::Lookup($perm_idx);
			if (isset($group)) {
			    $pid = $group->pid();
			    $gid = $group->gid();
			    echo "<tr>
                                    <td>Group: </td>
                                    <td class=left>$pid/$gid $writable</td>
                                  </tr>\n";
			}
		    }
		}
	    }
	}

	echo "</table>\n";
    }

    #
    # See if an image is inuse.
    #
    function InUse() {
	$imageid = $this->imageid();

	$query_result1 =
	    DBQueryFatal("select * from current_reloads ".
			 "where image_id='$imageid'");
	$query_result2 =
	    DBQueryFatal("select * from scheduled_reloads ".
			 "where image_id='$imageid'");
	$query_result3 =
	    DBQueryFatal("select * from node_type_attributes ".
			 "where attrkey='default_imageid' and ".
			 "      attrvalue='$imageid' limit 1");

	if (mysql_num_rows($query_result1) ||
	    mysql_num_rows($query_result2) ||
	    mysql_num_rows($query_result3)) {
	    return 1;
	}
	return 0;
    }

    function TypeList() {
	$imageid = $this->imageid();
        $version = $this->version();
        $result  = array();

        #
        # Deleted images stash a list in the descriptor.
        #
        $deleted = $this->deleted();
        if (isset($deleted)) {
            $nodetypes = $this->nodetypes();
            if (isset($nodetypes)) {
                foreach (preg_split("/,/", $this->nodetypes()) as $type) {
                    $result[] = $type;
                }
            }
            return $result;
        }
        #
        # If there is an architecture set in the image, we use that to
        # find the matching types in the node_types table. This overrides
        # anything found in the osidtoimageid.
        #
        $arch = $this->architecture();
        if (isset($arch)) {
            $query_result =
                DBQueryFatal("select distinct nt.type from images as i ".
                             # The image architecture could be a short list.
                             "inner join node_types as nt on ".
                             "   FIND_IN_SET(nt.architecture,i.architecture) ".
                             "where i.imageid='$imageid'");

            $osinfo = OSinfo::Lookup($imageid, $version);
            if ($osinfo && $osinfo->def_parentosid()) {
                $result[] = "pcvm";
            }
        }
        else {
            $query_result =
                DBQueryFatal("select distinct type from osidtoimageid ".
                             "where imageid='$imageid'");
        }
        while ($row = mysql_fetch_array($query_result)) {
            $type = $row['type'];
            $result[] = $type;
        }
	return $result;
    }

    function GetLogfile() {
	$this->Refresh();
	
	if ($this->logfileid()) 
	    return Logfile::Lookup($this->logfileid());
	return null;
    }

    function DoesXen($does) {
	$imageid = $this->imageid();
	$version = $this->version();
	
	if ($does) {
            if (TBSiteVarExists("general/default_xen_parentosid")) {
                $xenname = TBGetSiteVar("general/default_xen_parentosid");
            }
            else {
                $xenname = "emulab-ops,XEN43-64-STD";
            }
	    list($pid,$osname) = preg_split('/,/', $xenname);
	    $parentosinfo = OSinfo::LookupByName($pid,$osname);
	    if (!$parentosinfo) {
                return -1;
	    }
	    $parentosid = $parentosinfo->osid();

	    DBQueryFatal("update os_info_versions set ".
			 "    def_parentosid='$parentosid' ".
			 "where osid='$imageid' and vers='$version'");
	    DBQueryFatal("replace into os_submap set ".
			 "  osid='$imageid', parent_osid='$parentosid'");
	    DBQueryFatal("replace into osidtoimageid set ".
			 " osid='$imageid', type='pcvm', imageid='$imageid'");
	}
	else {
	    DBQueryFatal("delete from osidtoimageid ".
			 "where osid='$imageid' and type='pcvm'");
	    DBQueryFatal("delete from os_submap ".
			 "where osid='$imageid'");
	    DBQueryFatal("update os_info_versions set def_parentosid=NULL ".
			 "where osid='$imageid' and vers='$version'");
	}
	return 0;
    }

    #
    # Page header; spit back some html for the typical page header.
    #
    function PageHeader() {
	$pid = $this->pid();
	$imagename = $this->imagename();
	$imageid = $this->imageid();
	$version = $this->version();
	
	$html = "<font size=+1>Image <b>".
	    "<a href='showproject.php3?pid=$pid'>$pid</a>/".
	    "<a href='showimageid.php3?imageid=$imageid&version=$version'>".
	    "$imagename</a>".
	    "</b></font>\n";

	return $html;
    }
    function OSinfo() {
	return OSinfo::Lookup($this->imageid(), $this->version());
    }

    function URL() {
        global $TBBASE;
	$uuid           = $this->uuid();
        $image_uuid     = $this->image_uuid();

        return "$TBBASE/image_metadata.php?uuid=$image_uuid";
    }
    function VersionURL() {
        global $TBBASE;
	$uuid           = $this->uuid();
        $image_uuid     = $this->image_uuid();

        return "$TBBASE/image_metadata.php?uuid=$uuid";
    }
}
