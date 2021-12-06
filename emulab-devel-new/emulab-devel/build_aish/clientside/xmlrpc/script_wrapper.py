#! /usr/bin/env python
#
# Copyright (c) 2004-2021 University of Utah and the Flux Group.
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
# Wrapper to convert select commands into XMLRPC calls to boss. The point
# is to provide a script interface that is backwards compatable with the
# pre-rpc API, but not have to maintain that interface beyond this simple
# conversion.
#
from __future__ import print_function
import sys
import pwd
sys.path.append("/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/lib")
import getopt
import os
import re
import errno

import ssl
try:
    import xmlrpclib
except:
    import xmlrpc.client as xmlrpclib
from emulabclient import *

# When building on the clientside, there are a few minor differences.
WITH_EMULAB     = 1

##
# The package version number
#
PACKAGE_VERSION = 0.1

# Default server
XMLRPC_SERVER   = "boss.cloudlab.umass.edu"
XMLRPC_PORT   = 3069

# User supplied server name/port
xmlrpc_server   = XMLRPC_SERVER
xmlrpc_port     = XMLRPC_PORT

# User supplied login ID to use (overrides env variable USER if exists).
login_id        = os.environ["USER"]

# Debugging output.
debug           = 0
impotent        = 0

#
# For admin people, and for using their devel trees. These options are
# meaningless unless you are an Emulab developer; they will be rejected
# at the server most ungraciously.
#
if WITH_EMULAB:
    SERVER_PATH = "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish"
else:
    SERVER_PATH = "/usr/testbed"
SERVER_DIR      = "sbin"
DEVEL_DIR       = "devel"
develuser       = None
path            = None
admin           = 0
devel           = 0
needhelp        = 0

try:
    pw = pwd.getpwuid(os.getuid())
    pass
except KeyError:
    sys.stderr.write("error: unknown user id %d" % os.getuid())
    sys.exit(2)
    pass

USER = pw.pw_name
HOME = pw.pw_dir

CERTIFICATE = os.path.join(HOME, ".ssl", "emulab.pem")
certificate = CERTIFICATE
ca_certificate = None
verify = False

API = {
    "node_admin"        : { "func" : "adminmode",
                            "help" : "Boot selected nodes into FreeBSD MFS" },
    "node_reboot"       : { "func" : "reboot",
                            "help" : "Reboot selected nodes or all nodes in " +
                                     "an experiment" },
    "os_load"           : { "func" : "reload",
                            "help" : "Reload disks on selected nodes or all " +
                                     "nodes in an experiment" },
    "create_image"      : { "func" : "create_image",
                            "help" : "Create a disk image from a node" },
    "node_list"         : { "func" : "node_list",
                            "help" : "Print physical mapping of nodes " +
                                     "in an experiment" },
    "node_avail"        : { "func" : "node_avail",
                            "help" : "Print free node counts" },
    "node_avail_list"   : { "func" : "node_avail_list",
                            "help" : "Print physical node_ids for matching" +
                                     "free nodes" },
    "delay_config"      : { "func" : "delay_config",
                            "help" : "Change the link shaping characteristics " +
                                     "for a link or lan" },
    "wilink_config"     : { "func" : "wilink_config",
                            "help" : "Change INTERFACE parameters " +
                                     "for a WIRELESS link" },
    "savelogs"          : { "func" : "savelogs",
                            "help" : "Save console tip logs to experiment " +
                                     "directory" },
    "portstats"         : { "func" : "portstats",
                            "help" : "Get portstats from the switches" },
    "eventsys_control"  : { "func" : "eventsys_control",
                            "help" : "Start/Stop/Restart the event system" },
    "readycount"        : { "func" : "readycount",
                            "help" : "Get readycounts for nodes in experiment " +
                                     "(deprecated)" },
    "nscheck"           : { "func" : "nscheck",
                            "help" : "Check and NS file for parser errors" },
    "startexp"          : { "func" : "startexp",
                            "help" : "Start an Emulab experiment" },
    "batchexp"          : { "func" : "startexp",
                            "help" : "Synonym for startexp" },
    "swapexp"           : { "func" : "swapexp",
                            "help" : "Swap experiment in or out" },
    "modexp"            : { "func" : "modexp",
                            "help" : "Modify experiment" },
    "endexp"            : { "func" : "endexp",
                            "help" : "Terminate an experiment" },
    "expinfo"           : { "func" : "expinfo",
                            "help" : "Get information about an experiment" },
    "imageinfo"         : { "func" : "imageinfo",
                            "help" : "Get information about an image" },
    "tbuisp"            : { "func" : "tbuisp",
                            "help" : "Upload code to a mote" },
    "expwait"           : { "func" : "expwait",
                            "help" : "Wait for experiment to reach a state" },
    "tipacl"            : { "func" : "tipacl",
                            "help" : "Get console acl" },
    "template_commit"   : { "func" : "template_commit",
                            "help" : "Commit changes to template (modify)" },
    "template_export"   : { "func" : "template_export",
                            "help" : "Export template record" },
    "template_checkout" : { "func" : "template_checkout",
                            "help" : "Checkout a template" },
    "template_instantiate": { "func" : "template_instantiate",
                            "help" : "Instantiate a template" },
    "template_swapin":    { "func" : "template_swapin",
                            "help" : "Swapin a preloaded template instance" },
    "template_swapout"  : { "func" : "template_swapout",
                            "help" : "Terminate template instance" },
    "template_startrun" : { "func" : "template_startrun",
                            "help" : "Start new experiment run" },
    "template_modrun"   : { "func" : "template_modrun",
                            "help" : "Modify resources for run" },
    "template_stoprun"  : { "func" : "template_stoprun",
                            "help" : "Stop current experiment run" },
    "mkblob"            : { "func" : "mkblob",
                            "help" : "Create a new blob in the blob store" },
    "rmblob"            : { "func" : "rmblob",
                            "help" : "Remove a blob from the blob store" },
    "createdataset"     : { "func" : "createdataset",
                            "help" : "Create a persistent dataset" },
    "deletedataset"     : { "func" : "deletedataset",
                            "help" : "Delete a persistent dataset" },
    "extenddataset"     : { "func" : "extenddataset",
                            "help" : "Extend the lease on a persistent dataset" },
    "showdataset"       : { "func" : "showdataset",
                            "help" : "Show persistent datasets" },
    "startExperiment"   : { "func" : "startExperiment",
                            "help" : "Start a Portal experiment" },
    "terminateExperiment" : { "func" : "terminateExperiment",
                              "help" : "Terminate a Portal experiment" },
    "extendExperiment"  : { "func" : "extendExperiment",
                              "help" : "Extend a Portal experiment" },
    "experimentStatus"  : { "func" : "experimentStatus",
                            "help" : "Get status for a Portal experiment" },
    "experimentManifests" : { "func" : "experimentManifests",
                            "help" : "Get manifests for a Portal experiment" },
    "experimentReboot"  : { "func" : "experimentReboot",
                            "help" : "Reboot nodes in a Portal experiment" },
};

#
# Print the usage statement to stdout.
#
def usage():
    print ("Usage: wrapper [wrapper options] command [command args and opts]");
    print("");
    print("Commands:");
    for key, val in API.items():
        print(("    %-12s %s." % (key, val["help"])));
        pass
    print("(Specify the --help option to specific commands for more help)");
    wrapperoptions();
    print("")
    print("Example:")
    print("  "
           + "wrapper"
           + " --server=boss.emulab.net node_admin -n testbed one-node")

def wrapperoptions():
    print("");
    print("Wrapper Options:")
    print("    --help      Display this help message")
    print("    --server    Set the server hostname")
    print("    --port      Set the server port")
    print("    --login     Set the login id (defaults to $USER)")
    print("    --cert      Specify the path to your testbed SSL certificate")
    print("    --cacert    The path to the CA certificate to use for server verification")
    print("    --verify    Enable SSL verification; defaults to disabled")
    print("    --debug     Turn on semi-useful debugging")
    return

#
# Process a single command line
#
def do_method(module, method, params):
    if debug:
        print(module + " " + method + " " + str(params));
        pass
    if impotent:
        return 0;

    if not os.path.exists(certificate):
        sys.stderr.write("error: certificate not found: %s\n" %
                         certificate)
        sys.exit(2)
        pass

    URI = "https://" + xmlrpc_server + ":" + str(xmlrpc_port) + SERVER_PATH

    ctx = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
    try:
        ctx.set_ciphers("DEFAULT:@SECLEVEL=1")
    except:
        pass
    ctx.load_cert_chain(certificate)
    if not verify:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    else:
        if ca_certificate != None:
            ctx.load_verify_locations(cafile=ca_certificate)
        ctx.verify_mode = ssl.CERT_REQUIRED
        pass
    
    # Get a handle on the server,
    server = xmlrpclib.ServerProxy(URI, context=ctx, verbose=debug)
        
    # Get a pointer to the function we want to invoke.
    meth      = getattr(server, module + "." + method)
    meth_args = [ PACKAGE_VERSION, params ]

    #
    # Make the call. 
    #
    try:
        response = meth(*meth_args)
        pass
    except socket.error as e:
        print(e)
        rval = -1;
        if e.args[0] == errno.ECONNREFUSED:
            rval = RESPONSE_NETWORK_ERROR
            pass
        return (rval, None)
    except Exception as e:
        print(e)
        return (-1, None)

    #
    # Parse the Response, which is a Dictionary. See EmulabResponse in the
    # emulabclient.py module. The XML standard converts classes to a plain
    # Dictionary, hence the code below. 
    # 
    if len(response["output"]):
        print(response["output"])
        pass

    rval = response["code"]

    #
    # If the code indicates failure, look for a "value". Use that as the
    # return value instead of the code. 
    # 
    if rval != RESPONSE_SUCCESS:
        if response["value"]:
            rval = response["value"]
            pass
        pass
    return (rval, response)

