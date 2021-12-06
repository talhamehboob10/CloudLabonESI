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
include("showstuff.php3");
include_once("template_defs.php");
include_once("table_defs.php");
include_once("pub_defs.php");

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie(CHECKLOGIN_USERSTATUS|
			     CHECKLOGIN_WEBONLY|CHECKLOGIN_WIKIONLY);
$uid       = $this_user->uid();
$uid_idx   = $this_user->uid_idx();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("target_user", PAGEARG_USER);

if (! isset($target_user)) {
    $target_user = $this_user;
}
$userstatus = $target_user->status();
$wikionly   = $target_user->wikionly();
$target_idx = $target_user->uid_idx();
$target_uid = $target_user->uid();
$archived   = ($userstatus == TBDB_USERSTATUS_ARCHIVED);


#
# Verify that this uid is a member of one of the projects that the
# target_uid is in. Must have proper permission in that group too. 
#
if (!$isadmin && 
    !$target_user->AccessCheck($this_user, $TB_USERINFO_READINFO)) {
    USERERROR("You do not have permission to view this user's information!", 1);
}

#
# Tell the user how many PCs he is using.
#
$notice  = null;
$yourpcs = $target_user->PCsInUse();

if ($yourpcs) {
    if (! $this_user->SameUser($target_user))
	$notice = "$target_uid is using $yourpcs PCs!\n";
    else
	$notice = "You are using $yourpcs PCs!\n";
}

#
# Standard Testbed Header, now that we know what we want to say.
#
if (! $this_user->SameUser($target_user)) {
    PAGEHEADER("${target_uid}'s $FLAVOR", null, null, $notice);
}
else {
    PAGEHEADER("My $FLAVOR", null, null, $notice);
}

$html_groups    = null;
$html_stats     = null;
$html_templates = null;
$html_pubs      = null;
$html_exports   = null;

#
# See if any mailman lists owned by the user. If so we add a menu item.
#
$mm_result =
    DBQueryFatal("select owner_uid from mailman_listnames ".
		 "where owner_uid='$target_uid'");
#
# Table defs for functions that generate tables.
#
$tabledefs = array('#html' => TRUE);

echo "<script type='text/javascript' language='javascript'>
	function PortalLogin(theform, user) {
            var namex = theform['selectpeer'].selectedIndex;
            var name  = theform['selectpeer'].options[namex].value;
            newurl    = 'gotopeer.php?peer=' + name + '&user=' + user;
            window.open(newurl, '_self');
	}
      </script>\n";

# The user profile.
# Add all the menu stuff. Ick.
ob_start();
SUBPAGESTART();

#
# Permission check not needed; if the user can view this page, they can
# generally access these subpages, but if not, the subpage will still whine.
#
if (!$archived) {
    SUBMENUSTART("Options");

    WRITESUBMENUBUTTON("Edit Profile",
		       CreateURL("moduserinfo", $target_user));
}
if (!$archived && !$target_user->wikionly() &&
    ($isadmin || $target_user->SameUser($this_user))) {
    WRITESUBMENUBUTTON("Edit SSH Keys",
		       CreateURL("ssh-keys", $target_user));
    
    WRITESUBMENUBUTTON("Generate SSL Cert",
		       CreateURL("gensslcert", $target_user));

    if ($target_user->HasEncryptedCert(0)) {
	WRITESUBMENUBUTTON("Download your SSL Cert",
			   CreateURL("gensslcert", $target_user,
				     "finished", 1));
    }

    # Do we have a storage pool? The we support datasets.
    $havestoragepool = HaveStoragePool();
    if ($havestoragepool) {
        WRITESUBMENUBUTTON("My Datasets",
                           CreateURL("list-datasets", $target_user));
    }

    if ($MAILMANSUPPORT) {
        #
        # See if any mailman lists owned by the user. If so we add a menu item.
        #
	$mm_result =
	    DBQueryFatal("select owner_uid from mailman_listnames ".
			 "where owner_uid='$target_uid'");

	if (mysql_num_rows($mm_result)) {
	    WRITESUBMENUBUTTON("Show Mailman Lists",
			       CreateURL("showmmlists", $target_user));
	}
    }
    if ($PEER_ENABLE && $PEER_ISPRIMARY) {
	$peer_result =
	    DBQueryFatal("select peer from user_exports ".
			 "where uid_idx=$target_idx");
	if (mysql_num_rows($peer_result) &&
	    ($this_user->SameUser($target_user) || $isadmin)) {
	
	    $portaltext =
		"<form name=\"portal\" onsubmit=\"return false;\">\n
                  <select name=\"selectpeer\">
                    <option value=''>Portal Login</option>\n";
	    while ($row = mysql_fetch_array($peer_result)) {
		$peer = $row["peer"];

		$portaltext .= "<option value='$peer'>$peer</option>\n";
	    }
	    $portaltext .= "</select> ";
	    $portaltext .=
		"<input type=button name='go' value='Go'
                        onclick='PortalLogin(portal, $target_idx);'>";
	    $portaltext .= "</form>\n";
	
	    WRITESUBMENUBUTTON($portaltext);
	}
    }
}

