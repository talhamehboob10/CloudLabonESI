<?php
#
# Copyright (c) 2000-2021 University of Utah and the Flux Group.
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
include_once("geni_defs.php");
chdir("apt");
include("quickvm_sup.php");
include_once("instance_defs.php");
$page_title = "Summary Stats";

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("showby",   PAGEARG_STRING,
                                 "min",      PAGEARG_INTEGER,
                                 "max",      PAGEARG_INTEGER);
if (!isset($showby)) {
    $showby = "user";
}

#
# Get current user.
#
RedirectSecure();
$this_user = CheckLoginOrRedirect();

if (! (ISADMIN() || ISFOREIGN_ADMIN())) {
    SPITUSERERROR("You do not have permission to view summary stats");
}
SPITHEADER(1);

echo "<link rel='stylesheet'
            href='css/jQRangeSlider.css'>\n";

function ShowByCreator()
{
    global $urn_mapping, $TBBASE, $min, $max;
    $whereclause = "";

    if (isset($min)) {
        $whereclause = "where UNIX_TIMESTAMP(started) > $min ";
        if (isset($max)) {
            $whereclause .= "and UNIX_TIMESTAMP(started) < $max ";
        }
    }
    
    $query_result =
        DBQueryFatal("(select creator,aggregate_urn,count(creator) as ecount, ".
                     "   sum(physnode_count) as pcount, ".
                     "   truncate(sum(physnode_count * ".
                     "     ((UNIX_TIMESTAMP(destroyed) - ".
                     "       UNIX_TIMESTAMP(started)) / 3600.0)),2) as phours ".
                     " from apt_instance_history ".
                       $whereclause .
                     " group by creator,aggregate_urn) ".
                     "union ".
                     "(select creator,aggregate_urn,count(creator) as ecount,".
                     "   sum(physnode_count) as pcount, ".
                     "   truncate(sum(physnode_count * ".
                     "     ((UNIX_TIMESTAMP(now()) - ".
                     "       UNIX_TIMESTAMP(started)) / 3600.0)),2) as phours ".
                     " from apt_instances ".
                       $whereclause .
                     " group by creator,aggregate_urn)");
    #
    # Aggregate the per aggregate rows into a single row per user.
    #
    $uid_array = array();

    while ($row = mysql_fetch_array($query_result)) {
        $uid    = $row["creator"];
        $urn    = $row["aggregate_urn"];
        $cluster= $urn_mapping[$urn];
        $ecount = $row["ecount"];
        $pcount = $row["pcount"];
        $phours = $row["phours"];
    
        if (!array_key_exists($uid, $uid_array)) {
            $uid_array[$uid] = array("ecount" => 0,
                                     "pcount" => 0,
                                     "phours" => 0,
                                     "Utah"   => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0),
                                     "Wisc"   => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0),
                                     "Clem"   => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0),
                                     "APT"    => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0),
                                     "Emulab" => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0));
        }
        $uid_array[$uid]["ecount"] += $ecount;
        $uid_array[$uid]["pcount"] += $pcount;
        $uid_array[$uid]["phours"] += $phours;
        $uid_array[$uid][$cluster]["ecount"] += $ecount;
        $uid_array[$uid][$cluster]["pcount"] += $pcount;
        $uid_array[$uid][$cluster]["phours"] += $phours;
    }
    echo "<div id='output_dropdown'></div>\n";
    echo "<input class='form-control search' type='search' data-column='0'
             id='search_sumstats' placeholder='Search'>\n";
    echo "  <table class='tablesorter' id='tablesorter_sumstats'>
         <thead>
          <tr>
           <th rowspan=1>UID</th>
           <th colspan=3>Totals</th>
           <th colspan=3>APT</th>
           <th colspan=3>Utah</th>
           <th colspan=3>Wisc</th>
           <th colspan=3>Clem</th>
           <th colspan=3>Emulab</th>
          </tr>
          <tr>
           <th class='filter-false sorter-false'
               style='padding-left:1px; text-align:left'>Total</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>PHours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>PHours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>PHours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>PHours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>PHours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>PHours</th>
          </tr>
          <tr id='header-column-counts'>
           <th class='filter-false sorter-false' data-math='col-count'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
          </tr>
         </thead>\n";
 echo"   <tfoot>
          <tr id='footer-column-counts'>
           <th class='filter-false sorter-false'>Totals</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
          </tr>
         </tfoot>\n";

    foreach ($uid_array as $uid => $ref) {
        $uid = "<a href='activity.php?user=$uid'>$uid</a>";
        
        echo
            "<tr>".
            "<td>$uid</td>".
            "<td>" . $ref["ecount"] . "</td> ".
            "<td>" . $ref["pcount"] . "</td> ".
            "<td>" . $ref["phours"] . "</td> ".
            "<td>" . $ref["APT"]["ecount"] . "</td> ".
            "<td>" . $ref["APT"]["pcount"] . "</td> ".
            "<td>" . $ref["APT"]["phours"] . "</td> ".
            "<td>" . $ref["Utah"]["ecount"] . "</td> ".
            "<td>" . $ref["Utah"]["pcount"] . "</td> ".
            "<td>" . $ref["Utah"]["phours"] . "</td> ".
            "<td>" . $ref["Wisc"]["ecount"] . "</td> ".
            "<td>" . $ref["Wisc"]["pcount"] . "</td> ".
            "<td>" . $ref["Wisc"]["phours"] . "</td> ".
            "<td>" . $ref["Clem"]["ecount"] . "</td> ".
            "<td>" . $ref["Clem"]["pcount"] . "</td> ".
            "<td>" . $ref["Clem"]["phours"] . "</td> ".
            "<td>" . $ref["Emulab"]["ecount"] . "</td> ".
            "<td>" . $ref["Emulab"]["pcount"] . "</td> ".
            "<td>" . $ref["Emulab"]["phours"] . "</td> ".
            "</tr>\n";
    }
    echo "</table>";
}

