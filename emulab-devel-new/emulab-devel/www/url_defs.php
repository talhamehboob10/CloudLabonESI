<?php
#
# Copyright (c) 2006-2021 University of Utah and the Flux Group.
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
# This is my attempt at factoring our the zillions of URL addresses and
# their arguments. This will hopefully make it easier to change how we
# address things, like when I change the uid,pid,gid arguments to numeric
# IDs instead of names.
#
define("URLARG_UID",		"__uid");
define("URLARG_PID",		"__pid");
define("URLARG_GID",		"__gid");
define("URLARG_EID",		"__eid");
define("URLARG_NODEID",		"__nodeid");
define("URLARG_IMAGEID",	"__imageid");
define("URLARG_OSID",		"__osid");
define("URLARG_TEMPLATE",	"__template");
define("URLARG_INSTANCE",	"__instance");
define("URLARG_METADATA",	"__metadata");
define("URLARG_LOGFILE",	"__logfile");

define("PAGEARG_USER",		"user");
define("PAGEARG_PROJECT",	"project");
define("PAGEARG_GROUP",		"group");
define("PAGEARG_EXPERIMENT",	"experiment");
define("PAGEARG_TEMPLATE",	"template");
define("PAGEARG_INSTANCE",	"instance");
define("PAGEARG_METADATA",	"metadata");
define("PAGEARG_NODE",		"node");
define("PAGEARG_IMAGE",		"image");
define("PAGEARG_OSINFO",	"osinfo");
define("PAGEARG_UID",		"uid");
define("PAGEARG_PID",		"pid");
define("PAGEARG_GID",		"gid");
define("PAGEARG_EID",		"eid");
define("PAGEARG_GUID",		"guid");
define("PAGEARG_VERS",  	"version");
define("PAGEARG_NODEID",	"nodeid");
define("PAGEARG_IMAGEID",	"imageid");
define("PAGEARG_OSID",		"osid");
define("PAGEARG_LOGFILE",	"logfile");
define("PAGEARG_BOOLEAN",	"boolean");
define("PAGEARG_STRING",	"string");
define("PAGEARG_PASSWORD",	"password");
define("PAGEARG_INTEGER",	"integer");
define("PAGEARG_NUMERIC",	"numeric");
define("PAGEARG_ARRAY",		"array");
define("PAGEARG_ANYTHING",	"anything");
define("PAGEARG_ALPHALIST",     "alphalist");
define("PAGEARG_UUID",		"uuid");
define("PAGEARG_URL",   	"url");

define("URL_USER",		"user");
define("URL_PROJECT",		"project");
define("URL_GROUP",		"group");
define("URL_EXPERIMENT",	"experiment");
define("URL_TEMPLATE",		"template");
define("URL_INSTANCE",		"instance");
define("URL_METADATA",		"metadata");
define("URL_LOGFILE",		"logfile");
define("URL_NODE",		"node");
define("URL_IMAGE",		"image");
define("URL_OSINFO",		"osinfo");
define("URL_UID",		"uid");
define("URL_PID",		"pid");
define("URL_GID",		"gid");
define("URL_EID",		"eid");
# Temporary until all pages converted
define("URL_NODEID",		"node_id");
# This happens a lot!
define("URL_NODEID_ALT",	"nodeid");
define("URL_IMAGEID",		"imageid");
define("URL_OSID",		"osid");
define("URL_GUID",		"guid");
define("URL_INSTANCEID",	"exptidx");
define("URL_VERS",		"version");
# Temporary until all pages converted
define("URL_EXPTIDX",		"exptidx");

