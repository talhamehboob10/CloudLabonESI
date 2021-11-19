<?php
#
# Copyright (c) 2000-2015, 2019 University of Utah and the Flux Group.
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
include_once("imageid_defs.php");
include_once("osinfo_defs.php");
include_once("node_defs.php");
include_once("osiddefs.php3");

#
# XXX
# In this form, we make the images:imagename and the os_info:osname the same!
# Currently, TBDB_OSID_OSNAMELEN is shorter than TBDB_IMAGEID_IMAGENAMELEN
# and that causes problems since we use the same id for both tables. For
# now, test for the shorter of the two.
# 
#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$dbid      = $this_user->dbid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("submit",       PAGEARG_STRING,
				 "imagetype",    PAGEARG_STRING,
				 "canceled",     PAGEARG_BOOLEAN,
				 "confirmed",    PAGEARG_BOOLEAN,
				 "ec2",		 PAGEARG_BOOLEAN,
				 "node",	 PAGEARG_NODE,
				 "baseimage",    PAGEARG_IMAGE,
				 "baseosinfo",   PAGEARG_OSINFO,
				 "formfields",   PAGEARG_ARRAY,
                                 "classic",      PAGEARG_BOOLEAN);

# Flag to import an EC2 image.
if (!isset($ec2)) {
    $ec2 = 0;
}

#
# If starting from a specific node we can derive the type and possibly
# the baseimage from it. 
#
if (isset($node)) {
    #
    # If we can find the running osid, then we can setup the page instead
    # of having the user figure it out. Note that only makes sense for
    # EZ images.
    #
    $baseimage = $node->def_boot_image();
    #
    # Try for at least an osinfo if no image.
    #
    if (! $baseimage) {
	$baseosinfo = $node->def_boot_osinfo();
    }
    else {
	$baseosinfo = $baseimage->OSinfo();
    }
}
elseif (isset($baseimage)) {
    $baseosinfo = $baseimage->OSinfo();
}
elseif ($ec2) {
    $imagetype = "xen";
}
if (isset($baseosinfo) && $baseosinfo->def_parentosid()) {
    $def_parentosinfo = OSinfo::Lookup($baseosinfo->def_parentosid());
    if (! $def_parentosinfo) {
	TBERROR("Could not lookup osinfo object for parent " .
		$baseosinfo->def_parentosid(), 1);
    }
}

#
# In general, there is no reason for a mere user to do anything but
# clone or snapshot an existing image. 
#
if (!$CLASSICWEB_OVERRIDE && !$classic && !$ec2) {
    $imageid = $baseimage->imageid();
    $version = $baseimage->version();
    
    $url = "apt/clone-image.php?imageid=$imageid&version=$version";
    if (isset($node)) {
        $url .= "&node=" . $node->node_id();
    }
    header("Location: $url");
    return;
}

#
# Try to determine what kind of image so we can tailor the form
# a little bit for openvz and xen.
#
if (!isset($imagetype) && isset($def_parentosinfo)) {
    if ($def_parentosinfo->FeatureSupported("xen-host")) {
	$imagetype = "xen";
    }
    else {
	$imagetype = "openvz";
    }
}
$title  = "EZ Form";

#
# Options for using this page with different types of nodes.
#
if (!isset($imagetype)) {
    #
    # Generic PC image.
    #
    $view  = array('hide_upload' => 1);
    $help_message = 
          "See the
          <a href=$WIKIDOCURL/Tutorial#CustomOS>
          tutorial</a> for more info on creating/using custom Images.";
    # Default to imagezip ndz files
    $filename_extension = "ndz";
}
else {
    $view = array('hide_partition' => 1,
		  'hide_upload' => 1);
    
    if ($imagetype == "openvz") {
	$title = "OpenVZ Form";

	$view['hide_mbr']        = 1;
	$view['hide_concurrent'] = 1;
	$view['hide_footnotes']  = 1;
	$view['hide_wholedisk']  = 1;
    }
    # Default to imagezip ndz files
    $filename_extension = "ndz";
}

#
# If we are lucky enough to get a baseimage, do not show footnotes.
#
if (isset($baseimage)) {
    $view['hide_footnotes'] = 1;
}

#
# Standard Testbed Header
#
PAGEHEADER("Create a new Image Descriptor ($title)");

#
# See what projects the uid can do this in.
#
$projlist = $this_user->ProjectAccessList($TB_PROJECT_MAKEIMAGEID);

if (! count($projlist)) {
    USERERROR("You do not appear to be a member of any Projects in which ".
	      "you have permission to create new Image descriptors.", 1);
}

#
# Need a list of node types. We join this over the nodes table so that
# we get a list of just the nodes that are currently in the testbed, not
# just in the node_types table. Limit by class if given.
#
$types_list = array();

if (isset($imagetype) && $imagetype == "openvz") {
    $types_list['pcvm'] = 1;
}
else {
    $types_result =
	DBQueryFatal("select distinct n.type from nodes as n ".
		     "left join node_types as nt on n.type=nt.type ".
		     "left join node_type_attributes as a on a.type=n.type ".
		     "where a.attrkey='imageable' and nt.class='pc' and ".
		     "      a.attrvalue!='0' and n.role='testnode'");

    while ($row = mysql_fetch_array($types_result)) {
        $types_list[$row["type"]] = 1;
    }
    if (isset($imagetype) && $imagetype == "xen") {
	$types_list['pcvm'] = 1;
    }
}

