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
include_once("profile_defs.php");
include_once("instance_defs.php");
$page_title = "Experiment Status";
$ajax_request = 0;

#
# Get current user.
#
$this_user = CheckLogin($check_status);
if (isset($this_user)) {
    CheckLoginOrDie(CHECKLOGIN_NONLOCAL);
}
else {
    RedirectLoginPage();
}
#
# We do not set the isfadmin flag if the user has normal permission
# to see this experiment, since that would change what the user sees.
# Okay for real admins, but not for foreign admins.
#
$isfadmin = 0;

#
# Verify page arguments.
#
$reqargs = OptionalPageArguments("uuid",      PAGEARG_UUID,
                                 "slice_uuid",PAGEARG_UUID,
                                 "maxextend", PAGEARG_INTEGER,
				 "oneonly",   PAGEARG_BOOLEAN);

if (! (isset($uuid) || isset($slice_uuid))) {
    SPITHEADER(1);
    echo "<div class='align-center'>
            <p class='lead text-center'>
              What experiment would you like to look at?
            </p>
          </div>\n";
    SPITNULLREQUIRE();
    SPITFOOTER();
    return;
}

#
# See if the instance exists. If not, redirect back to the create page
#
if (isset($uuid)) {
    $instance = Instance::Lookup($uuid);
}
else {
    $instance = Instance::LookupBySlice($slice_uuid);
}
if (!$instance) {
    $instance = InstanceHistory::Lookup($uuid);
    
    SPITHEADER(1);
    echo "<div class='align-center' style='margin-top: 15px;'>
            <p class='lead text-center'>
              Experiment does not exist.
              Redirecting to the front page in a few seconds ...
            </p>
          </div>\n";
    if ($instance && (ISADMIN() || $instance->CanView($this_user))) {
        $url = "memlane.php?uuid=$uuid";
        echo "<div class='align-center' style='margin-top: 15px;'>
               <p class='text-center'>
                 You can also visit the
                 <a href='$url'>history page</a> for this experiment.
               </p>
             </div>\n";
    }
    echo "<script type='text/javascript'>\n";
    echo "  window.APT_OPTIONS.PAGEREPLACE = 'landing.php';\n";
    echo "</script>\n";
    SPITNULLREQUIRE();
    SPITFOOTER();
    return;
}

#
# When coming her via the slice_uuid, we want to flip over to the
# correct portal. Hacky.
#
if ($TBMAINSITE && isset($slice_uuid) &&
    $instance->servername() != $_SERVER['SERVER_NAME']) {
    if ($instance->servername() == "www.aptlab.net") {
        $url = "https://www.aptlab.net";
    }
    elseif ($instance->servername() == "www.cloudlab.us") {
        $url = "https://www.cloudlab.us";
    }
    elseif ($instance->servername() == "www.phantomnet.org") {
        $url = "https://www.phantomnet.org";
    }
    elseif ($instance->servername() == "www.powderwireless.net") {
        $url = "https://www.powderwireless.net";
    }
    if (isset($url)) {
        $url = $url . str_replace("/portal/", "/", $_SERVER['REQUEST_URI']);
	header("Location: $url");
        return;
    }
}

$uuid = $instance->uuid();
$creator = GeniUser::Lookup("sa", $instance->creator_uuid());
if (! $creator) {
    $creator = User::LookupByUUID($instance->creator_uuid());
}
if (!$creator) {
    SPITHEADER(1);
    echo "<div class='align-center'>
            <p class='lead text-center'>
               Hmm, there seems to be a problem.
            </p>
          </div>\n";
    SPITNULLREQUIRE();
    SPITFOOTER();
    TBERROR("No creator for instance: $uuid", 0);
    return;
}
#
# Only logged in admins can access an experiment created by someone else.
#
if (! (isset($this_user) && ISADMIN())) {
    # An experiment created by a real user, can be accessed by that user only.
    # Ditto a guest user; must be the same guest.
    if (! ((get_class($creator) == "User" && isset($this_user) &&
            $instance->CanView($this_user)) ||
	   (get_class($creator) == "GeniUser" &&
	    isset($_COOKIE['quickvm_user']) &&
	    $_COOKIE['quickvm_user'] == $creator->uuid()))) {
        if (ISFOREIGN_ADMIN()) {
            # See comment above.
            $isfadmin = 1;
        }
        else {
            PAGEERROR("You do not have permission to look at this experiment!");
        }
    }
}
$slice = GeniSlice::Lookup("sa", $instance->slice_uuid());

