<?php
#
# Copyright (c) 2000-2016 University of Utah and the Flux Group.
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
chdir("apt");
include_once("profile_defs.php");

function SPITERROR($code, $msg)
{
    header("HTTP/1.0 $code $msg");
    exit();
}

#
# No current user needed, this gets source code for public profiles.
#
$optargs = OptionalPageArguments("profile",   PAGEARG_STRING,
				 "version",   PAGEARG_INTEGER,
				 "project",   PAGEARG_PROJECT);

if (!isset($profile)) {
    SPITERROR(400, "Must provide profile!");
}
if (IsValidUUID($profile)) {
    $profile = Profile::Lookup($profile);
}
elseif (isset($project)) {
    if (!isset($version)) {
        $version = null;
    }
    $profile = Profile::LookupByName($project, $profile, $version);
}
else {
    SPITERROR(401, "Must provide a project and profile name");
}
if (!$profile) {
    SPITERROR(400, "No such profile exists!");
}
if (!$profile->ispublic()) {
    SPITERROR(403, "Not a public profile!");
}
header("Content-Type: text/plain");
if ($profile->script()) {
    echo $profile->script();
}
else {
    echo $profile->rspec();
}

?>
