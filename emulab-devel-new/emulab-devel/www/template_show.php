<?php
#
# Copyright (c) 2006-2011 University of Utah and the Flux Group.
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
require("Sajax.php");
sajax_init();
sajax_export("Show", "GraphChange");

#
# Only known and logged in users ...
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments 
#
$reqargs = RequiredPageArguments("template", PAGEARG_TEMPLATE);
$optargs = OptionalPageArguments("action",   PAGEARG_STRING,
				 "show",     PAGEARG_STRING,
				 "confirmed",PAGEARG_STRING);

if (! ($experiment = $template->GetExperiment())) {
    TBERROR("Could not find experiment object for template!", 1);
}

# Need these below
$guid = $template->guid();
$vers = $template->vers();
$pid  = $template->pid();
$eid  = $template->eid();
$tid  = $template->tid();
$exptidx  = $experiment->idx();
$unix_gid = $experiment->UnixGID();
$this_url = CreateURL("template_show", $template);
$project  = $template->GetProject();
$unix_pid = $project->unix_gid();

#
# Verify Permission.
#
if (! $template->AccessCheck($this_user, $TB_EXPT_READINFO)) {
    USERERROR("You do not have permission to view experiment ".
	      "template $guid/$vers", 1);
}

#
# For the Sajax Interface
#
function Show($which, $zoom, $detail)
{
    global $pid, $eid, $uid, $TBSUEXEC_PATH, $TBADMINGROUP;
    global $template, $isadmin;
    $html = "";

    if ($which == "vis") {
	if ($zoom == 0) {
            # Default is whatever we have; to avoid regen of the image.
	    list ($zoom, $detail) = $template->CurrentVisDetails();	    
	}
	else {
            # Sanity check but lets not worry about throwing an error.
	    if (!TBvalid_float($zoom))
		$zoom = 1.25;
	    if (!TBvalid_integer($detail))
		$detail = 1;
    	}

	ob_start();
	$template->ShowVis($zoom, $detail);
	$html = ob_get_contents();
	ob_end_clean();

	$zoomout = sprintf("%.2f", $zoom / 1.25);
	$zoomin  = sprintf("%.2f", $zoom * 1.25);

	$html .= "<button name=viszoomout type=button value=$zoomout";
	$html .= " onclick=\"VisChange('$zoomout', $detail);\">";
	$html .= "Zoom Out</button>\n";
	$html .= "<button name=viszoomin type=button value=$zoomin";
	$html .= " onclick=\"VisChange('$zoomin', $detail);\">";
	$html .= "Zoom In</button>\n";

	if ($detail) {
	    $html .= "<button name=hidedetail type=button value=0";
	    $html .= " onclick=\"VisChange('$zoom', 0);\">";
	    $html .= "Hide Details</button>\n";
	}
	else {
	    $html .= "<button name=showdetail type=button value=1";
	    $html .= " onclick=\"VisChange('$zoom', 1);\">";
	    $html .= "Show Details</button>\n";
	}
    }
    elseif ($which == "graph") {
	ob_start();
	$template->ShowGraph();
	$html = ob_get_contents();
	ob_end_clean();

	if (! $template->IsRoot()) {
	    if ($template->IsHidden()) {
		$html .= "<button name=showtemplate type=button value=Show";
		$html .= " onclick=\"GraphChange('showtemplate');\">";
		$html .= "Show Template</button>&nbsp";
	    }
	    else {
		$html .= "<button name=hidetemplate type=button value=Hide";
		$html .= " onclick=\"GraphChange('hidetemplate');\">";
		$html .= "Hide Template</button>&nbsp";
	    }
	    $html .= "<input id=showexp_recursive type=checkbox value=Yep> ";
	    $html .= "Recursive? &nbsp &nbsp &nbsp &nbsp ";
	}
	$root = Template::LookupRoot($template->guid());

        # We overload the hidden bit on the root.
	if ($root->IsHidden()) {
	    $html .= "<button name=showhidden type=button value=showhidden";
	    $html .= " onclick=\"GraphChange('showhidden');\">";
	    $html .= "Show Hidden Templates</button>&nbsp &nbsp &nbsp &nbsp ";
	}
	else {
	    $html .= "<button name=hidehidden type=button value=hidehidden";
	    $html .= " onclick=\"GraphChange('hidehidden');\"> ";
	    $html .= "Hide Hidden Templates</button>&nbsp &nbsp &nbsp &nbsp ";
	}
	$html .= "<button name=zoomout type=button value=out";
	$html .= " onclick=\"GraphChange('zoomout');\">Zoom Out</button>\n";
	$html .= "<button name=zoomin type=button value=in";
	$html .= " onclick=\"GraphChange('zoomin');\">Zoom In</button>\n";

	# A delete button with a confirm box right there.
	if ($isadmin) {
	    $html .= "<br><br>\n";
	    $html .= "<button name=deletetemplate type=button value=Delete";
	    $html .= " onclick=\"DeleteTemplate();\">";
	    $html .= "<font color=red>Delete</font></button>&nbsp";	
	    $html .= "<input id=confirm_delete type=checkbox value=Yep> ";
	    $html .= "Confirm";
	}
    }
    elseif ($which == "nsfile") {
	$nsdata = "";

	$input_list = $template->InputFiles();

	for ($i = 0; $i < count($input_list); $i++) {
	    $nsdata .= htmlentities($input_list[$i]);
	    $nsdata .= "\n\n";
	}
	$html = "<pre><div align=left class=\"showexp_codeblock\">".
	    "$nsdata</div></pre>\n";

	$html .= "<button name=savens type=button value=1";
	$html .= " onclick=\"SaveNS();\">";
	$html .= "Save</button>\n";
    }
    
    return $html;
}

