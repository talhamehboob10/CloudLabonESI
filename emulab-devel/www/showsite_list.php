<?php
#
# Copyright (c) 2000-2013 University of Utah and the Flux Group.
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
include("defs.php3");

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments
#
$optargs = OptionalPageArguments("sortby",   PAGEARG_STRING);

#
# Standard Testbed Header
#
PAGEHEADER("Emulab Site List");


if (! ($isadmin || OPSGUY() || STUDLY())) {
    USERERROR("Cannot view site list.", 1);
}

if (! isset($sortby)) {
    $sortby="created";
}
$sortclause = "";

if ($sortby == "created") {
    $sortclause = "order by created";
}
elseif ($sortby == "urn") {
    $sortclause = "order by urn";
}
elseif ($sortby == "commonname") {
    $sortclause = "order by commonname";
}
elseif ($sortby == "buildinfo") {
    $sortclause = "order by buildinfo";
}
elseif ($sortby == "updated") {
    $sortclause = "order by updated";
}

$sites_result =
    DBQueryFatal("SELECT * from emulab_sites $sortclause");

echo "<table width='100%' border=2 id='sitelist'
             cellpadding=2 cellspacing=2 align=center>\n";

echo "<tr>\n";
echo " <th><a href='showsite_list.php?sortby=urn'>URN</a></th>\n";
echo " <th><a href='showsite_list.php?sortby=created'>Created</a></th>\n";
echo " <th><a href='showsite_list.php?sortby=buildinfo'>Last Build</a></th>\n";
echo " <th>OS Vers</th>\n";
echo "</tr>\n";

echo "<tr>\n";
echo " <th><a href='showsite_list.php?sortby=commonname'>Boss Name</a></th>\n";
echo " <th><a href='showsite_list.php?sortby=updated'>Updated</a></th>\n";
echo " <th>Commit Hash</th>\n";
echo " <th>Perl Vers</th>\n";
echo "</tr>\n";

while ($row = mysql_fetch_array($sites_result)) {
    $urn             = substr($row["urn"], strlen("urn:publicid:IDN+"));
    $commonname      = $row["commonname"];
    $url             = $row["url"];
    $created         = $row["created"];
    $updated         = $row["updated"];
    $buildinfo       = $row["buildinfo"];
    $commithash      = $row["commithash"];
    $dbrev           = $row["dbrev"];
    $install         = $row["install"];
    $os_version      = $row["os_version"];
    $perl_version    = $row["perl_version"];
    
    echo "<tr><td height=10 colspan=4></td></tr>\n";
    
    echo "<tr>\n";
    echo " <td><a href='$url'>$urn</a></td>\n";
    echo " <td>$created</td>\n";
    echo " <td>$buildinfo</td>\n";
    echo " <td>$os_version</td>\n";
    echo "</tr>\n";

    echo "<tr>\n";
    echo " <td>$commonname</td>\n";
    echo " <td>$updated</td>\n";
    echo " <td>$commithash</td>\n";
    echo " <td>$perl_version</td>\n";
    echo "</tr>\n";
}
echo "</table>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
