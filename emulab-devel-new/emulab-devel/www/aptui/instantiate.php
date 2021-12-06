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
include_once("osinfo_defs.php");
include_once("geni_defs.php");
include_once("webtask.php");
chdir("apt");
include("quickvm_sup.php");
include_once("instance_defs.php");
include_once("profile_defs.php");
$page_title = "Instantiate a Profile";
$dblink = GetDBLink("sa");
# Did the user provide "secret" hash to use the profile?
$ishashed = 0;
# Feature for new scheduling step.
$usenewschedule = 0;
# The specific profile to start with
$selected_profile = null;

#
# Get current user but make sure coming in on SSL. 
#
RedirectSecure();
$this_user = CheckLogin($check_status);
if (isset($this_user)) {
    CheckLoginOrDie(CHECKLOGIN_NONLOCAL|CHECKLOGIN_WEBONLY);
    if (NOPROJECTMEMBERSHIP()) {
        return NoProjectMembershipError($this_user);
    }
}
else {
    RedirectLoginPage();
}

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("profile",       PAGEARG_STRING,
				 "version",       PAGEARG_INTEGER,
				 "project",       PAGEARG_PROJECT,
				 "default",       PAGEARG_STRING,
				 "from",          PAGEARG_STRING,
				 "refspec",       PAGEARG_STRING,
                                 "rerun_instance",PAGEARG_UUID,
                                 "rerun_paramset",PAGEARG_UUID,
                                 "rerun_branch",  PAGEARG_BOOLEAN,
                                 "skipfirststep", PAGEARG_BOOLEAN,
				 "formfields",    PAGEARG_ARRAY);

# Need to make non-hardcoded
$maxduration = 16;

if (isset($rerun_instance) || isset($rerun_paramset) ||
    (isset($from) && ($from == "manage-profile" || $from == "show-profile"))) {
    $skipfirststep = 1;
}
if (isset($rerun_instance) && isset($rerun_paramset)) {
    SPITUSERERROR("Only one of rerun_paramset or rerun_instance allowed.");
    exit();
}
if ((isset($rerun_instance) || isset($rerun_paramset)) && isset($refspec)) {
    SPITUSERERROR("refspec not allowed with rerun_paramset/rerun_instance.");
    exit();
}

$projlist = $this_user->ProjectAccessList($TB_PROJECT_CREATEEXPT);
#
# Cull out the nonlocal projects, we do not want to show those
# since they are just the holding projects.
#
$tmp = array();
while (list($pid) = each($projlist)) {
    # Watch out for killing page variable called "project"
    $proj = Project::Lookup($pid);
    if ($proj && !$proj->IsNonLocal()) {
        $tmp[$pid] = $projlist[$pid];
        if (FeatureEnabled("NewScheduleStep", $this_user, $proj)) {
            $usenewschedule = 1;
        }
    }
}
$projlist = $tmp;
    
if (count($projlist) == 0) {
    SPITUSERERROR("You do not belong to any projects with permission to ".
                  "create new experiments. Please contact your project ".
                  "leader to grant you the neccessary privilege.");
    exit();
}
if ($ISCLOUD) {
    $portal_default_profile = TBGetSiteVar("cloudlab/default_profile");
    list ($profile_default_pid,
          $profile_default) = explode(',', $portal_default_profile);
}
elseif ($ISPNET) {
    $portal_default_profile = TBGetSiteVar("phantomnet/default_profile");
    list ($profile_default_pid,
          $profile_default) = explode(',', $portal_default_profile);
}
elseif ($ISPOWDER) {
    $portal_default_profile = "PowderProfiles,srsLTE-SIM";
    list ($profile_default_pid,
          $profile_default) = explode(',', $portal_default_profile);
}
else {
    $portal_default_profile = TBGetSiteVar("portal/default_profile");
    list ($profile_default_pid,
          $profile_default) = explode(',', $portal_default_profile);
}
$profile_array  = array();
$usageinfo      = UserUsageInfo($this_user);

