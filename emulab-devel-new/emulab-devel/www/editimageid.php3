<?php
#
# Copyright (c) 2000-2014, 2016 University of Utah and the Flux Group.
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
include_once("osiddefs.php3");
include_once("imageid_defs.php");
include_once("osinfo_defs.php");

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();
$doespcvm  = 0;

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("image",      PAGEARG_IMAGE);
$optargs = OptionalPageArguments("submit",     PAGEARG_STRING,
				 "formfields", PAGEARG_ARRAY);

# Need these below.
$imageid = $image->imageid();
if ($image->ezid()) {
    $osinfo = OSinfo::Lookup($imageid);
}

#
# Verify permission.
#
if (!$image->AccessCheck($this_user, $TB_IMAGEID_MODIFYINFO)) {
    USERERROR("You do not have permission to access ImageID $imageid!", 1);
}

#
# Standard Testbed Header
#
PAGEHEADER("Edit Image Descriptor");

#
# Need a list of node types. We join this over the nodes table so that
# we get a list of just the nodes that currently in the testbed, not
# just in the node_types table.
#
$types_result =
    DBQueryFatal("select distinct n.type from nodes as n ".
		 "left join node_type_attributes as a on a.type=n.type ".
		 "where a.attrkey='imageable' and ".
		 "      a.attrvalue!='0'");
$types_array = array();
while ($row = mysql_fetch_array($types_result)) {
    $types_array[] = $row["type"];
}

#
# Special hack to specify subOSes that can run on vnodes 
# -- see SetupReload in os_setup
#
$types_array[] = "pcvm";

$osid_result =
    DBQueryFatal("select o.osid,v.vers,o.osname,o.pid from os_info as o ".
		 "left join os_info_versions as v on ".
		 "     v.osid=o.osid and v.vers=o.version ".
		 "where (v.path='' or v.path is NULL) ".
		 "order by o.pid,o.osname");

