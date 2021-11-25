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
chdir("apt");
include("quickvm_sup.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Matched Papers";

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
    $isadmin = 0;
}

SPITHEADER(1);

echo "<script type='text/javascript'>\n";
echo "  window.ISADMIN     = $isadmin;\n";
echo "</script>\n";

# Place to hang the toplevel template.
echo "<div id='main-body'></div>\n";
# Place to hang some modals.
echo "<div id='oops_div'></div>
      <div id='waitwait_div'></div>\n";

$unmatched = array();
$papers = array();

$query_result =
    DBQueryFatal("select p.*,u.uid,u.uid_idx,u.usr_name ".
                 "  from scopus_paper_info as p ".
                 "left join scopus_paper_authors as a on ".
                 "     a.abstract_id=p.scopus_id ".
                 "left join user_scopus_info as i on ".
                 "     i.scopus_id=a.author_id ".
                 "left join users as u on u.uid_idx=i.uid_idx ".
                 "where p.cites='$PORTAL_GENESIS' and u.uid is not null ".
                 "order by p.pubdate desc");

while ($row = mysql_fetch_array($query_result)) {
    $abstract_id = $row["scopus_id"];

    if (!array_key_exists("$abstract_id", $papers)) {
        $papers["$abstract_id"] = array(
            "latest_abstract_id"      => $row["scopus_id"],
            "latest_abstract_pubdate" => $row["pubdate"],
            "latest_abstract_pubtype" => $row["pubtype"],
            "latest_abstract_doi"     => $row["doi"],
            "latest_abstract_url"     => $row["url"],
            "latest_abstract_pubname" => $row["pubname"],
            "latest_abstract_title"   => $row["title"],
            "latest_abstract_authors" => $row["authors"],
            "citedby_count"           => $row["citedby_count"],
            "uses"    => $row["uses"],
            "authors" => array(),
        );
    }
    $paper  = $papers["$abstract_id"];
    if ($isadmin) {
        $authors = $paper["authors"];
        $blob = array (
            "uid_idx"  => $row["uid_idx"],
            "uid"      => $row["uid"],
            "name"     => $row["usr_name"],
        );
        $paper["authors"][] = $blob;
    }
    # PHP scoping is dumb.
    $papers["$abstract_id"] = $paper;
}

#
# List of papers not matched to a specific user.
#
$query_result =
    DBQueryFatal("select p.*,GROUP_CONCAT(i.scopus_id) as auids ".
                 "   from scopus_paper_info as p ".
                 "left join scopus_paper_authors as a on ".
                 "     a.abstract_id=p.scopus_id ".
                 "left join user_scopus_info as i on ".
                 "     i.scopus_id=a.author_id ".
                 "where p.cites='$PORTAL_GENESIS' ".
                 "group by p.scopus_id having auids is null");

while ($row = mysql_fetch_array($query_result)) {
    $abstract_id = $row["scopus_id"];

    $blob = array(
        "latest_abstract_id"      => $row["scopus_id"],
        "latest_abstract_pubdate" => $row["pubdate"],
        "latest_abstract_pubtype" => $row["pubtype"],
        "latest_abstract_doi"     => $row["doi"],
        "latest_abstract_url"     => $row["url"],
        "latest_abstract_pubname" => $row["pubname"],
        "latest_abstract_title"   => $row["title"],
        "latest_abstract_authors" => $row["authors"],
        "citedby_count"           => $row["citedby_count"],
        "uses"                    => $row["uses"],
        "authors"                 => null,
    );

    #
    # If we confirmed that a paper used us, we add it to the first table.
    #
    if ($row["uses"] == "yes") {
        if (!array_key_exists("$abstract_id", $papers)) {
            $papers["$abstract_id"] = $blob;
        }
    }
    else {
        if (!array_key_exists("$abstract_id", $unmatched)) {
            $unmatched["$abstract_id"] = $blob;
        }
    }
}

echo "<script type='text/plain' id='papers-json'>\n";
echo json_encode($papers,
                 JSON_HEX_APOS|JSON_HEX_QUOT|JSON_HEX_TAG|JSON_HEX_AMP);
echo "</script>\n";

echo "<script type='text/plain' id='unmatched-json'>\n";
echo json_encode($unmatched,
                 JSON_HEX_APOS|JSON_HEX_QUOT|JSON_HEX_TAG|JSON_HEX_AMP);
echo "</script>\n";

REQUIRE_UNDERSCORE();
REQUIRE_TABLESORTER();
REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER();
SPITREQUIRE("js/matched-papers.js");

AddTemplateList(array("matched-papers",
                      "oops-modal", "waitwait-modal"));
SPITFOOTER();
?>
