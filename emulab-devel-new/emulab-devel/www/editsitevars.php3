<?php
#
# Copyright (c) 2000-2007, 2018 University of Utah and the Flux Group.
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

if (! $isadmin) {
    USERERROR("You do not have admin privileges to edit site variables!", 1);
}

if ($PORTAL_ENABLE || $CLUSTER_PORTAL != "") {
    header("Location: ${TBBASE}/portal/sitevars.php");
    return;
}

#
# Verify page arguments.
#
$optargs = OptionalPageArguments(# Edit greenballs pull up an Edit subform.
				 "edit",       PAGEARG_STRING,
				 "formfields", PAGEARG_ARRAY,
				 # Edit has three submit buttons.
				 "defaulted",  PAGEARG_STRING,
				 "edited",     PAGEARG_STRING,
				 "canceled",   PAGEARG_STRING);

#
# Standard Testbed Header
#
PAGEHEADER("Edit Site Variables");

function SPIT_MSGS($message, $errors)
{
    if ($message !== "") {
	echo "<H3>$message</H3>\n";
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

	while (list ($name, $text) = each ($errors)) {
	    echo "<tr>
                     <td align=right>
                       <font color=red>$name:&nbsp;</font></td>
                     <td align=left>
                       <font color=red>$text</font></td>
                  </tr>\n";
	}
	echo "</table><br>\n";
    }
}

function SPITFORM($message, $errors) {
    SPIT_MSGS($message, $errors);

    echo "<table>
	  <tr>
	    <th>&nbsp;Name&nbsp;</th>
	    <th>&nbsp;Value&nbsp;</th>
	    <th><font size='-1'>Edit</font></th>
	    <th>&nbsp;Default Value&nbsp;</th>
	    <th>&nbsp;Description&nbsp;</th> 
	  </tr>";

    $result = DBQueryFatal("SELECT name, value, defaultvalue, description ".
			   "FROM sitevariables ".
			   "ORDER BY name");

    while ($row = mysql_fetch_row($result)) {
	$name         = $row[0];
	$value        = $row[1];
	$defaultvalue = $row[2];
	$description  = $row[3];
	$cginame      = urlencode($name);

	echo "<tr><td>&nbsp;<b>$name</b>&nbsp;</td>\n";

	echo "<td>&nbsp;";
	if (isset($value)) {
	    if (0 != strcmp($value, "")) {
		$wrapped_value = wordwrap($value, 30, "<br />", 1);
		echo "<code>$wrapped_value</code>&nbsp;</td>";
	    } else {
		echo "<font color='#00B040'><i>empty string</i></font>&nbsp;</td>";	
	    }
	} else {
	    echo "<font color='#00B040'><i>default</i></font>&nbsp;</td>";
	}
	echo "<td align=center>";
	echo "&nbsp;<a href='editsitevars.php3?edit=$cginame'>";
	echo "<img border='0' src='greenball.gif' /></a>";
	echo "&nbsp;</td>";

	echo "<td nowrap='1'>&nbsp;";
	if (0 != strcmp($defaultvalue, "")) {
	    echo "<code>$defaultvalue</code>&nbsp;</td>";
	} else {
	    echo "<font color='#00B040'><i>empty string</i></font>&nbsp;</td>";	
	}

	echo "<td>&nbsp;$description&nbsp;</td></tr>\n";
    }

    echo "</table>";
}

# The "Edit" greenball column displays an edit subform for individual vars.
function SPIT_SUBFORM($formfields, $message, $errors)
{
    SPIT_MSGS($message, $errors);

    $name = $formfields["name"];
    $result = DBQueryFatal("SELECT name, value, defaultvalue, description ".
			   "FROM sitevariables ".
			   "WHERE name='$name'");

    if ($row = mysql_fetch_row($result)) {
	$name         = $row[0];
	$value        = $row[1];
	$defaultvalue = $row[2];
	$description  = $row[3];

	echo "<center>";
	echo "<form action='editsitevars.php3' method='post'>";

	echo "<input type='hidden' name=\"formfields[name]\"
		     value=\"" . $formfields["name"] . "\">";

	echo "<table><tr><th colspan=2>";
	echo "Editing site variable '<b>$name</b>':";
	echo "</th></tr><tr><td>";
	echo "<b>Description:</b></td><td>$description</font>";
	echo "</td></tr><tr><td>";
	echo "<b>Default value:</b></td><td>";
	if (0 != strcmp($defaultvalue,"")) {
	    echo "<code>$defaultvalue</code>";
	} else {
	    echo "<font color='#00B040'><i>Empty String</i></font>";	    
	}
	echo "</td></tr><tr><td>&nbsp;</td><td>";

	echo "<input type='submit' name='defaulted' ".
	     "       value='Reset to Default Value'></input>";

	echo "</td></tr><tr><td>";
	echo "<b>New value:</b></td><td>";
	echo "<input size='60' type='text'
		     name=\"formfields[value]\"
		     value=\"" . $value . "\">";
	echo "</td></tr><tr><td>&nbsp;</td><td>";

	echo "<input type='submit' name='edited'
	    	     value='Change to New Value'></input>";
	echo "&nbsp;";

	echo "<input type='submit' name='canceled'
		     value='Cancel'>";

	echo "</td></tr></table>";
	echo "</form>";
	echo "</center>";
    }
}

#
# Accumulate error reports for the user, e.g.
#    $errors["Key"] = "Msg";
# Required page args may need to be checked early.
$errors  = array();

# Show an optional status message.
$message = "";

#
#  On first load, just display current values.
#
if (!isset($edit) && 
    !isset($edited) && !isset($defaulted) && !isset($canceled)) {
    SPITFORM("", $errors);
    PAGEFOOTER();
    return;
}

# The "Edit" greenball column displays an edit subform for individual vars.
if (isset($edit)) {
    if (!TBSiteVarExists($edit)) {
	USERERROR("Couldn't find variable '$edit'!", 1);
    }
    else {
	$formfields["name"] = $edit;
	SPIT_SUBFORM($formfields, $message, $errors);
	PAGEFOOTER();
	return;
    }
}

#
# Build up argument array to pass along.
#
$args = array();
$name = "";
if (isset($formfields["name"]) && $formfields["name"] != "") {
    $name = $formfields["name"];
}

# Actions for the Edit subform.
$do_change = 0;
if (isset($canceled)) {		# Action for the Cancel submit button.
    $message = "Operation canceled.";
}
elseif (isset($edited)) {	# Action for the "Change to new value" button.
    if (isset($formfields["value"]) && $formfields["value"] != "") {
	$args["value"] = $value = $formfields["value"];
    }
    $message = "Setting '$name' to '$value'.";
    $do_change = 1;
}
elseif (isset($defaulted)) {	# Action for "Reset to Default value" button.
    $message = "Resetting '$name' to default.";
    $do_change = 1;
    $args["reset"] = "1";
}

if ($do_change) {
    $result = SetSiteVar($name, $args, $errors);
}

# Respit the form to see the result.
SPITFORM($message, $errors);

#
# Standard Testbed Footer
# 
PAGEFOOTER();
return;
			
?>
