<?php
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
chdir("..");
include("defs.php3");
include_once("webtask.php");
chdir("apt");
include("quickvm_sup.php");
include_once("profile_defs.php");
include_once("instance_defs.php");
$page_title = "Manage Profile";
$notifyupdate = 0;
$notifyclone = 0;

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();
if ((!isset($action) || $action == "create") && NOPROJECTMEMBERSHIP()) {
    return NoProjectMembershipError($this_user);
}

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("create",      PAGEARG_STRING,
				 "action",      PAGEARG_STRING,
				 "uuid",        PAGEARG_STRING,
                                 "fromexp",     PAGEARG_STRING,
				 "copyuuid",    PAGEARG_STRING,
				 "snapuuid",    PAGEARG_STRING,
				 "snapnode_id", PAGEARG_NODEID,
				 "finished",    PAGEARG_BOOLEAN,
                                 "updated",     PAGEARG_INTEGER,
				 "formfields",  PAGEARG_ARRAY);

#
# Spit the form
#
function SPITFORM($formfields, $errors)
{
    global $this_user, $projlist, $action, $profile, $DEFAULT_AGGREGATE;
    global $notifyupdate, $notifyclone, $copyuuid, $snapuuid, $snapnode_id;
    global $ISCLOUD, $fromexp;
    global $version_array, $WITHPUBLISHING;
    $viewing    = 0;
    $candelete  = 0;
    $nodelete   = 0;
    $canmodify  = 0;
    $canpublish = 0;
    $history    = 0;
    $activity   = 0;
    $paramsets  = 0;
    $ispp       = 0;
    $isadmin    = (ISADMIN() ? 1 : 0);
    $isstud     = (STUDLY() ? 1 : 0);
    $isleader   = 0;
    $iscreator  = 0;
    $canrepo    = (ISADMIN() || STUDLY() ? 1 : 0);
    $multisite  = ($ISCLOUD ? 1 : 0);
    $cloning    = 0;
    $copying    = 0;
    $disabled   = 0;
    $version_uuid = "null";
    $profile_uuid = "null";
    $this_version = "null";
    $latest_uuid    = "null";
    $latest_version = "null";
    $profile_pid    = "null";

    if ($action == "edit") {
	$button_label = "Save";
	$viewing      = 1;
	$version_uuid = "'" . $profile->uuid() . "'";
	$profile_uuid = "'" . $profile->profile_uuid() . "'";
	$profile_pid  = "'" . $profile->pid() . "'";
	$candelete    = ($profile->CanDelete($this_user) ? 1 : 0);
	$nodelete     = ($profile->isLocked() ? 1 : 0);
	$history      = ($profile->HasHistory() ? 1 : 0);
	$paramsets    = ($profile->HasParamsets($this_user) ? 1 : 0);
	$canmodify    = ($profile->CanModify() ? 1 : 0);
	$canpublish   = ($profile->CanPublish() ? 1 : 0);
	$activity     = ($profile->HasActivity($this_user) ? 1 : 0);
	$ispp         = ($profile->isParameterized() ? 1 : 0);
        $disabled     = ($profile->isDisabled() ? 1 : 0);
        $isleader     = ($profile->isLeader($this_user) ? 1 : 0);
        $iscreator    = ($profile->isCreator($this_user) ? 1 : 0);
        $this_version = $profile->version();
	if ($canmodify) {
	    $title    = "Modify Profile";
	}
	else {
	    $title    = "View Profile";
	}
        $latest_profile = Profile::Lookup($profile->profile_uuid());
        $latest_uuid    = "'" . $latest_profile->uuid() . "'";
        $latest_version = $latest_profile->version();
    }
    else  {
        # New page action is now create, not copy or clone.
        if ($action == "copy" || $action == "clone") {
            if ($action == "clone") {
                $cloning = 1;
            }
            else {
                $copying = 1;
            }
	    $action = "create";
        }
	$button_label = "Create";
	$title        = "Create Profile";
        $iscreator    = 1;
    }

    SPITHEADER(1);

    echo "<div id='ppviewmodal_div'></div>\n";
    # Place to hang the toplevel template.
    echo "<div id='page-body'></div>\n";

    # Place to hang the genilib-editor template.
    echo "<div id='genilib-editor-body'></div>\n";

    # These two modals live outside so that genilib-editor can
    # use them as well.
    echo "<div id='waitwait_div'></div>
          <div id='oops_div'></div>";

    # I think this will take care of XSS prevention?
    echo "<script type='text/plain' id='form-json'>\n";
    echo htmlentities(json_encode($formfields)) . "\n";
    echo "</script>\n";
    echo "<script type='text/plain' id='error-json'>\n";
    echo htmlentities(json_encode($errors));
    echo "</script>\n";

    # Needed for genilib-editor
    echo "<script src='https://cdn.jsdelivr.net/ace/1.2.3/noconflict/ace.js'></script>\n";
    echo "<script src='https://cdn.jsdelivr.net/ace/1.2.3/noconflict/keybinding-vim.js'></script>\n";
    echo "<script src='https://cdn.jsdelivr.net/ace/1.2.3/noconflict/keybinding-emacs.js'></script>\n";

    # Pass project list through. Need to convert to list without groups.
    $plist = array();
    while (list($project) = each($projlist)) {
        $plist[] = $project;
    }
    echo "<script type='text/plain' id='projects-json'>\n";
    echo htmlentities(json_encode($plist));
    echo "</script>\n";

    if ($viewing) {
        echo "<script type='text/plain' id='versions-json'>\n";
        echo json_encode($version_array);
        echo "</script>\n";
    }
    
    echo "<link rel='stylesheet'
            href='css/jquery-ui-1.10.4.custom.min.css'>\n";
    echo "<link rel='stylesheet'
            href='css/jquery.appendGrid-1.3.1.min.css'>\n";
    # For progress bubbles in the imaging modal.
    echo "<link rel='stylesheet' href='css/progress.css'>\n";
    echo "<link rel='stylesheet' href='css/codemirror.css'>\n";
    echo "<link rel='stylesheet' href='css/genilib-editor.css'>\n";

    SpitAggregateStatus();
    echo "<script type='text/javascript'>\n";
    echo "    window.VIEWING  = $viewing;\n";
    echo "    window.VERSION_UUID = $version_uuid;\n";
    echo "    window.PROFILE_UUID = $profile_uuid;\n";
    echo "    window.PROFILE_PID = $profile_pid;\n";
    echo "    window.LATEST_UUID = $latest_uuid;\n";
    echo "    window.LATEST_VERSION = $latest_version;\n";
    echo "    window.THIS_VERSION = $this_version;\n";
    echo "    window.UPDATED  = $notifyupdate;\n";
    echo "    window.SNAPPING = $notifyclone;\n";
    echo "    window.AJAXURL  = 'server-ajax.php';\n";
    echo "    window.ACTION   = '$action';\n";
    echo "    window.CANDELETE= $candelete;\n";
    echo "    window.NODELETE = $nodelete;\n";
    echo "    window.CANEDIT= $canmodify;\n";
    echo "    window.CANPUBLISH= $canpublish;\n";
    echo "    window.DISABLED= $disabled;\n";
    echo "    window.ISADMIN  = $isadmin;\n";
    # Compatabilty with show-profile.
    echo "    window.ISGUEST  = 0;\n";
    echo "    window.ISSTUD  = $isstud;\n";
    echo "    window.ISCREATOR = $iscreator;\n";
    echo "    window.ISLEADER = $isleader;\n";
    echo "    window.MULTISITE = $multisite;\n";
    echo "    window.HISTORY  = $history;\n";
    echo "    window.CLONING  = $cloning;\n";
    echo "    window.COPYING  = $copying;\n";
    echo "    window.ACTIVITY = $activity;\n";
    echo "    window.PARAMSETS= $paramsets;\n";
    echo "    window.TITLE    = '$title';\n";
    echo "    window.BUTTONLABEL = '$button_label';\n";
    echo "    window.ISPPPROFILE = $ispp;\n";
    echo "    window.WITHPUBLISHING = $WITHPUBLISHING;\n";
    if (isset($copyuuid)) {
	echo "    window.COPYUUID = '$copyuuid';\n";
    }
    elseif (isset($snapuuid)) {
	echo "    window.SNAPUUID = '$snapuuid';\n";
        if (isset($snapnode_id)) {
            echo "    window.SNAPNODE_ID = '$snapnode_id';\n";
        }
    }
    if (isset($fromexp)) {
	echo "    window.EXPUUID = '$fromexp';\n";
    }
    echo "    window.CANREPO = $canrepo;\n";
    echo "</script>\n";
    echo "<script src='js/lib/jquery-ui.js'></script>\n";
    echo "<script src='js/lib/jquery.appendGrid-1.3.1.min.js'></script>\n";
    echo "<script src='js/lib/codemirror-min.js'></script>\n";

    REQUIRE_UNDERSCORE();
    REQUIRE_SUP();
    REQUIRE_FILESIZE();
    REQUIRE_JACKS_EDITOR();
    REQUIRE_IMAGE();
    REQUIRE_MOMENT();
    REQUIRE_APTFORMS();
    REQUIRE_FILESTYLE();
    REQUIRE_MARKED();
    REQUIRE_GENILIB_EDITOR();
    AddLibrary("js/copy-profile.js");
    AddLibrary("js/gitrepo.js");
    AddLibrary("js/paramhelp.js");
    AddLibrary("js/profile-support.js");
    AddTemplateList(array('confirm-delete-profile', 'profile-list-modal'));
    SPITREQUIRE("js/manage_profile.js");

    AddTemplateList(array('manage-profile', 'waitwait-modal', 'renderer-modal', 'showtopo-modal', 'oops-modal', 'rspectextview-modal', 'publish-modal', 'share-modal', 'gitrepo-picker', "copy-repobased-profile", "copy-profile-modal"));
    SPITFOOTER();
}

