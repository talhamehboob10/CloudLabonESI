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
$page_title = "Show Profile";

$isadmin = 0;
$isguest = 0;
$ishashed= 0;
    
#
# Get current user.
#
RedirectSecure();
$this_user = CheckLogin($check_status);
if (isset($this_user)) {
    CheckLoginOrDie(CHECKLOGIN_NONLOCAL|CHECKLOGIN_WEBONLY);
    $isadmin  = (ISADMIN() ? 1 : 0);
}
else {
    $isguest = 1;
}

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("uuid",   PAGEARG_STRING,
                                 "profile",PAGEARG_STRING,
                                 "project",PAGEARG_PROJECT,
                                 "source", PAGEARG_BOOLEAN,
                                 "rspec",  PAGEARG_BOOLEAN);
if (isset($uuid))  {
    $profile = Profile::Lookup($uuid);
}
elseif (isset($project) && isset($profile)) {
    $profile = Profile::LookupByName($project, $profile);
}
elseif (isset($profile) && (IsValidHash($profile) || IsValidUUID($profile))) {
    $obj = Profile::Lookup($profile);
    if ($obj && IsValidHash($profile)) {
        $ishashed = 1;
    }
    $profile = $obj;
}
else {
    SPITUSERERROR("Must provide a uuid or project/profile name!");
}
if (!$profile) {
    SPITUSERERROR("No such profile!");
}
if ($isguest) {
    if (!$profile->ispublic()) {
        SPITUSERERROR("This profile is not publicly accessible!");
    }
}
elseif (! ($profile->CanView($this_user) || $ishashed || ISFOREIGN_ADMIN())) {
    SPITUSERERROR("Not enough permission!");
}
# If the user has permission without the hash, revert to normal access.
if ($ishashed && $profile->CanView($this_user)) {
    $ishashed = 0;
}

# For the download source button.
if ($source || $rspec) {
    $filename = $profile->name() . ".xml";
    $stuff    = $profile->rspec();

    if ($source && $profile->script() && $profile->script() != "") {
        $stuff = $profile->script();
        $filename = $profile->name() . ".py";
    }
    header("Content-Type: text/plain");
    header("Content-Disposition: attachment; filename='${filename}'");
    echo $stuff;
    return;
}
SPITHEADER(1);
echo "<div id='ppviewmodal_div'></div>\n";

$profile_uuid = $profile->profile_uuid();
$version_uuid = $profile->uuid();
$ispp         = ($profile->isParameterized() ? 1 : 0);

# In case user has permission without the hashkey
if ($isguest || $ishashed) {
    $history      = 0;
    $activity     = 0;
    $canedit      = 0;
    $cancopy      = 0;
    $disabled     = ($profile->isDisabled() ? 1 : 0);
    $paramsets    = 0;
}
else {
    $history      = ($profile->HasHistory() ? 1 : 0);
    $activity     = ($profile->HasActivity($this_user) ? 1 : 0);
    $canedit      = ($profile->CanEdit($this_user) ? 1 : 0);
    $disabled     = ($profile->isDisabled() ? 1 : 0);
    $cancopy      = ($this_user->webonly() || $ishashed ? 0 : 1);
    $paramsets    = ($profile->HasParamsets($this_user) ? 1 : 0);
}

# Place to hang the toplevel template.
echo "<div id='page-body'></div>\n";

# Place to hang the genilib-editor template.
echo "<div id='genilib-editor-body'></div>\n";

# These two modals live outside so that genilib-editor can
# use them as well.
echo "<div id='waitwait_div'></div>
      <div id='oops_div'></div>";

echo "<link rel='stylesheet'
            href='css/jquery-ui-1.10.4.custom.min.css'>\n";
echo "<link rel='stylesheet' href='css/codemirror.css'>\n";
echo "<link rel='stylesheet' href='css/genilib-editor.css'>\n";

# Needed for genilib-editor
echo "<script src='https://cdn.jsdelivr.net/ace/1.2.3/noconflict/ace.js'></script>\n";
echo "<script src='https://cdn.jsdelivr.net/ace/1.2.3/noconflict/keybinding-vim.js'></script>\n";
echo "<script src='https://cdn.jsdelivr.net/ace/1.2.3/noconflict/keybinding-emacs.js'></script>\n";

echo "<script type='text/javascript'>\n";
if ($ishashed) {
    echo "    window.PROFILE      = '" . $profile->hashkey() . "';\n";
}
else {
    echo "    window.PROFILE      = '$profile_uuid';\n";
}
echo "    window.PROFILE_UUID = '$profile_uuid';\n";
echo "    window.VERSION_UUID = '$version_uuid';\n";
echo "    window.AJAXURL      = 'server-ajax.php';\n";
echo "    window.ISGUEST      = $isguest;\n";
echo "    window.ISADMIN      = $isadmin;\n";
echo "    window.CANEDIT      = $canedit;\n";
echo "    window.CANCOPY      = $cancopy;\n";
echo "    window.DISABLED     = $disabled;\n";
echo "    window.HISTORY      = $history;\n";
echo "    window.ACTIVITY     = $activity;\n";
echo "    window.PARAMSETS    = $paramsets;\n";
echo "    window.ISPPPROFILE  = $ispp;\n";
echo "    window.WITHPUBLISHING = $WITHPUBLISHING;\n";
echo "    window.EDITOR_READONLY = true;\n";
echo "</script>\n";

# See what projects the user can make copies in.
if ($cancopy) {
    $projlist = $this_user->ProjectAccessList($TB_PROJECT_CREATEEXPT);

    # Need to convert to list without groups.
    $plist = array();
    while (list($project) = each($projlist)) {
        $plist[] = $project;
    }
    echo "<script type='text/plain' id='projects-json'>\n";
    echo htmlentities(json_encode($plist));
    echo "</script>\n";
}
echo "<script src='js/lib/codemirror-min.js'></script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_JACKS();
REQUIRE_MOMENT();
REQUIRE_APTFORMS();
REQUIRE_MARKED();
REQUIRE_GENILIB_EDITOR();
AddLibrary("js/copy-profile.js");
AddLibrary("js/gitrepo.js");
AddLibrary("js/paramhelp.js");
SPITREQUIRE("js/show-profile.js",
            "<script src='js/lib/jquery-ui.js'></script>\n".
            "<script src='js/lib/jquery.appendGrid-1.3.1.min.js'></script>");

AddTemplateList(array("show-profile", "waitwait-modal", "renderer-modal", "showtopo-modal", "rspectextview-modal", "oops-modal", "share-modal", "gitrepo-picker", "copy-repobased-profile", "copy-profile-modal"));
SPITFOOTER();

?>
