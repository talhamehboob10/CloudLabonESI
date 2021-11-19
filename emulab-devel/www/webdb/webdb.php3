<?php
#
# Copyright (c) 2000-2002, 2006 University of Utah and the Flux Group.
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

chdir("..");
require("defs.php3");

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();
$dbedit    = $this_user->dbedit();

if (! $dbedit) {
    USERERROR("You do not have permission to use WEBDB!", 1);
}

header("Pragma: no-cache");
echo "<html>
      <head>\n";

chdir("webdb");

include "webdb_backend.php3";

webdb_backend_main();

?>    
    <title>WebDb - <?php echo $title_header ?></title>

    <style type="text/css"><!--
      p.location {
	color: #11bb33;
	font-size: small;
      }
      body {
	background-color: #EEFFEE;
      }
      h1 {
	color: #004400;
      }
      th {
	background-color: #AABBAA;
	color: #000000;
	font-size: x-small;
      }
      td {
	background-color: #D4E5D4;
	font-size: x-small;
      }
      form {
	margin-top: 0;
	margin-bottom: 0;
      }
      a {
	text-decoration:none;
	color: #248200;
      }
      a:link {}
      a:hover {
	ba2ckground-color:#EEEFD5;
	color:#54A232;
	text-decoration:underline;               
      }
      //-->
 </style>


  </head>
  <body>
    <h1><?php echo $body_header ?></h1> 
    <?php echo $body?>
    <hr><p>based on mysql.php3 by SooMin Kim.</p>
  </body>
</html>