if ($isadmin) {
    SUBMENUSECTION("Admin Options");

    if (!$archived) {
	if ($target_user->status() == TBDB_USERSTATUS_FROZEN) {
	    WRITESUBMENUBUTTON("Thaw User",
			       CreateURL("freezeuser", $target_user,
					 "action", "thaw"));
	}
	else {
	    WRITESUBMENUBUTTON("Freeze User",
			       CreateURL("freezeuser", $target_user,
					 "action", "freeze"));
	}
	WRITESUBMENUBUTTON("Delete User",
			   CreateURL("deleteuser", $target_user));

	WRITESUBMENUBUTTON("SU as User",
			   CreateURL("suuser", $target_user));

	if ($target_user->status() == TBDB_USERSTATUS_UNAPPROVED) {
	    WRITESUBMENUBUTTON("Change UID",
			       CreateURL("changeuid", $target_user));
	}

	if ($target_user->status() == TBDB_USERSTATUS_NEWUSER ||
	    $target_user->status() == TBDB_USERSTATUS_UNVERIFIED) {
	    WRITESUBMENUBUTTON("Resend Verification Key",
			       CreateURL("resendkey", $target_user));
	}
	else {
	    WRITESUBMENUBUTTON("Send Test Email Message",
			       CreateURL("sendtestmsg", $target_user));
	}
    }
    WRITESUBMENUBUTTON("Experiment History",
		       CreateURL("showstats", $target_user, "showby", "user"));
}
SUBMENUEND();
$target_user->Show();
SUBPAGEEND();
$html_profile = ob_get_contents();
ob_end_clean();
list ($html_profile, $button_profile) =
	TableWrapUp($html_profile, FALSE, FALSE,
		    "profile_table", "profile_button");

if ($isadmin) {
    $html_stats = $target_user->ShowStats();
    $html_stats = "<center><h3>User Stats</h3></center>$html_stats";
    list ($html_stats, $button_stats) =
	TableWrapUp($html_stats, FALSE, FALSE,
		    "stats_table", "stats_button");
}

#
# Lets show Experiments.
#
if ($EXPOSETEMPLATES) {
    $html_templates = SHOWTEMPLATELIST("USER", 0, $uid, $target_uid, "", TRUE);
    if ($html_templates) {
	list ($html_templates, $button_templates) =
	    TableWrapUp($html_templates, FALSE, FALSE,
			"templates_table", "templates_button");
    }
}
$html_experiments =
    ShowExperimentList_internal(FALSE, "USER", $this_user,
				$target_user,
				array('#html' => TRUE,
				      '#id'   => 'experiments_sorted'));
if ($html_experiments) {
    list ($html_experiments, $button_experiments) =
	TableWrapUp($html_experiments, FALSE, TRUE,
		    "experiments_table", "experiments_button");
}
$html_instances =
    ShowExperimentList_internal(TRUE, "USER", $this_user, 
				$target_user,
				array('#html' => TRUE,
				      '#id'   => 'instances_sorted'));
				
if ($html_instances) {
    list ($html_instances, $button_instances) =
	TableWrapUp($html_instances, FALSE, FALSE,
		    "instances_table", "instances_button");
}