#
# node_admin
#
class adminmode:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "nw", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
                pass
            elif opt == "-n":
                params["reboot"] = "no";
                pass
            elif opt == "-w":
                params["wait"] = "yes";
                pass
            pass

        # Do this after so --help is seen.
        if len(req_args) != 2:
            self.usage();
            return -1;
        
        params["mode"]  = req_args[0];
        params["node"]  = req_args[1];

        rval,response = do_method("node", "adminmode", params);
        return rval;

    def usage(self):
        print("node_admin [options] on|off node");
        print("where:");
        print("    -n    - Do not reboot node; just change OSID");
        print("    -w    - If rebooting, wait for node to reboot");
        print("on|off    - Turn admin mode on or off");
        print("  node    - Node to change (pcXXX)");
        wrapperoptions();
        return
    pass


#
# node_reboot
#
class reboot:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "wcfse:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        module = "node";
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
                pass
            elif opt == "-c":
                params["reconfig"] = "yes";
                pass
            elif opt == "-f":
                params["power"] = "yes";
                pass
            elif opt == "-w":
                params["wait"] = "yes";
                pass
            elif opt == "-s":
                params["slow"] = "yes";
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                module = "experiment";
                pass
            pass

        if module == "node":
            # Do this after so --help is seen.
            if len(req_args) < 1:
                self.usage();
                return -1;

            params["nodes"]  = str.join(",", req_args);
            pass
        else:
            if len(req_args):
                self.usage();
                return -1;
            pass
        
        rval,response = do_method(module, "reboot", params);
        return rval;

    def usage(self):
        print("node_reboot [options] node [node ...]");
        print("node_reboot [options] -e pid,eid")
        print("where:");
        print("    -w    - Wait for nodes is come back up");
        print("    -c    - Reconfigure nodes instead of rebooting");
        print("    -f    - Force power cycle of nodes (skip OS reboot)");
        print("    -s    - Force a 'slow' power cycle of nodes (power off, pause, power on)");
        print("            Try this if a node does not respond to a normal reboot");
        print("            or if you have accidentally powered off a node.");
        print("    -e    - Reboot all nodes in an experiment");
        print("  node    - Node to reboot (pcXXX)");
        wrapperoptions();
        return
    pass