function ShowByProject()
{
    global $urn_mapping, $TBBASE, $min, $max;
    $whereclause = "";

    if (isset($min)) {
        $whereclause = "where UNIX_TIMESTAMP(started) > $min ";
        if (isset($max)) {        
            $whereclause .= " and UNIX_TIMESTAMP(started) < $max ";
        }
    }
    
    $query_result =
        DBQueryFatal("(select pid,aggregate_urn,count(pid) as ecount, ".
                     "   sum(physnode_count) as pcount, ".
                     "   truncate(sum(physnode_count * ".
                     "     ((UNIX_TIMESTAMP(destroyed) - ".
                     "       UNIX_TIMESTAMP(started)) / 3600.0)),2) as phours ".
                     " from apt_instance_history ".
                       $whereclause .
                     " group by pid,aggregate_urn) ".
                     "union ".
                     "(select pid,aggregate_urn,count(pid) as ecount, ".
                     "   sum(physnode_count) as pcount, ".
                     "   truncate(sum(physnode_count * ".
                     "     ((UNIX_TIMESTAMP(now()) - ".
                     "       UNIX_TIMESTAMP(started)) / 3600.0)),2) as phours ".
                     " from apt_instances ".
                       $whereclause .
                     " group by pid,aggregate_urn)");
    #
    # Aggregate the per aggregate rows into a single row per user.
    #
    $pid_array = array();

    while ($row = mysql_fetch_array($query_result)) {
        $pid    = $row["pid"];
        $urn    = $row["aggregate_urn"];
        $cluster= $urn_mapping[$urn];
        $ecount = $row["ecount"];
        $pcount = $row["pcount"];
        $phours = $row["phours"];

        if (!$pid) {
            $pid = "NONE";
        }
    
        if (!array_key_exists($pid, $pid_array)) {
            $pid_array[$pid] = array("ecount" => 0,
                                     "pcount" => 0,
                                     "phours" => 0,
                                     "Utah"   => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0),
                                     "Wisc"   => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0),
                                     "Clem"   => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0),
                                     "APT"    => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0),
                                     "Emulab" => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0),
                                     "Mass"   => array("ecount" => 0,
                                                       "pcount" => 0,
                                                       "phours" => 0));
        }
        $pid_array[$pid]["ecount"] += $ecount;
        $pid_array[$pid]["pcount"] += $pcount;
        $pid_array[$pid]["phours"] += $phours;
        $pid_array[$pid][$cluster]["ecount"] += $ecount;
        $pid_array[$pid][$cluster]["pcount"] += $pcount;
        $pid_array[$pid][$cluster]["phours"] += $phours;
    }
    echo "<div id='output_dropdown'></div>\n";
    echo "<input class='form-control search' type='search' data-column='0'
             id='search_sumstats' placeholder='Search'>\n";
    echo "  <table class='tablesorter' id='tablesorter_sumstats'>
         <thead>
          <tr>
           <th rowspan=1>PID</th>
           <th colspan=3>Totals</th>
           <th colspan=3>APT</th>
           <th colspan=3>Utah</th>
           <th colspan=3>Wisc</th>
           <th colspan=3>Clem</th>
           <th colspan=3>Emulab</th>
           <th colspan=3>Mass</th>
          </tr>
          <tr>
           <th class='filter-false sorter-false'
               style='padding-left:1px; text-align:left'>Total</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>Phours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>Phours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>Phours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>Phours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>Phours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>Phours</th>
           <th>Expt</th>
           <th>PCs</th>
           <th>Phours</th>
          </tr>
          <tr id='header-column-counts'>
           <th class='filter-false sorter-false' data-math='col-count'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
          </tr>
         </thead>\n";
 echo"   <tfoot>
          <tr id='footer-column-counts'>
           <th class='filter-false sorter-false'>Totals</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' data-math='col-sum'>0</th>
           <th class='filter-false sorter-false' 
                  data-math='col-sum' data-math-mask='##0.00'>0</th>
          </tr>
         </tfoot>\n";

    foreach ($pid_array as $pid => $ref) {
        if ($pid != "NONE") {
            $pid = "<a href='activity.php?pid=$pid'>$pid</a>";
        }
        echo
            "<tr>".
            "<td>$pid</td>".
            "<td>" . $ref["ecount"] . "</td> ".
            "<td>" . $ref["pcount"] . "</td> ".
            "<td>" . $ref["phours"] . "</td> ".
            "<td>" . $ref["APT"]["ecount"] . "</td> ".
            "<td>" . $ref["APT"]["pcount"] . "</td> ".
            "<td>" . $ref["APT"]["phours"] . "</td> ".
            "<td>" . $ref["Utah"]["ecount"] . "</td> ".
            "<td>" . $ref["Utah"]["pcount"] . "</td> ".
            "<td>" . $ref["Utah"]["phours"] . "</td> ".
            "<td>" . $ref["Wisc"]["ecount"] . "</td> ".
            "<td>" . $ref["Wisc"]["pcount"] . "</td> ".
            "<td>" . $ref["Wisc"]["phours"] . "</td> ".
            "<td>" . $ref["Clem"]["ecount"] . "</td> ".
            "<td>" . $ref["Clem"]["pcount"] . "</td> ".
            "<td>" . $ref["Clem"]["phours"] . "</td> ".
            "<td>" . $ref["Emulab"]["ecount"] . "</td> ".
            "<td>" . $ref["Emulab"]["pcount"] . "</td> ".
            "<td>" . $ref["Emulab"]["phours"] . "</td> ".
            "<td>" . $ref["Mass"]["ecount"] . "</td> ".
            "<td>" . $ref["Mass"]["pcount"] . "</td> ".
            "<td>" . $ref["Mass"]["phours"] . "</td> ".
            "</tr>\n";
    }
    echo "</table>";
}
$minmax = "";
if (isset($min)) {
    $minmax .= "&min=$min";
    if (isset($max)) {
        $minmax .= "&max=$max";
    }
}
if ($showby == "user") {
    echo "<a href='sumstats.php?showby=project$minmax'>".
        "Show project stats</a>,";
}
else {
    echo "<a href='sumstats.php?showby=user$minmax'>".
        "Show user stats</a>,"; 
}
echo "<a href='summary-graphs.php'> Summary Graphs</a><br>\n";