#
# Sajax callback for operating on the template graph.
#
function GraphChange($action, $recursive = 0, $no_output = 0)
{
    global $pid, $unix_gid, $eid, $uid, $guid, $TBSUEXEC_PATH, $TBADMINGROUP;
    global $template, $unix_pid;
    $html = "";

    $reqarg  = "-a ";
    $versarg = $template->vers();

    if ($action == "zoomout" || $action == "zoomin") {
	$optarg = "";
	
	if ($action == "zoomin") {
	    $optarg = "-z in";
	}
	else {
	    $optarg = "-z out";
	}

        # Need to update the template graph.
	SUEXEC($uid, "$unix_pid,$unix_gid", "webtemplate_graph $optarg $guid",
	       SUEXEC_ACTION_DIE);
    }
    else {
	$optarg  = ($recursive ? "-r" : "");
	
	if ($action == "showtemplate") {
	    $reqarg .= "show";
	}
	elseif ($action == "hidetemplate") {
	    $reqarg .= "hide";
	}
	elseif ($action == "showhidden") {
	    $reqarg .= "showhidden";
	    # Applies only to root template
	    $versarg = "1";
	}
	elseif ($action == "hidehidden") {
	    $reqarg .= "hidehidden";
	    # Applies only to root template
	    $versarg = "1";
	}
	elseif ($action == "activate") {
	    $reqarg .= "activate";
	}
	elseif ($action == "inactivate") {
	    $reqarg .= "inactivate";
	}
	else {
	    PAGEARGERROR("Invalid action $action");
	    return;
	}
	$reqarg .= " $guid/$versarg";
	
	SUEXEC($uid, "$unix_pid,$unix_gid",
	       "webtemplate_control $reqarg $optarg",
	       SUEXEC_ACTION_DIE);
    }
    $template->Refresh();

    $html = "";
    if (! $no_output)
	$html = Show("graph", 0, 0);
    
    return $html;
}

#
# See if this request is to the above function. Does not return
# if it is. Otherwise return and continue on.
#
sajax_handle_client_request();

#
# Active/Inactive is a plain menu link.
#
if (isset($action) && ($action == "activate" || $action == "inactivate")) {
    GraphChange($action, 0, 1);
}

