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
include("defs.php3");
include_once("node_defs.php");
include("xmlrpc.php3");

#
# This script generates an "acl" file.
#
#
# Verify form arguments first, since we might be using optional key.
#
$reqargs = RequiredPageArguments("node",       PAGEARG_NODE);
$optargs = OptionalPageArguments("key",        PAGEARG_STRING,
				 "closekills", PAGEARG_BOOLEAN,
				 "noclose",    PAGEARG_BOOLEAN);

# Need these below
$node_id = $node->node_id();

if (isset($key)) {
    $safe_key = addslashes($key);
    
    $query_result =
	DBQueryFatal("select urlstamp,reuseurl from tiplines ".
		     "where node_id='$node_id' and urlhash='$safe_key' and ".
		     "      urlstamp!=0");
    
    if (mysql_num_rows($query_result) == 0) {
	USERERROR("Invalid node or invalid key", 1);
    } else {
	$row = mysql_fetch_array($query_result);
	$stamp = $row['urlstamp'];
	if ($stamp <= time()) {
	    DBQueryFatal("update tiplines set urlhash=NULL,urlstamp=0,".
			 "reuseurl=0 ".
	    		 "where node_id='$node_id'");
	    USERERROR("Key is no longer valid", 1);
	}
    }
    # URLs are use-once, unless marked as reusable (dangerous).
    $reuse = $row['reuseurl'];
    if ($reuse != 1) {
        DBQueryFatal("update tiplines set urlhash=NULL,urlstamp=0,".
                     "reuseurl=0 ".
                     "where node_id='$node_id'");
    }
    $uid = "nobody";
    $isadmin = 0;
}
else {
    #
    # Only known and logged in users can get acls..
    #
    $this_user = CheckLoginOrDie();
    $uid       = $this_user->uid();
    $isadmin   = ISADMIN();
}

#
# Admin users can look at any node, but normal users can only control
# nodes in their own experiments.
#
# Do not allow console access for certain node taint states.
#
# XXX is MODIFYINFO the correct one to check? (probably)
#
if (!$isadmin && !isset($key)) {
    if (!$node->AccessCheck($this_user, $TB_NODEACCESS_READINFO)) {
        USERERROR("You do not have permission to tip to node $node_id!", 1);
    }
    if ($node->IsTainted("useronly") || $node->IsTainted("blackbox")) {
        USERERROR("Node $node_id is in a restricted state - console access denied.", 1);
    }
}

# Array of arguments
$console = array();

#
# Ask outer emulab for the stuff we need. It does it own perm checks
#
if ($ELABINELAB) {
    $arghash = array();
    $arghash["node"] = $node_id;

    $results = XMLRPC($uid, "nobody", "elabinelab.console", $arghash);

    if (!$results ||
	! (isset($results{'server'})  && isset($results{'portnum'}) &&
	   isset($results{'keydata'}) && isset($results{'certsha'}))) {
	TBERROR("Did not get everything we needed from RPC call", 1);
    }

    $server  = $results['server'];
    $portnum = $results['portnum'];
    $keydata = $results['keydata'];
    $keylen  = strlen($keydata);
    $certhash= strtolower($results{'certsha'});
}
else {

    $query_result =
	DBQueryFatal("SELECT server, portnum, keylen, keydata, disabled " . 
		     "FROM tiplines WHERE node_id='$node_id'" );

    if (mysql_num_rows($query_result) == 0) {
	USERERROR("The node $node_id does not exist, ".
		  "or does not have a tipline!", 1);
    }
    $row = mysql_fetch_array($query_result);
    $server  = $row["server"];
    $portnum = $row["portnum"];
    $keylen  = $row["keylen"];
    $keydata = $row["keydata"];
    $disabled= $row["disabled"];

    if ($disabled) {
	USERERROR("The tipline for $node_id is currently disabled", 1);
    }

    #
    # Read in the fingerprint of the capture certificate
    #
    $capfile = "$TBETC_DIR/capture.fingerprint";
    $lines = file($capfile);
    if (!$lines) {
	TBERROR("Unable to open $capfile!",1);
    }

    $fingerline = rtrim($lines[0]);
    if (!preg_match("/Fingerprint=([\w:]+)$/",$fingerline,$matches)) {
	TBERROR("Unable to find fingerprint in string $fingerline!",1);
    }
    $certhash = str_replace(":","",strtolower($matches[1]));
}

if (! $BROWSER_CONSOLE_ENABLE) {
    $filename = $node_id . ".tbacl"; 

    header("Content-Type: text/x-testbed-acl");
    header("Content-Disposition: inline; filename=$filename;");
    header("Content-Description: ACL key file for a testbed node serial port");

    # XXX, should handle multiple tip lines gracefully somehow, 
    # but not important for now.

    echo "host:   $server\n";	
    echo "port:   $portnum\n";
    echo "keylen: $keylen\n";
    echo "key:    $keydata\n";
    echo "ssl-server-cert: $certhash\n";
    return;
}

#
# ShellInABox
#
$console["server"]   = $server;
$console["portnum"]  = $portnum;
$console["keylen"]   = $keylen;
$console["keydata"]  = $keydata;
$console["certhash"] = $certhash;

$console_auth = $node->ConsoleAuthObject($uid, $console);

if (!isset($key)) {
    PAGEHEADER("$node_id Console");
}
if (!isset($closekills)) {
    $closekills = 0;
}
if (!isset($noclose)) {
    $noclose = 0;
}