#
# See what projects the user can do this in.
#
$projlist = $this_user->ProjectAccessList($TB_PROJECT_CREATEEXPT);

if (isset($action) && ($action == "edit" || $action == "copy")) {
    if (!isset($uuid)) {
	SPITUSERERROR("Must provide uuid!");
    }
    else {
	$profile = Profile::Lookup($uuid);
	if (!$profile) {
	    SPITUSERERROR("No such profile!");
	}
	else if ($profile->locked()) {
	    SPITUSERERROR("Profile is currently locked!");
	}
	else if ($profile->deleted()) {
	    SPITUSERERROR("Profile has been deleted!");
	}
	if ($action == "edit") {
            if (!$profile->CanEdit($this_user)) {
		SPITUSERERROR("Not enough permission!");
	    }
	}
	elseif (!$profile->CanView($this_user) && !ISADMIN()) {
	    SPITUSERERROR("Not enough permission!");
	}
        #
        # Spit out the version history.
        #
        $version_array  = array();
        $profileid      = $profile->profileid();

        $query_result =
            DBQueryFatal("select v.*,DATE(v.created) as created, ".
                         "    vp.uuid as parent_uuid ".
                         "  from apt_profile_versions as v ".
                         "left join apt_profile_versions as vp on ".
                         "     v.parent_profileid is not null and ".
                         "     vp.profileid=v.parent_profileid and ".
                         "     vp.version=v.parent_version ".
                         "where v.profileid='$profileid' ".
                         "order by v.version asc");

        while ($row = mysql_fetch_array($query_result)) {
            $uuid    = $row["uuid"];
            $puuid   = $row["parent_uuid"];
            $version = $row["version"];
            $pversion= $row["parent_version"];
            $created = $row["created"];
            $deleted = (isset($row["deleted"]) ? 1 : 0);
            $published = $row["published"];
            $repourl = $row["repourl"];
            $rspec   = $row["rspec"];
            $desc    = '';
            $obj     = array();

            if (!$published) {
                $published = " ";
            }
            else {
                $published = date("Y-m-d", strtotime($published));
            }
            $parsed_xml = simplexml_load_string($rspec);
            if ($parsed_xml &&
                $parsed_xml->rspec_tour &&
                $parsed_xml->rspec_tour->description) {
                $desc = (string) $parsed_xml->rspec_tour->description;
            }
            $obj["uuid"]    = $uuid;
            $obj["version"] = $version;
            $obj["description"] = $desc;
            $obj["created"]     = $created;
            $obj["deleted"]     = $deleted;
            $obj["published"]   = $published;
            $obj["parent_uuid"] = $puuid;
            $obj["parent_version"] = $pversion;
            $version_array[]  = $obj;
        }
    }
}

