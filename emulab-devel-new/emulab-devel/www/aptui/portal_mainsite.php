<?php
#
# Copyright (c) 2006-2020 University of Utah and the Flux Group.
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
#

#
# So, we could be coming in on the alternate APT address (virtual server)
# which causes cookie problems. I need to look into avoiding this problem
# but for now, just change the global value of the TBAUTHDOMAIN when we do.
# The downside is that users will have to log in twice if they switch back
# and forth.
#
if ($_SERVER["SERVER_NAME"] == "www.aptlab.net") {
    $ISVSERVER    = 1;
    $ISEMULAB     = 0;
    $ISAPT        = 1;
    $TBAUTHDOMAIN = ".aptlab.net";
    $COOKDIEDOMAIN= ".aptlab.net";
    $APTHOST      = "www.aptlab.net";
    $WWWHOST      = "www.aptlab.net";
    $APTBASE      = "https://www.aptlab.net";
    $SUPPORT      = "portal-ops@aptlab.net";
    $APTMAIL      = "APT Operations <$SUPPORT>";
    $APTMAILTO    = "<a href='mailto:$SUPPORT'>APT Operations</a>";
    $APTTITLE     = "APT";
    $FAVICON      = "aptlab.ico";
    $APTLOGO      = "aptlogo.png";
    $APTSTYLE     = "apt.css";
    $GOOGLEUA     = 'UA-42844769-3';
    $TBMAILTAG    = "aptlab.net";
    $EXTENSIONS   = "portal-extensions@aptlab.net";
    $TBAUTHTIMEOUT= (24 * 3600 * 7);
    # For devel trees
    if (preg_match("/\/([\w\/]+)$/", $WWW, $matches)) {
        $APTBASE .= "/" . $matches[1];
    }
    $PORTAL_MANUAL         = "http://docs.aptlab.net";
    $PORTAL_WIKI           = null;
    $PORTAL_HELPFORUM      = "apt-users";
    $PORTAL_PASSWORD_HELP  = "Aptlab.net or Emulab.net Username";
    $PORTAL_NSFNUMBER      = "1338155";
    $DEFAULT_AGGREGATE     = "Utah APT";
    $DEFAULT_AGGREGATE_URN = "urn:publicid:IDN+apt.emulab.net+authority+cm";
    $PORTAL_GENESIS        = "aptlab";
    $PORTAL_NAME           = "APT";
}
elseif ($_SERVER["SERVER_NAME"] == "www.cloudlab.us") {
    $ISVSERVER    = 1;
    $TBAUTHDOMAIN = ".cloudlab.us";
    $COOKDIEDOMAIN= "www.cloudlab.us";
    $APTHOST      = "www.cloudlab.us";
    $WWWHOST      = "www.cloudlab.us";
    $APTBASE      = "https://www.cloudlab.us";
    $SUPPORT      = "portal-ops@cloudlab.us";
    $APTMAIL      = "Cloudlab Operations <$SUPPORT>";
    $APTMAILTO    = "<a href='mailto:$SUPPORT'>Cloulab Operations</a>";
    $APTTITLE     = "CloudLab";
    $FAVICON      = "cloudlab.ico";
    $APTLOGO      = "cloudlogo.png";
    $APTSTYLE     = "cloudlab.css";
    $ISEMULAB     = 0;
    $ISCLOUD      = 1;
    $GOOGLEUA     = 'UA-42844769-2';
    $TBMAILTAG    = "cloudlab.us";
    $EXTENSIONS   = "portal-extensions@cloudlab.us";
    $TBAUTHTIMEOUT= (24 * 3600 * 14);
    # For devel trees
    if (preg_match("/\/([\w\/]+)$/", $WWW, $matches)) {
	$APTBASE .= "/" . $matches[1];
    }
    $PORTAL_MANUAL       = "http://docs.cloudlab.us";
    $PORTAL_WIKI         = null;
    $PORTAL_HELPFORUM    = "cloudlab-users";
    $PORTAL_PASSWORD_HELP= "CloudLab.us or Emulab.net Username";
    $PORTAL_NSFNUMBER    = "1419199";
    $DEFAULT_AGGREGATE   = "Utah Cloudlab";
    $PORTAL_GENESIS      = "cloudlab";
    $PORTAL_NAME         = "CloudLab";
    $PROTOGENI_GENIWEBLOGIN = 1;
}
elseif ($ISALTDOMAIN && $_SERVER["SERVER_NAME"] == "www.phantomnet.org") {
    $ISVSERVER    = 1;
    $TBAUTHDOMAIN = ".phantomnet.org";
    $COOKDIEDOMAIN= "www.phantomnet.org";
    $APTHOST      = "www.phantomnet.org";
    $WWWHOST      = "www.phantomnet.org";
    $APTBASE      = "https://www.phantomnet.org"; 
    $SUPPORT      = "portal-ops@phantomnet.org";
    $APTMAIL      = "PhantomNet Operations <$SUPPORT>";
    $APTMAILTO    = "<a href='mailto:$SUPPORT'>PhantomNet Operations</a>";
    $APTTITLE     = "PhantomNet";
    $FAVICON      = "phantomnet.ico";
    $APTLOGO      = "phantomlogo.png";
    $APTSTYLE     = "phantomnet.css";
    $ISEMULAB     = 0;
    $ISPNET       = 1;
    #$GOOGLEUA     = 'UA-42844769-2';
    $TBMAILTAG    = "phantomnet.org";
    $EXTENSIONS   = "portal-extensions@phantomnet.org";
    $TBAUTHTIMEOUT= (24 * 3600 * 14);
    # For devel trees
    if (preg_match("/\/([\w\/]+)$/", $WWW, $matches)) {
	$APTBASE .= "/" . $matches[1];
    }
    $PORTAL_MANUAL         = "http://docs.phantomnet.org";
    $PORTAL_WIKI           = "https://wiki.phantomnet.org/wiki/phantomnet";
    $PORTAL_HELPFORUM      = "phantomnet-users";
    $PORTAL_PASSWORD_HELP  = "PhantomNet.org or Emulab.net Username";
    $PORTAL_NSFNUMBER      = "1305384";
    $DEFAULT_AGGREGATE     = "Emulab";
    $DEFAULT_AGGREGATE_URN = "urn:publicid:IDN+emulab.net+authority+cm";
    $PORTAL_GENESIS        = "phantomnet";
    $PORTAL_NAME           = "PhantomNet";
    $PROTOGENI_GENIWEBLOGIN = 1;
}
elseif ($_SERVER["SERVER_NAME"] == "www.powderwireless.net") {
    $ISVSERVER    = 1;
    $TBAUTHDOMAIN = ".powderwireless.net";
    $COOKDIEDOMAIN= "www.powderwireless.net";
    $APTHOST      = "www.powderwireless.net";
    $WWWHOST      = "www.powderwireless.net";
    $APTBASE      = "https://www.powderwireless.net";
    $SUPPORT      = "powder-ops@powderwireless.net";
    $APTMAIL      = "Powder Wireless Operations <$SUPPORT>";
    $APTMAILTO    = "<a href='mailto:$SUPPORT'>Powder Wireless Operations</a>";
    $APTTITLE     = "Powder";
    $FAVICON      = "powder.ico";
    $APTLOGO      = "powderlogo.png";
    $APTSTYLE     = "powder.css";
    $ISEMULAB     = 0;
    $ISPOWDER     = 1;
    $GOOGLEUA     = 'UA-42844769-7';
    $TBMAILTAG    = "powderwireless.net";
    $EXTENSIONS   = "portal-extensions@powderwireless.net";
    $TBAUTHTIMEOUT= (24 * 3600 * 14);
    # For devel trees
    if (preg_match("/\/([\w\/]+)$/", $WWW, $matches)) {
	$APTBASE .= "/" . $matches[1];
    }
    $PORTAL_MANUAL         = "http://docs.powderwireless.net";
    $PORTAL_WIKI           = null;
    $PORTAL_HELPFORUM      = "powder-users";
    $PORTAL_PASSWORD_HELP  = "powderwireless.net or emulab.net Username";
    $PORTAL_NSFNUMBER      = false;
    $DEFAULT_AGGREGATE     = "Emulab";
    $DEFAULT_AGGREGATE_URN = "urn:publicid:IDN+emulab.net+authority+cm";
    $PORTAL_GENESIS        = "powder";
    $PORTAL_NAME           = "Powder";
    $PROTOGENI_GENIWEBLOGIN = 0;
}

#
# Array to map a portal "genesis" to its URL.
#
$BrandMapping = array(
    "emulab"     => "$TBBASE/portal",
    "cloudlab"   => "https://www.cloudlab.us",
    "phantomnet" => "https://www.phantomnet.org",
    "powder"     => "https://www.powderwireless.net",
);

?>