#
# Spit the form out using the array of data.
#
function SPITFORM($formfields, $errors)
{
    global $projlist, $isadmin, $types_list, $osid_oslist, $osid_opmodes,
	$osid_featurelist, $filename_extension, $help_message, $askxen;
    global $node;
    global $TBDB_OSID_OSNAMELEN, $TBDB_NODEIDLEN;
    global $TBDB_OSID_VERSLEN, $TBBASE, $TBPROJ_DIR, $TBGROUP_DIR;
    global $WIKIDOCURL;
    global $view, $ec2, $baseimage;
    
    #
    # Explanation of the $view argument: used to turn on and off display of
    # various parts of the form, so that it can be used for different types
    # of nodes. It's an associative array, with contents like:'hide_partition'.
    # In general, when an option is hidden, it is replaced with a hidden
    # field from $formfields
    #
    if ($help_message) {
        echo "<center><b>$help_message</b></center>\n";
    }

    if ($isadmin) {
	echo "<center>
               Administrators get to use the
               <a href='newimageid.php3'>long form</a>.
              </center>\n";
    }
    
    if ($errors) {
	echo "<table class=nogrid
                     align=center border=0 cellpadding=6 cellspacing=0>
              <tr>
                 <th align=center colspan=2>
                   <font size=+1 color=red>
                      &nbsp;Oops, please fix the following errors!&nbsp;
                   </font>
                 </td>
              </tr>\n";

	while (list ($name, $message) = each ($errors)) {
            # XSS prevention.
	    $message = CleanString($message);
	    echo "<tr>
                     <td align=right>
                       <font color=red>$name:&nbsp;</font></td>
                     <td align=left>
                       <font color=red>$message</font></td>
                  </tr>\n";
	}
	echo "</table><br>\n";
    }
    # XSS prevention.
    while (list ($key, $val) = each ($formfields)) {
	$formfields[$key] = CleanString($val);
    }

    echo "<SCRIPT LANGUAGE=JavaScript>
              function SetPrefix(theform) 
              {
                  var pidx   = theform['formfields[pid]'].selectedIndex;
                  var pid    = theform['formfields[pid]'].options[pidx].value;
                  var gidx   = theform['formfields[gid]'].selectedIndex;
                  var gid    = theform['formfields[gid]'].options[gidx].value;
                  var shared = theform['formfields[shared]'].checked;
          \n";
    if ($isadmin)
	echo     "var global = theform['formfields[global]'].checked;";
    else
	echo     "var global = 0;";

    echo         "if (pid == '') {
                      theform['formfields[path]'].value = '$TBPROJ_DIR';
                  }
                  else if (theform['formfields[imagename]'].value == '') {
		      theform['formfields[imagename]'].defaultValue = '';

                      if (global) {
    	                  theform['formfields[path]'].value =
                                  '/usr/testbed/images/';
                      }
		      else if (gid == '' || gid == pid || shared) {
    	                  theform['formfields[path]'].value =
                                  '$TBPROJ_DIR/' + pid + '/images/';
                      }
                      else {
    	                  theform['formfields[path]'].value =
                                  '$TBGROUP_DIR/' + pid + '/' + gid + '/images/';
                      }
                  }
                  else if (theform['formfields[imagename]'].value != '') {
                      var filename =
                           theform['formfields[imagename]'].value + '/';

                      if (global) {
    	                  theform['formfields[path]'].value =
                                  '/usr/testbed/images/' + filename;
                      }
		      else if (gid == '' || gid == pid || shared) {
    	                  theform['formfields[path]'].value =
                                  '$TBPROJ_DIR/' + pid + '/images/' + filename;
                      }
                      else {
    	                  theform['formfields[path]'].value =
                                  '$TBGROUP_DIR/' + pid + '/' + gid + '/images/' +
                                  filename;
                      }
                  }
              }
          </SCRIPT>\n";

    echo "<br>
          <table align=center border=1> 
          <tr>
             <td align=center colspan=2>
                 <em>(Fields marked with * are required)</em>
             </td>
          </tr>
          <form action='newimageid_ez.php3' enctype='multipart/form-data'
              method=post name=idform>\n";

    # Carry along stuff ...
    if (isset($node)) {
	$id = $node->node_id();
	echo "<input type=hidden name=node_id value='$id'>";
    }
    if ($ec2) {
	echo "<input type=hidden name=ec2 value=true>";
    }
    if ($classic) {
	echo "<input type=hidden name=classic value=true>";
    }
    if (isset($baseimage)) {
        $id = $baseimage->imageid();
	$version = $baseimage->version();
	echo "<input type=hidden name=baseimage value='$id'>";
	echo "<input type=hidden name=version value='$version'>";
    }
    #
    # Select Project
    #
    echo "<tr>
              <td>*Select Project:</td>
              <td><select name=\"formfields[pid]\"
                          onChange='SetPrefix(idform);'>
                      <option value=''>Please Select &nbsp</option>\n";
    
    while (list($project) = each($projlist)) {
	$selected = "";

	if ($formfields["pid"] == $project)
	    $selected = "selected";
	
	echo "        <option $selected value='$project'>$project </option>\n";
    }
    echo "       </select>";
    echo "    </td>
          </tr>\n";

    #
    # Select a group
    # 
    echo "<tr>
              <td >Group:</td>
              <td><select name=\"formfields[gid]\"
                          onChange='SetPrefix(idform);'>
                    <option value=''>Default Group </option>\n";

    reset($projlist);
    while (list($project, $grouplist) = each($projlist)) {
	for ($i = 0; $i < count($grouplist); $i++) {
	    $group    = $grouplist[$i];

	    if (strcmp($project, $group)) {
		$selected = "";

		if (isset($formfields["gid"]) &&
		    isset($formfields["pid"]) &&
		    strcmp($formfields["pid"], $project) == 0 &&
		    strcmp($formfields["gid"], $group) == 0)
		    $selected = "selected";
		
		echo "<option $selected value=\"$group\">
                           $project/$group</option>\n";
	    }
	}
    }
    echo "     </select>
             </td>
          </tr>\n";

    #
    # Image Name
    #
    echo "<tr>
              <td>*Descriptor Name (no blanks):</td>
              <td class=left>
                  <input type=text
                         onChange='SetPrefix(idform);'
                         name=\"formfields[imagename]\"
                         value=\"" . $formfields["imagename"] . "\"
	                 size=$TBDB_OSID_OSNAMELEN
                         maxlength=$TBDB_OSID_OSNAMELEN>
              </td>
          </tr>\n";

    #
    # Description
    #
    echo "<tr>
              <td>*Description:<br>
                  (a short pithy sentence)</td>
              <td class=left>
                  <input type=text
                         name=\"formfields[description]\"
                         value=\"" . $formfields["description"] . "\"
	                 size=50>
              </td>
          </tr>\n";

    #
    # Load Partition
    #
    if (isset($view["hide_partition"])) {
	spithidden($formfields, 'loadpart');
    } else {
	echo "<tr>
		  <td>*Which DOS Partition[<b>1</b>]:<br>
		      (DOS partitions are numbered 1-4)</td>
		  <td><select name=\"formfields[loadpart]\">
			      <option value=X>Please Select </option>\n";

	for ($i = 1; $i <= 4; $i++) {
	    $selected = "";

	    if (strcmp($formfields["loadpart"], "$i") == 0)
		$selected = "selected";

	    echo "        <option $selected value=$i>$i </option>\n";
	}
	echo "       </select>";
	echo "    </td>
	      </tr>\n";
    }

    #
    # Select an OS
    # 
    if (isset($view["hide_os"])) {
	spithidden($formfields, 'OS');
    } else {
	echo "<tr>
		 <td>*Operating System:<br>
		    (OS that is on the partition)</td>
		 <td><select name=\"formfields[OS]\">
		       <option value=none>Please Select </option>\n";

	while (list ($os, $userokay) = each($osid_oslist)) {
	    $selected = "";

	    if (!$userokay && !$isadmin)
		continue;

	    if (isset($formfields["OS"]) &&
		strcmp($formfields["OS"], $os) == 0)
		$selected = "selected";

	    echo "<option $selected value=$os>$os &nbsp; </option>\n";
	}
	echo "       </select>
		 </td>
	      </tr>\n";
    }

    #
    # Version String
    #
    if (isset($view["hide_version"])) {
	spithidden($formfields, 'version');
    } else {
	echo "<tr>
		  <td>*OS Version:<br>
		      (eg: 4.3, 7.2, etc.)</td>
		  <td class=left>
		      <input type=text
			     name=\"formfields[version]\"
			     value=\"" . $formfields["version"] . "\"
			     size=$TBDB_OSID_VERSLEN
			     maxlength=$TBDB_OSID_VERSLEN>
		  </td>
	      </tr>\n";
    }

    #
    # Path to image.
    #
    $style = ($isadmin ? "" : "style='display:none;'");
    echo "<tr $style>
              <td>Directory for Image:<br>
                  (must reside in $TBPROJ_DIR)</td>
              <td class=left>
                  <input type=text
                         name=\"formfields[path]\"
                         value=\"" . $formfields["path"] . "\"
	                 size=50>
              </td>
          </tr>\n";

    #
    # Node to Snapshot image from.
    #
    if ($ec2) {
	echo "<tr>
		  <td>EC2 User@Node Info:</td>
		  <td class=left>
		      <input type=text
			     name=\"formfields[ec2_info]\"
			     value=\"" . $formfields["ec2_info"] . "\"
			     size=64>
		  </td>
	      </tr>\n";
    }
    elseif (isset($view["hide_snapshot"])) {
	spithidden($formfields, 'node');
    } else {
	echo "<tr>
		  <td>Node to Obtain Snapshot from[<b>2</b>]:</td>
		  <td class=left>
		      <input type=text
			     name=\"formfields[node_id]\"
			     value=\"" . $formfields["node_id"] . "\"
			     size=$TBDB_NODEIDLEN maxlength=$TBDB_NODEIDLEN>
		  </td>
	      </tr>\n";
    }
    

    #
    # OS Features.
    # 
    if (isset($view["hide_features"])) {
        reset($osid_featurelist);
        while (list ($feature, $userokay) = each($osid_featurelist)) {
            spithidden($formfields, "os_feature_$feature");
        }
    } else {
	echo "<tr>
		  <td>OS Features[<b>3</b>]:</td>
		  <td>";

	reset($osid_featurelist);
	while (list ($feature, $userokay) = each($osid_featurelist)) {
	    $checked = "";
	    
	    if (!$userokay && !$isadmin)
		continue;

	    if (isset($formfields["os_feature_$feature"]) &&
		! strcmp($formfields["os_feature_$feature"], "checked"))
		$checked = "checked";

	    echo "<input $checked type=checkbox value=checked
			 name=\"formfields[os_feature_$feature]\">
		       $feature &nbsp\n";
	}
	echo "    </td>
	      </tr>\n";
    }

    #
    # Operational Mode
    # 
    if (isset($view["hide_opmode"])) {
	spithidden($formfields, 'op_mode');
    } else {
	echo "<tr>
		 <td>*Operational Mode[<b>4</b>]:</td>
		 <td><select name=\"formfields[op_mode]\">
		       <option value=none>Please Select </option>\n";

	while (list ($mode, $userokay) = each($osid_opmodes)) {
	    $selected = "";

	    if (!$userokay && !$isadmin)
		continue;

	    if (isset($formfields["op_mode"]) &&
		strcmp($formfields["op_mode"], $mode) == 0)
		$selected = "selected";

	    echo "<option $selected value=$mode>$mode &nbsp; </option>\n";
	}
	echo "       </select>
		 </td>
	      </tr>\n";
    }

    #
    # Node Types.
    #
    if (!isset($view["hide_footnotes"])) {
	$footnote = "[<b>5</b>]";
    } else {
	$footnote = "";
    }
    echo "<tr>
              <td>Node Types${footnote}:</td>
              <td>\n";

    foreach ($types_list as $type => $value) {
        $checked = "";

        if ((isset($formfields["mtype_$type"]) &&
	     $formfields["mtype_$type"] == "Yep") ||
	    (isset($formfields["mtype_all"]) &&
	     $formfields["mtype_all"] == "Yep")) {
	    $checked = "checked";
	}
    
        echo "<input $checked type=checkbox
                     value=Yep name=\"formfields[mtype_$type]\">
                     $type &nbsp
              </input>\n";
    }
    echo "    </td>
          </tr>\n";

    #
    # Whole Disk Image
    #
    if (isset($view["hide_wholedisk"]) && $view["hide_wholedisk"]) {
	spithidden($formfields, 'wholedisk');
    } else {
	echo "<tr>
		  <td>Whole Disk Image?[<b>6</b>]:</td>
		  <td class=left>
		      <input type=checkbox
			     name=\"formfields[wholedisk]\"
			     value=Yep";

	if (isset($formfields["wholedisk"]) &&
	    strcmp($formfields["wholedisk"], "Yep") == 0)
	    echo "           checked";
	    
	echo "                       > Yes
		  </td>
	      </tr>\n";
    }

    #
    # Maxiumum concurrent loads
    #
    if (isset($view["hide_concurrent"])) {
	spithidden($formfields, 'max_concurrent');
    } else {
	echo "<tr>
		  <td>Maximum concurrent loads[<b>7</b>]:</td>
		  <td class=left>
		      <input type=text
			     name=\"formfields[max_concurrent]\"
			     value=\"" . $formfields["max_concurrent"] . "\"
			     size=4 maxlength=4>
		  </td>
	      </tr>\n";

    }

    if (isset($view["hide_mbr"])) {
	spithidden($formfields, 'mbr_version');
    }
    else {
	echo "<tr>
	          <td>MBR Version:<br>
		  <td class=left>
		      <input type=text
			     name=\"formfields[mbr_version]\"
			     value=\"" . $formfields["mbr_version"] . "\"
			     size= maxlength=2>
		  </td>
	      </tr>\n";
    }

    #
    # Shared?
    #
    if (isset($view["hide_snapshot"])) {
	spithidden($formfields, 'shared');
    } else {
	echo "<tr>
		  <td>Shared?:<br>
		      (available to all subgroups)</td>
		  <td class=left>
		      <input type=checkbox
			     onClick='SetPrefix(idform);'
			     name=\"formfields[shared]\"
			     value=Yep";

	if (isset($formfields["shared"]) &&
	    strcmp($formfields["shared"], "Yep") == 0)
	    echo "           checked";
	    
	echo "                       > Yes
		  </td>
	      </tr>\n";
    }

    #
    # Upload an image file
    #
    if (isset($view["hide_upload"])) {
	;
    }
    else {
	echo "<tr>
		  <td>Upload a file:</td>
		  <td class=left>
		      <input type=file
			     name=\"upload_file\"
			     value=''
			     size=35></tr>";

    }

    if ($isadmin) {
        #
        # Global?
        #
	echo "<tr>
  	          <td>Global?:<br>
                      (available to all projects)</td>
                  <td class=left>
                      <input type=checkbox
                             onClick='SetPrefix(idform);'
                             name=\"formfields[global]\"
                             value=Yep";

	if (isset($formfields["global"]) &&
	    strcmp($formfields["global"], "Yep") == 0)
	    echo "           checked";
	
	echo "                       > Yes
                  </td>
              </tr>\n";
    }
    #
    # Reboot waittime. 
    # 
    if (!isset($view["hide_footnotes"])) {
	$footnote = "[<b>8</b>]";
    } else {
	$footnote = "";
    }
    echo "<tr>
	      <td>Reboot Waittime (seconds)${footnote}:</td>
	      <td class=left>
		  <input type=text
		         name=\"formfields[reboot_waittime]\"
			 value=\"" . $formfields["reboot_waittime"] . "\"
			 size=4 maxlength=4>
   	      </td>
	  </tr>\n";

    if (isset($formfields["def_parentosid"]) &&
	$formfields["def_parentosid"] != "") {
	$osinfo = OSInfo::Lookup($formfields["def_parentosid"]);
	$osname = $osinfo->osname();
	$url    = CreateURL("showosinfo", $osinfo);

	echo "<tr>
	          <td>Parent OS:</td> 
		  <input type=hidden
		         name=\"formfields[def_parentosid]\"
			 value=\"" . $formfields["def_parentosid"] . "\">
  	          <td class=left><a href='$url'>$osname</a></td>
	  </tr>\n";

	if ($ec2) {
	    echo "<tr>
	  	    <td>Package:</td>
		    <td class=left>
		        <input type=checkbox
		  	       name=\"formfields[package]\"
			       value=Yep";

	    if (isset($formfields["package"]) &&
		strcmp($formfields["package"], "Yep") == 0)
		echo "           checked";
	    
	    echo "         > Yes (XEN only, and only if you know what this means!)
		  </td>
	      </tr>\n";
	}
    }

    echo "<tr>
              <td align=center colspan=2>
                  <b><input type=submit name=submit value=Submit></b>
              </td>
          </tr>\n";

    echo "</form>
          </table>\n";

    if (isset($view["hide_footnotes"])) {
	echo "<center><blockquote>
	      <b>In general, you should leave the default settings alone!</b>
              </blockquote></center>\n";
    }
    else {
	echo "<blockquote>
	      <ol type=1 start=1>
		 <li> If you don't know what partition you have customized,
		      here are some guidelines:
		     <ul>
			<li> if you customized one of our standard Linux
                             (RHL*) or Fedora images (FC*) then it is
                             partition 2.
			</li>
			<li> if you customized one of our standard BSD
			     images (FBSD*) then it is partition 1.
			</li>
			<li> if you customized one of our standard Windows XP
			     images then it is partition 1, and make sure
                             you check the <em>Whole Disk Image</em> box.
			</li>
			<li> otherwise, feel free to ask us!
			</li>
		     </ul>
		 </li>
		 <li> If you already have a node customized, enter that node
		      name (pcXXX) and a snapshot will automatically be made of
		      its disk contents into the specified Image File. 
		      Notification of completion will be sent to you via email. 
		 </li>
		 <li> Guidelines for setting OS features for your OS:
		      (Most images should mark all four of these.)
		    <ul>
		      <li> Mark ping and/or ssh if they are supported. 
		      </li>
		      <li> If you use one of our standard Linux, Fedora or
                           FreeBSD kernels, or started from our kernel
                           configs, mark ipod.
			   ipod is not supported on Windows XP.
		      </li>
		      <li> If it is based on one of our standard Linux, Fedora,
			   FreeBSD, or Windows XP images (or otherwise
			   sends its own ISUP notification), mark isup.
                      </li>
		      <li> If it is based on one of our standard Linux, Fedora,
			   FreeBSD, or Windows XP images, mark linktest.
		      </li>
		      <li> If it is based on an image with
			   <a href=$WIKIDOCURL/EmulabStorage#section-9>
			   blockstore support</a>, then mark the loc-bstore
			   and/or rem-bstore checkboxes (indicating local
			   and remote blockstore support, respectively).
		      </li>
		    </ul>
		 </li>
		 <li> Guidelines for setting Operational Mode for your OS:
		      (Most images should use " . TBDB_DEFAULT_OSID_OPMODE . ")
		    <ul>
		      <li> If it is based on a testbed image (one of our
			   Linux, Fedora, FreeBSD, or Windows XP images)
                           use the same op_mode as that image.
                           Select it from the
			   <a href=\"$TBBASE/showosid_list.php3\"
			   >OS Descriptor List</a> to find out).
		      </li>
		      <li> If not, use MINIMAL. 
		      </li>
		    </ul>
		 </li>
		 <li> Specify the node types that this image will be able
		      to work on (can be loaded on and expected to work).
		      Typically, images of newer OS versions will work on all
		      of the \"pc\" types.  However, older versions of OSes
		      may only work on the older hardware types (pc600, pc850,
		      pc2000).  To make this type selection process easier,
		      when you take a snapshot of an existing node that you
		      have customized (see 2. above), the system will restrict
		      the types to those allowed for the \"base\" image (the
		      one originally loaded, that you have customized).  If
		      you need to override this restriction and add a type
		      that is not allowed in the current image, you will have
		      to contact us.  If you have any questions, free to ask
		      us!
		 </li>
		 <li> If you need to snapshot the entire disk (including the MBR),
		      check this option. <b>Most users will not need to check this
		      option. Please ask us first to make sure</b>.
		 </li>
		 <li> If your image contains software that is only licensed to run
		      on a limited number of nodes at a time, you can put this
		      number here. Most users will want to leave this option blank.
                 </li>
		 <li> Leave this field <b>blank</b> unless you know what you
                      are doing, or you have an explicit problem with images
                      taking too long to boot. <b>Please talk to us first!</b>
                 </li>
	      </ol>
	      </blockquote>\n";
    }
}

