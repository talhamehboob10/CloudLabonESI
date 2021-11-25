<?php
#
# Copyright (c) 2006-2012 University of Utah and the Flux Group.
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
# Only known and logged in users can look at experiments.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("experiment", PAGEARG_EXPERIMENT);
$optargs = OptionalPageArguments("submit", PAGEARG_STRING,
				 "formfields", PAGEARG_ARRAY);

# Need these below.
$pid = $experiment->pid();
$eid = $experiment->eid();
$gid = $experiment->gid();

# Permission
if (!$isadmin &&
    !$experiment->AccessCheck($this_user, $TB_PROJECT_READINFO)) {
    USERERROR("You do not have permission to view tags for ".
	      "archive in $pid/$eid!", 1);
}

#
# Standard Testbed Header
#
PAGEHEADER("Commit and Tag");

function SPITFORM($formfields, $errors)
{
    global $experiment, $TBDB_ARCHIVE_TAGLEN, $referrer;

    echo "<center>
          Commit/Tag Archive
          </center><br>\n";

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

    echo "<table align=center border=1> 
          <form action='" . CreateURL("archive_tag", $experiment) . "' ".
	        "method=post>\n";

    echo "<tr>
              <td align=center>
               <b>Please enter a tag[<b>1</b>]</b>
              </td>
          </tr>\n";

    echo "<tr>
              <td class=left>
                  <input type=text
                         name=\"formfields[tag]\"
                         value=\"" . $formfields["tag"] . "\"
	                 size=$TBDB_ARCHIVE_TAGLEN
                         maxlength=$TBDB_ARCHIVE_TAGLEN>
          </tr>\n";


    echo "<tr>
              <td align=center>
               <b>Please enter an optional message to be logged
                       with the tag.</b>
              </td>
          </tr>
          <tr>
              <td align=center class=left>
                  <textarea name=\"formfields[message]\"
                    rows=10 cols=70>" .
	            str_replace("\r", "", $formfields["message"]) .
	            "</textarea>
              </td>
          </tr>\n";

    echo "<tr>
              <td align=center>
                 <b><input type=submit name=submit value='Commit and Tag'></b>
              </td>
          </tr>\n";

    echo "</form>
          </table>\n";

    echo "<blockquote><blockquote><blockquote>
          <ol>
            <li> Optional tag must contain only alphanumeric characters,
                 starting with an alpha character. If no tag is supplied,
                 we will make one up for you, but that is probably not
                 what you want.

          </ol>
          </blockquote></blockquote></blockquote>\n";
}

#
# On first load, display a virgin form and exit.
#
if (! isset($submit)) {
    $defaults = array();
    $defaults["tag"]     = "";
    $defaults["message"] = "";
    
    SPITFORM($defaults, 0);
    PAGEFOOTER();
    return;
}

# Args to shell.
$tag      = "";
$tagarg   = "";
$message  = "";
$tmpfname = Null;

function CLEANUP()
{
    global $tmpfname;

    if ($tmpfname != NULL)
	unlink($tmpfname);
    
    exit();
}
register_shutdown_function("CLEANUP");

#
# Otherwise, must validate and redisplay if errors
#
$errors = array();

#
# Tag
#
if (isset($formfields["tag"]) && $formfields["tag"] != "") {
    if (! TBvalid_archive_tag($formfields["tag"])) {
	$errors["Tag"] = TBFieldErrorString();
    }
    else {
	$tag = escapeshellarg($formfields["tag"]);
	$tagarg = "-t $tag" ;
    }
}

if (isset($formfields["message"]) && $formfields["message"] != "") {
    if (! TBvalid_archive_message($formfields["message"])) {
	$errors["Message"] = TBFieldErrorString();
    }
    else {
	#
	# Easier to stick the entire message into a temporary file and
	# send that through. 
	#
	$tmpfname = tempnam("/tmp", "archive_tag");

	$fp = fopen($tmpfname, "w");
	fwrite($fp, $formfields["message"]);
	fclose($fp);
	chmod($tmpfname, 0666);
	
	$message = "-m $tmpfname";
    }
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

STARTBUSY("Committing and Tagging!");

#
# First lets make sure the tag is unique. 
#
if ($tag != "") {
    $retval = SUEXEC($uid, "$pid,$gid",
		     "webarchive_control checktag $pid $eid $tag",
		     SUEXEC_ACTION_IGNORE);

    /* Clear the various 'loading' indicators. */
    if ($retval) 
	CLEARBUSY();

    #
    # Fatal Error. 
    # 
    if ($retval < 0) {
	SUEXECERROR(SUEXEC_ACTION_DIE);
    }

    # User error. Tell user and exit.
    if ($retval) {
	$errors["Tag"] = "Already in use; pick another";
    
	SPITFORM($formfields, $errors);
	PAGEFOOTER();
	return;
    }
}

SUEXEC($uid, "$pid,$gid",
       "webarchive_control $tagarg $message -u commit $pid $eid",
       SUEXEC_ACTION_DIE);

STOPBUSY();

if (!isset($referrer)) {
    $exptidx  = $experiment->idx();
    $referrer = "archive_view.php3/$exptidx/?exptidx=$exptidx";
}

PAGEREPLACE($referrer);

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