$instance_status = $instance->status();
$creator_uid     = $creator->uid();
$cansnapshot     = ((isset($this_user) &&
                     $this_user->idx() == $creator->idx()) ||
                    ISADMIN() ? 1 : 0);
$canterminate    = ((isset($this_user) &&
                     $instance->CanTerminate($this_user)) ||
                    ISADMIN() ? 1 : 0);
$cancopy_profile   = 0;
$canclone_profile  = 0;
$canupdate_profile = 0;
$isscript          = 0;

if ($profile = Profile::Lookup($instance->profile_id(),
			       $instance->profile_version())) {
    #
    # Not allowed to copy/clone/update a repo based profile. 
    #
    if (!$profile->repourl())  {
        $cancopy_profile   = ((isset($this_user) &&
                               $profile->CanInstantiate($this_user)) ||
                              ISADMIN() ? 1 : 0);
        $canclone_profile  = ((isset($this_user) &&
                               $profile->CanClone($this_user)) ||
                              ISADMIN() ? 1 : 0);
        $canupdate_profile = ((isset($this_user) &&
                               $this_user->idx() == $profile->creator_idx()) ||
                              ISADMIN() ? 1 : 0);
    }
    $isscript = ($profile->script() && $profile->script() != "" ? 1 : 0);
}
$registered      = (isset($this_user) ? "true" : "false");
$snapping        = 0;
$oneonly         = (isset($oneonly) && $oneonly ? 1 : 0);
$isadmin         = (ISADMIN() ? 1 : 0);
$isstud          = (isset($this_user) && $this_user->stud() ? 1 : 0);
$wholedisk       = FeatureEnabled("WholeDiskImage",$creator,$instance->Group());

#
# Temp hack, maybe generalize. These people should not be creaing
# new images.
#
#if ($instance->pid() == "cord-testdrive" && !ISADMIN()) {
#    $cansnap = 0;
#}
#$cansnap = 0;

#
# We give ssh to the creator (real user or guest user).
#
$dossh =
    (((isset($this_user) && $instance->CanDoSSH($this_user)) ||
      (isset($_COOKIE['quickvm_user']) &&
       $_COOKIE['quickvm_user'] == $creator->uuid())) ? 1 : 0);

#
# See if we have a task running in the background for this instance.
# At the moment it can only be a snapshot task. If there is one, we
# have to tell the js code to show the status of the snapshot.
#
# XXX we could be imaging for a new profile (Cloning) instead. In that
# case the webtask object will not be attached to the instance, but to
# whatever profile is cloning. We do not know that profile here, so we
# cannot show that progress. Needs more thought.
#
if ($instance_status == "imaging") {
    $webtask = $instance->WebTask();
    if ($webtask && ! $webtask->exited()) {
	$snapping = 1;
    }
}

SPITHEADER(1);

echo "<link rel='stylesheet'
            href='css/nv.d3.css'>\n";

echo "<link rel='stylesheet'
            href='css/frequency-graph.css'>\n";

# Place to hang the toplevel template.
echo "<div id='status-body'></div>\n";

echo "<script type='text/javascript'>\n";
echo "  window.APT_OPTIONS.uuid = '" . $uuid . "';\n";
if (isset($this_user)) {
    echo "  window.APT_OPTIONS.thisUid = '" . $this_user->uid() . "';\n";
}
else {
    echo "  window.APT_OPTIONS.thisUid = '" . $creator_uid . "';\n";
}
echo "  window.APT_OPTIONS.registered = $registered;\n";
echo "  window.APT_OPTIONS.isadmin = $isadmin;\n";
echo "  window.APT_OPTIONS.isfadmin = $isfadmin;\n";
echo "  window.APT_OPTIONS.isstud = $isstud;\n";
echo "  window.APT_OPTIONS.cansnapshot = $cansnapshot;\n";
echo "  window.APT_OPTIONS.canclone_profile = $canclone_profile;\n";
echo "  window.APT_OPTIONS.canupdate_profile = $canupdate_profile;\n";
echo "  window.APT_OPTIONS.cancopy_profile = $cancopy_profile;\n";
echo "  window.APT_OPTIONS.canterminate = $canterminate;\n";
echo "  window.APT_OPTIONS.wholedisk = $wholedisk;\n";
echo "  window.APT_OPTIONS.snapping = $snapping;\n";
echo "  window.APT_OPTIONS.hidelinktest = false;\n";
echo "  window.APT_OPTIONS.oneonly = $oneonly;\n";
echo "  window.APT_OPTIONS.dossh = $dossh;\n";
echo "  window.APT_OPTIONS.isscript = $isscript;\n";
echo "  window.APT_OPTIONS.AJAXURL = 'server-ajax.php';\n";
if (isset($maxextend) && $maxextend != "") {
    # Assumed to be hours.
    echo "  window.APT_OPTIONS.MAXEXTEND = $maxextend;\n";
}
else {
    echo "  window.APT_OPTIONS.MAXEXTEND = null;\n";
}
# Temporary feature for webssh
$webssh = $this_user->DoWebSSH();
echo "  window.APT_OPTIONS.webssh = $webssh;\n";    

