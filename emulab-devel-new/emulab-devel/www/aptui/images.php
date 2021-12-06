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
chdir("apt");
include("quickvm_sup.php");
include_once("instance_defs.php");
include_once("aggregate_defs.php");
$page_title = "Image List";

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("target_user", PAGEARG_USER,
                                 "all",         PAGEARG_BOOLEAN);

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();
# Ignore all flag if not an admin
if (!ISADMIN()) {
    $all = 0;
}
elseif (!isset($all)) {
    $all = 0;
}

if (!isset($target_user)) {
    $target_user = $this_user;
}
if (!$this_user->SameUser($target_user)) {
    if (!ISADMIN()) {
	SPITUSERERROR("You do not have permission to view ".
		      "target user's images");
	exit();
    }
    # Do not show admin access images if targeting a different user.
    $all = 0;
}
$target_idx = $target_user->uid_idx();
$projlist   = $target_user->ProjectAccessList($TB_PROJECT_CREATEEXPT);

$tmp = array();
$images = array();
$domain = $OURDOMAIN;
if ($TBMAINSITE) {
    $domain = "emulab.net";
}

SPITHEADER(1);

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";

if ($ISCLOUD) {
    $aggregates = array();
    
    #
    # Look in the IMS database for images from all clusters.
    #
    $dblink = DBConnect("ims");
    
    $query =
           "SELECT i.*, iv.* ".
           "FROM images as i ".
           "JOIN ".
           "( ".
           "  SELECT iv1.* FROM image_versions as iv1 ".
           "  JOIN ".
           "  ( ".
           "   SELECT urn,MAX(version) as maxVersion ".
           "   FROM image_versions ".
           "   GROUP BY urn ".
           "  ) iv2 ".
           "  ON iv1.urn = iv2.urn ".
           "  AND iv1.version = iv2.maxVersion ".
           ") iv ".
           "ON i.urn = iv.urn";
    $query_result = DBQueryFatal($query, $dblink);

    while ($row = mysql_fetch_array($query_result)) {
        $name    = $row["imagename"];
        $pid     = "n/a";
        $pid_idx = 0;
        $blob    = array();

        #
        # Mere users only see listed. non-deprecated images
        #
        if (!ISADMIN()) {
            if ($row["listed"] == 0 || $row["deprecated"]) {
                continue;
            }
        }
        
        # Need to map creator/project to local.
        list ($auth,$type,$id) = Instance::ParseURN($row["creator_urn"]);
        if ($auth == $domain) {
            $user = User::LookupByUid($id);
        }
        else {
            $user = User::LookupNonLocal($row["creator_urn"]);
        }
        if ($user) {
            $creator     = $user->uid();
            $creator_idx = $user->idx();
        }
        else {
            $creator     = $id;
            $creator_idx = 0;
        }
        list ($auth,$type,$id) = Instance::ParseURN($row["project_urn"]);
        # project urn is in domain:project format.
        if (preg_match("/^([^:]+)\:([^:]+)$/", $auth, $matches)) {
            $project = Project::LookupByPid($matches[2]);
            if ($project) {
                $pid     = $project->pid();
                $pid_idx = $project->pid_idx();
            }
            else {
                $pid = $matches[2];
            }
        }
        #
        # Lets try to get a url.
        #
        list ($imagedomain,$type,$id) = Instance::ParseURN($row["urn"]);
        if ($imagedomain == $domain) {
            $url = "$APTBASE/show-image.php?imageid=" . $row["image_uuid"];
        }
        else {
            if (array_key_exists($imagedomain, $aggregates)) {
                $aggregate = $aggregates[$imagedomain];
            }
            else {
                $aggregate = Aggregate::LookupByDomain($imagedomain);
                if ($aggregate) {
                    $aggregates[$imagedomain] = $aggregate;
                }
            }
            if ($aggregate) {
                $url = $aggregate->weburl() .
                  "/showimageid.php3?imageid=" . $row["image_uuid"];
            }
        }
        $blob["description"] = $row["description"];
        $blob["imagename"]   = $row["imagename"];
        $blob["updated"]     = DateStringGMT($row["created"]);
        $blob["pid"]         = $pid;
        $blob["pid_idx"]     = $pid_idx;
        $blob["global"]      = $row["visibility"] == "public" ? 1 : 0;
        $blob["creator"]     = $creator;
        $blob["creator_idx"] = $creator_idx;
        $blob["project_urn"] = $row["project_urn"];
        $blob["urn"]         = $row["urn"];
        #
        # Virtualization implies the format.
        #
        if ($row["virtualizaton"] == "emulab-docker") {
            $blob["format"] = "docker";
        }
        else {
            $blob["format"] = "ndz";
        }
        if (ISADMIN() && isset($url)) {
            $blob["url"] = $url;
        }
        $tmp[] = $blob;
    }
}
else {
    if (ISADMIN() && $all) {
        $joinclause  = "";
        $whereclause = "";
    }
    else {
        #
        # User is allowed to view the list of all global images that have the
        # listed flag set (to pare down what user see), and all images
        # in his project. Include images in the subgroups too, since its okay
        # for the all project members to see the descriptors. They need proper 
        # permission to use/modify the image/descriptor of course, but that is
        # checked in the pages that do that stuff. In other words, ignore the
        # shared flag in the descriptors.
        #
        $uid_idx = $target_user->uid_idx();

        $joinclause =     
                "left join image_permissions as p1 on ".
                "     p1.imageid=i.imageid and p1.permission_type='group' ".
                "left join image_permissions as p2 on ".
                "     p2.imageid=i.imageid and p2.permission_type='user' and ".
                "     p2.permission_idx='$uid_idx' ".
                "left join group_membership as g on ".
                "     g.uid_idx='$uid_idx' and  ".
                "     (g.pid_idx=i.pid_idx or ".
                "      g.gid_idx=p1.permission_idx) ";
    
        $whereclause = "and (iv.global or p2.imageid is not null or ".
                     "g.uid_idx is not null) and i.listed!=0 ";
    }
    $query =
           "select distinct i.imagename,iv.* from images as i ".
           "left join image_versions as iv on ".
           "          iv.imageid=i.imageid and iv.version=i.version ".
           "left join os_info_versions as ov on ".
           "          i.imageid=ov.osid and ov.vers=i.version ".
           "left join osidtoimageid as map on map.osid=i.imageid ".
           $joinclause .
           "where (iv.ezid = 1 or iv.isdataset = 1) $whereclause ".
           (ISADMIN() ? "" : "and deprecated is null ") .
           "order by i.imagename";

    $query_result = DBQueryFatal($query);

    while ($row = mysql_fetch_array($query_result)) {
	$imageid = $row["imageid"];
        $name    = $row["imagename"];
        $pid     = $row["pid"];
        $urn     = "urn:publicid:IDN+${domain}+image+${pid}//${name}";
        $blob    = array();

        $blob["imageid"]     = $imageid;
        $blob["description"] = $row["description"];
        $blob["imagename"]   = $row["imagename"];
        $blob["updated"]     = DateStringGMT($row["updated"]);
        $blob["pid"]         = $row["pid"];
        $blob["pid_idx"]     = $row["pid_idx"];
        $blob["global"]      = $row["global"] ? 1 : 0;
        $blob["listed"]      = $row["listed"] ? 1 : 0;
        $blob["creator"]     = $row["creator"];
        $blob["creator_idx"] = $row["creator_idx"];
        $blob["format"]      = $row["format"];
        $blob["urn"]         = $urn;
	$blob["url"]         = "show-image.php?imageid=$imageid";
        $tmp[] = $blob;
    }
}