echo "<div class='row'>
        <div class='col-xs-10 col-xs-offset-1'>\n";
echo "    <div id='date-slider'></div>\n";
echo "  </div>\n";
echo "<button type='button' id='slider-go-button'
         class='btn btn-primary btn-xs'
         style='margin-left: 20px; margin-top: 40px;'>Go</button>\n";   
echo "</div><br>\n";
echo "<div class='row'>
        <div class='col-xs-12 col-xs-offset-0'>\n";
if ($showby == "user") {
    ShowByCreator();
}
else {
    ShowByProject();
}
echo " </div>
      </div>\n";

echo "<script type='text/javascript'>\n";
if (isset($min)) {
    echo "    window.MIN  = $min;\n";
}
else {
    echo "    window.MIN  = null;\n";
}
if (isset($max)) {
    echo "    window.MAX  = $max;\n";
}
else {
    echo "    window.MAX  = null;\n";
}
echo "</script>\n";
echo "<script src='js/lib/jquery-ui.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSliderMouseTouch.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSliderDraggable.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSliderHandle.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSliderBar.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSliderLabel.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRangeSlider.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQDateRangeSliderHandle.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQDateRangeSlider.js'></script>\n";
echo "<script src='js/lib/jQRangeSlider/jQRuler.js'></script>\n";

REQUIRE_SUP();
REQUIRE_MOMENT();
REQUIRE_TABLESORTER(array('js/lib/tablesorter/widgets/widget-output.js'));
SPITREQUIRE("js/sumstats.js");

AddTemplate("output-dropdown");
SPITFOOTER();
?>
