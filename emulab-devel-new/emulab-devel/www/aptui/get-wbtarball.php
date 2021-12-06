<?php
#
# Copyright (c) 2000-2020 University of Utah and the Flux Group.
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
$page_title = "Get WB Store";

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
$this_idx  = $this_user->uid_idx();
$this_uid  = $this_user->uid();
$isadmin   = (ISADMIN() ? 1 : 0);

#
# Verify page arguments.
#
$optargs = RequiredPageArguments("uuid", PAGEARG_UUID);

#
# No header, since we spit back a redirect if the user has permission.
#
$instance = InstanceHistory::LookupBySlice($uuid);
if (!$instance) {
    $instance = InstanceHistory::Lookup($uuid);
    if (!$instance) {
        SPITUSERERROR("No such instance");
        return;
    }
}
$project = $instance->Project();
if (!$project) {
    SPITUSERERROR("No project for instance");
    return;
}
if (!$isadmin && 
    !$project->AccessCheck($this_user, $TB_USERINFO_READINFO)) {
    SPITUSERERROR("You do not have permission to download the tarball!");
    return;
}
$baseurl    = "https://${USERNODE}/getfilebyurl";
$pid        = $project->pid();
$path       = "/proj/$pid/wbstore/${uuid}.tgz";
$webtask    = WebTask::CreateAnonymous();
$webtask_id = $webtask->task_id();

$retval = SUEXEC("nobody", "nobody",
                 "websignurl -t $webtask_id $baseurl $path",
                 SUEXEC_ACTION_CONTINUE);
$webtask->Refresh();

if ($retval) {
    SPITUSERERROR("Internal error getting tarball");
    $webtask->Delete();
    return;
}
$url = $webtask->TaskValue("url");
$webtask->Delete();
header("Location: $url");

?>