#
# This is for the hidden search filter column. It indicates how 
# the user has access to the image. Creator, project, public.
#
foreach ($tmp as $blob) {
    $name    = $blob["imagename"];
    $pid     = $blob["pid"];
    $filters = array();
    
    if ($all && $blob["creator_idx"] == $target_user->uid_idx()) {
        $filters[] = "creator";
    }
    if (array_key_exists($pid, $projlist)) {
            $filters[] = "project";
    }
    if ($all) {
        if ($pid == "emulab-ops") {
            $filters[] = "system";
        }
        if ($blob["global"] != "0") {
            $filters[] = "public";
        }
    }
    else {
        if ($pid == "emulab-ops" && $blob["global"] != "0") {
            $filters[] = "system";
        }
        # If not in any filters and global, skip. 
        if (!count($filters) && $blob["global"] != "0") {
            continue;
        }
    }
    # If none of the filters match, then mark as admin so we can show
    # those under a separate checkbox.
    if (!count($filters)) {
        if ($all) {
            $filters[] = "admin";
        }
        else {
            continue;
        }
    }
    $blob["filter"] = implode(",", $filters);
    $images[] = $blob;
}
echo "<script type='text/javascript'>\n";
$isadmin = (isset($this_user) && ISADMIN() ? 1 : 0);
echo "    window.ISADMIN    = $isadmin;\n";
echo "    window.ALL        = $all;\n";
echo "</script>\n";

echo "<script type='text/plain' id='images-json'>\n";
echo htmlentities(json_encode($images)) . "\n";
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
SPITREQUIRE("js/images.js");

AddTemplate("images");
AddTemplate("image-format-modal");
SPITFOOTER();
?>