#
# If the given field is defined in the given set of fields, spit out a hidden
# form element for it
#
function spithidden($formfields, $field) {
    if (isset($formfields[$field])) {
	echo "<input type=hidden name=formfields[$field] value='" .
	     $formfields[$field] . "'>\n";
    }
}

#
# On first load, display a virgin form and exit.
#
if (!isset($submit)) {
    $defaults = array();
    $defaults["pid"]		 = "";
    $defaults["gid"]		 = "";
    $defaults["imagename"]	 = "";
    $defaults["description"]	 = "";
    $defaults["path"]		 = "$TBPROJ_DIR/";
    $defaults["node_id"]	 = (isset($node) ? $node->node_id() : "");
    $defaults["max_concurrent"]	 = "";
    $defaults["shared"]		 = "No";
    $defaults["global"]		 = "No";
    $defaults["OS"]	 	 = "";
    $defaults["version"]	 = "";
    $defaults["wholedisk"]	 = "No";
    $defaults["reboot_waittime"] = "";
    $defaults["mbr_version"]     = "";
    $defaults["noexport"]        = "No";

    #
    # Use the base image to seed the form.
    #
    if (isset($baseimage)) {
	$baseosinfo = $baseimage->OSinfo();
	if (! $baseosinfo) {
	    TBERROR("Could not lookup osinfo object for image " .
		    $baseimage->imageid(), 1);
	}
	$defaults["loadpart"]    = $baseimage->loadpart();
	if ($baseimage->loadpart() == 0 && $baseimage->loadlength() == 4) {
	    $loadpart = ($baseimage->part1_osid() ? 1 : 2);
	    $defaults["loadpart"]    = $loadpart;
	    $defaults["wholedisk"]   = "Yep";
	}
	$defaults["mbr_version"]     = $baseimage->mbr_version();
	$defaults["noexport"]        = ($baseimage->noexport() ? "Yes" : "No");
	#
	# Same types as the parent.
	#
	foreach ($baseimage->Types() as $type) {
	    $defaults["mtype_${type}"] = "Yep";
	}
    }
    elseif (isset($imagetype) && $imagetype == "openvz") {
	$defaults["loadpart"]    = "1";
	$defaults["wholedisk"]   = "Yep";
	$defaults["mtype_pcvm"]  = "Yep";
    }
    else {
	# Defaults for PC-type nodes
	$defaults["loadpart"] = "X";
	# mtype_all is a "fake" variable which makes all
	# mtypes checked in the virgin form.
	$defaults["mtype_all"] = "Yep";
    }
    
    if (isset($baseosinfo)) {
	#
	# Same features as the parent.
	#
	if ($baseosinfo->osfeatures()) {
	    foreach (preg_split("/,/", $baseosinfo->osfeatures()) as $feature) {
		$defaults["os_feature_${feature}"] = "checked";
	    }
	}
	$defaults["reboot_waittime"] = $baseosinfo->reboot_waittime();
	$defaults["OS"]	 	     = $baseosinfo->OS();
	$defaults["version"]	     = $baseosinfo->version();
	$defaults["op_mode"]         = $baseosinfo->op_mode();
	$defaults["description"]     = "Copy of " . $baseosinfo->osname();

	if ($baseosinfo->def_parentosid()) {
	    $def_parentosinfo = OSinfo::Lookup($baseosinfo->def_parentosid());
	    if (! $def_parentosinfo) {
		TBERROR("Could not lookup osinfo object for parent " .
			$baseosinfo->def_parentosid(), 1);
	    }
	    $defaults["def_parentosid"]   = $def_parentosinfo->osid();
	}
    }
    elseif (isset($imagetype) && $imagetype == "openvz") {
	$defaults["op_mode"]             = TBDB_PCVM_OPMODE;
	$defaults["reboot_waittime"]     = "240";
	$defaults["os_feature_ping"]	 = "checked";
	$defaults["os_feature_ssh"]	 = "checked";
	$defaults["os_feature_isup"]	 = "checked";
	$defaults["os_feature_linktest"] = "checked";
	$defaults["package"]             = "No";

	#
        # XXX Need to fix this.
        # 
	$def_parentosinfo = OSinfo::LookupByName("emulab-ops",
						 "FEDORA15-OPENVZ-STD");
	if (! $def_parentosinfo) {
	    TBERROR("Could not lookup osinfo object for FEDORA15-OPENVZ-STD",1);
	}
	$defaults["def_parentosid"]   = $def_parentosinfo->osid();
    }
    elseif (isset($imagetype) && $imagetype == "xen") {
	#
        # XXX Need to fix this.
        # 
	$def_parentosinfo = OSinfo::LookupByName("emulab-ops", "XEN43-64-STD");
	if (! $def_parentosinfo) {
	    $def_parentosinfo = OSinfo::LookupByName("emulab-ops",
						     "XEN41-64-STD");
	    TBERROR("Could not lookup osinfo object for XEN image", 1);
	}
	$defaults["def_parentosid"]   = $def_parentosinfo->osid();

	if ($ec2) {
	    $defaults["package"]  = "Yep";
	    $defaults["op_mode"]  = TBDB_ALWAYSUP_OPMODE;
	    $defaults["loadpart"] = 2;
	}
	else {
	    $defaults["os_feature_ipod"]	 = "checked";
	    $defaults["os_feature_isup"]	 = "checked";
	    $defaults["os_feature_linktest"]     = "checked";
	}
	$defaults["reboot_waittime"]     = "240";
	$defaults["os_feature_ping"]	 = "checked";
	$defaults["os_feature_ssh"]	 = "checked";
    }
    else {
	# Defaults for PC-type nodes
	$defaults["op_mode"]  = TBDB_DEFAULT_OSID_OPMODE;
	$defaults["os_feature_ping"]	 = "checked";
	$defaults["os_feature_ssh"]	 = "checked";
	$defaults["os_feature_ipod"]	 = "checked";
	$defaults["os_feature_isup"]	 = "checked";
	$defaults["os_feature_linktest"] = "checked";
    }

    #
    # For users that are in one project and one subgroup, it is usually
    # the case that they should use the subgroup, and since they also tend
    # to be in the naive portion of our users, give them some help.
    # 
    if (count($projlist) == 1) {
	list($project, $grouplist) = each($projlist);

	if (count($grouplist) <= 2) {
	    $defaults["pid"] = $project;
	    if (count($grouplist) == 1 || strcmp($project, $grouplist[0]))
		$group = $grouplist[0];
	    else {
		$group = $grouplist[1];
	    }
	    $defaults["gid"] = $group;
	    
	    if (!strcmp($project, $group))
		$defaults["path"]     = "$TBPROJ_DIR/$project/images/";
	    else
		$defaults["path"]     = "$TBGROUP_DIR/$project/$group/images/";
	}
	reset($projlist);
    }
    elseif (isset($node)) {
	#
	# Use the current pid/eid of the experiment the node is in.
	#
	$experiment = $node->Reservation();
	if ($experiment) {
	    $defaults["pid"] = $experiment->pid();
	    $defaults["gid"] = $experiment->gid();
	}
    }

    #
    # Allow formfields that are already set to override defaults.
    #
    if (isset($formfields)) {
	while (list ($field, $value) = each ($formfields)) {
	    $defaults[$field] = $formfields[$field];
	}
    }

    SPITFORM($defaults, 0);
    PAGEFOOTER();
    return;
}