#
# Make sure rerun instance or paramset exists.
#
if (isset($rerun_instance)) {
    $record = Instance::Lookup($rerun_instance);
    if (!$record) {
        $record = InstanceHistory::Lookup($rerun_instance);
        if (!$record) {
            SPITUSERERROR("No such rerun instance");
            exit();
        }
    }
    if (! ($record->CanView($this_user) || ISADMIN())) {
        SPITUSERERROR("Not allowed to to view the rerun instance");
        exit();
    }
    $rerun_record = $record;
}
elseif ($rerun_paramset) {
    $rerun_record = Paramset::Lookup($rerun_paramset);
    if (!$rerun_record) {
        SPITUSERERROR("No such parameter set");
        exit();
    }
    if (! ($rerun_record->CanUse($this_user) ||
           # Private name of the paramset.
           $rerun_record->hashkey() == $rerun_paramset || ISADMIN())) {
        SPITUSERERROR("Not allowed to to use this parameter set");
        exit();
    }
}

#
# if using the super secret URL, make sure the profile exists, and
# add to the array now since it might not be public or belong to the user.
#
if (isset($profile)) {
    #
    # Guest users must use the uuid, but logged in users may use the
    # internal index. But, we have to support simple the URL too, which
    # is /p/project/profilename, but only for public profiles.
    #
    if (isset($project) && isset($profile)) {
	$obj = Profile::LookupByName($project, $profile, $version);
    }
    elseif (IsValidUUID($profile) || IsValidHash($profile)) {
	$obj = Profile::Lookup($profile);
    }
    else {
	SPITUSERERROR("Illegal profile for guest user: $profile");
	exit();
    }
    if (! $obj || $obj->deleted()) {
	SPITUSERERROR("No such profile: $profile");
	exit();
    }
    if (IsValidHash($profile)) {
        #
        # Secret URL access to a user in another project.
        #
        $profile = $obj;
        
        # If the user can access the profile without using key, do it that way.
        if (!$profile->CanInstantiate($this_user)) {
            $ishashed = 1;
        }
        $blob = 
            array("name"      => $profile->name(),
                  "profileid" => $profile->profileid(),
                  "project"   => $profile->pid(),
                  "pid"       => $profile->pid(), # JS messes with project.
                  "creator"   => $profile->creator(),
                  "usecount"  => $profile->usecount(),
                  "favorite"  => $profile->isFavorite($this_user));
        if ($ishashed) {
            $selected_profile = $profile->hashkey();
        }
        else {
            $selected_profile = $profile->uuid();
        }
	$profilename = $profile->name();
    }
    else {
	#
	# Must be public or pass the permission test for the user.
	#
	if (! ($obj->ispublic() || $obj->CanInstantiate($this_user))) {
	    SPITUSERERROR("No permission to use profile: $profile");
	    exit();
	}
	$profile = $obj;
        $blob =
            array("name"      => $profile->name(),
                  "profileid" => $profile->profileid(),
                  "project"   => $profile->pid(),
                  "pid"       => $profile->pid(), # JS messes with project.
                  "creator"   => $profile->creator(),
                  "usecount"  => $profile->usecount(),
                  "favorite"  => $profile->isFavorite($this_user));
        $selected_profile = $profile->uuid();
	$profilename = $profile->name();
    }
    $profile_array[$selected_profile] = $blob;
    
    if ($profile->isDisabled()) {
        SPITUSERERROR("This profile is disabled!");
        exit();
    }
}
else {
    #
    # Find all the public and user profiles. We use the UUID instead of
    # indicies cause we do not want to leak internal DB state to guest
    # users. Need to decide on what clause to use, depending on whether
    # a guest user or not.
    #
    $joinclause   = "";
    $whereclause  = "";
    if (!isset($this_user)) {
	$whereclause = "p.public=1";
    }
    else {
	$this_idx = $this_user->uid_idx();
	$joinclause =
	    "left join group_membership as g on ".
	    "     g.uid_idx='$this_idx' and ".
	    "     g.pid_idx=v.pid_idx and g.pid_idx=g.gid_idx ".
            "left join apt_profile_favorites as f on ".
            "     f.profileid=p.profileid and f.uid_idx='$this_idx'";
                    
	$whereclause =
	    "p.public=1 or p.shared=1 or v.creator_idx='$this_idx' or ".
	    "g.uid_idx is not null ";
    }

    $query_result =
	DBQueryFatal("select p.uuid,p.name,p.pid,v.creator,p.profileid, ".
                     "     p.usecount,f.marked ".
                     "   from apt_profiles as p ".
		     "left join apt_profile_versions as v on ".
		     "     v.profileid=p.profileid and ".
		     "     v.version=p.version ".
		     "$joinclause ".
		     "where locked is null and p.disabled=0 and ".
                     "      v.disabled=0 and ($whereclause) ");
    while ($row = mysql_fetch_array($query_result)) {
	$profile_array[$row["uuid"]] =
            array("name"      => $row["name"],
                  "profileid" => $row["profileid"],
                  "project"   => $row["pid"],
                  "pid"       => $row["pid"],
                  "creator"   => $row["creator"],
                  "usecount"  => $row["usecount"],
                  "favorite"  => $row["marked"] ? 1 : 0);
        if ($row["pid"] == $profile_default_pid &&
            $row["name"] == $profile_default) {
	    $selected_profile = $row["uuid"];
	}
    }
    #
    # A default profile, but we still want to give the user the selection
    # list above, but the profile might not be in the list if it is not
    # the highest numbered version.
    #
    if (isset($default)) {
        if (IsValidUUID($default)) {
            $obj = Profile::Lookup($default);
            if (!$obj) {
                SPITUSERERROR("Unknown default profile: $default");
                exit();
            }
            if (! ($obj->ispublic() || $obj->CanInstantiate($this_user))) {
                SPITUSERERROR("No permission to use profile: $default");
                exit();
            }
            if ($obj->isDisabled()) {
                SPITUSERERROR("This profile is disabled!");
                exit();
            }
            #
            # See if we have the version or profile uuid in the list
            # already, do not add twice since we do not show versions
            # in the picker list.
            #
            if (array_key_exists($obj->profile_uuid(), $profile_array)) {
                unset($profile_array[$obj->profile_uuid()]);
            }
            $profile_array[$obj->uuid()] = $obj->name();
                    array("name"      => $obj->name(),
                          "profileid" => $obj->profileid(),
                          "project"   => $obj->pid(),
                          "pid"       => $obj->pid(),
                          "creator"   => $obj->creator(),
                          "usecount"  => $obj->usecount(),
                          "favorite"  => $obj->isFavorite($this_user));
            $selected_profile = $obj->uuid();
        }
        else {
            SPITUSERERROR("Illegal default profile: $default");
            exit();
        }
    }
}