#
# Spit the form out using the array of data.
#
function SPITFORM($image, $formfields, $errors)
{
    global $uid, $isadmin, $types_array, $defaults, $osid_result, $doespcvm;
    global $TBDB_IMAGEID_IMAGENAMELEN, $TBDB_NODEIDLEN;

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

    # Must encode the imageid since Rob started using plus signs in
    # the names.
    $url = CreateURL("editimageid", $image);
    echo "<br>
          <table align=center border=1> 
          <form action='$url' method=post>\n";

    #
    # Image Name
    #
    echo "<tr>
              <td>ImageID:</td>
              <td class=left>" . $defaults["imagename"] . "</td>
          </tr>\n";

    #
    # Project
    #
    echo "<tr>
              <td>Project:</td>
              <td class=left>" . $defaults["pid"] . "</td>
          </tr>\n";

    #
    # Group
    # 
    echo "<tr>
              <td>Group:</td>
              <td class=left>" . $defaults["gid"] . "</td>
          </tr>\n";

    #
    # Image Name:
    #
    echo "<tr>
              <td>Descriptor Name:</td>
              <td class=left>" . $defaults["imagename"] . "</td>
          </tr>\n";

    #
    # Description
    #
    echo "<tr>
              <td>Description:<br>
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
    echo "<tr>
              <td>Load Partition:</td>
              <td class=left>" . $defaults["loadpart"] . "</td>
          </tr>\n";

    #
    # Load Length
    #
    echo "<tr>
              <td>Load Partition:</td>
              <td class=left>" . $defaults["loadlength"] . "</td>
          </tr>\n";

    echo "<tr>
             <td>Partition 1 OS: </td>
             <td class=\"left\">";
    if (isset($defaults["part1_osid"]))
	SpitOSIDLink($defaults["part1_osid"], $defaults["part1_vers"]);
    else
	echo "No OS";
    echo "   </td>
          </tr>\n";
    
    echo "<tr>
             <td>Partition 2 OS: </td>
             <td class=\"left\">";
    if (isset($defaults["part2_osid"]))
	SpitOSIDLink($defaults["part2_osid"], $defaults["part2_vers"]);
    else
	echo "No OS";
    echo "   </td>
          </tr>\n";

    echo "<tr>
             <td>Partition 3 OS: </td>
             <td class=\"left\">";
    if (isset($defaults["part3_osid"]))
	SpitOSIDLink($defaults["part3_osid"], $defaults["part3_vers"]);
    else
	echo "No OS";
    echo "   </td>
          </tr>\n";

    echo "<tr>
             <td>Partition 4 OS: </td>
             <td class=\"left\">";
    if (isset($defaults["part4_osid"]))
	SpitOSIDLink($defaults["part4_osid"], $defaults["part4_vers"]);
    else
	echo "No OS";
    echo "   </td>
          </tr>\n";
    
    echo "<tr>
             <td>Boot OS: </td>
             <td class=\"left\">";
    if (isset($defaults["default_osid"]))
	SpitOSIDLink($defaults["default_osid"], $defaults["default_vers"]);
    else
	echo "No OS";
    echo "   </td>
          </tr>\n";
    
    #
    # Path to image.
    #
    echo "<tr>
              <td>Filename (full path) of Image:</td>
              <td class=left>
                  <input type=text
                         name=\"formfields[path]\"
                         value=\"" . $formfields["path"] . "\"
	                 size=50>
              </td>
          </tr>\n";

    echo "<tr>
              <td>Architecture:</td>
              <td class=left>
                 <input type=text
                        name=\"formfields[architecture]\"
                        value=\"" . $formfields["architecture"] . "\"
                        size=30>
              </td>
         </tr>\n";

    #
    # Node Types.
    #
    echo "<tr>
              <td>Node Types:</td>
              <td>\n";
    #
    # Is using the architecture, types are not editable. Instead, we allow
    # editing of the architecture.
    #
    if ($image->architecture()) {
        echo implode(",", $image->TypeList());
    }
    else {
        foreach ($types_array as $type) {
            $checked = "";

            if (isset($formfields["mtype_$type"]) &&
                $formfields["mtype_$type"] == "Yep") {
                $checked = "checked";

                if ("mtype_$type" == "mtype_pcvm") {
                    $doespcvm = 1;
                }
            }
    
            echo "<input $checked type=checkbox
                     value=Yep name=\"formfields[mtype_$type]\">
                     $type &nbsp
              </input>\n";
        }
    }
    echo "    </td>
          </tr>\n";

    #
    # Shared?
    #
    echo "<tr>
  	      <td>Shared?:<br>
                  (available to all subgroups)</td>
              <td class=left>". ($defaults["shared"] ? "Yes" : "No") . "</td>
          </tr>\n";

    #
    # Global?
    #
    echo "<tr>
  	      <td>Global?:<br>
                      (available to all projects)</td>
              <td class=left>". ($defaults["global"] ? "Yes" : "No") . "</td>
          </tr>\n";

    if ($isadmin) {
	echo "<tr>
	          <td>MBR Version:<br>
		  <td class=left>
		      <input type=text
			     name=\"formfields[mbr_version]\"
			     value=\"" . $formfields["mbr_version"] . "\"
			     size= maxlength=2>
		  </td>
	      </tr>\n";

	if ($doespcvm) {
	    WRITEOSIDMENU("Default Parent OS",
			  "formfields[def_parentosid]",
			  $osid_result, $formfields["def_parentosid"]);
	}
        #
	# Notes
	#
	echo "<tr>
                  <td>Admin Notes:</td>
                  <td class=left>
                      <textarea name=\"formfields[notes]\"
                                rows=4 cols=60>" .
		                   str_replace("\r", "",
						$formfields["notes"]) .
	              "</textarea>
                  </td>
              </tr>\n";
    }

    echo "<tr>
              <td align=center colspan=2>
                 <b><input type=submit name=submit value=Submit></b>
              </td>
          </tr>\n";

    echo "</form>
          </table>\n";
}