#
# Map page "ids" to the actual script names if there is anything unusual.
# Otherwise, default to foo.php3 if not in the list.
#
$url_mapping			    = array();
$url_mapping["suuser"]		    = "suuser.php";
$url_mapping["toggle"]		    = "toggle.php";
$url_mapping["changeuid"]	    = "changeuid.php";
$url_mapping["template_analyze"]    = "template_analyze.php";
$url_mapping["template_commit"]     = "template_commit.php";
$url_mapping["template_create"]     = "template_create.php";
$url_mapping["template_defs"]       = "template_defs.php";
$url_mapping["template_editevents"] = "template_editevents.php";
$url_mapping["template_export"]     = "template_export.php";
$url_mapping["template_exprun"]     = "template_exprun.php";
$url_mapping["template_graph"]      = "template_graph.php";
$url_mapping["template_history"]    = "template_history.php";
$url_mapping["template_metadata"]   = "template_metadata.php";
$url_mapping["template_modify"]     = "template_modify.php";
$url_mapping["template_show"]       = "template_show.php";
$url_mapping["template_swapin"]     = "template_swapin.php";
$url_mapping["template_search"]     = "template_search.php";
$url_mapping["record_revise"]       = "record_revise.php";
$url_mapping["linkgraph_image"]     = "linkgraph_image.php";
$url_mapping["resendapproval"]      = "resendapproval.php";
$url_mapping["showevents"]          = "showevents.php";
$url_mapping["spewevents"]          = "spewevents.php";
$url_mapping["spitreport"]          = "spitreport.php";
$url_mapping["statechange"]         = "statechange.php";
$url_mapping["experimentrun_show"]  = "experimentrun_show.php";
$url_mapping["instance_show"]       = "instance_show.php";
$url_mapping["cvswebwrap"]          = "cvsweb/cvswebwrap.php3";
$url_mapping["profile"]             = "profile.php";
$url_mapping["submitpub"]           = "submitpub.php";
$url_mapping["showslice"]           = "showslice.php";
$url_mapping["genihistory"]         = "genihistory.php";
$url_mapping["showmanifest"]        = "showmanifest.php";
$url_mapping["showslicelogs"]       = "showslicelogs.php";
$url_mapping["ssh-keys"]            = "ssh-keys.php";
$url_mapping["list-datasets"]       = "list-datasets.php";
	     