echo "</script>\n";
echo "<script src='js/lib/d3.v3.js'></script>\n";
echo "<script src='js/lib/d3.v5.js'></script>\n";
echo "<script src='js/lib/nv.d3.js'></script>\n";
echo "<script src='js/lib/jquery-ui.js'></script>\n";
echo "<script src='js/lib/codemirror-min.js'></script>\n";
echo "<script src='js/lib/filesize.min.js'></script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
REQUIRE_JACKS();
REQUIRE_MARKED();
REQUIRE_URITEMPLATE();
REQUIRE_IMAGE();
REQUIRE_EXTEND();
REQUIRE_IDLEGRAPHS();
REQUIRE_OPENSTACKGRAPHS();
REQUIRE_CONTEXTMENU();
REQUIRE_SUP();
AddLibrary("js/bindings.js");
AddLibrary("js/paramsets.js");
if ($ISPOWDER) {
    AddLibrary("js/freqgraphs.js");
    AddLibrary("js/lib/pako/pako.min.js");
}
SPITREQUIRE("js/status.js");

echo "<link rel='stylesheet'
            href='css/jquery-ui-1.10.4.custom.min.css'>\n";
# For progress bubbles in the imaging modal.
echo "<link rel='stylesheet' href='css/progress.css'>\n";
echo "<link rel='stylesheet' href='css/codemirror.css'>\n";

#
# Build up a blob of all aggregates for this portal. We need the entire
# list in case new aggregates are added.
#
$aggregates = Aggregate::DefaultAggregateList($this_user);
#
# Because of cross portal linking on the Mothership, make sure there
# are no missing aggregates.
#
foreach ($instance->slivers() as $sliver) {
    $aggregate_urn = $sliver->aggregate_urn();

    if (!array_key_exists($aggregate_urn, $aggregates)) {
        $aggregate = Aggregate::Lookup($aggregate_urn);
        $aggregates[$aggregate_urn] = $aggregate;
    }
}
$blob = array();

foreach ($aggregates as $aggregate) {
    $aggregate_urn = $aggregate->urn();
    $weburl        = $aggregate->weburl();

    $blob[$aggregate_urn] =
        array("weburl"       => $weburl,
              "name"         => $aggregate->name(),
              "nickname"     => $aggregate->nickname(),
              "abbreviation" => $aggregate->abbreviation(),
              "ismobile"     => $aggregate->ismobile(),
              "isFE"         => $aggregate->isFE());
}
echo "<script type='text/plain' id='amlist-json'>\n";
echo json_encode($blob, JSON_HEX_APOS|JSON_HEX_QUOT|JSON_HEX_TAG|JSON_HEX_AMP);
echo "</script>\n";

#
# For Powder, send the radio info.
#
if ($ISPOWDER) {
    $radioinfo = Aggregate::RadioInfoNew();
    echo "<script type='text/plain' id='radioinfo-json'>\n";
    echo json_encode($radioinfo,
                     JSON_HEX_APOS|JSON_HEX_QUOT|JSON_HEX_TAG|JSON_HEX_AMP);
    echo "</script>\n";
}

# This is for Clone.
if (isset($this_user)) {
    $projlist = $this_user->ProjectAccessList($TB_PROJECT_CREATEEXPT);
    $plist = array();
    while (list($project) = each($projlist)) {
        $plist[] = $project;
    }
    echo "<script type='text/plain' id='projects-json'>\n";
    echo htmlentities(json_encode($plist));
    echo "</script>\n";
}

AddTemplateList(array("status", "waitwait-modal", "oops-modal",
                      "register-modal", "terminate-modal", "oneonly-modal",
                      "approval-modal", "linktest-modal",
                      "destroy-experiment", "save-paramset-modal",
                      "prestage-table", "frequency-graph"));

AddTemplateKey("linktest-md", "template/linktest.md");
SPITFOOTER();
?>
