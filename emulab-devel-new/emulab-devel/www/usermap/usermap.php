<?php
#
# Copyright (c) 2009-2019 University of Utah and the Flux Group.
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

include_once("../defs.php3");

#
# Select one of these types for the page
#
$USERMAP_TYPE_NORMAL = 0;
$USERMAP_TYPE_EMBED = 1;
$USERMAP_TYPE_FULLSCREEN = 2;

$USERMAP_JSONFILE = "all-emulab-cities.json";

$USERMAP_LOC = "${TBBASE}/usermap";

#
# The headers to load the javascript files
#
$USERMAP_SCRIPTHEADERS = <<<EOH
<script src="https://maps.google.com/maps?file=api&v=2&sensor=false&key=$GMAP_API_KEY"
              type="text/javascript">
</script>

<script src="${USERMAP_LOC}/markerclusterer.js" type="text/javascript">
</script>

<script src="${USERMAP_LOC}/$USERMAP_JSONFILE" type="text/javascript">
</script>

<script src="${USERMAP_LOC}/usermap.js" type="text/javascript">
</script>

<script type="text/javascript" language="javascript">
addLoadFunction(usermap_initialize);
addUnloadFunction(GUnload);
</script>
EOH;

function usermap_setup() {
    global $GMAP_API_KEY, $USERMAP_JSONFILE;
    return (($GMAP_API_KEY != "") && file_exists($USERMAP_JSONFILE));
}

function draw_usermap($type) {
    global $GMAP_API_KEY, $USERMAP_JSONFILE, $USERMAP_TYPE_FULLSCREEN,
        $USERMAP_TYPE_EMBED, $USERMAP_TYPE_NORMAL, $USERMAP_LOC, $THISHOMEBASE,
        $USERMAP_SCRIPTHEADERS, $TBBASE;
    if ($GMAP_API_KEY == "") {
        if ($type == $USERMAP_TYPE_EMBED) {
            echo("<p><b>Google Map API key not set</b></p>");
        } else {
            PAGEERROR("Google Map API key not set");
        }
    }

    if (!file_exists($USERMAP_JSONFILE)) {
        if ($type == $USERMAP_TYPE_EMBED) {
            echo("<p><b>JSON data source not created</b></p>");
        } else {
            PAGEERROR("JSON data source not created");
        }
    }

    #
    # If in fullscreen mode, we don't emit the standard header, just emit the
    # HTML ourselves
    #
    if ($type == $USERMAP_TYPE_FULLSCREEN) {
        $divstyle = "width: 100%; height: 100%; margin: 0px; padding: 0px;";
    ?>

    <!DOCTYPE html "-//W3C//DTD XHTML 1.0 Strict//EN" 
      "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <meta http-equiv="content-type" content="text/html; charset=utf-8"/>
        <title><? echo $THISHOMEBASE ?> User Map</title>
        <script src="<? echo $TBBASE ?>/onload.js" type="text/javascript">
        </script>
        <? echo $USERMAP_SCRIPTHEADERS ?>
    </head>
    <body style="margin: 0px; padding: 0px;">
    <?php

    } else {
        $divstyle = "width: 850px; height: 400px; margin-right: auto; margin-left: auto";
        if ($type != $USERMAP_TYPE_EMBED) {
            PAGEHEADER("User Map",NULL,$USERMAP_SCRIPTHEADERS);
            echo("<p>This map shows the cities with registered users of this ");
            echo("testbed. Numbers on the markers give the numbers of users ");
            echo("in a region. You can zoom in to see more detail, and ");
            echo("clicking on a maker will bring up a list of the cities it ");
            echo("represents.</p>");
        }
    }

    #
    # The meat - where the map will get displayed
    #
    echo "<div id=\"map_canvas\" style=\"$divstyle\"></div>\n";

    if (isset($fullscreen)) {
        echo "</body></html>";
    } else {
        echo "<a href=\"${USERMAP_LOC}/?fullscreen=true\">larger version</a>";
        if ($type != $USERMAP_TYPE_EMBED) {
            PAGEFOOTER();
        }
    }
}
?>