#
# The caller will pass in a page id, and a list of things. If the thing
# is a class we know about, then we generate the argument directly from
# it. For example, if the argument is a User instance, we know to append
# "user=$user->uid()" cause all pages that take uid arguments use
# the same protocol.
#
# If the thing is not something we know about, then its a key/value pair,
# with the next argument being the value.
# The key (say, "uid") is the kind of argument to be added to the URL,
# and the value (a string or an user class instance) is where we get
# the argument from. To be consistent across all pages, something like "uid"
# is mapped to "?user=$value" rather then "uid".
#
# Note that this idea comes from a google search for ways to deal with
# this problem. Nothing fancy.
#
function CreateURL($page_id)
{
    global $url_mapping;
    
    $pageargs = func_get_args();
    # drop the required argument.
    array_shift($pageargs);

    if (array_key_exists($page_id, $url_mapping)) {
	$newurl = $url_mapping[$page_id];
    }
    else {
	$newurl = "$page_id" . ".php3";
    }

    # No args?
    if (! count($pageargs)) {
	return $newurl;
    }

    # Form an array of arguments to append.
    $url_args = array();

    while ($pageargs and count($pageargs)) {
	$key = array_shift($pageargs);

	#
	# Do we know about the object itself.
	#
	if (gettype($key) == "object") {
	    #
	    # Make up the key/value pair for below.
	    #
	    $val = $key;
	    
            #
            # In the cases, use both the lowercased version of the classname
            # and the real classname so this works under php4 and php5.
            #
	    switch (get_class($key)) {
	    case "user":
	    case "User":
		$key = URLARG_UID;
		break;
	    case "project":
	    case "Project":
		$key = URLARG_PID;
		break;
	    case "group":
	    case "Group":
		$key = URLARG_GID;
		break;
	    case "experiment":
	    case "Experiment":
		$key = URLARG_EID;
		break;
	    case "node":
	    case "Node":
		$key = URLARG_NODEID;
		break;
	    case "image":
	    case "Image":
		$key = URLARG_IMAGEID;
		break;
	    case "osinfo":
	    case "OSinfo":
		$key = URLARG_OSID;
		break;
	    case "template":
	    case "Template":
		$key = URLARG_TEMPLATE;
		break;
	    case "templateinstance":
	    case "TemplateInstance":
		$key = URLARG_INSTANCE;
		break;
	    case "templatemetadata":
	    case "TemplateMetadata":
		$key = URLARG_METADATA;
		break;
	    case "logfile":
	    case "Logfile":
		$key = URLARG_LOGFILE;
		break;
	    default:
		TBERROR("CreateURL: ".
			"Unknown object class - " . get_class($key), 1);
	    }
	}
	elseif (count($pageargs)) {
	    #
	    # A key/value pair so get the value from next argument.
	    #
	    $val = array_shift($pageargs);
	}
	else {
	    TBERROR("CreateURL: Malformed arguments for $key", 1);
	}

	#
	# Now process the key/value.
	#
	switch ($key) {
	case URLARG_UID:
	    $key = "user";
	    if (is_a($val, 'User')) {
		$val = $val->webid();
	    }
	    break;
	case URLARG_PID:
	    $key = "pid";
	    if (is_a($val, 'Project')) {
		$val = $val->pid();
	    }
	    break;
	case URLARG_GID:
	    $key = "gid";
	    if (is_a($val, 'Group')) {
		$url_args[] = "pid=" . $val->pid();
		$val = $val->gid();
	    }
	    break;
	case URLARG_EID:
	    if (is_a($val, 'Experiment')) {
		$key = "experiment";
		$val = $val->idx();
	    }
	    elseif (preg_match("/^[\d]+$/", "$val")) {
		$key = "experiment";
	    }
	    else {
		$key = "eid";
	    }
	    break;
	case URLARG_NODEID:
	    $key = "node_id";
	    if (is_a($val, 'Node')) {
		$val = $val->node_id();
	    }
	    break;
	case URLARG_IMAGEID:
	    $key = "imageid";
	    if (is_a($val, 'Image')) {
		$str = $val->imageid();
		if (1 || $val->version()) {
		    $str .= ":" . $val->version();
		}
		$val = $str;
	    }
	    $val = rawurlencode($val);
	    break;
	case URLARG_OSID:
	    $key = "osid";
	    if (is_a($val, 'OSinfo')) {
		$str = $val->osid();
		if (1 || $val->vers()) {
		    $str .= ":" . $val->vers();
		}
		$val = $str;
	    }
	    $val = rawurlencode($val);
	    break;
	case URLARG_TEMPLATE:
	    $key = "guid";
	    if (! is_a($val, 'Template')) {
		TBERROR("CreateURL: Must provide a Template object", 1);
	    }
	    $url_args[] = "version=" . $val->vers();
	    $val = $val->guid();
	    break;
	case URLARG_INSTANCE:
	    $key = "instance";
	    if (!is_a($val, 'TemplateInstance')) {
		TBERROR("CreateURL: Must provide a TemplateInstance object",1);
	    }
	    $val = $val->exptidx();
	    break;
	case URLARG_METADATA:
	    $key = "metadata";
	    if (!is_a($val, 'TemplateMetadata')) {
		TBERROR("CreateURL: Must provide a TemplateMetadata object",1);
	    }
	    $val = $val->guid() . "/" . $val->vers();
	    break;
	case URLARG_LOGFILE:
	    $key = "logfile";
	    if (is_a($val, 'Logfile')) {
		$val = $val->logid();
	    }
	    $val = rawurlencode($val);
	    break;
	default:
            # Use whatever it was we got.
	    ;
	}
	$url_args[] = "${key}=${val}";
    }
    $newurl .= "?" . implode("&", $url_args);
    return $newurl;
}

#
# This is other side; Given a list of arguments we want for the page,
# make sure we got the right stuff. For example, if I want an "experiment"
# the page needed to get either pid/eid, or exptidx arguments. Return
# an array of named objects.
#
function RequiredPageArguments()
{
    $argspec = func_get_args();

    return VerifyPageArguments($argspec, 1);
}
function OptionalPageArguments()
{
    $argspec = func_get_args();
    
    return VerifyPageArguments($argspec, 0);
}

