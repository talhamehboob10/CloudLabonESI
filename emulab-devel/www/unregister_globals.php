<?php
#
# Copyright (c) 2010-2013 University of Utah and the Flux Group.
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
# Emulate register_globals off on the fly.
#
$emulating_on = 0;

function EmulateRegisterGlobals()
{
    global $emulating_on;
    
    if ($emulating_on)
	return;

    $emulating_on++;

    # 
    # Start out slow ...
    #
    $superglobals = array($_GET, $_POST, $_COOKIE);

    //
    // Known PHP Reserved globals and superglobals:
    //    
    $knownglobals = array(
			  '_ENV',       'HTTP_ENV_VARS',
			  '_GET',       'HTTP_GET_VARS',
			  '_POST',	'HTTP_POST_VARS',
			  '_COOKIE',    'HTTP_COOKIE_VARS',
			  '_FILES',     'HTTP_FILES_VARS',
			  '_SERVER',    'HTTP_SERVER_VARS',
			  '_SESSION',   'HTTP_SESSION_VARS',
			  '_REQUEST',	'emulating_on'
			 );

    foreach ($superglobals as $superglobal) {
	foreach ($superglobal as $global => $void) {
	    if (!in_array($global, $knownglobals)) {
		unset($GLOBALS[$global]);
	    }
	}
    }

    error_reporting(E_ALL & ~E_STRICT);
}

EmulateRegisterGlobals();
?>