#
# Otherwise, must validate and redisplay if errors
#
$errors  = array();

# Be friendly about the required form field names.
if (!isset($formfields["imagename"]) ||
    strcmp($formfields["imagename"], "") == 0) {
    $errors["Descriptor Name"] = "Missing Field";
}

if (!isset($formfields["description"]) ||
    strcmp($formfields["description"], "") == 0) {
    $errors["Descriptor Name"] = "Missing Field";
}

if (!isset($formfields["loadpart"]) ||
    strcmp($formfields["loadpart"], "X") == 0) {
    $errors["Starting DOS Partion"] = "Missing Field";
}

if (!isset($formfields["OS"]) ||
    strcmp($formfields["OS"], "X") == 0) {
    $errors["Operating System"] = "Missing Field";
}

if (!isset($formfields["version"]) ||
    strcmp($formfields["version"], "X") == 0) {
    $errors["Operating System"] = "Missing Field";
}

if (!isset($formfields["op_mode"]) ||
    strcmp($formfields["op_mode"], "none") == 0) {
    $errors["Operational Mode"] = "Missing Field";
}

$project = null;
$group   = null;

#
# Project:
#
if (!isset($formfields["pid"]) ||
    strcmp($formfields["pid"], "") == 0) {
    $errors["Project"] = "Not Selected";
}
elseif (!TBvalid_pid($formfields["pid"])) {
    $errors["Project"] = "Invalid project name";
}
elseif (! ($project = Project::Lookup($formfields["pid"]))) {
    $errors["Project"] = "Invalid project name";
}