# Delete is just plain special!
if (isset($action) && $action == "deletetemplate" &&
    isset($confirmed) && $confirmed == "yep") {

    PAGEHEADER("Delete Template: $guid/$vers");
    STARTBUSY("Deleting template $guid/$vers recursively");

    # Pass recursive option all the time.
    $retval = SUEXEC($uid, "$unix_pid,$unix_gid",
		     "webtemplate_delete -r $guid/$vers",
		     SUEXEC_ACTION_IGNORE);

    CLEARBUSY();
    
    #
    # Fatal Error. Report to the user, even though there is not much he can
    # do with the error. Also reports to tbops.
    # 
    if ($retval < 0) {
	SUEXECERROR(SUEXEC_ACTION_CONTINUE);
    }

    # User error. Tell user and exit.
    if ($retval) {
	SUEXECERROR(SUEXEC_ACTION_USERERROR);
	PAGEFOOTER();
	return;
    }
    #
    # Okay, lets zap back to the root, unless this was the root.
    #
    if ($template->IsRoot()) {
	PAGEREPLACE(CreateURL("showuser", $this_user));
    }
    else {
	PAGEREPLACE("template_show.php?guid=$guid&version=1");
    }
    return;
}

#
# Standard Testbed Header after argument checking.
#
PAGEHEADER("Template $tid ($guid/$vers)");

SUBPAGESTART();

SUBMENUSTART("Template Options");

if ($template->IsActive()) {
    WRITESUBMENUBUTTON("InActivate Template &nbsp &nbsp",
		       "${this_url}&action=inactivate");
}
else {
    WRITESUBMENUBUTTON("Activate Template &nbsp &nbsp",
		       "${this_url}&action=activate");
}

WRITESUBMENUBUTTON("Modify Template",
		   CreateURL("template_modify", $template));

WRITESUBMENUBUTTON("Instantiate Template",
		   CreateURL("template_swapin", $template));

WRITESUBMENUBUTTON("Create New Template", CreateURL("template_create"));

WRITESUBMENUBUTTON("Add Metadata",
		   CreateURL("template_metadata", $template) . "&action=add");

if ($template->EventCount() > 0) {
    WRITESUBMENUBUTTON("Edit Template Events",
		       CreateURL("template_editevents", $template));
}

WRITESUBMENUBUTTON("Search Template",
		   CreateURL("template_search", $template));

# We show the user the datastore for the template;
# the rest of it is not important.
WRITESUBMENUBUTTON("Browse Datastore",
		   CreateURL("archive_view", $template));

WRITESUBMENUBUTTON("Browse CVS Repository",
		   CreateURL("cvswebwrap", $template));

WRITESUBMENUBUTTON("View Records",
		   CreateURL("template_history", $template));

SUBMENUEND_2A();

#
# Ick.
#
if (($stats = $experiment->GetStats())) {
    $rsrcidx = $stats->rsrcidx();

    echo "<br>
          <img border=1 alt='template visualization'
               src='showthumb.php3?idx=$rsrcidx'>";
}

if ($template->InstanceCount()) {
    $template->ShowInstances();
}

SUBMENUEND_2B();

# See below; for getting the tab correct at the first page load.
if (!isset($show)) {
    $show = "vis";
}
if ($show == "vis") {
    $li_current = "li_vis";
    $init_show  = Show("vis", 0, 0);
}
elseif ($show == "nsfile") {
    $li_current = "li_nsfile";
    $init_show  = Show("nsfile", 0, 0);
}
elseif ($show == "graph") {
    $li_current = "li_graph";
    $init_show  = Show("graph", 0, 0);
}