#
# Update the array with extra info for the profile picker.
#
foreach ($profile_array as $uuid => &$details) {
    $profileid = $details["profileid"];
    $usecount  = $details["usecount"];
    $lastused  = 0;
    
    # If profile never used, no need to check if user has used it.
    if ($usecount) {
        if (array_key_exists($profileid, $usageinfo)) {
            $usecount = $usageinfo[$profileid]["count"];
            $lastused = $usageinfo[$profileid]["lastused"];
        }
    }
    $details["usecount"] = $usecount;
    $details["lastused"] = $lastused;
}
reset($profile_array);

$showabout  = 0;        # Deprecated guest user stuff
$registered = true;     # Deprecated guest user stuff
# We use webonly to mark users that have no project membership
# at the Geni portal.
$webonly    = $this_user->webonly() ? "true" : "false";
$cancopy    = $this_user->webonly() || $ishashed ? 0 : 1;
$nopprspec  = "false";  # Deprecated guest user stuff
$portal     = "";
$showpicker = isset($profile) || isset($rerun_record) ? 0 : 1;
if (isset($profilename)) {
    $profilename = "'$profilename'";
    $profilevers = $profile->version();
}
else {
    $profilename = "null";
    $profilevers = "null";
}

$formfields = array();
$formfields["username"] = "";
$formfields["email"]    = "";
$formfields["sshkey"]   = "";
$formfields["where"]    = $DEFAULT_AGGREGATE;
$formfields["profile"]  = $selected_profile;

