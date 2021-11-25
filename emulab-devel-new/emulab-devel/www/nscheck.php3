<?php
#
# Copyright (c) 2000-2007, 2012 University of Utah and the Flux Group.
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
# Define a stripped-down view of the web interface - less clutter
#
$view = array(
    'hide_banner' => 1,
    'hide_sidebar' => 1,
    'hide_copyright' => 1
);

#
# Only known and logged in users can begin experiments.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("nsdata",          PAGEARG_ANYTHING,
				 "formfields",      PAGEARG_ARRAY,
				 "fromform",        PAGEARG_BOOLEAN);

#
# Standard Testbed Header (not that we know if want the stripped version).
#
PAGEHEADER("Syntax Check an NS File",
	   (isset($fromform) || isset($nsdata) ? $view : null));

#
# Not allowed to specify both a local and an upload!
#
$speclocal  = 0;
$specupload = 0;
$specform   = 0;
$nsfile     = "";
$tmpfile    = 0;

if (isset($formfields)) {
    $exp_localnsfile = $formfields['exp_localnsfile'];
}

if (isset($exp_localnsfile) && strcmp($exp_localnsfile, "")) {
    $speclocal = 1;
}
if (isset($_FILES['exp_nsfile']) &&
    $_FILES['exp_nsfile']['name'] != "" &&
    $_FILES['exp_nsfile']['tmp_name'] != "") {
    if ($_FILES['exp_nsfile']['size'] == 0) {
        USERERROR("Uploaded NS file does not exist, or is empty");
    }
    $specupload = 1;
}
if (!$speclocal && !$specupload && isset($nsdata))  {
    $specform = 1;
}

if ($speclocal + $specupload + $specform > 1) {
    USERERROR("You may not specify both an uploaded NS file and an ".
	      "NS file that is located on the Emulab server", 1);
}
#
# Gotta be one of them!
#
if (!$speclocal && !$specupload && !$specform) {
    USERERROR("You must supply an NS file!", 1);
}

if ($speclocal) {
    #
    # No way to tell from here if this file actually exists, since
    # the web server runs as user nobody. The startexp script checks
    # for the file before going to ground, so the user will get immediate
    # feedback if the filename is bogus.
    #
    # Do not allow anything outside of the usual directories. I do not think
    # there is a security worry, but good to enforce it anyway.
    #
    if (!preg_match("/^([-\@\w\.\/]+)$/", $exp_localnsfile)) {
	USERERROR("NS File: Pathname includes illegal characters", 1);
    }
    if (!VALIDUSERPATH($exp_localnsfile)) {
	USERERROR("NS File: You must specify a server resident file in " .
		  "one of: ${TBVALIDDIRS}.", 1);
    }
    
    $nsfile = $exp_localnsfile;
    $nonsfile = 0;
}
elseif ($specupload) {
    #
    # XXX
    # Set the permissions on the NS file so that the scripts can get to it.
    # It is owned by nobody, and most likely protected. This leaves the
    # script open for a short time. A potential security hazard we should
    # deal with at some point.
    #
    $nsfile = $_FILES['exp_nsfile']['tmp_name'];
    chmod($nsfile, 0666);
    $nonsfile = 0;
} else # $specform
{
    #
    # Take the NS file passed in from the form and write it out to a file
    #
    $tmpfile = 1;

    #
    # Generate a hopefully unique filename that is hard to guess.
    # See backend scripts.
    # 
    list($usec, $sec) = explode(' ', microtime());
    srand((float) $sec + ((float) $usec * 100000));
    $foo = rand();

    $nsfile = "/tmp/$uid-$foo.nsfile";
    $handle = fopen($nsfile,"w");
    fwrite($handle,$nsdata);
    fclose($handle);
}

STARTBUSY("Starting NS syntax check from " .
	  ($speclocal ? "local file" :
	   ($specupload ? "uploaded file" :
	    ($specform ? "form" : "???"))));
$retval = SUEXEC($uid, "nobody", "webnscheck " . escapeshellarg($nsfile),
		 SUEXEC_ACTION_IGNORE);

if ($tmpfile) {
    unlink($nsfile);
}

#
# Fatal Error. Report to the user, even though there is not much he can
# do with the error. Also reports to tbops.
# 
if ($retval < 0) {
    SUEXECERROR(SUEXEC_ACTION_DIE);
    #
    # Never returns ...
    #
    die("");
}
STOPBUSY();

# Parse Error.	 
if ($retval) {
    echo "<br><br><h2>
          Parse Failure($retval): Output as follows:
          </h2>
          <br>
          <XMP>$suexec_output</XMP>\n";
    PAGEFOOTER();
    die("");
}

echo "<center>";
echo "<br>";
echo "<h2>Your NS file looks good!</h2>";
echo "</center>\n";

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