#
# The center area is a form that can show NS file, Template Graph, or Vis.
#
echo "<script type='text/javascript' src='template_sup.js'></script>\n";
echo "<script type='text/javascript' language='javascript'>
        var li_current = '$li_current';
        function Show(which) {
	    li = getObjbyName(li_current);
            li.style.backgroundColor = '#DDE';
            li.style.borderBottom = 'none';

            li_current = 'li_' + which;
	    li = getObjbyName(li_current);
            li.style.backgroundColor = 'white';
            li.style.borderBottom = '1px solid white';

            x_Show(which, 0, 0, Show_cb);
            return false;
        }
        function Show_cb(html) {
	    visarea = getObjbyName('showexp_visarea');
            if (visarea) {
                visarea.innerHTML = html;
            }
        }
        function Setup() {
	    li = getObjbyName(li_current);
            li.style.backgroundColor = 'white';
            li.style.borderBottom = '1px solid white';
        }
        function ShowVisInit() {
            ADD_DHTML(\"myvisdiv\");
        }
        function ShowGraphInit() {
 	    ADD_DHTML(\"mygraphdiv\");
  	    SetActiveTemplate(\"mygraphimg\", \"CurrentTemplate\", 
			      \"Tarea${vers}\");
            tt_Init();
        }
        function VisChange(zoom, detail) {
            x_Show('vis', zoom, detail, Show_cb);
            return false;
        }
        function DeleteTemplate() {
            confirm_flag = 0;
            confirm_box  = getObjbyName('confirm_delete');

	    if (confirm_box) {
                confirm_flag = ((confirm_box.checked == true) ? 1 : 0);
            }
            if (confirm_flag == 0) {
                return false;
            }
	    window.location.replace('$this_url" .
                  "&action=deletetemplate&confirmed=yep');
            return false;
        }
        function GraphChange(action) {
            recursive_flag = 0;

	    recursive = getObjbyName('showexp_recursive');
            if (recursive) {
                recursive_flag = ((recursive.checked == true) ? 1 : 0);
            }

            x_GraphChange(action, recursive_flag, Show_cb);
            return false;
        }
        function SaveNS() {
            window.open('" . CreateURL("spitnsdata", $template) . "',
                        'Save NS File','width=650,height=400,toolbar=no,".
                        "resizeable=yes,scrollbars=yes,status=yes,".
	                "menubar=yes');
        }\n\n";
sajax_show_javascript();
echo "</script>\n";
echo "<script type='text/javascript' src='js/wz_dragdrop.js'></script>";

#
# This has to happen for dragdrop to work.
#
$bodyclosestring = "<script type='text/javascript'>SET_DHTML();</script>\n";

#
# This is the topbar
#
echo "<div width=\"100%\" align=center>\n";
echo "<ul id=\"topnavbar\">\n";
echo "<li>
          <a href=\"#A\" " .
               "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
               "id=\"li_vis\" onclick=\"Show('vis');\">".
               "Topology</a></li>\n";
echo "<li>
          <a href=\"#B\" " .
               "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
               "id=\"li_nsfile\" onclick=\"Show('nsfile');\">".
               "NS File</a></li>\n";
echo "<li>
          <a href=\"#C\" " .
               "class=topnavbar onfocus=\"this.hideFocus=true;\" ".
               "id=\"li_graph\" onclick=\"Show('graph');\">".
               "History</a></li>\n";
echo "</ul>\n";
echo "</div>\n";
echo "<div align=center id=topnavbarbottom>&nbsp</div>\n";

#
# Start out with  ...
#
echo "<div align=center width=\"100%\" id=\"showexp_visarea\">\n";
echo $init_show;
echo "</div>\n";

SUBPAGEEND();

$paramcount = $template->ParameterCount();
$metacount  = $template->MetadataCount();
$rowspan    = (($paramcount && $metacount) ? 2 : 1);

echo "<center>\n";
echo "<table border=0 bgcolor=#000 color=#000 class=stealth ".
     " cellpadding=0 cellspacing=0>\n";
echo "<tr valign=top><td rowspan=$rowspan class=stealth align=center>\n";

$template->Show();

echo "</td>\n";

if ($paramcount || $metacount) {
    echo "<td align=center class=stealth> &nbsp &nbsp &nbsp </td>\n";
    echo "<td align=center class=stealth> \n";
    
    if ($paramcount && $metacount) {
	$template->ShowParameters();
	echo "</td>\n";
	echo "</tr>\n";
	echo "<tr valign=top>";
	echo "<td align=center class=stealth> &nbsp &nbsp &nbsp </td>\n";
	echo "<td class=stealth align=center>\n";
	$template->ShowMetadata();
    }
    elseif ($paramcount) {
	$template->ShowParameters();
    }
    else {
	$template->ShowMetadata();
    }
    echo "</td>\n";
}

echo "</tr>\n";
echo "</table>\n";
echo "</center>\n";

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