#
# If the user provided the key, pass it along for ajax calls
# to verify its permission to access the profile. 
#
if ($ishashed) {
    $formfields["hashkey"] = $profile->hashkey();
}

#
# If the user is in the same project as the profile, default to that
# project, else use the first in the list (which is ordered by last
# time the user instantiated in it).
#
if (isset($profile) && array_key_exists($profile->pid(), $projlist)) {
    $project = $profile->pid();
}
else {
    list($project, $grouplist) = each($projlist);
    reset($projlist);
}
$formfields["pid"] = $project;
$formfields["gid"] = $project;
$formfields["username"] = $this_user->uid();
$formfields["email"]    = $this_user->email();

SPITHEADER(1);

echo "<link rel='stylesheet' href='css/jquery-ui.min.css'>\n";
echo "<link rel='stylesheet' href='css/picker.css'>\n";
echo "<link rel='stylesheet' href='css/nv.d3.css'>\n";

# I think this will take care of XSS prevention?
echo "<script type='text/plain' id='form-json'>\n";
echo htmlentities(json_encode($formfields)) . "\n";
echo "</script>\n";
echo "<script type='text/plain' id='error-json'>\n";
echo htmlentities(json_encode($errors));
echo "</script>\n";
echo "<script type='text/plain' id='profiles-json'>\n";
echo htmlentities(json_encode($profile_array));
echo "</script>\n";
    
# Gack.
if ($this_user->IsNonLocal()) {
    if (preg_match("/^[^+]*\+([^+]+)\+([^+]+)\+(.+)$/",
                   $this_user->nonlocal_id(), $matches) &&
        $matches[1] == "ch.geni.net") {
        $portal = "https://portal.geni.net/";
    }
}

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

#
# Spit out a project selection list if a real user.
#
if (!$this_user->webonly()) {
    echo "<script type='text/plain' id='projects-json'>\n";
    echo htmlentities(json_encode($projlist));
    echo "</script>\n";
}
SpitAggregateStatus(true, $this_user);

if ($ISPOWDER) {
    # Powder Radio info.
    $radioinfo = Aggregate::RadioInfoNew();
    echo "<script type='text/plain' id='radioinfo-json'>\n";
    echo htmlentities(json_encode($radioinfo));
    echo "</script>\n";
}

$prunelist = Instance::NodeTypePruneList(null, true);
echo "<script type='text/plain' id='prunelist-json'>\n";
echo htmlentities(json_encode($prunelist));
echo "</script>\n";

