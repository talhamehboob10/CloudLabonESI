<?php
#
# Copyright (c) 2000-2013 University of Utah and the Flux Group.
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

#
# Define a stripped-down view of the web interface - less clutter
#
$view = array(
    'hide_banner' => 1,
    'hide_sidebar' => 1,
    'hide_copyright' => 1
);

#
# Only known and logged in users can do this.
#
$this_user = CheckLoginOrDie();
$uid       = $this_user->uid();
$isadmin   = ISADMIN();

#
# Verify page arguments.
#
$optargs = OptionalPageArguments("experiment", PAGEARG_EXPERIMENT,
				 "fallback",   PAGEARG_BOOLEAN);


PAGEHEADER("Experiment Creation GUI", $view);
?>

<h3>Note: See the Help menu for quickstart and tips</h3>

<div id="clientblock" name="clientblock"></div>

<script language='JavaScript'>

<?php

if (isset($experiment)) {
  $pid = $experiment->pid();
  $eid = $experiment->eid();
  
  echo "var pid = '$pid';\n";
  echo "var eid = '$eid';\n";
}
else {
  unset($pid);
  unset($eid);
  echo "var pid = '';\n";
  echo "var eid = '';\n";
}

?>

/* @return The innerHeight of the window. */
function ml_getInnerHeight() {
    var retval;

    if (self.innerHeight) {
	// all except Explorer
	retval = self.innerHeight;
    }
    else if (document.documentElement && document.documentElement.clientHeight) {
	// Explorer 6 Strict Mode
	retval = document.documentElement.clientHeight;
    }
    else if (document.body) {
	// other Explorers
	retval = document.body.clientHeight;
    }

    return retval;
}

function resize() {
    var w_newWidth,w_newHeight;
    var w_maxWidth=1600, w_maxHeight=1200;

    if (navigator.appName.indexOf('Microsoft') != -1) {
        w_newWidth=document.body.clientWidth;
        w_newHeight=document.body.clientHeight;
    } else {
        var netscapeScrollWidth=15;

        w_newWidth=window.innerWidth-netscapeScrollWidth;
        w_newHeight=window.innerHeight-netscapeScrollWidth;
    }

    if (w_newWidth>w_maxWidth)
        w_newWidth=w_maxWidth;
    if (w_newHeight>w_maxHeight)
        w_newHeight=w_maxHeight;

    w_newWidth -= 75;
    w_newHeight -= 140;
    document.client.setOuterSize(w_newWidth, w_newHeight);
    document.client.width = w_newWidth;
    document.client.height = w_newHeight;

    window.scroll(0,0);
}

    var w_newWidth,w_newHeight;
    var w_maxWidth=1600, w_maxHeight=1200;

    if (navigator.appName.indexOf('Microsoft') != -1) {
        w_newWidth=document.body.clientWidth;
    } else {
        var netscapeScrollWidth=15;

        w_newWidth=window.innerWidth-netscapeScrollWidth;
    }

    w_newHeight = ml_getInnerHeight();
    if (w_newWidth>w_maxWidth)
        w_newWidth=w_maxWidth;
    if (w_newHeight>w_maxHeight)
        w_newHeight=w_maxHeight;

    w_newWidth -= 75;
    w_newHeight -= 140;

    if (w_newHeight<650)
        w_newHeight = 650;

app = document.createElement("applet");
app.setAttribute("width", w_newWidth);
app.setAttribute("height", w_newHeight);
app.setAttribute("archive", "netlab-client.jar");
app.setAttribute("code", "thinlet.AppletLauncher.class");
app.setAttribute("MAYSCRIPT", "MAYSCRIPT");

param = document.createElement("param");
param.setAttribute("name", "class");
param.setAttribute("value", "net.emulab.netlab.client.NetlabClient");
app.appendChild(param);

param = document.createElement("param");
param.setAttribute("name", "uid");
param.setAttribute("value", "<?php echo $uid?>");
app.appendChild(param);

param = document.createElement("param");
param.setAttribute("name", "auth");
param.setAttribute("value", "<?php echo $_COOKIE[$TBAUTHCOOKIE]?>");
app.appendChild(param);

if (pid != "" && eid != "") {
  param = document.createElement("param");
  param.setAttribute("name", "pid");
  param.setAttribute("value", pid);
  app.appendChild(param);

  param = document.createElement("param");
  param.setAttribute("name", "eid");
  param.setAttribute("value", eid);
  app.appendChild(param);
}

cb = document.getElementById("clientblock");
cb.appendChild(app);

window.onResize = resize;
window.onLoad = resize;
</script>

<?php if (isset($fallback)): ?>
<applet code='thinlet.AppletLauncher.class'
            archive='netlab-client.jar'
            width='800' height='600'
            alt='You need java to run this applet'>
    <param name="class" value="net.emulab.netlab.client.NetlabClient">
    <param name="uid" value="<?php echo $uid?>">
    <param name="auth" value="<?php echo $_COOKIE[$TBAUTHCOOKIE]?>">
    <?php if (isset($pid)): ?>
    <param name='pid' value='{$pid}'>
    <?php endif; ?>
    <?php if (isset($eid)): ?>
    <param name='eid' value='{$eid}'>
    <?php endif; ?>
</applet>
<?php endif; ?>

</body>
</html>
<?php
#
# Standard Testbed Footer
# 
PAGEFOOTER($view);
?>