echo "\n";
echo "<script src='$TBBASE/emulab_sup.js'></script>\n";
echo "<script src='https://code.jquery.com/jquery.js'></script>\n";
echo "<script>\n";
echo "var tbbaseurl  = '$TBBASE';\n";
echo "var closekills = $closekills;\n";
echo "var noclose    = $noclose;\n";
echo "var proxied    = $BROWSER_CONSOLE_PROXIED;\n";
echo "var webssh     = $BROWSER_CONSOLE_WEBSSH;\n";
?>
function StartConsole(id, authobject)
{
    var jsonauth = $.parseJSON(authobject);
	
    if (webssh) {
        var url     = jsonauth.baseurl;
	var iwidth  = "100%";
        var iheight = 400;

	var loadiframe = function () {
	    console.info("Sending message", jsonauth.baseurl);
	    iframewindow.postMessage(authobject, "*");
	    window.removeEventListener("message", loadiframe, false);
	};
	window.addEventListener("message", loadiframe);

        var iwidth  = $('#' + id).width();
	var iheight = $(window).height();
	var Iframe  = getObjbyName(id);
	// Now get the Y offset of the outputframe.
	var yoff    = Iframe.offsetTop;

	if (iheight != 0 && yoff != 0) {
	    iheight = iheight - yoff;
	}
	else {
	    iheight = 200;
	}
        iheight = iheight - 25;

        $('#' + id).html('<iframe id="' + id + '_iframe" ' +
                         'width=' + iwidth + ' ' +
                         'height=' + iheight + ' ' +
                         'src=\'' + url + '\'>');

	var iframe = $('#' + id + '_iframe')[0];
	var iframewindow = (iframe.contentWindow ?
			    iframe.contentWindow :
			    iframe.contentDocument.defaultView);

        return;
    }

    var callback = function(stuff) {
        var split   = stuff.split(':');
        var session = split[0];
    	var port    = split[1];
        var url     = jsonauth.baseurl;

        if (proxied) {
            // mod_proxy/mod_rewrite rule
            url = url + '/shellinabox/' + port;
        }
        else {
            url = url + ':' + port;
        }
        url = url + '/' + '#' +
            encodeURIComponent(document.location.href) + ',' + session;
        console.log(url);
        var iwidth  = $('#' + id).width();
	var iheight = $(window).height();
	var Iframe  = getObjbyName(id);
	// Now get the Y offset of the outputframe.
	var yoff    = Iframe.offsetTop;

	if (iheight != 0 && yoff != 0) {
	    iheight = iheight - yoff;
	}
	else {
	    iheight = 200;
	}
        iheight = iheight - 25;

	/*
	 * Oh, this is a pain.
	 *
	 * Firefox views the same server certificate on different
	 * ports, as needing to be confirmed. Since the server side of
	 * the console picks a new port each time, firefox wants to
	 * confirm the security exception each time.
	 *
	 * Firefox will not allow you to confirm aforementioned
	 * security exception when it is inside an iframe. It just
	 * tells you it is insecure, and thats it. The only way around
	 * it is to right-click and say open in new tab, and then you
	 * get the option to confirm.
	 *
	 * So put the damn in the current tab and be done with it. DUMB!
	 */
	if (is_firefox) {
	    PageReplace(url);
	}
	else {
	    $('#' + id).html('<iframe id="' + id + '_iframe" ' +
			     'width=' + iwidth + ' ' +
			     'height=' + iheight + ' ' +
			     'src=\'' + url + '\'>');

	    //
	    // Setup a custom event handler so we can kill the connection.
	    //
	    $('#' + id).on("killconsole",
		{ "url": jsonauth.baseurl + ':' + port + '/quit' +
			'?session=' + session },
		function(e) {
		    console.log("killconsole: " + e.data.url);
		    $.ajax({
			url: e.data.url,
				type: 'GET',
		    });
		});

	    addEventListener("message",
			     function(event) {
				 console.info(event);
				 // Trigger the custom event.
				 $("#" + id).trigger("killconsole");
			     },
			     false);

	    if (!noclose) {
		// Install a click handler for the X button.
		$("#" + id + "_kill").click(function(e) {
			e.preventDefault();
			// Trigger the custom event.
			$("#" + id).trigger("killconsole");
                    
			if (closekills) {
			    window.close();
			}
			else {
			    PageReplace(tbbaseurl);
			}
		    });
	    }
	}
    }
    var callback_failed = function(jqXHR, textStatus) {
	var acceptURL = jsonauth.baseurl + '/accept_cert.html';
	
	console.log("Request failed: " + textStatus);
	
	$('#' + id).html("An SSL certificate must be accepted by your " +
			 "browser to continue.  Please click " +
			 "<a href='" + acceptURL + "'>here</a> " +
			 "to be redirected.");
    }

    var xmlthing = $.ajax({
	// the URL for the request
     	url: jsonauth.baseurl + '/d77e8041d1ad',
 
     	// the data to send (will be converted to a query string)
	data: {
	    auth: authobject,
	},
 
 	// Needs to be a POST to send the auth object.
	type: 'POST',
 
    	// Ask for plain text for easier parsing. 
	dataType : 'text',
    });
    xmlthing.done(callback);
    xmlthing.fail(callback_failed);
}
</script>

<?php
echo "<div id='${node_id}_console' style='width: 100%;'></div>";
if (!$noclose) {
    echo "<center><button type=button
                          id='${node_id}_console_kill'>Close</button>" .
	 "</center>\n";
}
echo "<script language=JavaScript>
        window.onload = function() {
            StartConsole('${node_id}_console', '$console_auth');
        }
      </script>\n";

if (!isset($key)) {
    PAGEFOOTER();
}
?>