# Need this below.
$defaults = $image->DBData();
   
#
# On first load, display a virgin form and exit.
#
if (!isset($submit)) {
    # Generate the current types array for the form.
    foreach ($image->Types() as $type) {
	$defaults["mtype_${type}"] = "Yep";
    }
    $defaults["def_parentosid"] = "";
    if ($image->ezid() && $osinfo->def_parentosid()) {
	$defaults["def_parentosid"] = $osinfo->def_parentosid();
    }

    SPITFORM($image, $defaults, 0);
    PAGEFOOTER();
    return;
}

#
# Otherwise, must validate and redisplay if errors
#
$errors     = array();
$updates    = array();

#
# If any errors, respit the form with the current values and the
# error messages displayed. Iterate until happy.
# 
if (count($errors)) {
    SPITFORM($image, $formfields, $errors);
    PAGEFOOTER();
    return;
}

#
# Build up argument array to pass along.
#
$args = array();

# Notice that {part*,default}_osid are not editable inputs on this form.

# Skip passing ones that are not changing from the default (DB state.)
if (isset($formfields["description"]) && $formfields["description"] != "" &&
    ($formfields["description"] != $image->description())) {
    $args["description"] = $formfields["description"];
}

if (isset($formfields["path"]) && $formfields["path"] != "" &&
    ($formfields["path"] != $image->path())) {
    $args["path"] = $formfields["path"];
}

if (isset($formfields["mbr_version"]) && $formfields["mbr_version"] != "" &&
    $formfields["mbr_version"] != $image->mbr_version()) {
    $args["mbr_version"] = $formfields["mbr_version"];
}

if (isset($formfields["notes"])) {
    if (!TBvalid_fulltext($formfields["notes"])) {
	$errors["Notes"] = TBFieldErrorString();
    }
    else {
	$args["notes"] = $formfields["notes"];
    }
}

