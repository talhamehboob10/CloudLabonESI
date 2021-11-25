<?php
#
# Copyright (c) 2005-2014 University of Utah and the Flux Group.
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
require_once("Sajax.php");
sajax_init();
sajax_export("GetPNodes", "GetExpState");

# If this call is to client request function, then turn off interactive mode.
# All errors will go to above function and get reported back through the
# Sajax interface.
if (sajax_client_request()) {
    $session_interactive = 0;
}

#
# This will return the experiment object to the caller.
#
function CHECKPAGEARGS($pid, $eid) {
    global $this_user, $TB_EXPT_READINFO;

    #
    # Verify page arguments.
    # 
    if (!isset($pid) ||
	strcmp($pid, "") == 0) {
	USERERROR("You must provide a Project ID.", 1);
    }
    if (!isset($eid) ||
	strcmp($eid, "") == 0) {
	USERERROR("You must provide an Experiment ID.", 1);
    }
    if (!TBvalid_pid($pid)) {
	PAGEARGERROR("Invalid project ID.");
    }
    if (!TBvalid_eid($eid)) {
	PAGEARGERROR("Invalid experiment ID.");
    }

    #
    # If $this_user is not set, someone got confused. 
    #
    if (!isset($this_user)) {
	TBERROR("Current user is not defined in CHECKPAGEARGS()", 1);
    }

    #
    # Check to make sure this is a valid PID/EID tuple.
    #
    $experiment = Experiment::LookupByPidEid($pid, $eid);
    if (! $experiment) {
	USERERROR("The experiment $pid/$eid is not a valid experiment!", 1);
    }
    
    #
    # Verify permission.
    #
    if (! $experiment->AccessCheck($this_user, $TB_EXPT_READINFO)) {
	USERERROR("You do not have permission to view the log for $pid/$eid!", 1);
    }
    return $experiment;
}

function GetPNodes($pid, $eid) {
    CHECKPAGEARGS($pid, $eid);

    $retval = array();

    $query_result = DBQueryFatal(
	"select r.node_id from reserved as r ".
	"where r.eid='$eid' and r.pid='$pid' order by LENGTH(node_id) desc");

    while ($row = mysql_fetch_array($query_result)) {
      $retval[] = $row[node_id];
    }

    return $retval;
}

function GetExpState($pid, $eid)
{
    $experiment = CHECKPAGEARGS($pid, $eid);
    $expstate   = $experiment->state();

    return $expstate;
}

function STARTWATCHER($experiment)
{
    echo "<script type='text/javascript' language='javascript'
                  src='showexp.js'></script>\n";

    $pid   = $experiment->pid();
    $eid   = $experiment->eid();
    $state = $experiment->state();
    
    echo "<script type='text/javascript' language='javascript'>\n";
    sajax_show_javascript();
    echo "StartStateChangeWatch('$pid', '$eid', '$state');\n";
    echo "</script>\n";
}

function STARTLOG($object)
{
    if (is_a($object, 'Experiment')) {
	STARTWATCHER($object);
    }
    if (!is_a($object, 'Logfile')) {
	$object = $object->GetLogfile();
    }
    $url = CreateURL("spewlogfile", $object);

    #
    # If the logfile is open, put up the spinner.
    #
    if ($object->isopen()) {
	echo "<center>\n";
	echo "<img id='load_busy' src='busy.gif'>
                   <span id='load_loading'> Working ...</span>";
	echo "</center>\n";
	echo "<br>\n";

        echo "<script>
              function loadFinished() {
                  var busyimg     = getObjbyName('load_busy');
                  var loadingspan = getObjbyName('load_loading');

                  busyimg.style.display = 'none';
                  busyimg.src           = '1px.gif';
                  loadingspan.innerHTML = '<center><b>Done!</b></center>';
              }
              </script>\n";
    }
    echo "<iframe id='downloader' name='downloader'
                 class='downloader' src='$url'>
         </iframe></div>\n";
    echo "<script type='text/javascript' language='javascript'>\n";
    echo "  ShowDownLoader('downloader');\n";
    echo "</script>";
}

# See if this request is to one of the above functions. Does not return
# if it is. Otherwise return and continue on.
sajax_handle_client_request();

#
# We return to the including script ...
#

