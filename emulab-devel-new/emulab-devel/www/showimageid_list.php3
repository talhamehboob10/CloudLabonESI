<?php
#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
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
# Admin users can see all ImageIDs, while normal users can only see
# ones in their projects or ones that are globally available.
#
$optargs = OptionalPageArguments("searchfor", PAGEARG_STRING,
				 "searchby",  PAGEARG_STRING,
                                 "classic",   PAGEARG_BOOLEAN);

if (!$CLASSICWEB_OVERRIDE && !$classic) {
    header("Location: apt/images.php");
    return;
}
$extraclause = "";
$extrajoin   = "";

#
# Standard Testbed Header
#
PAGEHEADER("Image Search");

if (isset($searchfor) && isset($searchby)) {
    if (! preg_match('/^[\w\:,\.\+]+$/', $searchfor)) {    
	USERERROR("Illegal characters in search clause", 1);
    }
    if ($searchby == "nodetype") {
	$tokens = array();
	
	foreach (preg_split("/,/", $searchfor) as $type) {
	    $tokens[] = "oi.type='$type'";
	}
	$extraclause = join(" or ", $tokens);
	$extraclause = "and ($extraclause)";
        $extrajoin   = "left join osidtoimageid as oi on ".
                     "oi.osid=i.imageid and oi.imageid=i.imageid ";
    }
    elseif ($searchby == "features") {
	$tokens = array();
	
	foreach (preg_split("/,/", $searchfor) as $feature) {
	    $tokens[] = "find_in_set('$feature',ov.osfeatures)";
	}
	$extraclause = join(" or ", $tokens);
	$extraclause = "and ($extraclause)";
    }
    elseif ($searchby == "namedesc") {
	$safe_searchfor = addslashes($searchfor);
	$extraclause = "and (match (iv.imagename,iv.description) ".
	    "against('*${safe_searchfor}*'))";
    }
}
else {
    # For test in forms below.
    $searchby = "";
}

$query =
    "select distinct iv.*,i.imagename from images as i ".
    "left join image_versions as iv on ".
    "          iv.imageid=i.imageid and iv.version=i.version ".
    "left join os_info_versions as ov on ".
    "          i.imageid=ov.osid and ov.vers=i.version ".
    $extrajoin;

#
# Tack on the permission clause for mere users. 
#
if (!$isadmin) {
    #
    # User is allowed to view the list of all global images, and all images
    # in his project. Include images in the subgroups too, since its okay
    # for the all project members to see the descriptors. They need proper 
    # permission to use/modify the image/descriptor of course, but that is
    # checked in the pages that do that stuff. In other words, ignore the
    # shared flag in the descriptors.
    #
    $uid_idx = $this_user->uid_idx();
    
    $query .=
	"left join image_permissions as p1 on ".
	"     p1.imageid=i.imageid and p1.permission_type='group' ".
	"left join image_permissions as p2 on ".
	"     p2.imageid=i.imageid and p2.permission_type='user' and ".
	"     p2.permission_idx='$uid_idx' ".
	"left join group_membership as g on ".
	"     g.uid_idx='$uid_idx' and  ".
	"     (g.pid_idx=i.pid_idx or ".
	"      g.gid_idx=p1.permission_idx) ".
	"where (iv.global or p2.imageid is not null or g.uid_idx is not null) ";
}
else {
    $query .= "where 1 ";
}

$query .=
    "and (iv.ezid = 1 or iv.isdataset = 1) $extraclause ".
    "order by i.imagename";

$query_result = DBQueryFatal($query);

SUBPAGESTART();
SUBMENUSTART("More Options");
WRITESUBMENUBUTTON("Import an Amazon EC2 Instance Image",
		   "newimageid_ez.php3?ec2=1");
WRITESUBMENUBUTTON("More info on Images",
		   "$WIKIDOCURL/Tutorial#CustomOS");
if ($isadmin) {
    WRITESUBMENUBUTTON("Create an Image Descriptor",
		       "newimageid_ez.php3");
    WRITESUBMENUBUTTON("Create an OS Descriptor",
		       "newosid.php3");
    WRITESUBMENUBUTTON("OS Descriptor list",
		       "showosid_list.php3");
}
SUBMENUEND();
echo "<table class=stealth>\n";
echo "<tr><form action=showimageid_list.php3 method=get>
      <td class=stealth><b>Find images that run on:&nbsp</b> 
      <input type=text style=\"float:right\"
             name=searchfor
             size=40
             value=\"" . ($searchby == "nodetype" ? $searchfor : "") . "\"</td>
      <input type=hidden name=searchby value='nodetype'>
      <td class=stealth>
        <b><input type=submit name=search1 value=Search></b></td>
      <td class=stealth>
         Comma separated list of types</td>\n";
echo "</form></tr>\n";
echo "<tr><form action=showimageid_list.php3 method=get>
      <td class=stealth><b>Find images with with features:&nbsp</b> 
      <input type=text 
             name=searchfor
             size=40
             value=\"" . ($searchby == "features" ? $searchfor : "") . "\"</td>
      <input type=hidden name=searchby value='features'>
      <td class=stealth>
        <b><input type=submit name=search2 value=Search></b></td>
      <td class=stealth>
         Comma separated list of features</td>\n";
echo "</form></tr>\n";
echo "<tr><form action=showimageid_list.php3 method=get>
      <td class=stealth><b>Search name and description:&nbsp</b> 
      <input type=text style=\"float:right\"
             name=searchfor
             size=40
             value=\"" . ($searchby == "namedesc" ? $searchfor : "") . "\"</td>
      <input type=hidden name=searchby value='namedesc'>
      <td class=stealth>
        <b><input type=submit name=search3 value=Search></b></td>
      <td class=stealth>
         Plain text, case insensitive search</td>\n";
echo "</form></tr>\n";
echo "</table>\n";
SUBPAGEEND();

if (mysql_num_rows($query_result)) {
    $numrows = mysql_num_rows($query_result);
    
    echo "<center>There are $numrows matching images.</center>\n";
    echo "<table border=2 cellpadding=0 cellspacing=2 id='showimagelist'
           align='center'>\n";

    echo "<thead class='sort'>
           <tr>
              <th class='sorttable_alpha'>Image</th>
              <th class='sorttable_alpha'>PID</th>
              <th class='sorttable_alpha'>Description</th>
           </tr>
          </thead>\n";

    while ($row = mysql_fetch_array($query_result)) {
	$imageid    = $row["imageid"];
	$descrip    = $row["description"];
	$imagename  = $row["imagename"];
	$pid        = $row["pid"];
	$url        = CreateURL("showimageid", URLARG_IMAGEID, $imageid);

	echo "<tr>
                  <td><A href='$url'>$imagename</A></td>
                  <td>$pid</td>
                  <td>$descrip</td>\n";
        echo "</tr>\n";
    }
    echo "</table>\n";
}
echo "<script type='text/javascript' language='javascript'>
	sorttable.makeSortable(getObjbyName('showimagelist'));
      </script>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