#
# See what node types this image will work on. Must be at least one!
# Store the valid types in a new array for simplicity.
#
if ($image->architecture()) {
    if (! (isset($formfields["architecture"]) &&
           $formfields["architecture"] != "")) {
	$errors["Architecture"] = "Must set the Architecture";
    }
    else {
        foreach (preg_split("/,/", $formfields["architecture"]) as $arch) {
            if (!array_key_exists($arch, $image_architectures)) {
                $errors["Architecture"] = "Not a valid Architecture";
            }
            else {
                #
                # If no node types of this arch, reject it.
                #
                $query_result = DBQueryFatal("select type from node_types ".
                                             "where architecture='$arch'");
                if (!mysql_num_rows($query_result)) {
                    $errors["Architecture"] =
                        "No node types of this architecture.";
                }
            }
        }
	$args["architecture"] = $formfields["architecture"];
    }
}
else {
    $mtypes_array = array();
    foreach ($types_array as $type) {
        #
        # Look for a post variable with name.
        # 
        if (isset($formfields["mtype_$type"]) &&
            $formfields["mtype_$type"] == "Yep") {
            $mtypes_array[] = $type;
            if ("mtype_$type" == "mtype_pcvm") {
                $doespcvm = 1;
            }
        }
    }
    if (! count($mtypes_array)) {
        $errors["Node Types"] = "Must select at least one type";
    }

    # The mtype_* checkboxes are dynamically generated.
    foreach ($mtypes_array as $type) {
        # Filter booleans from checkbox values, send if different.
        $checked = isset($formfields["mtype_$type"]) &&
                 strcmp($formfields["mtype_$type"], "Yep") == 0;
        if ($checked != array_search("mtype_$type", $mtypes_array)) {
            $args["mtype_$type"] = $checked ? "1" : "0";
        }
    }
    #
    # Mereusers are not allowed to create more than one osid/imageid mapping
    # for each machinetype. They cannot actually do that through the EZ form
    # since the osid/imageid has to be unique, but it can happen by mixed
    # use of the long form and the short form, or with multiple uses of the
    # long form.

    # Can't check this unless we have at least one mtype!
    if (!count($mtypes_array) || count($errors)) {
        SPITFORM($image, $formfields, $errors);
        PAGEFOOTER();
        return;
    }
    $typeclause = "type=" . "'$mtypes_array[0]'";
    for ($i = 1; $i < count($mtypes_array); $i++) {
        $typeclause = "$typeclause or type=" . "'$mtypes_array[$i]'";
    }

    unset($osidclause);
    $osid_array = array();
    for ($i = 1; $i <= 4; $i++) {
        # Local variable dynamically created.    
        $foo      = "part${i}_osid";

        if (isset($defaults[$foo])) {
            if (isset($osidclause))
                $osidclause = "$osidclause or osid='" . $defaults[$foo] . "' ";
            else 
                $osidclause = "osid='" . $defaults[$foo] . "' ";

            $osid_array[] = $defaults[$foo];
        }
    }
    if (isset($osidclause)) {
        DBQueryFatal("lock tables images write, os_info write, ".
                     "    osidtoimageid write");
        $query_result =
            DBQueryFatal("select osidtoimageid.*,images.pid,images.imagename ".
                         " from osidtoimageid ".
                         "left join images on ".
                         " images.imageid=osidtoimageid.imageid ".
                         "where ($osidclause) and ($typeclause) and ".
                         "      images.imageid!='$imageid'");
        DBQueryFatal("unlock tables");

        if (mysql_num_rows($query_result)) {
	    echo "<center>
              There are other image descriptors that specify the 
	      same OS descriptors for the same node types.<br>
              There must be a
	      unique mapping of OS descriptor to Image descriptor for
              each node type! Perhaps you need to delete one of the
              images below, or create a new OS descriptor to use in
              this new Image descriptor.
              </center><br>\n";

            echo "<table border=1 cellpadding=2 cellspacing=2 align='center'>\n";

            echo "<tr>
                  <td align=center>OSID</td>
                  <td align=center>Type</td>
                  <td align=center>ImageID</td>
             </tr>\n";

            while ($row = mysql_fetch_array($query_result)) {
                $imageid   = $row['imageid'];
                $url       = CreateURL("showimageid", URLARG_IMAGEID, $imageid);
                $osid      = $row["osid"];
                $type      = $row["type"];
                $imagename = $row["imagename"];
	    
                echo "<tr>
                      <td>$osid</td>
	              <td>$type</td>
                      <td><A href='$url'>$imagename</A></td>
	          </tr>\n";
           }
            echo "</table><br><br>\n";
            
            USERERROR("Please check the other Image descriptors and make the ".
                      "necessary changes!", 1);
        }
    }
}
# Can't check this unless we have at least one mtype!
if (count($errors)) {
    SPITFORM($image, $formfields, $errors);
    PAGEFOOTER();
    return;
}

# Send to the backend for more checking, and eventually, to update the DB.
if (! ($result = Image::EditImageid($image,
				 $args, $errors))) {
    # Always respit the form so that the form fields are not lost.
    # I just hate it when that happens so lets not be guilty of it ourselves.
    SPITFORM($image, $formfields, $errors);
    PAGEFOOTER();
    return;
}

#
# Special case. 
#
if ($isadmin && $doespcvm && $image->ezid() &&
    isset($formfields["def_parentosid"]) &&
    $formfields["def_parentosid"] != "" &&
    TBvalid_osid($formfields["def_parentosid"]) &&
    OSinfo::Lookup($formfields["def_parentosid"])) {
    $osinfo->SetParent($formfields["def_parentosid"]);
}

PAGEREPLACE(CreateURL("showimageid", $image));

#
# Dump record in case the redirect fails.
# 
$image->Refresh();
$image->Show();

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