if (! isset($create)) {
    $errors   = array();
    $defaults = array();

    # Default action is create.
    if (! isset($action) || $action == "") {
	$action = "create";
    }

    if (! (isset($projlist) && count($projlist))) {
	SPITUSERERROR("You do not appear to be a member of any projects in ".
                      "which you have permission to create new profiles");
    }
    if (isset($snapuuid)) {
        if (!IsValidUUID($snapuuid)) {
            SPITUSERERROR("Not a valid UUID for clone");
        }
        else {
            $instance = Instance::Lookup($snapuuid);
            if (!$instance) {
                SPITUSERERROR("No such instance to clone!");
            }
            else if ($this_idx != $instance->creator_idx() && !ISADMIN()) {
                SPITUSERERROR("Not enough permission!");
            }
            else if ($instance->status() != "ready") {
                SPITUSERERROR("Instance is busy, cannot clone it. " .
                              "Please try again later.");
            }
        }
    }
    if ($action == "edit" || $action == "clone" || $action == "copy") {
	if ($action == "clone" || $action == "copy") {
	    if ($action == "clone") {
		if (! isset($instance)) {
		    SPITUSERERROR("No experiment specified for clone!");
		}
		$profile = Profile::Lookup($instance->profile_id(),
					   $instance->profile_version());
		if (!$profile) {
		    SPITUSERERROR("Cannot load profile!");
		}
		if (!$profile->CanView($this_user)) {
		    SPITUSERERROR("Not allowed to access this profile!");
		}
	    }
            elseif ($action == "copy") {
                # Pass this along through the new create page.
                $copyuuid = $profile->uuid();
            }
	    $defaults["profile_who"]   = "private";
	    if ($profile->rspec() && $profile->rspec() != "") {
                $defaults["profile_rspec"]  = $profile->rspec();
            }
	    if ($profile->script() && $profile->script() != "") {
		$defaults["profile_script"] = $profile->script();
	    }
            $defaults["portal_converted"]
                = ($profile->portal_converted() == 1 ? "yes" : "no");
            
            # Default the project if in only one project.
	    if (count($projlist) == 1) {
		list($project) = each($projlist);
		reset($projlist);
		$defaults["profile_pid"] = $project;
	    }
            elseif (array_key_exists($profile->pid(), $projlist)) {
                #
                # Default to same project as the original, *if* the user
                # is a member of that project. Convenient.
                #
		$defaults["profile_pid"] = $profile->pid();
            }
	}
	else {
	    $defaults["profile_pid"]         = $profile->pid();
	    $defaults["profile_name"]        = $profile->name();
	    $defaults["profile_version"]     = $profile->version();
	    if ($profile->rspec() && $profile->rspec() != "") {
                $defaults["profile_rspec"] = $profile->rspec();
            }
	    if ($profile->script() && $profile->script() != "") {
		$defaults["profile_script"] = $profile->script();
                if ($profile->paramdefs() && $profile->paramdefs() != "") {
                    $defaults["profile_paramdefs"] = $profile->paramdefs();
                }
	    }
            $defaults["portal_converted"]
                = ($profile->portal_converted() == 1 ? "yes" : "no");
	    if ($profile->repourl() && $profile->repourl() != "") {
		$defaults["profile_repourl"]  = $profile->repourl();
                # Need this so JS code knows when HEAD changes.
		$defaults["profile_repohash"]  = $profile->repohash();
		$defaults["profile_repopushurl"]
                    = "https://www.emulab.net:51369/githook/" .
                    $profile->repokey();
	    }
	    $defaults["profile_creator"]     = $profile->creator();
	    $defaults["profile_updater"]     = $profile->updater();
	    $defaults["profile_created"]     =
		DateStringGMT($profile->created());
	    $defaults["profile_published"]   =
		($profile->published() ?
		 DateStringGMT($profile->published()) : "");
	    $defaults["profile_version_url"] = $profile->URL();
	    $defaults["profile_profile_url"] = $profile->ProfileURL();
	    $defaults["profile_listed"]      =
		($profile->listed() ? "checked" : "");
	    $defaults["profile_who"] =
		($profile->shared() ? "shared" : 
		 ($profile->ispublic() ? "public" : "private"));
	    $defaults["profile_topdog"]      =
		($profile->topdog() ? "checked" : "");
	    $defaults["profile_disabled"]      =
		($profile->isDisabled() ? "checked" : "");
	    $defaults["profile_nodelete"]      =
		($profile->isLocked() ? "checked" : "");
	    $defaults["profile_project_write"]      =
		($profile->project_write() ? "checked" : "");
	    $defaults["examples_portals"]      =
                ($profile->examples_portals() ?
                 $profile->examples_portals() : "");

	    # Warm fuzzy message.
	    if (isset($updated) && time() - $updated < 3) {
		$notifyupdate = 1;
	    }
	}
        #
        # See if we have a task running in the background
        # for this profile. At the moment it can only be a
        # clone task. If there is one, we have to tell
        # the js code to show the status of the clone.
        #
        $webtask = $profile->webtask();
        if ($webtask && $webtask->TaskValue("cloning")) {
            $notifyclone = 1;
        }
    }
    else {
	# Default the project if in only one project.
	if (count($projlist) == 1) {
	    list($project) = each($projlist);
	    reset($projlist);
	    $defaults["profile_pid"] = $project;
	}
        elseif (isset($instance) &&
                array_key_exists($instance->pid(), $projlist)) {
            #
            # Default to same project as the original, *if* the user
            # is a member of that project. Convenient.
            #
            $defaults["profile_pid"] = $instance->pid();
        }
	$defaults["profile_who"]   = "private";

        #
        # If coming from a classic emulab experiment, then do permission checks
        # and then use the NS file for the script. Also set the project.
        #
        if (isset($fromexp) && $fromexp != "") {
            $experiment = Experiment::LookupByUUID($fromexp);
            if (!$experiment) {
                SPITUSERERROR("No such classic emulab experiment!");
            }
            if (!$experiment->AccessCheck($this_user, $TB_EXPT_MODIFY)) {
                SPITUSERERROR("Not enough permission to create a profile from ".
                              "this classic emulab experiment");
            }
	    $defaults["profile_pid"] = $experiment->pid();
	    $defaults["profile_name"] = $experiment->eid();
        }
    }
    SPITFORM($defaults, $errors);
    return;
}

?>
