<?php
#
# Copyright (c) 2000-2019 University of Utah and the Flux Group.
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
include_once("defs.php3");
chdir("apt");
include("quickvm_sup.php");

RedirectSecure();

#
# Verify page arguments.
#
$reqargs = RequiredPageArguments("logfile",  PAGEARG_LOGFILE);

if (! isset($logfile)) {
    PAGEARGERROR("Must provide a logfile ID");
}

# Check permission in the backend.
$logfileid = $logfile->logid();

header("Content-type: text/html; charset=utf-8");
header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT");
header("Cache-Control: no-cache, must-revalidate");
header("Pragma: no-cache");
header("Access-Control-Allow-Origin: *");

echo "<html>\n";
echo "<script type='text/javascript'>\n";
echo "    window.LOGFILEID = '$logfileid';\n";
echo "    window.SPEWURL   = '$TBBASE/spewlogfile.php3?logfile=$logfileid';\n";
echo "</script>\n";

echo "<script src='js/lib/jquery.min.js'></script>\n";
REQUIRE_UNDERSCORE();
AddLibrary("js/quickvm_sup.js");
SPITREQUIRE("js/spewlogfile.js");

echo "<body><pre></pre></body></html>\n";

?>