#
# Lets show project and group membership.
#
$query_result =
    DBQueryFatal("select distinct g.pid,g.gid,g.trust,p.name,gr.description, ".
    		 "       count(distinct r.node_id) as ncount ".
		 " from group_membership as g ".
		 "left join projects as p on p.pid=g.pid ".
		 "left join groups as gr on gr.pid=g.pid and gr.gid=g.gid ".
		 "left join experiments as e on g.pid=e.pid and g.gid=e.gid ".
		 "left join reserved as r on e.pid=r.pid and e.eid=r.eid ".
		 "left join group_membership as g2 on g2.pid=g.pid and ".
		 "     g2.gid=g.gid and ".
		 "     g2.uid_idx='" . $this_user->uid_idx() . "' ".
		 "where g.uid_idx='$target_idx' ".
		 ($isadmin ? "" : "and g2.uid_idx is not null ") .
		 "group by g.pid, g.gid, g.trust ".
		 "order by g.pid,gr.created");

if (mysql_num_rows($query_result)) {
    ob_start();
    echo "<center>
          <h3>Project and Group Membership</h3>
          </center>
          <table align=center border=1 cellpadding=1 cellspacing=2>\n";

    echo "<tr>
              <th>PID</th>
              <th>GID</th>
	      <th>Nodes</th>
              <th>Name/Description</th>
              <th>Trust</th>
              <th>MailTo</th>
          </tr>\n";

    while ($projrow = mysql_fetch_array($query_result)) {
	$pid   = $projrow["pid"];
	$gid   = $projrow["gid"];
	$name  = $projrow["name"];
	$desc  = $projrow["description"];
	$trust = $projrow["trust"];
	$nodes = $projrow["ncount"];

	echo "<tr>
                 <td><A href='showproject.php3?pid=$pid'>
                        $pid</A></td>
                 <td><A href='showgroup.php3?pid=$pid&gid=$gid'>
                        $gid</A></td>\n";

	echo "<td>$nodes</td>\n";

	if (strcmp($pid,$gid)) {
	    echo "<td>$desc</td>\n";
	    $mail  = $pid . "-" . $gid . "-users@" . $OURDOMAIN;
	}
	else {
	    echo "<td>$name</td>\n";
	    $mail  = $pid . "-users@" . $OURDOMAIN;
	}

	$color = ($trust == TBDB_TRUSTSTRING_NONE ? "red" : "black");

	echo "<td><font color=$color>$trust</font></td>\n";

	if ($MAILMANSUPPORT) {
            # Not sure what I want to do here ...
	    echo "<td nowrap><a href=mailto:$mail>$mail</a></td>";
	}
	else {
	    echo "<td nowrap><a href=mailto:$mail>$mail</a></td>";
	}
	echo "</tr>\n";
    }
    echo "</table>\n";

    echo "<center>
          Click on the GID to view/edit group membership and trust levels.
          </center>\n";
    $html_groups = ob_get_contents();
    list ($html_groups, $button_groups) =
	TableWrapUp($html_groups, FALSE, FALSE,
		    "groups_table", "groups_button");
    ob_end_clean();
}

if ($PUBSUPPORT) {
    #
    # List pubs owned by user if any
    #
    $query_result = GetPubs("`owner` = $target_idx");
    if (mysql_num_rows($query_result)) {
	$html_pubs = MakeBibList($this_user, $isadmin, $query_result);
	$html_pubs .= '<p><a href="deleted_pubs.php">Show Deleted Publications</a></p>';
	$html_pubs .= "\n";
	list ($html_pubs, $button_pubs) =
	  TableWrapUp($html_pubs, FALSE, FALSE,
		      "pubs_table", "pubs_button");
    }
}

#
# Portal support; show exports.
#
if ($PEER_ENABLE && $PEER_ISPRIMARY) {
    $query_result =
	DBQueryFatal("select * from user_exports where uid_idx='$target_idx'");
    if (mysql_num_rows($query_result)) {
	$html_exports =
	    "<center>
               <h3>Peer Exports</h3>
             </center>
             <table align=center border=1 cellpadding=1 cellspacing=2>\n";

        $html_exports .=
	    "<tr>
                <th>Peer</th>
                <th>Exported</th>
  	        <th>Updated</th>
             </tr>\n";

	while ($exportrow = mysql_fetch_array($query_result)) {
	    $peer     = $exportrow["peer"];
	    $updated  = $exportrow["updated"];
	    $exported = $exportrow["exported"];

	    $html_exports .=
		"<tr>
                    <td>$peer</td>
                    <td>$exported</td>
                    <td>$updated</td>
                  </tr>\n";
	}
	$html_exports .= "</table>\n";
	list ($html_exports, $button_exports) =
	    TableWrapUp($html_exports, FALSE, FALSE,
			"exports_table", "exports_button");
    }
}
 
