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
include_once("template_defs.php");
include_once("pub_defs.php");

#
# Note the difference with which this page gets it arguments!
# I invoke it using GET arguments, so uid and pid are are defined
# without having to find them in URI (like most of the other pages
# find the uid).
#

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs  = RequiredPageArguments("project", PAGEARG_PROJECT);
$project  = $reqargs["project"];
$group    = $project->Group();
$pid      = $project->pid();

#
# Standard Testbed Header
#
PAGEHEADER("Project $pid");

#
# Verify that this uid is a member of the project being displayed.
#
if (! $project->AccessCheck($this_user, $TB_PROJECT_READINFO)) {
    USERERROR("You are not a member of Project $pid.", 1);
}

SUBPAGESTART();
SUBMENUSTART("Project Options");
WRITESUBMENUBUTTON("Create Subgroup",
		   "newgroup.php3?pid=$pid");
WRITESUBMENUBUTTON("Edit User Privs",
		   "editgroup.php3?pid=$pid&gid=$pid");
WRITESUBMENUBUTTON("Remove Users",
		   "showgroup.php3?pid=$pid&gid=$pid");
WRITESUBMENUBUTTON("Show Project History",
		   "showstats.php3?showby=project&pid=$pid");
WRITESUBMENUBUTTON("Free Node Summary",
		   "nodecontrol_list.php3?showtype=summary&bypid=$pid");
if ($isadmin) {
    WRITESUBMENUDIVIDER();
    WRITESUBMENUBUTTON("Delete this project",
		       "deleteproject.php3?pid=$pid");
    WRITESUBMENUBUTTON("Resend Approval Message",
		       "resendapproval.php?pid=$pid");
}
SUBMENUEND();

# Gather up the html sections.
ob_start();
$project->Show();
$profile_html = ob_get_contents();
ob_end_clean();

ob_start();
$group->ShowMembers();
$members_html = ob_get_contents();
ob_end_clean();

ob_start();
$project->ShowGroupList();
$groups_html = ob_get_contents();
ob_end_clean();

# Project wide Templates.
$templates_html = null;
if ($EXPOSETEMPLATES) {
    $templates_html = SHOWTEMPLATELIST("PROJ", 0, $uid, $pid, "", TRUE);
}

ob_start();
ShowExperimentList("PROJ", $this_user, $project);
$experiments_html = ob_get_contents();
ob_end_clean();

$stats_html = null;
if ($isadmin) {
    ob_start();
    $project->ShowStats();
    $stats_html = ob_get_contents();
    ob_end_clean();
}

#
# Portal support; show exports.
#
$exports_html = null;
if ($PEER_ENABLE && $PEER_ISPRIMARY) {
    $pid_idx = $project->pid_idx();
    
    $query_result =
	DBQueryFatal("select * from group_exports ".
		     "where pid_idx='$pid_idx' and pid_idx=gid_idx");
    if (mysql_num_rows($query_result)) {
	$exports_html =
	    "<center>
               <h3>Peer Exports</h3>
             </center>
             <table align=center border=1 cellpadding=1 cellspacing=2>\n";

        $exports_html .=
	    "<tr>
                <th>Peer</th>
                <th>Exported</th>
  	        <th>Updated</th>
             </tr>\n";

	while ($exportrow = mysql_fetch_array($query_result)) {
	    $peer     = $exportrow["peer"];
	    $updated  = $exportrow["updated"];
	    $exported = $exportrow["exported"];

	    $exports_html .=
		"<tr>
                    <td>$peer</td>
                    <td>$exported</td>
                    <td>$updated</td>
                  </tr>\n";
	}
	$exports_html .= "</table>\n";
    }
}
 
$papers_html = null;
if ($PUBSUPPORT) {
    #
    # List papers for this project if any
    #
    $query_result = GetPubs("`project` = \"$pid\"");
    if (mysql_num_rows($query_result)) {
	$papers_html = MakeBibList($this_user, $isadmin, $query_result);
    }
}

$vis_html = null;
$whocares = null;
if ($EXP_VIS && CHECKURL("http://$USERNODE/proj-vis/$pid/", $whocares)) {
  $vis_html = "<iframe src=\"http://$USERNODE/proj-vis/$pid/\" width=\"100%\" height=600 id=\"vis-iframe\"></iframe>";
}

#
# Show number of PCS
#
$numpcs = $project->PCsInUse();

if ($numpcs) {
    echo "<center><font color=Red size=+2>\n";
    echo "Project $pid is using $numpcs PCs!\n";
    echo "</font></center><br>\n";
}

