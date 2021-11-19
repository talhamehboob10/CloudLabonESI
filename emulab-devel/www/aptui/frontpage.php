<?php
#
# Copyright (c) 2016-2018 University of Utah and the Flux Group.
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
include("defs.php3");
chdir("apt");
include("quickvm_sup.php");
# Must be after quickvm_sup.php since it changes the auth domain.
$page_title = "Emulab";

#
# Get current user.
#
RedirectSecure();
$check_status = 0;
$this_user    = CheckLogin($check_status);

SPITHEADER(1, true, true);
SPITREQUIRE("");

#
# Allow for a site specific front page
#
$sitefile = "frontpage-" . strtolower($THISHOMEBASE) . ".html";

# allow local frontpage customizations
if (file_exists($sitefile)) {
    $matter    = file_get_contents($sitefile);
} else {
    $matter    = file_get_contents("frontpage.html");
}
$stats     = json_decode(file_get_contents("$APTBASE/stats-ajax.php"), true);
$whoarewe  = ($TBMAINSITE ? "" : $THISHOMEBASE);
$counts    = "<tr><th>Type</th><th>Free</th><th>% Inuse</th></tr>";

foreach ($stats["typeinfo"] as $type => $totals) {
    $total   = $totals["total"];
    $free    = $totals["free"];
    $pctfull = round(100.0 * ($total - $free) / $total);
    if ($TBMAINSITE) {
        $type = "<a href='https://gitlab.flux.utah.edu/emulab/emulab-devel/wikis/Utah%20Cluster#${type}s' target=_blank>$type</a>";
    }
    $counts .=
            "<tr>
              <td>$type</td>
              <td><small> 
	        <span class='badge badge-light'>$free</span></small></td>
	          <td style='width: 8em'>
	            <div class='progress' style='margin-bottom: 0px'>
	              <div class='progress-bar' style='width: ${pctfull}%;'
                           role='progressbar'>${pctfull}% inuse</div>
    	            </div>
	          </td>
             </tr>\n";
}

$vars = array(
    '{$active}'       => $stats["active_experiments"],
    '{$projects}'     => $stats["projects"],
    '{$users}'        => $stats["distinct_users"],
    '{$profiles}'     => $stats["profiles"],
    '{$experiments}'  => $stats["total_experiments"],
    '{$nodecounts}'   => $counts,
    '{$whoarewe}'     => $whoarewe,
);
echo strtr($matter, $vars);

SPITFOOTER(1);

?>