if (isset($formfields["gid"]) && $formfields["gid"] != "") {
    if ($formfields["pid"] == $formfields["gid"] && $project) {
	$group = $project->DefaultGroup();
    }
    elseif (!TBvalid_gid($formfields["gid"])) {
	$errors["Group"] = "Invalid group name";
    }
    elseif ($project &&
	    ! ($group = $project->LookupSubgroupByName($formfields["gid"]))) {
	$errors["Group"] = "Invalid group name";
    }
}
elseif ($project) {
    $group = $project->DefaultGroup();
}

# Permission check if we managed to get a proper group above.
if ($group &&
    ! $group->AccessCheck($this_user, $TB_PROJECT_MAKEIMAGEID)) {
    $errors["Project"] = "Not enough permission";
}

#
# EC2 Checks
#
if ($ec2) {
    if (!isset($formfields["ec2_info"]) ||
	strcmp($formfields["ec2_info"], "") == 0) {
	$errors["EC2 Info"] = "Missing Field";
    }
    if (!preg_match("/^[-\w\@\.\+]+$/", $formfields["ec2_info"])) {
	$errors["EC2 Info"] = "Illegal characters";
    }
}
 
#
# Build up argument array to pass along.
#
$args = array();

# Ignore the form for this ...
if (isset($formfields["def_parentosid"]) &&
    $formfields["def_parentosid"] != "") {
    $osinfo = OSinfo::Lookup($formfields["def_parentosid"]);
    $args["def_parentosid"] = $osinfo->pid() . "," . $osinfo->osname();
}