#
# Function to change what is being shown.
#
echo "<script type='text/javascript' language='javascript'>
        var li_current = 'li_profile';
        var div_current = 'div_profile';
        function Show(which) {
	    li = getObjbyName(li_current);
            if (li) {
                li.style.backgroundColor = '#DDE';
                li.style.borderBottom = '1px solid #778';
                div = getObjbyName(div_current);
                div.style.display = 'none';
            }

            li_current = 'li_' + which;
            div_current = 'div_' + which;
	    li = getObjbyName(li_current);
            if (li) {
                li.style.backgroundColor = 'white';
                li.style.borderBottom = '1px solid white';
                div = getObjbyName(div_current);
                div.style.display = 'block';
            }
            return false;
        }
        function Setup() {
	    var urllocation = location.href; //find url parameter
	    if (urllocation && urllocation.indexOf('#') >= 0) {
                var which = urllocation.substr(urllocation.indexOf('#') + 1);

	        li = getObjbyName('li_' + which);
                if (!li) {
                    which = 'profile';
                }
                Show(which);
            }
            else {
	        li = getObjbyName(li_current);
                if (li) {
                    li.style.backgroundColor = 'white';
                    li.style.borderBottom = '1px solid white';
                    div = getObjbyName(div_current);
                    div.style.display = 'block';
                }
            }
        }
      </script>\n";

#
# This is the topbar
#
echo "<div width=\"100%\" align=center>\n";
echo "<ul id=\"topnavbar\">\n";
if ($templates_html) {
    echo "<li>
           <a href=\"#templates\" ".
	       "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
               "id=\"li_templates\" onclick=\"Show('templates');\">".
               "Templates</a></li>\n";
}
if ($experiments_html) {
     echo "<li>
            <a href=\"#experiments\" ".
	       "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
               "id=\"li_experiments\" onclick=\"Show('experiments');\">".
               "Experiments</a></li>\n";
}
if ($groups_html) {
    echo "<li>
          <a href=\"#groups\" ".
	      "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
	      "id=\"li_groups\" onclick=\"Show('groups');\">".
              "Groups</a></li>\n";
}
if ($members_html) {
    echo "<li>
          <a href=\"#members\" ".
	      "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
	      "id=\"li_members\" onclick=\"Show('members');\">".
              "Members</a></li>\n";
}
echo "<li>
      <a href=\"#profile\" ".
           "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
           "id=\"li_profile\" onclick=\"Show('profile');\">".
           "Profile</a></li>\n";

if ($isadmin && $stats_html) {
    echo "<li>
          <a href=\"#F\" class=topnavbar onfocus=\"this.hideFocus=true;\" ".
	      "id=\"li_stats\" onclick=\"Show('stats');\">".
              "Project Stats</a></li>\n";
}
if ($papers_html) {
    echo "<li>
          <a href=\"#papers\" ".
	      "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
	      "id=\"li_papers\" onclick=\"Show('papers');\">".
              "Publications</a></li>\n";
}
if ($vis_html) {
    echo "<li>
          <a href=\"#vis\" ".
	      "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
	      "id=\"li_vis\" onclick=\"Show('vis');\">".
              "Visualization</a></li>\n";
}
if ($exports_html) {
    echo "<li>
          <a href=\"#exports\" ".
	      "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
	      "id=\"li_exports\" onclick=\"Show('exports');\">".
              "Peers</a></li>\n";
}
echo "</ul>\n";
echo "</div>\n";
echo "<div align=center id=topnavbarbottom>&nbsp</div>\n";

if ($templates_html) {
     echo "<div class=invisible id=\"div_templates\">$templates_html</div>";
}
if ($experiments_html) {
     echo "<div class=invisible id=\"div_experiments\">$experiments_html</div>";
}
if ($groups_html) {
     echo "<div class=invisible id=\"div_groups\">$groups_html</div>";
}
if ($members_html) {
     echo "<div class=invisible id=\"div_members\">$members_html</div>";
}
echo "<div class=invisible id=\"div_profile\">$profile_html</div>";
if ($isadmin && $stats_html) {
    echo "<div class=invisible id=\"div_stats\">$stats_html</div>";
}
if ($papers_html) {
     echo "<div class=invisible id=\"div_papers\">$papers_html</div>";
}
if ($vis_html) {
     echo "<div class=invisible id=\"div_vis\">$vis_html</div>";
}
if ($exports_html) {
     echo "<div class=invisible id=\"div_exports\">$exports_html</div>";
}
SUBPAGEEND();

#
# Get the active tab to look right.
#
echo "<script type='text/javascript' language='javascript'>
      Setup();
      </script>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