#
# Special banner message.
#
$message = TBGetSiteVar("web/banner");
if ($message != "") {
    echo "<center><font color=Red size=+1>\n";
    echo "$message\n";
    echo "</font></center><br>\n";
}

#
# Function to change what is being shown.
#
echo "<script type='text/javascript' language='javascript'>
        var li_current = 'li_profile';
        var table_current = 'profile_table';
        function Show(which) {
	    li = getObjbyName(li_current);
            if (li) {
                li.style.backgroundColor = '#DDE';
                li.style.borderBottom = '1px solid #778';
                table = getObjbyName(table_current);
                table.style.display = 'none';
            }

            li_current = 'li_' + which;
            table_current = which + '_table';
   	    li = getObjbyName(li_current);
            if (li) {
                li.style.backgroundColor = 'white';
                li.style.borderBottom = '1px solid white';
                table = getObjbyName(table_current);
                table.style.display = 'block';
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
                    table = getObjbyName(table_current);
                    table.style.display = 'block';
                }
            }
        }
      </script>\n";

#
# This is the topbar
#
echo "<div width=\"100%\" align=center>\n";
echo "<ul id=\"topnavbar\">\n";
if ($html_templates) {
    echo "<li>
           <a href=\"#templates\" ".
	       "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
               "id=\"li_templates\" onclick=\"Show('templates');\">".
               "Templates</a></li>\n";
}
if ($html_experiments) {
     echo "<li>
            <a href=\"#experiments\" ".
	       "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
               "id=\"li_experiments\" onclick=\"Show('experiments');\">".
               "Experiments</a></li>\n";
}
if ($html_instances) {
    echo "<li>
           <a href=\"#instances\" ".
	      "class=topnavbar onfocus=\"this.hideFocus=true;\"  ".
              "id=\"li_instances\" onclick=\"Show('instances');\">".
              "Instances</a></li>\n";
}
if ($html_groups) {
    echo "<li>
          <a href=\"#groups\" ".
	      "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
	      "id=\"li_groups\" onclick=\"Show('groups');\">".
              "Projects</a></li>\n";
}
echo "<li>
      <a href=\"#profile\" ".
           "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
           "id=\"li_profile\" onclick=\"Show('profile');\">".
           "Profile</a></li>\n";

if ($isadmin && $html_stats) {
    echo "<li>
          <a href=\"#stats\" ".
	      "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
	      "id=\"li_stats\" onclick=\"Show('stats');\">".
              "User Stats</a></li>\n";
}
if ($html_pubs) {
    echo "<li>
          <a href=\"#pubs\" ".
	      "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
	      "id=\"li_pubs\" onclick=\"Show('pubs');\">".
              "Publications</a></li>\n";
}
if ($html_exports) {
    echo "<li>
          <a href=\"#exports\" ".
	      "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
	      "id=\"li_exports\" onclick=\"Show('exports');\">".
              "Peers</a></li>\n";
}
echo "</ul>\n";
echo "</div>\n";
echo "<div align=center id=topnavbarbottom>&nbsp</div>\n"; 

if ($html_templates) {
     echo $html_templates;
}
if ($html_instances) {
    echo $html_instances;
}
if ($html_groups) {
    echo $html_groups;
}
echo $html_profile;
if ($isadmin && $html_stats) {
    echo $html_stats;
}
if ($html_pubs) {
    echo $html_pubs;
}
if ($html_exports) {
    echo $html_exports;
}
if ($html_experiments) {
    echo $html_experiments;
}

#
# Get the active tab to look right.
#
$current = ($html_experiments ? "experiments" : "profile");

echo "<script type='text/javascript' language='javascript'>
      Setup();
      </script>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>