if (isset($formfields["pid"]) && $formfields["pid"] != "") {
    $args["pid"] = $pid = $formfields["pid"];
}

if (isset($formfields["gid"]) && $formfields["gid"] != "") {
    $args["gid"] = $gid = $formfields["gid"];
}

if (isset($formfields["imagename"]) && $formfields["imagename"] != "") {
    $args["imagename"] = $imaganame = $formfields["imagename"];
}

if (isset($formfields["description"]) && $formfields["description"] != "") {
    $args["description"] = $formfields["description"];
}

if (isset($formfields["loadpart"]) &&
    $formfields["loadpart"] != "X" && $formfields["loadpart"] != "") {
    $args["loadpart"] = $formfields["loadpart"];
}

if (isset($formfields["OS"]) &&
    $formfields["OS"] != "none" && $formfields["OS"] != "") {
    $args["OS"] = $formfields["OS"];
}

if (isset($formfields["version"]) && $formfields["version"] != "") {
    $args["version"]	= $formfields["version"];
}

if (isset($formfields["path"]) && $formfields["path"] != "") {
    $args["path"] = $formfields["path"];
}

if (isset($formfields["node_id"]) && $formfields["node_id"] != "") {
    $args["node_id"] = $formfields["node_id"];
}

if (isset($formfields["op_mode"]) && $formfields["op_mode"] != "") {
    $args["op_mode"] = $formfields["op_mode"];
}

