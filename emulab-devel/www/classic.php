<?php
#
# Copyright (c) 2000-2009 University of Utah and the Flux Group.
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
require("defs.php3");

$optargs = OptionalPageArguments("stayhome", PAGEARG_BOOLEAN);

#
# The point of this is to redirect logged in users to their My Emulab
# page. 
#
if (($this_user = CheckLogin($check_status))) {
    $check_status = $check_status & CHECKLOGIN_STATUSMASK;
    if ($check_status == CHECKLOGIN_MAYBEVALID) {
	# Maybe the reason was because they where not using HTTPS ...
	RedirectHTTPS();
    }
    
    if (($firstinitstate = TBGetFirstInitState())) {
	unset($stayhome);
    }
    if (!isset($stayhome)) {
	if ($check_status == CHECKLOGIN_LOGGEDIN) {
	    if ($firstinitstate == "createproject") {
	        # Zap to NewProject Page,
 	        header("Location: $TBBASE/newproject.php3");
	    }
	    else {
		# Zap to My Emulab page.
		header("Location: $TBBASE/".
		       CreateURL("showuser", $this_user));
	    }
	    return;
	}
    }
    # Fall through; display the page.
}

#
# Standard Testbed Header
#
PAGEHEADER("Emulab - Network Emulation Testbed Home",NULL,$RSS_HEADER_NEWS);

#
# Special banner message.
#
$message = TBGetSiteVar("web/banner");
if ($message != "") {
    echo "<center><font color=Red size=+1>\n";
    echo "$message\n";
    echo "</font></center><br>\n";
}

if ($TBMAINSITE && !$ISALTDOMAIN) {
    echo "<span class='picture'>
            <center><font size=-1>In Memoriam</font></center><a href=jay.php>
            <img width=80 height=85 src=jay.jpg></a><br clear=left>
            <center><font size=-1>Jay Lepreau<br>03/52--09/08
            </font></center></span><br>\n";
}

?>
<p>
    <em>Emulab</em> is a network testbed, giving researchers a wide range of
        environments in which to develop, debug, and evaluate their systems.
    The name Emulab refers both to a <strong>facility</strong> and to a
    <strong>software system</strong>.
    The <a href="http://www.emulab.net">primary Emulab installation</a> is run
        by the
        <a href="http://www.flux.utah.edu">Flux Group</a>, part of the
        <a href="http://www.cs.utah.edu">School of Computing</a> at the
        <a href="http://www.utah.edu">University of Utah</a>.
    There are also installations of the Emulab software at more than
        <a href="http://users.emulab.net/trac/emulab/wiki/OtherEmulabs">two
        dozen sites</a> around the world, ranging from testbeds with a handful
        of nodes up to testbeds with hundreds of nodes.
    Emulab is <a href="http://www.emulab.net/expubs.php">widely used</a>
        by computer science researchers in the fields of networking and
        distributed systems.
    It is also designed to support <a href="http://users.emulab.net/trac/emulab/wiki/Education">education</a>, and has been used to <a href="http://users.emulab.net/trac/emulab/wiki/Classes">teach
        classes</a> in those fields.
</p>

<?php
#
# Allow for a site specific front page 
#
$sitefile = "index-" . strtolower($THISHOMEBASE) . ".html";

if (!file_exists($sitefile)) {
    if ($TBMAINSITE && !$ISALTDOMAIN)
	$sitefile = "index-mainsite.html";
    else
	$sitefile = "index-nonmain.html";
}
readfile("$sitefile");

#
# Standard Testbed Footer
# 
PAGEFOOTER();
?>