#
# os_load
#
class reload:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "i:p:m:sre:cF",
                                           [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        module = "node";
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
                pass
            elif opt == "-i":
                params["imagename"] = val;
                pass
            elif opt == "-p":
                params["imageproj"] = val;
                pass
            elif opt == "-m":
                params["imageid"] = val;
                pass
            elif opt == "-s":
                params["wait"] = "no";
                pass
            elif opt == "-r":
                params["reboot"] = "no";
                pass
            elif opt == "-c":
                params["usecurrent"] = "yes";
                pass
            elif opt == "-F":
                params["force"] = "yes";
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                module = "experiment";
                pass
            pass

        if module == "node":
            # Do this after so --help is seen.
            if len(req_args) < 1:
                self.usage();
                return -1;

            params["nodes"]  = str.join(",", req_args);
            pass
        else:
            if len(req_args):
                self.usage();
                return -1;
            pass
        
        rval,response = do_method(module, "reload", params);
        return rval;

    def usage(self):
        print("os_load [options] node [node ...]");
        print("os_load [options] -e pid,eid")
        print("where:");
        print("    -i    - Specify image name; otherwise load default image");
        print("    -p    - Specify project for finding image name (-i)");
        print("    -s    - Do *not* wait for nodes to finish reloading");
        print("    -m    - Specify internal image id (instead of -i and -p)");
        print("    -r    - Do *not* reboot nodes; do that yourself");
        print("    -c    - Reload nodes with the image currently on them");
        print("    -F    - Force; clobber any existing MBR/partition table");
        print("    -e    - Reload all nodes in the given experiment");
        print("  node    - Node to reload (pcXXX)");
        wrapperoptions();
        return
    pass

#
# create_image
#
class create_image:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "p:w", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
                pass
            elif opt == "-p":
                params["imageproj"] = val;
                pass
            elif opt == "-w":
                params["wait"] = "yes";
                pass
            pass

        # Do this after so --help is seen.
        if len(req_args) != 2:
            self.usage();
            return -1;
        
        params["imagename"]  = req_args[0];
        params["node"]      = req_args[1];

        rval,response = do_method("node", "create_image", params);
        return rval;

    def usage(self):
        print("create_image [options] imageid node");
        print("where:");
        print("     -w   - Wait for image to be created");
        print("     -p   - Project ID of imageid");
        print("imageid   - Name of the image");
        print("   node   - Node to create image from (pcXXX)");
        wrapperoptions();
        return
    pass


#
# node_list
#
class node_list:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "pPvhHme:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        which  = "phys";
        params = {};
        params["aspect"] = "mapping";

        for opt, val in opts:
            if opt == "--help":
                self.usage()
                return 0
                pass
            elif opt == "-p":
                which = "phys";
                pass
            elif opt == "-P":
                which = "phystype";
                pass
            elif opt == "-v":
                which = "virt";
                pass
            elif opt == "-h":
                which = "pphys";
                pass
            elif opt == "-H":
                which = "pphysauxtype";
                pass
            elif opt == "-m":
                which = "mapping";
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        # Do this after so --help is seen.
        if len(req_args) or "proj" not in params:
            self.usage();
            return -1;

        rval,response = do_method("experiment", "info", params);
        if rval:
            return rval;

        for node in response["value"]:
            val = response["value"][node];

            if which == "virt":
                print(node, " ", end=' ')
                pass
            elif which == "phys":
                print(val["node"], " ", end=' ')
                pass
            elif which == "phystype":
                print(("%s=%s") % (val["node"],val["type"]), " ", end=' ')
                pass
            elif which == "pphys":
                print(val["pnode"], " ", end=' ')
                pass
            elif which == "pphysauxtype":
                print("%s=%s"  % (val["pnode"],val["auxtype"]), " ", end=' ')
                pass
            elif which == "mapping":
                print("%s=%s" % (node, val["pnode"]), end=' ')
                pass
            pass
        print("");
        
        return rval;

    def usage(self):
        print("node_list [options] -e pid,eid");
        print("where:");
        print("     -p   - Print physical (Emulab database) names (default)");
        print("     -P   - Like -p, but include node type");
        print("     -v   - Print virtual (experiment assigned) names");
        print("     -h   - Print physical name of host for virtual nodes");
        print("     -H   - Like -h, but include node auxtypes");
        print("     -e   - Project and Experiment ID to list");
        wrapperoptions();
        return
    pass


#
# node_avail
#
class node_avail:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        params = {}
        
        try:
            opts, req_args = getopt.getopt(self.argv, "hp:t:c:", [
                "help", "project=", "node-type=", "node-class=" ])

            for opt, val in opts:
                if opt in ("-h", "--help"):
                    self.usage();
                    return 0
                elif opt in ("-p", "--project"):
                    params["proj"] = val
                    pass
                elif opt in ("-c", "--node-class"):
                    params["class"] = val
                    pass
                elif opt in ("-t", "--node-type"):
                    params["type"] = val
                    pass
                pass
            pass
        except  getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        rval,response = do_method("node", "available", params)
        return rval

    def usage(self):
        print("node_avail [-p project] [-c class] [-t type]")
        print("Print the number of available nodes.")
        print("where:")
        print("     -p project  - Specify project credentials for node types")
        print("                   that are restricted")
        print("     -c class    - The node class (Default: pc)")
        print("     -t type     - The node type")
        print("")
        print("example:")
        print("  $ node_avail -t pc850")
        wrapperoptions()
        return

    pass


#
# node_avail_list
#
class node_avail_list:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        params = {}
        
        try:
            opts, req_args = getopt.getopt(self.argv, "hp:t:c:n:", [
                "help", "project=", "node-type=", "node-class=", "nodes=" ])

            for opt, val in opts:
                if opt in ("-h", "--help"):
                    self.usage();
                    return 0
                elif opt in ("-p", "--project"):
                    params["proj"] = val
                    pass
                elif opt in ("-c", "--node-class"):
                    params["class"] = val
                    pass
                elif opt in ("-t", "--node-type"):
                    params["type"] = val
                    pass
                elif opt in ("-n", "--nodes"):
                    params["nodes"] = val
                    pass
                pass
            pass
        except  getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        rval,response = do_method("node", "getlist", params)
        return rval

    def usage(self):
        print("node_avail_list [-p project] [-c class] [-t type] [-n nodes]")
        print("Print physical node_ids of available nodes.")
        print("where:")
        print("     -p project         - Specify project credentials for node")
        print("                          types that are restricted")
        print("     -c class           - The node class (Default: pc)")
        print("     -t type            - The node type")
        print("     -n pcX,pcY,...,pcZ - A list of physical node_ids")
        print("")
        print("example:")
        print("  $ node_avail_list -t pc850")
        wrapperoptions()
        return

    pass


#
# delay_config
#
class delay_config:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "s:me:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt == "--help":
                self.usage()
                return 0
                pass
            elif opt == "-m":
                params["persist"] = "yes";
                pass
            elif opt == "-b":
                params["bridge"] = "yes";
                pass
            elif opt == "-s":
                params["src"] = val;
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        #
        # The point is to allow backwards compatable pid eid arguments, but
        # move to the better -e pid,eid format eventually. 
        #
        if "proj" not in params:
            if len(req_args) < 2:
                self.usage();
                return -1;
            
            params["proj"]  = req_args[0];
            params["exp"]   = req_args[1];
            req_args        = req_args[2:];
            pass

        # Do this after so --help is seen.
        if len(req_args) < 2:
            self.usage();
            return -1;

        # Next should be the link we want to control
        params["link"]  = req_args[0];

        # Now we turn the rest of the arguments into a dictionary
        linkparams = {}
        for linkparam in req_args[1:]:
            plist = str.split(linkparam, "=", 1)
            if len(plist) != 2:
                print(("Parameter, '" + linkparam
                       + "', is not of the form: param=value!"))
                self.usage();
                return -1
            
            linkparams[plist[0]] = plist[1];
            pass
        params["params"] = linkparams;

        rval,response = do_method("experiment", "delay_config", params);
        return rval;

    def usage(self):
        print("delay_config [options] -e pid,eid link PARAM=value ...");
        print("delay_config [options] pid eid link PARAM=value ...");
        print("where:");
        print("     -m   - Modify virtual experiment as well as current state");
        print("     -b   - bridge mode; operating on a bridge node instead of link");
        print("     -s   - Select the source of the link to change");
        print("     -e   - Project and Experiment ID to operate on");
        print("   link   - Name of link from your NS file (ie: 'link1')");
        print("            Or the bridge name, if explicitly using a bridge node");
        print("");
        print("PARAMS");
        print(" BANDWIDTH=NNN   - N=bandwidth (10-100000 Kbits per second)");
        print(" PLR=NNN         - N=lossrate (0 <= plr < 1)");
        print(" DELAY=NNN       - N=delay (one-way delay in milliseconds > 0)");
        print(" LIMIT=NNN       - The queue size in bytes or packets");
        print(" QUEUE-IN-BYTES=N- 0 means in packets, 1 means in bytes");
        print("RED/GRED Options: (only if link was specified as RED/GRED)");
        print(" MAXTHRESH=NNN   - Maximum threshold for the average Q size");
        print(" THRESH=NNN      - Minimum threshold for the average Q size");
        print(" LINTERM=NNN     - Packet dropping probability");
        print(" Q_WEIGHT=NNN    - For calculating the average queue size\n");
        wrapperoptions();
        return

#
# wilink_config
#
class wilink_config:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "s:me:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt == "--help":
                self.usage()
                return 0
                pass
            elif opt == "-m":
                params["persist"] = "yes";
                pass
            elif opt == "-s":
                params["src"] = val;
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        #
        # The point is to allow backwards compatable pid eid arguments, but
        # move to the better -e pid,eid format eventually. 
        #
        if "proj" not in params:
            if len(req_args) < 2:
                self.usage();
                return -1;
            
            params["proj"]  = req_args[0];
            params["exp"]   = req_args[1];
            req_args        = req_args[2:];
            pass

        # Do this after so --help is seen.
        if len(req_args) < 2:
            self.usage();
            return -1;

        # Next should be the link we want to control
        params["link"]  = req_args[0];

        # Now we turn the rest of the arguments into a dictionary
        linkparams = {}
        for linkparam in req_args[1:]:
            plist = str.split(linkparam, "=", 1)
            if len(plist) != 2:
                print(("Parameter, '" + param
                       + "', is not of the form: param=value!"))
                self.usage();
                return -1
            
            linkparams[plist[0]] = plist[1];
            pass
        params["params"] = linkparams;

        rval,response = do_method("experiment", "link_config", params);
        return rval;

    def usage(self):
        print("wilink_config [options] -e pid,eid link PARAM=value ...");
        print("wilink_config [options] pid eid link PARAM=value ...");
        print("where:");
        print("     -m   - Modify virtual experiment as well as current state");
        print("     -s   - Select the source of the link to change");
        print("     -e   - Project and Experiment ID to operate on");
        print("   link   - Name of link from your NS file (ie: 'link1')");
        print("");
        print("Special Param");
        print(" ENABLE=yes/no   - Bring the link up or down (or ENABLE=up/down)");
        print("")
        print("*********************** WARNING *******************************")
        print("   wilink_config is used to configure WIRELESS INTERFACES!")
        print("   Use delay_config to change the traffic shaping parameters")
        print("   on normal links and lans.")
        print("***************************************************************")
        wrapperoptions();
        return

#
# savelogs
#
class savelogs:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "e:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt == "--help":
                self.usage()
                return 0
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        # Do this after so --help is seen.
        #
        # The point is to allow backwards compatable pid eid arguments, but
        # move to the better -e pid,eid format eventually. 
        #
        if "proj" not in params:
            if len(req_args) < 2:
                self.usage();
                return -1;
            
            params["proj"]  = req_args[0];
            params["exp"]   = req_args[1];
            pass

        rval,response = do_method("experiment", "savelogs", params);
        return rval;

    def usage(self):
        print("savelogs -e pid,eid");
        print("savelogs pid eid");
        print("where:");
        print("     -e   - Project and Experiment ID");
        wrapperoptions();
        return
    pass

#
# portstats
#
class portstats:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "azqcpeC", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt == "--help":
                self.usage()
                return 0
                pass
            elif opt == "-e":
                params["errors-only"] = "yes";
                pass
            elif opt == "-a":
                params["all"] = "yes";
                pass
            elif opt == "-z":
                params["clear"] = "yes";
                pass
            elif opt == "-q":
                params["quiet"] = "yes";
                pass
            elif opt == "-c":
                params["absolute"] = "yes";
                pass
            elif opt == "-p":
                params["physnames"] = "yes";
                pass
            elif opt == "-C":
                params["control-net"] = "yes";
                pass
            pass

        # Do this after so --help is seen.
        if "physnames" not in params:
            if len(req_args) < 2:
                self.usage();
                return -1;
            
            params["proj"]  = req_args[0];
            params["exp"]   = req_args[1];
            req_args        = req_args[2:];
            pass
        elif len(req_args) < 1:
            self.usage();
            return -1;
        
        # Send the rest of the args along as a list.
        params["nodeports"] = req_args;

        rval,response = do_method("experiment", "portstats", params);
        return rval;

    def usage(self):
        print("portstats <-p | pid eid> [vname ...] [vname:port ...]");
        print("where:");
        print("    -e    - Show only error counters");
        print("    -a    - Show all stats");
        print("    -z    - Zero out counts for selected counters after printing");
        print("    -q    - Quiet: don't actually print counts - useful with -z");
        print("    -c    - Print absolute, rather than relative, counts");
        print("    -p    - The machines given are physical, not virtual, node");
        print("            IDs. No pid and eid should be given with this option");
        print("    -C    - Show counters for the control network interface ");
        print("            rather than experimental interfaces");
        print("");
        print("If only pid and eid are given, prints out information about all");
        print("ports in the experiment. Otherwise, output is limited to the");
        print("nodes and/or ports given.");
        print("");
        print("NOTE: Statistics are reported from the switch's perspective.");
        print("      This means that 'In' packets are those sent FROM the node,");
        print("      and 'Out' packets are those sent TO the node.");
        print("");
        print("In the output, packets described as 'NUnicast' or 'NUcast' are ");
        print("non-unicast (broadcast or multicast) packets.");
        wrapperoptions();
        return
    pass


#
# readycount. This is totally deprecated, but we leave it around. Users
# should be using the sync daemon.
#
class readycount:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "scple:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt == "--help":
                self.usage()
                return 0
                pass
            elif opt == "-s":
                params["set"] = "yes";
                pass
            elif opt == "-c":
                params["clear"] = "yes";
                pass
            elif opt == "-l":
                params["list"] = "yes";
                pass
            elif opt == "-p":
                params["physnames"] = "yes";
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        #
        # The point is to allow backwards compatable pid eid arguments, but
        # move to the better -e pid,eid format eventually. 
        #
        if "physnames" in params and "proj" in params:
            self.usage();
            return -1;
        
        if "physnames" not in params and "proj" not in params:
            if len(req_args) < 2:
                self.usage();
                return -1;
            
            params["proj"]  = req_args[0];
            params["exp"]   = req_args[1];
            req_args        = req_args[2:];
            pass
        elif "physnames" in params and len(req_args) < 1:
            self.usage();
            return -1;
        
        # Send the rest of the args along as a list.
        params["nodes"] = req_args;

        rval,response = do_method("experiment", "readycount", params);
        return rval;

    def usage(self):
        print("readycount [-c | -s] [-l] -e pid,eid [node ...]");
        print("readycount [-c | -s] [-l] pid eid [node ...]");
        print("where:");
        print("     -e   - Project and Experiment ID");
        print("     -s   - Set ready bits");
        print("     -c   - Clear ready bits");
        print("     -p   - Use physical node IDs instead of virtual (-c or -s).");
        print("            No pid and eid should be given with this option");
        print("     -l   - List ready status for each node in the experiment");
        print("");
        print("If no nodes are given, gives a summary of the nodes that have");
        print("reported ready. If nodes are given, reports just status for the");
        print("listed nodes. If -s or -c is given, sets or clears ready bits");
        print("for the listed nodes, or all them as being ready (or clears ");
        print("their ready bits if -c is given).");
        wrapperoptions();
        return
    pass

#
# eventsys_control
#
class eventsys_control:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "e:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt == "--help":
                self.usage()
                return 0
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        #
        # The point is to allow backwards compatable pid eid arguments, but
        # move to the better -e pid,eid format eventually. 
        #
        if "proj" not in params:
            if len(req_args) < 2:
                self.usage();
                return -1;
            
            params["proj"]   = req_args[0];
            params["exp"]    = req_args[1];
            params["action"] = req_args[2];
            pass
        elif len(req_args) != 1:
            self.usage();
            return -1;
        else:
            params["action"] = req_args[0];            

        rval,response = do_method("experiment", "eventsys_control", params);
        return rval;

    def usage(self):
        print("eventsys_control -e pid,eid start|stop|replay");
        print("eventsys_control pid eid start|stop|replay");
        print("where:");
        print("     -e   - Project and Experiment ID");
        print("   stop   - Stop the event scheduler");
        print("  start   - Start the event stream from time index 0");
        print(" replay   - Replay the event stream from time index 0");
        wrapperoptions();
        return
    pass

#
# nscheck
#
class nscheck:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            pass

        # Do this after so --help is seen.
        if len(req_args) != 1:
            self.usage();
            return -1;

        try:
            nsfilestr = open(req_args[0]).read();
            pass
        except:
            print("Could not open file: " + req_args[0]);
            return -1;

        params["nsfilestr"] = nsfilestr;
        rval,response = do_method("experiment", "nscheck", params);
        return rval;

    def usage(self):
        print("nscheck nsfile");
        print("where:");
        print(" nsfile    - Path to NS file you to wish check for parse errors");
        wrapperoptions();
        return
    pass

#
# startexp
#
class startexp:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv,
                                           "iwfqS:L:a:l:E:g:p:e:N",
                                           [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-i":
                params["batch"] = "no";
                pass
            elif opt == "-E":
                params["description"] = val;
                pass
            elif opt == "-g":
                params["group"] = val;
                pass
            elif opt == "-e":
                params["exp"] = val;
                pass
            elif opt == "-p":
                params["proj"] = val;
                pass
            elif opt == "-S":
                params["swappable"]     = "no";
                params["noswap_reason"] = val;
                pass
            elif opt == "-L":
                params["idleswap"]          = 0;
                params["noidleswap_reason"] = val;
                pass
            elif opt == "-l":
                params["idleswap"] = val;
                pass
            elif opt == "-a":
                params["max_duration"] = val;
                pass
            elif opt == "-f":
                params["noswapin"] = "yes"
                pass
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-N":
                params["noemail"] = "yes"
                pass
            pass

        # Do this after so --help is seen.
        if len(req_args) != 1:
            self.usage();
            return -1;

        try:
            nsfilestr = open(req_args[0]).read();
            pass
        except:
            print("Could not open file: " + req_args[0]);
            return -1;

        params["nsfilestr"] = nsfilestr;
        rval,response = do_method("experiment", "startexp", params);
        return rval;

    def usage(self):
        print("startexp [-q] [-i [-w]] [-f] [-N] [-E description] [-g gid]");
        print("         [-S reason] [-L reason] [-a <time>] [-l <time>]");
        print("         -p <pid> -e <eid> <nsfile>");
        print("where:");
        print("   -i   - swapin immediately; by default experiment is batched");
        print("   -w   - wait for non-batchmode experiment to preload or swapin");
        print("   -f   - preload experiment (do not swapin or queue yet)");
        print("   -q   - be less chatty");
        print("   -S   - Experiment cannot be swapped; must provide reason");
        print("   -L   - Experiment cannot be IDLE swapped; must provide reason");
        print("   -a   - Auto swapout NN minutes after experiment is swapped in");
        print("   -l   - Auto swapout NN minutes after experiment goes idle");
        print("   -E   - A pithy sentence describing your experiment");
        print("   -g   - The subgroup in which to create the experiment");
        print("   -p   - The project in which to create the experiment");
        print("   -e   - The experiment name (unique, alphanumeric, no blanks)");
        print("   -N   - Suppress most email to the user and testbed-ops");
        print("nsfile  - NS file to parse for experiment");
        wrapperoptions();
        return
    pass

#
# swapexp
#
class swapexp:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "wNe:s:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-N":
                params["noemail"] = "yes"
                pass
            elif opt == "-s":
                params["direction"] = val
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        #
        # The point is to allow backwards compatable pid eid arguments, but
        # move to the better -e pid,eid format eventually. 
        #
        if "proj" not in params:
            if len(req_args) < 2:
                self.usage();
                return -1;
            
            params["proj"] = req_args[0];
            params["exp"]  = req_args[1];
            req_args       = req_args[2:];
            pass

        if "direction" not in params and len(req_args) != 1:
            self.usage();
            return -1;
        else:
            params["direction"] = req_args[0];
            pass

        rval,response = do_method("experiment", "swapexp", params);
        return rval;

    def usage(self):
        print("swapexp -e pid,eid in|out");
        print("swapexp pid eid in|out");
        print("where:");
        print("     -w   - Wait for experiment to finish swapping");
        print("     -e   - Project and Experiment ID");
        print("     -N   - Suppress most email to the user and testbed-ops");
        print("     in   - Swap experiment in  (must currently be swapped out)");
        print("    out   - Swap experiment out (must currently be swapped in)");
        print("")
        print("By default, swapexp runs in the background, sending you email ");
        print("when the transition has completed. Use the -w option to wait");
        print("in the foreground, returning exit status. Email is still sent.");
        wrapperoptions();
        return
    pass

#
# modexp
#
class modexp:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "rswNe:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-r":
                params["reboot"] = "yes"
                pass
            elif opt == "-s":
                params["restart_eventsys"] = "yes"
                pass
            elif opt == "-N":
                params["noemail"] = "yes"
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        #
        # The point is to allow backwards compatable pid eid arguments, but
        # move to the better -e pid,eid format eventually. 
        #
        if "proj" not in params:
            if len(req_args) != 3:
                self.usage();
                return -1;
            
            params["proj"] = req_args[0];
            params["exp"]  = req_args[1];
            req_args       = req_args[2:];
            pass
        elif len(req_args) != 1:
            self.usage();
            return -1;

        #
        # Read in the NS file to pass along.
        # 
        try:
            nsfilestr = open(req_args[0]).read();
            pass
        except:
            print("Could not open file: " + req_args[0]);
            return -1;

        params["nsfilestr"] = nsfilestr;
        rval,response = do_method("experiment", "modify", params);
        return rval;

    def usage(self):
        print("modexp [-r] [-s] [-w] [-N] -e pid,eid nsfile");
        print("modexp [-r] [-s] [-w] [-N] pid eid nsfile");
        print("where:");
        print("     -w   - Wait for experiment to finish swapping");
        print("     -e   - Project and Experiment ID");
        print("     -r   - Reboot nodes (when experiment is active)");
        print("     -s   - Restart event scheduler (when experiment is active)");
        print("     -N   - Suppress most email to the user and testbed-ops");
        print("")
        print("By default, modexp runs in the background, sending you email ");
        print("when the transition has completed. Use the -w option to wait");
        print("in the foreground, returning exit status. Email is still sent.");
        print("")
        print("The experiment can be either swapped in *or* swapped out.");
        print("If the experiment is swapped out, the new NS file replaces the ");
        print("existing NS file (the virtual topology is updated). If the");
        print("experiment is swapped in (active), the physical topology is");
        print("also updated, subject to the -r and -s options above");
        wrapperoptions();
        return
    pass

#
# endexp
#
class endexp:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "wNe:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-N":
                params["noemail"] = "yes"
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        #
        # The point is to allow backwards compatable pid eid arguments, but
        # move to the better -e pid,eid format eventually. 
        #
        if "proj" not in params:
            if len(req_args) != 2:
                self.usage();
                return -1;
            
            params["proj"] = req_args[0];
            params["exp"]  = req_args[1];
            pass
        elif len(req_args) != 0:
            self.usage();
            return -1;

        rval,response = do_method("experiment", "endexp", params);
        return rval;

    def usage(self):
        print("endexp [-w] [-N] -e pid,eid");
        print("endexp [-w] [-N] pid eid");
        print("where:");
        print("     -w   - Wait for experiment to finish terminating");
        print("     -e   - Project and Experiment ID");
        print("     -N   - Suppress most email to the user and testbed-ops");
        print("")
        print("By default, endexp runs in the background, sending you email ");
        print("when the transition has completed. Use the -w option to wait");
        print("in the foreground, returning exit status. Email is still sent.");
        print("")
        print("The experiment can be terminated when it is currently swapped");
        print("in *or* swapped out.");
        wrapperoptions();
        return
    pass

#
# expinfo
#
class expinfo:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "nmldae:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        show   = [];
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-n":
                show.append("nodeinfo");
                pass
            elif opt == "-m":
                show.append("mapping");
                pass
            elif opt == "-l":
                show.append("linkinfo");
                pass
            elif opt == "-d":
                show.append("shaping");
                pass
            elif opt == "-a":
                show = ["nodeinfo", "mapping", "linkinfo", "shaping"];
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        #
        # The point is to allow backwards compatable pid eid arguments, but
        # move to the better -e pid,eid format eventually. 
        #
        if "proj" not in params:
            if len(req_args) != 2:
                self.usage();
                return -1;
            
            params["proj"] = req_args[0];
            params["exp"]  = req_args[1];
            pass
        elif len(req_args) or len(show) == 0:
            self.usage();
            return -1;

        params["show"] = str.join(",", show);
        rval,response = do_method("experiment", "expinfo", params);
        return rval;

    def usage(self):
        print("expinfo [-n] [-m] [-l] [-d] [-a] -e pid,eid");
        print("expinfo [-n] [-m] [-l] [-d] [-a] pid eid");
        print("where:");
        print("     -e   - Project and Experiment ID");
        print("     -n   - Show node info");
        print("     -m   - Show node mapping");
        print("     -l   - Show link info");
        print("     -a   - Show all of the above");
        wrapperoptions();
        return
    pass

#
# imageinfo
#
class imageinfo:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-i":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["imagename"]  = eid;
                pass
            pass

        #
        # The point is to allow backwards compatable pid imagename
        # arguments, but move to the better -i pid,imagename format
        # eventually.
        #
        if "proj" not in params:
            if len(req_args) != 2:
                self.usage();
                return -1;
            
            params["proj"]  = req_args[0];
            params["imagename"]  = req_args[1];
            pass
        elif len(req_args) or len(show) == 0:
            self.usage();
            return -1;

        rval,response = do_method("imageid", "info", params);
        return rval;

    def usage(self):
        print("expinfo -i pid,imagename");
        print("expinfo pid imagename");
        print("where:");
        print("     -i   - Project and Image ID");
        wrapperoptions();
        return
    pass

class tbuisp:
    def __init__(self, argv=None):
        self.argv = argv
        return

    def apply(self):
        params = {}
  
        try:
            opts, req_args = getopt.getopt(self.argv, "h", [
                "help", ])

            for opt, val in opts:
                if opt in ("-h", "--help"):
                    self.usage();
                    return 0
                pass

            if len(req_args) < 3:
                raise getopt.error(
                    "error: a file and one or more nodes must be specified")
            pass
        except  getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params["op"] = req_args[0]
        file = req_args[1]
        params["nodes"] = req_args[2:]
  
        try:
            filestr = open(file).read()
            pass
        except:
            print("Could not open file: " + file)
            return -1

        # I don't know what is in the file, so we'll base64 encode before
        # sending it over XML-RPC.  On the receiving side you'll get a Binary
        # object with the bits stored in the data field.  In code:
        #
        #   filestr = params["filestr"].data
        #
        # I think...
        params["filestr"] = xmlrpclib.Binary(filestr)

        rval,response = do_method("node", "tbuisp", params)
                
        return rval
                    
    def usage(self):
        print("tbuisp <operation> <file> <node1> [<node2> ...]")
        print("where:")
        print("     operation - Operation to perform. Currently, only 'upload'")
        print("                 is supported")
        print("     file      - Name of the to upload to the mote")
        print("     nodeN     - The physical node name ...")
        print("")
        print("example:")   
        print("  $ tbuisp upload foo.srec mote1")
        wrapperoptions()
        return
        
    pass

#
# expwait
#
class expwait:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "ht:e:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        show   = [];
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-t":
                params["timeout"] = val;
                pass
            elif opt == "-e":
                pid,eid = str.split(val, ",")
                params["proj"] = pid;
                params["exp"]  = eid;
                pass
            pass

        #
        # The point is to allow backwards compatable pid eid arguments, but
        # move to the better -e pid,eid format eventually. 
        #
        if "proj" not in params:
            if len(req_args) != 3:
                self.usage();
                return -1;
            
            params["proj"]  = req_args[0];
            params["exp"]   = req_args[1];
            params["state"] = req_args[2];
            pass
        elif len(req_args) != 1:
            self.usage();
            return -1;
        else:
            params["state"] = req_args[0];
            pass

        rval,response = do_method("experiment", "statewait", params);
        return rval;

    def usage(self):
        print("expwait [-t timeout] -e pid,eid state");
        print("expwait [-t timeout] pid eid state");
        print("where:");
        print("     -e   - Project and Experiment ID");
        print("     -t   - Maximum time to wait (in seconds).");
        wrapperoptions();
        return
    pass

#
# tipacl (get console acl goo)
#
class tipacl:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
                pass
            pass

        # Do this after so --help is seen.
        if len(req_args) != 1:
            self.usage();
            return -1;
        
        params["node"]  = req_args[0];

        rval,response = do_method("node", "console", params);

        if rval == 0:
            for key in response["value"]:
                val = response["value"][key];
                print("%s: %s" % (key, val))
                pass
            pass
        
        return rval;

    def usage(self):
        print("tipacl node");
        print("where:");
        print("  node    - Node to get tipacl data for (pcXXX)");
        wrapperoptions();
        return
    pass

#
# template_commit
#
class template_commit:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv,
                                           "we:p:E:t:r:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        guid   = None
        params = {}
        eid    = None
        pid    = None
        
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-e":
                params["exp"] = val
                eid = val
                pass
            elif opt == "-p":
                params["proj"] = val
                pid = val;
                pass
            elif opt == "-E":
                params["description"] = val;
                pass
            elif opt == "-t":
                params["tid"] = val;
                pass
            elif opt == "-r":
                params["tag"] = val;
                pass
            pass
        
        # Try to infer the template guid/vers from the current path.
        if len(req_args) == 1:
            params["guid"] = req_args[0]
            pass
        elif pid == None and eid == None:
            (guid, subdir) = infer_template()
            if subdir:
                params["path"] = os.getcwd()
                pass
            else:
                self.usage();
                return -1
            pass
        else:
            self.usage();
            return -1
        
        print("Committing template; please be (very) patient!")
        
        rval,response = do_method("template", "template_commit", params);
        return rval;
    
    def usage(self):
        print("template_commit [-w]")
        print("template_commit [-w] [-e eid | -r tag] <guid/vers>")
        print("template_commit [-w] -p pid -e eid")
        print("where:");
        print("     -w     - Wait for template to finish commit");
        print("     -e     - Commit from specific template instance (eid)")
        print("     -E     - A pithy sentence describing your experiment")
        print("     -t     - The template name (alphanumeric, no blanks)")
        print("     -p     - Project for -e option (pid)")
        print("    guid    - Template GUID")
        print("")
        print("By default, commit runs in the background, sending you email ");
        print("when the operation has completed. Use the -w option to wait");
        print("in the foreground, returning exit status. Email is still sent.");
        print("")
        print("Environment:")
        print("  cwd   The template will be inferred from the current")
        print("        working directory if it is inside a template checkout.")
        wrapperoptions();
        return
    pass

class template_export:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "i:r:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        instance = None
        params   = {}
        
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-i":
                params["instance"] = val
                instance = val
                pass
            elif opt == "-r":
                params["run"] = val
                pass
            pass
        
        # Try to infer the template guid/vers from the current path.
        if instance == None:
            self.usage();
            return -1
        
        rval,response = do_method("template", "export", params);
        return rval;
    
    def usage(self):
        print("template_export [-r runidx] -i instance_id");
        print("where:");
        print("     -i   - Export specific template instance (idx)");
        print("     -r   - Optional run index to export");
        print("")
        print("Environment:")
        print("  cwd   The template GUID will be inferred from the current")
        print("        working directory, if it is inside the templates's")
        print("        directory (e.g. /proj/foo/templates/10005/18).")
        wrapperoptions();
        return
    pass

class template_checkout:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "d", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        if (len(req_args) == 0):
            self.usage()
            return -1

        params         = {}
        params["guid"] = req_args[0]
        params["path"] = os.getcwd()
        
        rval,response = do_method("template", "checkout", params);
        return rval;
    
    def usage(self):
        print("template_checkout guid/vers");
        print("")
        print("Environment:")
        print("  cwd   The template checkout is placed in the current dir")
        wrapperoptions();
        return
    pass

#
# template_instantiate
#
class template_instantiate:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv,
                                           "bwqS:L:a:l:E:e:x:",
                                           [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        guid        = None
        xmlfilename = None
        params      = {}
        
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-b":
                params["batch"] = "yes";
                pass
            elif opt == "-E":
                params["description"] = val;
                pass
            elif opt == "-e":
                params["exp"] = val;
                pass
            elif opt == "-x":
                xmlfilename = val;
                pass
            elif opt == "-S":
                params["swappable"]     = "no";
                params["noswap_reason"] = val;
                pass
            elif opt == "-L":
                params["idleswap"]          = 0;
                params["noidleswap_reason"] = val;
                pass
            elif opt == "-l":
                params["idleswap"] = val;
                pass
            elif opt == "-a":
                params["max_duration"] = val;
                pass
            elif opt == "-f":
                params["noswapin"] = "yes"
                pass
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-p":
                params["preload"] = "yes"
                pass
            pass

        # Try to infer the template guid/vers from the current path.
        if len(req_args) == 0:
            guid = infer_guid(os.getcwd())
            if guid == None:
                (guid, subdir) = infer_template()
                if guid == None:
                    self.usage()
                    return -1
                pass
            pass
        elif len(req_args) == 1:
            guid = req_args[0]
            pass
        else:
            self.usage();
            return -1
        
        params["guid"] = guid

        if xmlfilename:
            try:
                params["xmlfilestr"] = open(xmlfilename).read();
                pass
            except:
                print("Could not open file: " + req_args[0]);
                return -1;
            pass
        
        rval,response = do_method("template", "instantiate", params);
        return rval;

    def usage(self):
        print("template_instantiate [-q] [-E description] [-p xmlfilename] ");
        print("     [-b] [-p] [-S reason] [-L reason] [-a <time>] [-l <time>]");
        print("     -e <eid> <guid>");
        print("where:");
        print("   -b   - queue for the batch system");
        print("   -p   - preload only; do not swapin");
        print("   -w   - wait for non-batchmode experiment to instantiate");
        print("   -q   - be less chatty");
        print("   -S   - Instance cannot be swapped; must provide reason");
        print("   -L   - Instance cannot be IDLE swapped; must provide reason");
        print("   -a   - Auto swapout NN minutes after instance is swapped in");
        print("   -l   - Auto swapout NN minutes after instance goes idle");
        print("   -E   - A pithy sentence describing your experiment");
        print("   -x   - XML file of parameter bindings");
        print("   -e   - The instance name (unique, alphanumeric, no blanks)");
        print("   guid - Template GUID");
        print("")
        print("Environment:")
        print("  cwd   The template GUID will be inferred from the current")
        print("        working directory if it is inside a template checkout.")
        wrapperoptions();
        return
    pass

#
# template_swapin
#
class template_swapin:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "wqe:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        guid   = None
        params = {}
        
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-q":
                params["quiet"] = "yes"
                pass
            elif opt == "-e":
                params["exp"]  = val;
                pass
            pass

        # Try to infer the template guid/vers from the current path.
        if len(req_args) == 0:
            guid = infer_guid(os.getcwd())
            if guid == None:
                self.usage();
                return -1
            pass
        elif len(req_args) == 1:
            guid = req_args[0]
        else:
            self.usage();
            return -1
            
        params["guid"] = guid

        rval,response = do_method("template", "swapin", params);
        return rval;

    def usage(self):
        print("template_swapin -e id [<guid/vers>]");
        print("where:");
        print("     -e   - Instance ID (aka eid)");
        print("     -q   - be less chatty");
        print("     -w   - Wait for instance to finish swapping in");
        print("    guid  - Template GUID");
        print("")
        print("Environment:")
        print("  cwd   The template GUID will be inferred from the current")
        print("        working directory, if it is inside the templates's")
        print("        directory (e.g. /proj/foo/templates/10005/18).")
        wrapperoptions();
        return
    pass

#
# template_swapout
#
class template_swapout:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "we:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        guid   = None
        params = {}
        
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-e":
                params["exp"]  = val;
                pass
            pass

        # Try to infer the template guid/vers from the current path.
        if len(req_args) == 0:
            guid = infer_guid(os.getcwd())
            if guid == None:
                self.usage();
                return -1
            pass
        elif len(req_args) == 1:
            guid = req_args[0]
        else:
            self.usage();
            return -1
            
        params["guid"] = guid

        rval,response = do_method("template", "swapout", params);
        return rval;

    def usage(self):
        print("template_swapout -e id [<guid/vers>]");
        print("where:");
        print("     -e   - Instance ID (aka eid)");
        print("     -w   - Wait for instance to finish terminating");
        print("    guid  - Template GUID");
        print("")
        print("Environment:")
        print("  cwd   The template GUID will be inferred from the current")
        print("        working directory, if it is inside the templates's")
        print("        directory (e.g. /proj/foo/templates/10005/18).")
        wrapperoptions();
        return
    pass

#
# template_startrun and template_modrun
#
class template_startrun:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "we:E:r:p:cx:my:",
                                           [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        pid         = None
        guid        = None
        xmlfilename = None
        params      = {}
        
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-E":
                params["description"] = val;
                pass
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-m":
                params["modify"] = "yes"
                pass
            elif opt == "-c":
                params["clear"] = "yes"
                pass
            elif opt == "-r":
                params["runid"] = val
                pass
            elif opt == "-y":
                params["params"] = val
                pass
            elif opt == "-p":
                pid = val
                pass
            elif opt == "-x":
                xmlfilename = val;
                pass
            elif opt == "-e":
                params["exp"]  = val;
                pass
            pass

        # Try to infer the template guid/vers from the current path.
        if pid == None:
            if len(req_args) == 0:
                guid = infer_guid(os.getcwd())
                if guid == None:
                    self.usage();
                    return -1
                pass
            elif len(req_args) == 1:
                guid = req_args[0]
                pass
            else:
                self.usage();
                return -1
            
            params["guid"] = guid
            pass
        else:
            params["pid"] = pid
            pass
        
        if xmlfilename:
            try:
                params["xmlfilestr"] = open(xmlfilename).read();
                pass
            except:
                print("Could not open file: " + req_args[0]);
                return -1;
            pass
        
        rval,response = do_method("template", "startrun", params);
        return rval;

    def usage(self):
        print("template_startrun [-r <id>] [-E <descr>] -e id [-p <pid> | <guid/vers>]");
        print("where:");
        print("     -E   - A pithy sentence describing your run");
        print("     -x   - XML file of parameter bindings");
        print("     -y   - Default params, one of template,instance,lastrun");
        print("     -r   - A token (id) for the run");
        print("     -e   - Instance ID (aka eid)");
        print("     -w   - Wait until run has started");
        print("     -m   - Reparse ns file (effectively a swap modify)");
        print("     -c   - run loghole clean before starting run");
        print("    guid  - Template GUID");
        print("")
        print("Environment:")
        print("  cwd   The template GUID will be inferred from the current")
        print("        working directory, if it is inside the templates's")
        print("        directory (e.g. /proj/foo/templates/10005/18).")
        wrapperoptions();
        return
    pass

class template_modrun:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "we:E:r:p:cx:my:",
                                           [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        pid         = None
        guid        = None
        xmlfilename = None
        params      = {}
        
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-E":
                params["description"] = val;
                pass
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-m":
                params["modify"] = "yes"
                pass
            elif opt == "-c":
                params["clear"] = "yes"
                pass
            elif opt == "-r":
                params["runid"] = val
                pass
            elif opt == "-y":
                params["params"] = val
                pass
            elif opt == "-p":
                pid = val
                pass
            elif opt == "-x":
                xmlfilename = val;
                pass
            elif opt == "-e":
                params["exp"]  = val;
                pass
            pass

        # Try to infer the template guid/vers from the current path.
        if pid == None:
            if len(req_args) == 0:
                guid = infer_guid(os.getcwd())
                if guid == None:
                    self.usage();
                    return -1
                pass
            elif len(req_args) == 1:
                guid = req_args[0]
                pass
            else:
                self.usage();
                return -1
            
            params["guid"] = guid
            pass
        else:
            params["pid"] = pid
            pass
        
        if xmlfilename:
            try:
                params["xmlfilestr"] = open(xmlfilename).read();
                pass
            except:
                print("Could not open file: " + req_args[0]);
                return -1;
            pass
        
        rval,response = do_method("template", "modrun", params);
        return rval;

    def usage(self):
        print("template_modrun [-r <id>] [-E <descr>] -e id [-p <pid> | <guid/vers>]");
        print("where:");
        print("     -E   - A pithy sentence describing your run");
        print("     -x   - XML file of parameter bindings");
        print("     -y   - Default params, one of template,instance,lastrun");
        print("     -r   - A token (id) for the run");
        print("     -e   - Instance ID (aka eid)");
        print("     -w   - Wait until run has started");
        print("     -m   - Reparse ns file (effectively a swap modify)");
        print("     -c   - run loghole clean before starting run");
        print("    guid  - Template GUID");
        print("")
        print("Environment:")
        print("  cwd   The template GUID will be inferred from the current")
        print("        working directory, if it is inside the templates's")
        print("        directory (e.g. /proj/foo/templates/10005/18).")
        wrapperoptions();
        return
    pass

#
# template_stoprun
#
class template_stoprun:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "we:qp:t:i", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        pid         = None
        guid        = None
        params      = {}
        
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-w":
                params["wait"] = "yes"
                pass
            elif opt == "-q":
                params["quiet"] = "yes"
                pass
            elif opt == "-p":
                pid = val
                pass
            elif opt == "-t":
                params["token"] = val;
                pass
            elif opt == "-i":
                params["ignoreerrors"] = "yes";
                pass
            elif opt == "-e":
                params["exp"] = val;
                pass
            pass

        # Try to infer the template guid/vers from the current path.
        if pid == None:
            if len(req_args) == 0:
                guid = infer_guid(os.getcwd())
                if guid == None:
                    self.usage();
                    return -1
                pass
            elif len(req_args) == 1:
                guid = req_args[0]
                pass
            else:
                self.usage();
                return -1
            params["guid"] = guid
            pass
        else:
            params["pid"] = pid
            pass

        rval,response = do_method("template", "stoprun", params);
        return rval;

    def usage(self):
        print("template_stoprun [-w] -e id [-p <pid> | <guid/vers>]");
        print("where:");
        print("     -e   - Instance ID (aka eid)");
        print("     -i   - Ignore errors and force Run to stop");
        print("     -w   - Wait for Run to finish stopping");
        print("    guid  - Template GUID");
        print("")
        print("Environment:")
        print("  cwd   The template GUID will be inferred from the current")
        print("        working directory, if it is inside the templates's")
        print("        directory (e.g. /proj/foo/templates/10005/18).")
        wrapperoptions();
        return
    pass

#
# mkblob
#
class mkblob:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "h", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0

        # Do this after so --help is seen.
        if len(req_args) != 1:
            self.usage();
            return -1;

        rval,response = do_method( "blob", "mkblob",
                                   { "filename" : req_args[ 0 ] } );
        return rval;

    def usage(self):
        print("mkblob [options] filename")
        wrapperoptions();
        return
    pass

#
# rmblob
#
class rmblob:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "h", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0

        # Do this after so --help is seen.
        if len(req_args) != 1:
            self.usage();
            return -1;

        rval,response = do_method( "blob", "rmblob",
                                   { "uuid" : req_args[ 0 ] } );
        return rval;

    def usage(self):
        print("rmblob [options] uuid")
        wrapperoptions();
        return
    pass

#
# createdataset
#
class createdataset:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "hUs:t:e:f:", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-U":
                params["noapprove"] = "yes";
                pass
            elif opt == "-s":
                params["size"] = val;
                pass
            elif opt == "-t":
                params["type"] = val;
                pass
            elif opt == "-f":
                params["fstype"] = val;
                pass
            elif opt == "-e":
                params["expire"] = val;
                pass
            pass

        # Do this after so --help is seen.
        if len(req_args) < 1 or "size" not in params:
            self.usage();
            return -1;

        # Warn about filesystem creation
        if "fstype" in params:
            print("WARNING: FS creation can take 5 minutes or longer, be patient!");
            pass

        # Send the rest of the args along as a list.
        params["dataset"] = req_args[0];

        rval,response = do_method("dataset", "create", params);
        return rval;

    def usage(self):
        print("createdataset [-hU] [-t type] [-e expire] [-f fstype] -s size dataset_id");
        print("where:");
        print("    -U        - Create but do not approve dataset");
        print("    -s size   - Size in MiB (1 MiB == 1024*1024)");
        print("    -t type   - Type: one of 'stdataset' (default) or 'ltdataset'");
        print("    -f fstype - Filesystem type: one of 'ext2', 'ext3', 'ext4', 'ufs' (default is no filesystem creation)");
        print("    -e expire - Expiration date ('0' == never, default is system defined)");
        print("");
        print("Create a dataset with the indicated size and name");
        wrapperoptions();
        return
    pass

#
# deletedataset
#
class deletedataset:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "hf", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-f":
                params["force"] = "yes";
                pass
            pass

        # Do this after so --help is seen.
        if len(req_args) < 1:
            self.usage();
            return -1;

        # Send the rest of the args along as a list.
        params["dataset"] = req_args[0];

        rval,response = do_method("dataset", "delete", params);
        return rval;

    def usage(self):
        print("deletedataset [-hf] dataset_id");
        print("where:");
        print("    -f        - Try extra hard to delete the dataset");
        print("");
        print("Delete the dataset with the indicated name.");
        print("The -f flag allows destruction of a dataset that is");
        print("currently mapped into an experiment or that is not in");
        print("the expired state. Obviously, this option should be used");
        print("with caution.")
        wrapperoptions();
        return
    pass

#
# extenddataset
#
class extenddataset:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "h", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            pass

        # Do this after so --help is seen.
        if len(req_args) < 1:
            self.usage();
            return -1;

        # Send the rest of the args along as a list.
        params["dataset"] = req_args[0];

        rval,response = do_method("dataset", "extend", params);
        return rval;

    def usage(self):
        print("extenddataset [-h] dataset_id");
        print("");
        print("Extend the lease on the dataset with the indicated name.");
        print("The lease will be extended by a fixed, site-specific length");
        print("of time. Only datasets in the 'grace' state can be extended.");
        wrapperoptions();
        return
    pass

#
# showdataset
#
class showdataset:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "Dau:p:hl", [ "help" ]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-D":
                params["limits"] = "yes";
                pass
            elif opt == "-a":
                params["all"] = "yes";
                pass
            elif opt == "-l":
                params["verbose"] = "yes";
                pass
            elif opt == "-u":
                params["user"] = val;
                pass
            elif opt == "-p":
                params["proj"] = val;
                pass
            pass

        # Send the rest of the args along as a list.
        params["datasets"] = req_args;

        rval,response = do_method("dataset", "getlist", params);
        return rval;

    def usage(self):
        print("showdataset [-hDal] [-p pid] [-u uid] dataset_id...");
        print("where:");
        print("    -D     - Describe the site-specific limits of datasets");
        print("    -a     - Show all datasets");
        print("    -l     - Long listing");
        print("    -p pid - Show all datasets for given project");
        print("    -u uid - Show all datasets for given user");
        print("");
        print("Describe the site-specific limits on the size/duration");
        print("of the different dataset types (-D), or");
        print("");
        print("Show all (-a) datasets or those associated with a particular");
        print("project (-p), user (-u), or those listed.");
        print("Only one of -a, -p, -u or an explicit list should be specified.");
        wrapperoptions();
        return
    pass

#
# start a portal experiment
#
class startExperiment:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "a:p:Ps",
                                           [ "help", "name=", "duration=",
                                             "project=", "site=", "start=",
                                             "bindings=",
                                             "stop=", "paramset=", "refspec="]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-a":
                params["aggregate"] = val
                pass
            elif opt == "-P":
                params["nopending"] = 1
                pass
            elif opt == "-s":
                params["noemail"] = 1
                pass
            elif opt == "--name":
                params["name"] = val;
                pass
            elif opt == "--duration":
                params["duration"] = val;
                pass
            elif opt in ("-p", "--project"):
                params["proj"] = val;
                pass
            elif opt == "--start":
                params["start"] = val;
                pass
            elif opt == "--stop":
                params["stop"] = val;
                pass
            elif opt == "--paramset":
                params["paramset"] = val;
                pass
            elif opt == "--bindings":
                params["bindings"] = val;
                pass
            elif opt == "--refspec":
                params["refspec"] = val;
                pass
            elif opt == "--site":
                params["site"] = val;
                pass
            pass

        # Do this after so --help is seen.
        if len(req_args) != 1:
            self.usage();
            return -1;

        params["profile"] = req_args[0]
        rval,response = do_method("portal", "startExperiment", params)
        return rval

    def usage(self):
        print("Usage: startExperiment <optons> ", end=' ')
        "[--site 'site:1=aggregate ...'] <profile>"
        print("where:")
        print(" -d           - Turn on debugging (run in foreground)")
        print(" -w           - Wait mode (wait for experiment to start)")
        print(" -s           - Do not send status email")
        print(" -P           - Do not pend deferrable aggregates")
        print(" -a urn       - Override default aggregate URN")
        print(" --project    - pid[,gid]: project[,group] for new experiment")
        print(" --name       - Optional pithy name for experiment")
        print(" --duration   - Number of hours for initial expiration")
        print(" --start      - Schedule experiment to start at (unix) time")
        print(" --stop       - Schedule experiment to stop at (unix) time")
        print(" --paramset   - uid,name of a parameter set to apply")
        print(" --bindings   - json string of bindings to apply to parameters")
        print(" --refspec    - refspec[:hash] of a repo based profile to use")
        print(" --site       - Bind sites used in the profile")
        print("profile       - Either UUID or pid,name")
        wrapperoptions();
        return
    pass

#
# Terminate a portal experiment
#
class terminateExperiment:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "h", [ "help"]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            pass

        # Do this after so --help is seen.
        if len(req_args) != 1:
            self.usage();
            return -1;

        params["experiment"] = req_args[0]
        rval,response = do_method("portal", "terminateExperiment", params)
        return rval

    def usage(self):
        print("Usage: terminateExperiment <optons> <experiment>")
        print("where:")
        print("experiment     - Either UUID or pid,name")
        wrapperoptions();
        return
    pass

#
# Extend a portal experiment
#
class extendExperiment:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "hm:f:", [ "help"]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;

        reason = ""
        params = {}
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-m":
                reason = val
                pass
            elif opt == "-f":
                try:
                    reason = open(val).read();
                    pass
                except:
                    print("Could not open file: " + val);
                    return -1;
            pass

        # Do this after so --help is seen.
        if len(req_args) != 2:
            self.usage();
            return -1;

        params["experiment"] = req_args[0]
        params["wanted"]     = req_args[1]
        params["reason"]     = reason
        rval,response = do_method("portal", "extendExperiment", params)
        return rval

    def usage(self):
        print("Usage: extendExperiment <optons> <experiment> <hours>")
        print("where:")
        print(" -m str        - Your reason for the extension (a string)")
        print(" -f file       - A file containing your reason")
        print("experiment     - Either UUID or pid,name")
        print("hours          - Number of hours to extend")
        wrapperoptions();
        return
    pass

#
# Get status for a portal experiment
#
class experimentStatus:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "hjr", [ "help"]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-j":
                params["asjson"] = 1
                pass
            elif opt == "-r":
                params["refresh"] = 1
                pass
            pass

        # Do this after so --help is seen.
        if len(req_args) != 1:
            self.usage();
            return -1;

        params["experiment"] = req_args[0]
        rval,response = do_method("portal", "experimentStatus", params)
        return rval

    def usage(self):
        print("Usage: experimentStatus <optons> <experiment>")
        print("where:")
        print(" -j            - json string instead of text")
        print("experiment     - Either UUID or pid,name")
        wrapperoptions();
        return
    pass

#
# Get manifests for a portal experiment
#
class experimentManifests:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "h", [ "help"]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            pass

        # Do this after so --help is seen.
        if len(req_args) != 1:
            self.usage();
            return -1;

        params["experiment"] = req_args[0]
        rval,response = do_method("portal", "experimentManifests", params)
        return rval

    def usage(self):
        print("Usage: experimentManifests <optons> <experiment>")
        print("where:")
        print("experiment     - Either UUID or pid,name")
        wrapperoptions();
        return
    pass

#
# Reboot nodes in a portal experiment
#
class experimentReboot:
    def __init__(self, argv=None):
        self.argv = argv;
        return

    def apply(self):
        try:
            opts, req_args = getopt.getopt(self.argv, "hf", [ "help"]);
            pass
        except getopt.error as e:
            print(e.args[0])
            self.usage();
            return -1;
        
        params = {};
        for opt, val in opts:
            if opt in ("-h", "--help"):
                self.usage()
                return 0
            elif opt == "-f":
                params["power"] = 1
                pass
            pass

        # Do this after so --help is seen.
        if len(req_args) < 2:
            self.usage();
            return -1;

        params["experiment"] = req_args.pop(0)
        params["nodes"]  = str.join(",", req_args)
        rval,response = do_method("portal", "reboot", params)
        return rval

    def usage(self):
        print("Usage: experimentStatus <optons> <experiment> node [node ...]")
        print("where:")
        print(" -f            - power cycle instead of reboot")
        print("experiment     - Either UUID or pid,name")
        print("node           - List of node client ids to reboot")
        wrapperoptions();
        return
    pass

#
# Infer template guid from path
#
def infer_guid(path):
    guid = None
    vers = None
    dirs = path.split(os.path.sep)
    if ((len(dirs) < 6) or
        (not (("proj" in dirs) and ("templates" in dirs))) or
        (len(dirs) < (dirs.index("templates") + 2))):
        return None
    else:
        guid = dirs[dirs.index("templates") + 1]
        vers = dirs[dirs.index("templates") + 2]
        pass
    return guid + "/" + vers

#
# Different version, that crawls up tree looking for .template file.
# Open up file and get the guid/vers, but also return path of final directory.
#
def infer_template():
    rootino = os.stat("/").st_ino
    cwd     = os.getcwd()
    guid    = None
    vers    = None
    subdir  = None

    try:
        while True:
            if os.access(".template", os.R_OK):
                fp = open(".template")
                line = fp.readline()
                while line:
                    m = re.search('^GUID:\s*([\w]*)\/([\d]*)$', line)
                    if m:
                        guid    = m.group(1)
                        vers    = m.group(2)
                        subdir  = os.getcwd()
                        fp.close();
                        return (guid + "/" + vers, subdir)
                    line = fp.readline()
                    pass
                fp.close();
                break
            if os.stat(".").st_ino == rootino:
                break
            os.chdir("..")
            pass
        pass
    except:
        pass
        
    os.chdir(cwd)
    return (guid, subdir)    
    pass

#
# Infer pid and eid
#
def infer_pideid(path):
    pid = None
    eid = None
    dirs = path.split(os.path.sep)
    if ((len(dirs) < 6) or
        (not (("proj" in dirs) and ("exp" in dirs))) or
        (len(dirs) < (dirs.index("exp") + 1))):
        return (None, None)
    else:
        pid = dirs[dirs.index("proj") + 1]
        eid = dirs[dirs.index("proj") + 3]
        pass
    return (pid, eid)

#
# Process program arguments. There are two ways we could be invoked.
# 1) as the wrapper, with the first required argument the name of the script.
# 2) as the script, with the name of the script in argv[0].
# ie:
# 1) wrapper --server=boss.emulab.net node_admin -n pcXXX
# 2) node_admin --server=boss.emulab.net -n pcXXX
#
# So, just split argv into the first part (all -- args) and everything
# after that which is passed to the handler for additional getopt parsing.
#
wrapper_argv = [];

for arg in sys.argv[1:]:
    if arg.startswith("--"):
        wrapper_argv.append(arg);
        pass
    else:
        break
    pass

try:
    # Parse the options,
    opts, req_args =  getopt.getopt(wrapper_argv[0:], "",
                      [ "help", "server=", "port=", "login=", "cert=", "admin", "devel",
                        "develuser=", "impotent", "debug",
                        "cacert=", "verify" ])
    # ... act on them appropriately, and
    for opt, val in opts:
        if opt in ("-h", "--help"):
            usage()
            sys.exit()
            pass
        elif opt == "--server":
            xmlrpc_server = val
            pass
        elif opt == "--port":
            xmlrpc_port = int(val)
            pass
        elif opt == "--login":
            login_id = val
            pass
        elif opt == "--cert":
            certificate = val
            pass
        elif opt == "--cacert":
            ca_certificate = val
            pass
        elif opt == "--verify":
            verify = True
            pass
        elif opt == "--debug":
            debug = 1
            pass
        elif opt == "--impotent":
            impotent = 1
            pass
        elif opt == "--admin":
            admin = 1
            pass
        elif opt == "--devel":
            devel = 1
            pass
        elif opt == "--develuser":
            develuser = val
            pass
        pass
    pass
except getopt.error as e:
    print(e.args[0])
    usage()
    sys.exit(2)
    pass

# Check some default locations for the Emulab CA certificate, if user
# requested verification but did not specify a CA cert.
if verify:
    if ca_certificate == None:
        for p in [ SERVER_PATH + "/etc/emulab.pem", "/etc/emulab/emulab.pem" ]:
            if os.access(p,os.R_OK):
                ca_certificate = p
                break
    if ca_certificate is not None and not os.access(ca_certificate, os.R_OK):
        print("CA Certificate cannot be accessed: " + ca_certificate)
        sys.exit(-1);
    pass

if admin:
    path = SERVER_PATH
    if devel:
        path += "/" + DEVEL_DIR
        if develuser:
            path += "/" + develuser
            pass
        else:
            path += "/" + login_id
            pass
        pass
    path += "/" + SERVER_DIR
    pass

#
# Okay, determine if argv[0] is the name of the handler, or if this was
# invoked generically (next token after wrapper args is the name of the
# handler).
#
handler      = None;
command_argv = None;

if os.path.basename(sys.argv[0]) in API:
    handler      = API[os.path.basename(sys.argv[0])]["func"];
    command_argv = sys.argv[len(wrapper_argv) + 1:];
    pass
elif (len(wrapper_argv) == len(sys.argv) - 1):
    # No command token was given.
    usage();
    sys.exit(-2);
    pass
else:
    token = sys.argv[len(wrapper_argv) + 1];

    if token not in API:
        print("Unknown script command, ", token)
        usage();
        sys.exit(-1);
        pass

    handler      = API[token]["func"];
    command_argv = sys.argv[len(wrapper_argv) + 2:];
    pass

instance = eval(handler + "(argv=command_argv)");
exitval  = instance.apply();
sys.exit(exitval);