# Filter booleans from checkboxes to 0 or 1.
if (isset($formfields["wholedisk"])) {
   $args["wholedisk"] = strcmp($formfields["wholedisk"], "Yep") ? 0 : 1;
}
if (isset($formfields["shared"])) {
   $args["shared"] = strcmp($formfields["shared"], "Yep") ? 0 : 1;
}
if (isset($formfields["global"])) {
   $args["global"] = strcmp($formfields["global"], "Yep") ? 0 : 1;
}
if (isset($formfields["noexport"]) && $formfields["noexport"] == "Yep") {
    $args["noexport"] = 1;
}

if (isset($formfields["max_concurrent"]) &&
    $formfields["max_concurrent"] != "") {
    $args["max_concurrent"] = $formfields["max_concurrent"];
}

if ($ec2 ||
    (isset($formfields["package"]) && $formfields["package"] == "Yep")) {
    # Bogus. This tells the client that the ndz file is a package.
    $args["mbr_version"] = "99";
}
elseif (isset($formfields["mbr_version"]) &&
    $formfields["mbr_version"] != "") {
    $args["mbr_version"] = $formfields["mbr_version"];
}

if (isset($formfields["reboot_waittime"]) &&
    $formfields["reboot_waittime"] != "") {
    $args["reboot_waittime"] = $formfields["reboot_waittime"];
}

#
# Form comma separated list of osfeatures.
#
$os_features_array = array();

while (list ($feature, $userokay) = each($osid_featurelist)) {
    if (isset($formfields["os_feature_$feature"]) &&
	$formfields["os_feature_$feature"] == "checked") {
	$os_features_array[] = $feature;
    }
}
$args["osfeatures"] = join(",", $os_features_array);

#
# Node.
#
unset($node);
unset($node_id);
if (isset($formfields["node_id"]) &&
    strcmp($formfields["node_id"], "")) {

    if (!TBvalid_node_id($formfields["node_id"])) {
	$errors["Node"] = "Invalid node name";
    }
    elseif (! ($node = Node::Lookup($formfields["node_id"]))) {
	$errors["Node"] = "Invalid node name";
    }
    elseif (!$node->AccessCheck($this_user, $TB_NODEACCESS_LOADIMAGE)) {
	$errors["Node"] = "Not enough permission";
    }
    else {
	$node_id = $node->node_id();
    }
}

#
# See what node types this image will work on. Must be at least one!
# Store the valid types in a new array for simplicity.
#
$mtypes_array = array();
foreach ($types_list as $type => $value) {
    #
    # Look for a post variable with name.
    # 
    if (isset($formfields["mtype_$type"]) &&
	$formfields["mtype_$type"] == "Yep") {
	$mtypes_array[] = $type;
    }
}
if (! count($mtypes_array)) {
    $errors["Node Types"] = "Must select at least one type";
}

# The mtype_* checkboxes are dynamically generated.
foreach ($mtypes_array as $type) {

    # Filter booleans from checkbox values.
    $checked = isset($formfields["mtype_$type"]) &&
	strcmp($formfields["mtype_$type"], "Yep") == 0;
    $args["mtype_$type"] = $checked ? "1" : "0";
}