function VerifyPageArguments($argspec, $required)
{
    global $drewheader;

    if ($drewheader) {
	trigger_error(
	    "PAGEHEADER called before VerifyPageArguments ".
	    "(called by RequiredPageArguments or OptionalPageArguments). ".
	    "Won't be able to return proper HTTP status code on Error ".
	    "in ". $_SERVER['SCRIPT_FILENAME'] . ",",
            E_USER_WARNING);
    }

    $result   = array();

    while ($argspec and count($argspec) > 1) {
	$name   = array_shift($argspec);
	$type   = array_shift($argspec);
	$yep    = 0;
	unset($object);

	switch ($type) {
	case PAGEARG_EXPERIMENT:
	    if (isset($_REQUEST[URL_EXPERIMENT])) {
		$idx = $_REQUEST[URL_EXPERIMENT];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_EXPERIMENT, $idx)) {
		    $object = Experiment::Lookup($idx);
		}
	    }
	    elseif (isset($_REQUEST[URL_EXPTIDX])) {
		$idx = $_REQUEST[URL_EXPTIDX];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_EXPERIMENT, $idx)) {
		    $object = Experiment::Lookup($idx);
		}
	    }
	    elseif (isset($_REQUEST[URL_PID]) &&
		    isset($_REQUEST[URL_EID])) {
		$pid = $_REQUEST[URL_PID];
		$eid = $_REQUEST[URL_EID];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_PID, $pid) &&
		    ValidateArgument($name, PAGEARG_EID, $eid)) {
		    $object = Experiment::LookupByPidEid($pid, $eid);
		}
	    }
	    break;

	case PAGEARG_TEMPLATE:
	    if (isset($_REQUEST[URL_GUID]) &&
		isset($_REQUEST[URL_VERS])) {
		$guid = $_REQUEST[URL_GUID];
		$vers = $_REQUEST[URL_VERS];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_GUID, $guid) &&
		    ValidateArgument($name, PAGEARG_VERS, $vers)) {
		    $object = Template::Lookup($guid, $vers);
		}
	    }
	    elseif (isset($_REQUEST[URL_TEMPLATE])) {
		$guidvers = $_REQUEST[URL_TEMPLATE];
		$yep = 1;
		
		if (preg_match("/^([\d]+)\/([\d]+)$/", $guidvers, $matches)) {
		    $guid = $matches[1];
		    $vers = $matches[2];
		    $object = Template::Lookup($guid, $vers);
		}
		else {
		    PAGEARGERROR("Invalid argument for '$type': $guidvers");
		}
	    }
	    break;

	case PAGEARG_INSTANCE:
	    if (isset($_REQUEST[URL_INSTANCE])) {
		$idx = $_REQUEST[URL_INSTANCE];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_INSTANCE, $idx)) {
		    $object = TemplateInstance::LookupByExptidx($idx);
		}
	    }
	    break;

	case PAGEARG_METADATA:
	    if (isset($_REQUEST[URL_METADATA])) {
		$guidvers = $_REQUEST[URL_METADATA];
		$yep = 1;
		
		if (preg_match("/^([\d]+)\/([\d]+)$/", $guidvers, $matches)) {
		    $guid = $matches[1];
		    $vers = $matches[2];
		    $object = TemplateMetadata::Lookup($guid, $vers);
		}
		else {
		    PAGEARGERROR("Invalid argument for '$type': $guidvers");
		}
	    }
	    break;

	case PAGEARG_PROJECT:
	    if (isset($_REQUEST[URL_PROJECT])) {
		$idx = $_REQUEST[URL_PROJECT];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_PROJECT, $idx)) {
		    $object = Project::Lookup($idx);
		}
	    }
	    elseif (isset($_REQUEST[URL_PID])) {
		$pid = $_REQUEST[URL_PID];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_PID, $pid)) {
		    $object = Project::Lookup($pid);
		}
	    }
	    break;

	case PAGEARG_GROUP:
	    if (isset($_REQUEST[URL_GROUP])) {
		$idx = $_REQUEST[URL_GROUP];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_GROUP, $idx)) {
		    $object = Group::Lookup($idx);
		}
	    }
	    elseif (isset($_REQUEST[URL_PID]) &&
		    isset($_REQUEST[URL_GID])) {
		$pid = $_REQUEST[URL_PID];
		$gid = $_REQUEST[URL_GID];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_PID, $pid) &&
		    ValidateArgument($name, PAGEARG_GID, $gid)) {
		    $object = Group::LookupByPidGid($pid, $gid);
		}
	    }
	    break;

	case PAGEARG_NODE:
	    if (isset($_REQUEST[URL_NODE])) {
		$idx = $_REQUEST[URL_NODE];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_NODE, $idx)) {
		    $object = Node::Lookup($idx);
		}
	    }
	    elseif (isset($_REQUEST[URL_NODEID])) {
		$nodeid = $_REQUEST[URL_NODEID];
		$yep    = 1;

		if (ValidateArgument($name, PAGEARG_NODEID, $nodeid)) {
		    $object = Node::Lookup($nodeid);
		}
	    }
	    elseif (isset($_REQUEST[URL_NODEID_ALT])) {
		$nodeid = $_REQUEST[URL_NODEID_ALT];
		$yep    = 1;

		if (ValidateArgument($name, PAGEARG_NODEID, $nodeid)) {
		    $object = Node::Lookup($nodeid);
		}
	    }
	    break;

	case PAGEARG_USER:
	    if (isset($_REQUEST[URL_USER])) {
		$idx = $_REQUEST[URL_USER];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_USER, $idx)) {
                    if (preg_match("/^\d+$/", $idx)) {
                        $object = User::Lookup($idx);
                    }
                    else {
                        $object = User::LookupByUid($idx);
                    }
		}
	    }
	    elseif (isset($_REQUEST[URL_UID])) {
		$uid = $_REQUEST[URL_UID];
		$yep    = 1;

		if (ValidateArgument($name, PAGEARG_UID, $uid)) {
		    $object = User::Lookup($uid);
		}
	    }
	    break;

	case PAGEARG_IMAGE:
	    $version = NULL;
	    if (isset($_REQUEST[URL_VERS])) {
		$version = $_REQUEST[URL_VERS];
		ValidateArgument($name, PAGEARG_VERS, $version);
	    }
	    if (isset($_REQUEST[URL_IMAGEID])) {
		$imageid = $_REQUEST[URL_IMAGEID];
		$yep    = 1;

		if (ValidateArgument($name, PAGEARG_UUID, $imageid, 0)) {
		    $object = Image::LookupByUUID($imageid, $version);
		}
		elseif (ValidateArgument($name, PAGEARG_IMAGE, $imageid)) {
		    $object = Image::Lookup($imageid, $version);
		}
	    }
	    elseif (isset($_REQUEST[$name]) && $_REQUEST[$name] != "") {
		$imageid = $_REQUEST[$name];
		$yep = 1;

		if (ValidateArgument($name, PAGEARG_IMAGE, $imageid)) {
		    $object = Image::Lookup($imageid, $version);
		}
	    }
	    break;

	case PAGEARG_OSINFO:
	    $version = NULL;
	    if (isset($_REQUEST[URL_VERS])) {
		$version = $_REQUEST[URL_VERS];
		ValidateArgument($name, PAGEARG_VERS, $version);
	    }
	    if (isset($_REQUEST[URL_OSID])) {
		$osid = $_REQUEST[URL_OSID];
		$yep  = 1;

		if (ValidateArgument($name, PAGEARG_OSINFO, $osid)) {
		    $object = OSinfo::Lookup($osid, $version);
		}
	    }
	    break;

	case PAGEARG_BOOLEAN:
	    if (isset($_REQUEST[$name]) && $_REQUEST[$name] != "") {
		$object = $_REQUEST[$name];
		$yep = 1;

		if (strcasecmp("$object", "yes") == 0 ||
		    strcasecmp("$object", "1") == 0 ||
		    strcasecmp("$object", "true") == 0 ||
		    strcasecmp("$object", "on") == 0) {
		    $object = True;
		}
		elseif (strcasecmp("$object", "no") == 0 ||
			strcasecmp("$object", "0") == 0 ||
			strcasecmp("$object", "false") == 0 ||
			strcasecmp("$object", "off") == 0) {
		    $object = False;
		}
	    }
	    break;

	case PAGEARG_INTEGER:
	case PAGEARG_NUMERIC:
	case PAGEARG_ARRAY:
	case PAGEARG_UUID:
	    if (isset($_REQUEST[$name]) && $_REQUEST[$name] != "") {
		$object = $_REQUEST[$name];
		$yep = 1;

		if (! ValidateArgument($name, $type, $object)) {
		    unset($object);
		}
	    }
	    break;
	    
	case PAGEARG_ANYTHING:
	    if (isset($_REQUEST[$name])) {
		$object = $_REQUEST[$name];
		$yep = 1;

                # Anything allowed, caller BETTER check it.
	    }
	    break;

	case PAGEARG_ALPHALIST:
	    if (isset($_REQUEST[$name])) {
		$object = $_REQUEST[$name];
		if (!preg_match("/^[\d\w\-\ \,]+$/",$object)) {
		    unset($object);
		}
		else {
		    $object = preg_split("/[\,\;]+\s*/",$_REQUEST[$name]);
		}
	    }
	    break;
	    
	case PAGEARG_STRING:
	    if (isset($_REQUEST[$name])) {
		$object = $_REQUEST[$name];
		$yep = 1;

                # Pages never get arguments with special chars. Check.
		if (preg_match("/[\'\"]/", $object)) {
		    $object = htmlspecialchars($object);
		    PAGEARGERROR("Invalid characters in '$name': $object");
		}
	    }
	    break;
	    
	case PAGEARG_URL:
            # Note that PHP has already urldecoded $_REQUEST values.
	    if (isset($_REQUEST[$name])) {
		$object = $_REQUEST[$name];
		$yep = 1;

                #
                # We use this strictly for internal URLs, so we can be
                # very narrow in what we allow, to avoid XSS attacks.
                #
                if (!preg_match("/^[-\w\?\/\&\.=\+\:]+$/", $object)) {
                    error_log($object);
		    $object = htmlspecialchars($object);
		    PAGEARGERROR("Invalid characters in '$name': $object");
                }
	    }
	    break;
	    
	case PAGEARG_NODEID:
	    if (isset($_REQUEST[$name])) {
		$object = $_REQUEST[$name];
		$yep = 1;

		if (!ValidateArgument($name, PAGEARG_NODEID, $object)) {
		    $object = htmlspecialchars($object);
		    PAGEARGERROR("Invalid characters in '$name': $object");
		}
	    }
	    break;
	    
	case PAGEARG_PASSWORD:
	    if (isset($_REQUEST[$name])) {
		$object = $_REQUEST[$name];
		$yep = 1;

                # Only printable chars.
		if (!preg_match("/^[\040-\176]*$/", $object)) {
		    PAGEARGERROR("Invalid characters in '$name'");
		}
	    }
	    break;
	    
	case PAGEARG_LOGFILE:
	    if (isset($_REQUEST[URL_LOGFILE])) {
		$logid = $_REQUEST[URL_LOGFILE];
		$yep   = 1;

		if (ValidateArgument($name, PAGEARG_LOGFILE, $logid)) {
		    $object = Logfile::Lookup($logid);
		}
	    }
	    break;
	}

	if (isset($object)) {
	    $result[$name]  = $object;
	    $GLOBALS[$name] = $object;
	}
	elseif ($yep) {
	    #
	    # Value supplied but could not be mapped to object.
	    # Lets make that clear in the error message.
	    #
	    USERERROR("Could not map page arguments to '$name'", 1);
	}
	elseif ($required) {
	    PAGEARGERROR("Must provide '$name' page argument");
	}
	else {
	    unset($GLOBALS[$name]);
	}
    }

    return $result;
}