SpitOopsModal("oops");
echo "<script type='text/javascript'>\n";
echo "    window.PROFILE    = '" . $formfields["profile"] . "';\n";
echo "    window.PROFILENAME= $profilename;\n";
echo "    window.PROFILEVERS= $profilevers;\n";
if ($ishashed) {
    # For gitrepo-picker template
    echo "    window.HASHKEY= '" . $formfields["hashkey"] . "';\n";
}
echo "    window.AJAXURL    = 'server-ajax.php';\n";
echo "    window.SHOWABOUT  = $showabout;\n";
echo "    window.NOPPRSPEC  = $nopprspec;\n";
echo "    window.REGISTERED = $registered;\n";
echo "    window.WEBONLY    = $webonly;\n";
echo "    window.PORTAL     = '$portal';\n";
echo "    window.SHOWPICKER = $showpicker;\n";
echo "    window.MAXDURATION = $maxduration;\n";
echo "    window.CANCOPY = $cancopy;\n";
$isadmin = (isset($this_user) && ISADMIN() ? 1 : 0);
echo "    window.ISADMIN    = $isadmin;\n";
$isstud = (isset($this_user) && STUDLY() ? 1 : 0);
echo "    window.ISSTUD    = $isstud;\n";
$multisite = (isset($this_user) && ($ISCLOUD || $ISPOWDER) ? 1 : 0);
echo "    window.MULTISITE  = $multisite;\n";
$doconstraints = $TBMAINSITE;
echo "    window.DOCONSTRAINTS = $doconstraints;\n";
echo "    window.SKIPFIRSTSTEP = " . ($skipfirststep ? "true" : "false") .";\n";
echo "    window.PORTAL_NAME = '$PORTAL_NAME';\n";
echo "    window.USERNAME = '" . $formfields["username"] . "';\n";
if (isset($profile) && $profile->repourl()) {
    echo "    window.FROMREPO = true;\n";
    if (isset($refspec)) {
        echo "    window.TARGET_REFSPEC = '$refspec';\n";
        echo "    window.TARGET_REFHASH = null;\n";
    }
    $phash    = $profile->repohash();
    $prefspec = $profile->reporef();
    echo "    window.PROFILE_REFHASH = '$phash';\n";
    echo "    window.PROFILE_REFSPEC = '$prefspec';\n";
}
else {
    echo "    window.FROMREPO = false;\n";
}
# Do we show an aggregate selector?
if (!$this_user->webonly() && !$ISAPT && !$ISPNET && !$ISEMULAB) {
    echo "    window.CLUSTERSELECT = true;\n";
}
else {
    echo "    window.CLUSTERSELECT = false;\n";
}
if (isset($rerun_instance) || isset($rerun_paramset)) {
    if (isset($rerun_paramset)) {
        # This might be the private hashkey, send it along. 
        echo "    window.RERUN_PARAMSET = '$rerun_paramset';\n";
        if ($profile->repourl()) {
            $phash    = $rerun_record->repohash();
            $prefspec = $rerun_record->reporef();
            
            if ($rerun_record->IsBound()) {
                echo "    window.TARGET_REFHASH = '$phash';\n";
            }
            else {
                echo "    window.TARGET_REFHASH = null;\n";
            }
            echo "    window.TARGET_REFSPEC = '$prefspec';\n";
        }
    }
    else {
        echo "    window.RERUN_INSTANCE = '$rerun_instance';\n";
        if ($profile->repourl()) {
            $hash    = $rerun_record->repohash();
            
            echo "    window.TARGET_REFHASH = '$hash';\n";
            echo "    window.TARGET_REFSPEC = null;\n";
        }
    }
}
echo "    window.USENEWSCHEDULE = $usenewschedule;\n";
echo "    window.EMBEDDED_RESGROUPS = true;\n";
echo "    window.EMBEDDED_RESGROUPS_SELECT = true;\n";
echo "</script>\n";
echo "<script src='js/lib/d3.v3.js'></script>\n";
echo "<script src='js/lib/nv.d3.js'></script>\n";
echo "<script src='js/lib/jquery-ui.js'></script>\n";
   
REQUIRE_WIZARD_TEMPLATE();
REQUIRE_PICKER();
REQUIRE_FORMHELPERS();
REQUIRE_FILESTYLE();
REQUIRE_MARKED();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
REQUIRE_JQUERY_STEPS();
# This includes SUP (JACKS (JACKSMOD)), UNDERSCORE, and JACKS_EDITOR
REQUIRE_PPWIZARDSTART();
# For the new ppwizardstart and Powder
AddLibrary("js/powder-types.js");
AddLibrary("js/resgraphs.js");
AddLibrary("js/gitrepo.js");
AddLibrary("js/paramsets.js");
AddLibrary("js/list-resgroups.js");
AddLibrary("js/copy-profile.js");
SPITREQUIRE("js/instantiate-new.js");

echo "<div style='display: none'><div id='jacks-dummy'></div></div>\n";

AddTemplateList(array("instantiate-new",
                      "aboutapt", "aboutcloudlab", "aboutpnet",
                      "waitwait-modal", "rspectextview-modal",
                      "picker-template","reservation-graph",
                      "save-paramset-modal", "resgroup-list",
                      "copy-profile-modal"));
SPITFOOTER();
?>