#
# If any errors, respit the form with the current values and the
# error messages displayed. Iterate until happy.
# 
if (count($errors)) {
    SPITFORM($formfields, $errors);
    PAGEFOOTER();
    return;
}

#
# See if the user is trying anything funky.
# If so, we run this twice.
# The first time we are checking for a confirmation
# by putting up a form (we tramp their settings through
# hidden variables). The next time through the confirmation will be
# set. Or, the user can hit the 'back' button, 
# which will respit the form with their old values still filled in.
#

if (isset($canceled) && $canceled) {
    SPITFORM($formfields, 0);    
    PAGEFOOTER();
    return;
}

$confirmationWarning = "";

#
# If user does not define a node to suck the image from,
# we seek confirmation.
#
if (! $ec2) {
    if (! isset($node)) {
        # We expect them to pick a node to take a snapshot from
        $confirmationWarning .=
              "<h2>You have not defined a node to obtain a snapshot from!
               If you continue, the image descriptor will be created,
               but not associated with any actual disk data.
               You will be able to remedy this later by
               going to the Image Descriptor information
               page for the new image and choosing 
               'Snapshot Node Disk into Image' from the menu.<br />
               Continue only if this is what you want.</h2>";
    }
}

#
# Generic confirmation-seeker.
#
if (!isset($confirmed) && 0 != strcmp($confirmationWarning,"")) {
    echo "<center><br />$confirmationWarning<br />";
    echo "<form enctype=\"multipart/form-data\" action='newimageid_ez.php3'
            method=post name=idform>";
    #
    # tramp all of their settings along.
    #
    reset($formfields);
    while (list($key, $value) = each($formfields)) {
	echo "<input type=hidden name=\"formfields[$key]\" value=\"$value\"></input>\n";
    }
    if (isset($node)) {
	$id = $node->node_id();
	echo "<input type=hidden name=node_id value='$id'>";
    }
    echo "<input type=hidden name='submit' value='Submit'>\n";
    echo "<input type=submit name=confirmed value=Confirm>&nbsp;";
    echo "<input type=submit name=canceled  value=Back>\n";
    if ($ec2) {
	echo "<input type=hidden name=ec2 value=true>";
    }
    if ($classic) {
	echo "<input type=hidden name=classic value=true>";
    }
    if (isset($baseimage)) {
        $id = $baseimage->imageid();
	$version = $baseimage->version();
	echo "<input type=hidden name=baseimage value='$id'>";
	echo "<input type=hidden name=version value='$version'>";
    }
    echo "</form></center>";

    PAGEFOOTER();
    return;
}

# The target (a node or an ec2) to take a snapshot from.
if ($ec2) {
    $target = $formfields["ec2_info"];
}
elseif (isset($node)) {
    $target = $node_id;
}
else {
    $target = null;
}
$imagename = $args["imagename"];
if (! ($image = Image::NewImageId(1, $imagename, $args, $this_user, $group,
				  $target, $errors))) {
    # Always respit the form so that the form fields are not lost.
    # I just hate it when that happens so lets not be guilty of it ourselves.
    SPITFORM($formfields, $errors);
    PAGEFOOTER();
    return;
}
$imageid = $image->imageid();

SUBPAGESTART();
SUBMENUSTART("More Options");
if (! isset($node)) {
    WRITESUBMENUBUTTON("Edit this Image Descriptor",
		       "editimageid.php3?imageid=$imageid");
    WRITESUBMENUBUTTON("Delete this Image Descriptor",
		       "deleteimageid.php3?imageid=$imageid");
}
if ($image->GetLogfile()) {
    WRITESUBMENUBUTTON("View Log File",
		       "showimageid.php3?imageid=$imageid&showlog=1");
}
if ($isadmin) {
    WRITESUBMENUBUTTON("Create a new Image Descriptor",
		       "newimageid_ez.php3");
    WRITESUBMENUBUTTON("Create a new OS Descriptor",
	  	       "newosid.php3");
    WRITESUBMENUBUTTON("OS Descriptor list",
		       "showosid_list.php3");
}
WRITESUBMENUBUTTON("Image Descriptor list",
		   "showimageid_list.php3");
SUBMENUEND();

#
# Dump os_info record.
#
$image->Show();
SUBPAGEEND();

if (isset($node) || $ec2) {
    #
    # The backend is creating the image. Patience please.
    #
    echo "<br>";

    if ($ec2) {
	$target = $formfields["ec2_info"];
    }
    else {
	$target = $node_id;
    }
    echo "Taking a snapshot of $target for image ...";
    echo "<br>\n";
    echo "This will take as little as 10 minutes or as much as an hour;
          you will receive email
          notification when the image is complete. In the meantime,
          <b>PLEASE DO NOT</b> delete the imageid or mess with
          the node at all! ";
    if ($image->GetLogfile()) {
	echo "You can watch the
               <a href='showimageid.php3?imageid=$imageid&showlog=1'>
               log file in realtime.</a>";
    }
}

#
# If we were given a file that represents the image, save that to the correct
# place now
#
if (isset($_FILES['upload_file']) &&
    $_FILES['upload_file']['name'] != "" &&
    $_FILES['upload_file']['name'] != "none") {
        
    # Get the correct group information for this image
    $unix_gid  = $group->unix_gid();
    $unix_pid  = $project->unix_gid();

    $tmpfile   = $_FILES['upload_file']['tmp_name'];
    $localfile = $formfields['path'];

    if (! preg_match("/^[-\w\.\/]*$/", $localfile)) {
        # Taint check shell arguments always!
	$errors["Image File"] = "Invalid characters";
    } else {
        # So that the webcopy, running as the user, can read the file
        chmod($tmpfile,0644);
	# Note - the script we call takes care of making sure that the local
        # filename is in /proj or /groups
        $retval = SUEXEC($uid, "$unix_pid,$unix_gid",
			 "webcopy " . escapeshellarg($tmpfile) . " " .
			 escapeshellarg($localfile),
			 SUEXEC_ACTION_DUPDIE);
    }
}

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