#
# Validate a single argument is safe to pass along to a DB query.
#
function ValidateArgument($name, $type, $arg, $isfatal = 1)
{
    switch ($type) {
    case PAGEARG_UID:
    case PAGEARG_PID:
    case PAGEARG_GID:
    case PAGEARG_EID:
    case PAGEARG_NODEID:
    case PAGEARG_PROJECT:
    case PAGEARG_GROUP:
    case PAGEARG_USER:
    case PAGEARG_EXPERIMENT:
    case PAGEARG_NODE:
    case PAGEARG_LOGFILE:
	if (preg_match("/^[-\w]+$/", "$arg")) {
	    return 1;
	}
	break;

    case PAGEARG_IMAGEID:
    case PAGEARG_IMAGE:
    case PAGEARG_OSID:
    case PAGEARG_OSINFO:
	if (preg_match("/^[-\w\.\+:]+$/", "$arg")) {
	    return 1;
	}
	break;

    case PAGEARG_GUID:
    case PAGEARG_VERS:
    case PAGEARG_INSTANCE:
	if (preg_match("/^[\d]+$/", "$arg")) {
	    return 1;
	}
	break;

    case PAGEARG_METADATA:
	if (preg_match("/^[\d]+\/[\d]+$/", "$arg")) {
	    return 1;
	}
	break;

    case PAGEARG_INTEGER:
    case PAGEARG_NUMERIC:
	if (is_numeric($arg)) {
	    return 1;
	}
	break;

    case PAGEARG_UUID:
	if (preg_match("/^\w+\-\w+\-\w+\-\w+\-\w+$/", "$arg")) {
	    return 1;
	}
	break;

    case PAGEARG_ARRAY:
	if (is_array($arg)) {
	    return 1;
	}
	break;

    default:
	TBERROR("ValidateArgument: ".
		"Unknown argument type - $name", 1);
    }
    if ($isfatal) {
        PAGEARGERROR("Argument '$name' should be of type '$type'");
    }
    return 0;
}
?>
