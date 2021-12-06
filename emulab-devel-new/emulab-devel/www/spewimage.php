<?php
#
# Copyright (c) 2003-2019 University of Utah and the Flux Group.
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

function SPITERROR($code, $msg)
{
    header("HTTP/1.0 $code $msg");
    exit();
}

#
# Capture script errors and report back to user.
#
$session_interactive  = 0;
$session_errorhandler = 'handle_error';

function handle_error($message, $death)
{
    SPITERROR(400, $message);
}

#
# Must be SSL, even though we do not require an account login.
#
if (!isset($_SERVER["SSL_PROTOCOL"])) {
    SPITERROR(400, "Must use https:// to access this page!");
}

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("image",	PAGEARG_IMAGE,
				 "access_key",	PAGEARG_STRING);
$optargs = OptionalPageArguments("stamp",       PAGEARG_INTEGER,
                                 "delta",       PAGEARG_BOOLEAN,
                                 "sigfile",     PAGEARG_BOOLEAN);

#
# A cleanup function to keep the child from becoming a zombie, since
# the script is terminated, but the children are left to roam.
#
$fp = 0;

function SPEWCLEANUP()
{
    global $fp;

    if (!$fp || !connection_aborted()) {
	exit();
    }
    pclose($fp);
    exit();
}
set_time_limit(0);
register_shutdown_function("SPEWCLEANUP");

#
# Invoke backend script to do it all.
#
$imageid    = $image->imageid();
$versid     = $image->versid();
$access_key = escapeshellarg($access_key);
$arg        = "";
$arg       .= (isset($stamp) ? "-t " . escapeshellarg($stamp) : "");
$arg       .= (isset($sigfile) && $sigfile ? "-s " : "");
$arg       .= (isset($delta) && $delta ? "-e " : "");
$group      = $image->Group();
$pid        = $group->pid();
$unix_gid   = $group->unix_gid();
$project    = $image->Project();
$unix_pid   = $project->unix_gid();
$rangearg   = "";

if ($image->noexport()) {
    SPITERROR(403, "This image is marked as export restricted");
}
if (!$image->isglobal()) {
    SPITERROR(403, "No permission to access image");
}

#
# Check for RANGE header. We support a singlw range, there is no
# reason for the client to ask for multiple ranges for an image.
#
if (isset($_SERVER['HTTP_RANGE'])) {
    // Delimiters are case insensitive
    if (preg_match('/bytes=(\d*)\-$/i', $_SERVER['HTTP_RANGE'], $matches) ||
        preg_match('/bytes=(\d*)\-(\d*)$/i', $_SERVER['HTTP_RANGE'], $matches)){
        $rangearg = "-r " . $matches[1] . "-";
        if (count($matches) == 3) {
            $rangearg .= $matches[2];
        }
    }
    else {
        SPITERROR(416, "Client requested invalid Range.");
    }
}

#
# We want to support HEAD requests to avoid sending the file.
#
$ishead  = 0;
$headarg = "";
if ($_SERVER['REQUEST_METHOD'] == "HEAD") {
    $ishead  = 1;
    $headarg = "-h";
}

if ($fp = popen("$TBSUEXEC_PATH nobody $unix_pid,$unix_gid ".
		"webspewimage $arg $headarg $rangearg -k $access_key $versid",
                "r")) {
    header("Content-Type: application/octet-stream");
    header("Cache-Control: no-cache, must-revalidate");
    header("Pragma: no-cache");

    #
    # If this is a head request, then the output needs to be sent as
    # headers. Then exit.
    #
    if ($ishead) {
	while (!feof($fp) && connection_status() == 0) {
	    $string = fgets($fp);
	    if ($string) {
		$string = rtrim($string);
		header($string);
	    }
	}
    }
    else {
        #
        # The point of this is to allow the backend script to return status
        # that the file has not been modified and does not need to be sent.
        # The first read will come back with no output, which means nothing is
        # going to be sent except the headers.
        #
	$string = fgets($fp);
	if ($string) {
            # We know the first line is a header.
            $string = rtrim($string);
            header($string);

            # Look for end of headers.
            $found_headers = false;

            while (!$found_headers) {
                $string = fgets($fp);
                if ($string == "\n") {
                    $found_headers = true;
                }
                else {
                    $string = rtrim($string);
                    header($string);
                }
            }
            while (!feof($fp) && connection_status() == 0) {
                print(fread($fp, 1024*32));
                flush();
            }
	}
    }
    $retval = pclose($fp);
    $fp = 0;

    if ($retval) {
	if ($retval == 2) {
	    SPITERROR(304, "File has not changed");
	}
	else {
	    SPITERROR(404, "Could not verify file: $retval!");
	}
    }
    flush();
}
else {
    SPITERROR(404, "Could not find $file!");
}

?>
