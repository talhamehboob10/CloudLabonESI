<?php
#
# Copyright (c) 2000-2017 University of Utah and the Flux Group.
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
#
# Only known and logged in users allowed.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Admin users can see all OSIDs, while normal users can only see
# ones in their projects or ones that are globally available.
#
$optargs = OptionalPageArguments("creator",  PAGEARG_USER);

#
# Standard Testbed Header
#
PAGEHEADER("OS Descriptor List");

#
# Allow for creator restriction
#
$extraclause = "";
if (isset($creator)) {
    $creator_idx = $creator->uid_idx();

    $extraclause = "and v.creator_idx='$creator_idx' ";
}

#
# Get the project list.
#
if ($isadmin) {
    $query_result =
	DBQueryFatal("SELECT distinct v.*,o.osname FROM os_info as o ".
		     "left join os_info_versions as v on ".
		     "     v.osid=o.osid and v.vers=o.version ".
		     "where 1 $extraclause ".
		     "order by o.osname");
}
else {
    $uid_idx = $this_user->uid_idx();

    $query_result =
	DBQueryFatal("select distinct v.*,o.osname from os_info as o ".
		     "left join os_info_versions as v on ".
		     "     v.osid=o.osid and v.vers=o.version ".
		     "left join image_permissions as p1 on ".
		     "     p1.imageid=o.osid and p1.permission_type='group' ".
		     "left join image_permissions as p2 on ".
		     "     p2.imageid=o.osid and p2.permission_type='user' ".
		     "left join group_membership as g on ".
		     "     g.pid_idx=o.pid_idx or ".
		     "     g.gid_idx=p1.permission_idx ".
		     "where (g.uid_idx='$uid_idx' or v.shared=1 or".
		     "       p2.permission_idx='$uid_idx') ".
		     "$extraclause ".
		     "order by o.osname");
}

SUBPAGESTART();
SUBMENUSTART("More Options");
if ($isadmin) {
    WRITESUBMENUBUTTON("Create an Image Descriptor",
		       "newimageid_ez.php3");
    WRITESUBMENUBUTTON("Create an OS Descriptor",
		       "newosid.php3");
}
WRITESUBMENUBUTTON("Image Descriptor list",
		   "showimageid_list.php3");
SUBMENUEND();

echo "Listed below are the OS Descriptors that you may use in your NS file
      with the <a href='$WIKIDOCURL/nscommands#OS'>
      <tt>tb-set-node-os</tt></a> directive. If the OS you have selected for
      a node is not loaded on that node when the experiment is swapped in,
      the Testbed system will automatically reload that node's disk with the
      appropriate image. You might notice that it takes a few minutes longer
      to start your experiment when selecting an OS that is not
      already resident. Please be patient.
      <br>
      More information on how to create your own Images is in the
      <a href='$WIKIDOCURL/Tutorial#CustomOS'>Custom OS</a> section of
      the <a href='$WIKIDOCURL/Tutorial'>Emulab Tutorial.</a>
      <br>\n";

SUBPAGEEND();

if (mysql_num_rows($query_result)) {
    echo "<br>
          <table border=2 cellpadding=0 cellspacing=2
                 align='center' id='showosidlist'>\n";
    
    echo "<thead class='sort'>
           <tr>
              <th>Name</th>
              <th>PID</th>
              <th>Description</th>
           </tr>
          </thead>\n";
    
    while ($row = mysql_fetch_array($query_result)) {
        $osname  = $row["osname"];
        $osid    = $row["osid"];
        $descrip = $row["description"];
        $pid     = $row["pid"];
	$url     = CreateURL("showosinfo", URLARG_OSID, $osid);
    
        echo "<tr>
                  <td><A href='$url'>$osname</A></td>
                  <td>$pid</td>
                  <td>$descrip</td>\n";
        echo "</tr>\n";
    }
    echo "</table>\n";
}
echo "<script type='text/javascript' language='javascript'>
	sorttable.makeSortable(getObjbyName('showosidlist'));
      </script>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
