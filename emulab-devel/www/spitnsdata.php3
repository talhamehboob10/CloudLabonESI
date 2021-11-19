<?php
#
# Copyright (c) 2000-2010 University of Utah and the Flux Group.
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

#
# Only known and logged in users.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("experiment",   PAGEARG_EXPERIMENT,
				 "template",     PAGEARG_TEMPLATE,
				 "copyid",       PAGEARG_INTEGER,
				 "record",       PAGEARG_INTEGER,
				 "nsref",        PAGEARG_INTEGER,
				 "guid",         PAGEARG_INTEGER,
				 "nsdata",       PAGEARG_ANYTHING);

#
# This comes from the begin_experiment page, when cloning an experiment
# from another experiment.
#
if (isset($copyid) && $copyid != "") {
    if (TBvalid_integer($copyid)) {
	#
	# See if its a current experiment.
	#
	$experiment = Experiment::Lookup($copyid);
	if (!$experiment) {
	    $record = $copyid;
	}
    }
    else {
	PAGEARGERROR("Invalid copyID!");
    }
}

#
# Spit back an NS file to the user. 
#
if (isset($record) && $record != "" && TBvalid_integer($record)) {
    $experiment_resources = ExperimentResources::Lookup($record);
    if (! $experiment_resources) {
	USERERROR("No such experiment resources record $record!", 1);
    }
    if (!$experiment_resources->AccessCheck($this_user, $TB_EXPT_READINFO)) {
	USERERROR("You do not have permission to view the NS file for ".
		  "experiment resource record $record!", 1);
    }
    
    #
    # Grab the NS file.
    #
    if (($nsfile = $experiment_resources->NSFile())) {
	header("Content-Type: text/plain");
	echo "$nsfile\n";
    }
    else {
	USERERROR("There is no NS file recorded for ".
		  "experiment resource record $record!", 1);
    }
    return;
}

#
# A template.
#
if (isset($template)) {
    if (! $template->AccessCheck($this_user, $TB_EXPT_READINFO)) {
	USERERROR("You do not have permission to view template!", 1);
    }
    header("Content-Type: text/plain");

    #
    # Grab all of the input files. Display each one. 
    #
    $input_list = $template->InputFiles();

    for ($i = 0; $i < count($input_list); $i++) {
	echo $input_list[$i];
	echo "\n\n";
    }
    return;
}

#
# if requesting a specific pid,eid must have permission.
#
if (isset($experiment)) {
    #
    # Verify Permission.
    #
    if (!$experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
	USERERROR("You do not have permission to view the NS file for ".
		  "experiment $eid in project $pid!", 1);
    }

    #
    # Grab the NS file from the DB.
    #
    if (($nsfile = $experiment->NSFile())) {
	header("Content-Type: text/plain");
	echo "$nsfile\n";
    }
    else {
	$pid = $experiment->pid();
	$eid = $experiment->eid();
	USERERROR("There is no NS file recorded for ".
		  "experiment $eid in project $pid!", 1);
    }
    return;
}

#
# Otherwise:
#
# See if nsdata was provided. I think nsdata is deprecated now, and
# netbuild uses the nsref variant (LBS).
#
# See if nsref was provided. This is how the current netbuild works, by 
# uploading the nsfile with nssave.php3, to a randomly generated name in 
# /tmp. Spit that file back.
#
if (isset($nsdata) && strcmp($nsdata, "") != 0) {
    header("Content-Type: text/plain");
    echo "$nsdata";
} elseif (isset($nsref) && strcmp($nsref,"") != 0 && 
          preg_match('/^[0-9]+$/', $nsref)) {
    if (isset($guid) && preg_match('/^[0-9]+$/', $guid)) {
	$nsfile = "/tmp/$guid-$nsref.nsfile";    
        $id = $guid;
    } else {
	$nsfile = "/tmp/$uid-$nsref.nsfile";    
        $id = $uid;
    }

    if (! file_exists($nsfile)) {
	PAGEHEADER("View Generated NS File");
	USERERROR("Could not find temporary file for user/guid \"" . $id .
                  "\" with id \"$nsref\".<br>\n" . 
	          "You likely copy-and-pasted an URL incorrectly,<br>\n" .
 		  "or you've already used the file to create an experiment" . 
                  "(thus erasing it),<br>\n" .
		  "or the file has expired.\n", 1 );
	PAGEFOOTER();
    } else {
	$fp = fopen($nsfile, "r");
	header("Content-Type: text/plain");
	$contents = fread ($fp, filesize ($nsfile));
	fclose($fp);
	echo "$contents";
    }
} else {
    USERERROR("No NS file provided!",1);
}

?>






