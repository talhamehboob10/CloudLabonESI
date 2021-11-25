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

import sys
import socket
import os
import os.path
import stat
import tempfile
import time
import re
import string
import pwd
import grp
import errno
import signal
import types
import datetime
import syslog
import subprocess
import json
try:
    import xmlrpclib
except:
    import xmlrpc.client as xmlrpclib

# Configure variables
TBDIR = "/users/mshobana/emulab-devel/build"
BOSSNODE = "boss.cloudlab.umass.edu"
BOSSEVENTPORT = "16505"
OURDOMAIN = "cloudlab.umass.edu"
USERNODE = "ops.cloudlab.umass.edu"
BASEADDR = "239.67.170"
BASEPORT = "6000"
SUBBOSS_UID = "elabman"
PREDICT = "/users/mshobana/emulab-devel/build/sbin/predict"

TBPATH = os.path.join(TBDIR, "lib")
if TBPATH not in sys.path:
    sys.path.append(TBPATH)
    pass

from libdb        import *
from libtestbed   import SENDMAIL, TBOPS
from emulabclient import *

# Version
VERSION = 0.1

# Well known directories
PROJROOT = "/proj"
GROUPROOT = "/groups"
SCRATCHROOT = ""
SHAREROOT = "/share"
USERSROOT = "/users"

# List of directories exported to nodes via NFS.
NFS_EXPORTS = [
    PROJROOT,
    GROUPROOT,
    SHAREROOT,
    USERSROOT,
    SCRATCHROOT,
    ]

#
# XXX
# This mirrors db/xmlconvert. Be sure to keep this table in sync with that table.
#
virtual_tables = {
    "experiments"		: { "rows"  : None, 
                                    "tag"   : "experiment",
                                    "attrs" : [ ] },
    "virt_nodes"		: { "rows"  : None, 
                                    "tag"   : "nodes",
                                    "attrs" : [ "vname" ]},
    "virt_lans"                 : { "rows"  : None, 
                                    "tag"   : "lans",
                                    "attrs" : [ "vname" ]},
    "virt_lan_lans"             : { "rows"  : None, 
                                    "tag"   : "lan_lans",
                                    "attrs" : [ "vname" ]},
    "virt_lan_settings"         : { "rows"  : None, 
                                    "tag"   : "lan_settings",
                                    "attrs" : [ "vname", "capkey" ]},
    "virt_lan_member_settings"  : { "rows"  : None, 
                                    "tag"   : "lan_member_settings",
                                    "attrs" : [ "vname", "member", "capkey" ]},
    "virt_trafgens"		: { "rows"  : None, 
                                    "tag"   : "trafgens",
                                    "attrs" : [ "vname", "vnode" ]},
    "virt_agents"		: { "rows"  : None, 
                                    "tag"   : "agents",
                                    "attrs" : [ "vname", "vnode" ]},
    "virt_node_desires"         : { "rows"  : None, 
                                    "tag"   : "node_desires",
                                    "attrs" : [ "vname", "desire" ]},
    "virt_node_startloc"        : { "rows"  : None,
                                    "tag"   : "node_startlocs",
                                    "attrs" : [ "vname", "building" ]},
    "virt_routes"		: { "rows"  : None, 
                                    "tag"   : "routes",
                                    "attrs" : [ "vname", "src", "dst" ]},
    "virt_vtypes"		: { "rows"  : None, 
                                    "tag"   : "vtypes",
                                    "attrs" : [ "name" ]},
    "virt_programs"		: { "rows"  : None, 
                                    "tag"   : "programs",
                                    "attrs" : [ "vname", "vnode" ]},
    "virt_user_environment"	: { "rows"  : None, 
                                    "tag"   : "user_environment",
                                    "attrs" : [ "name", "value" ]},
    "nseconfigs"		: { "rows"  : None, 
                                    "tag"   : "nseconfigs",
                                    "attrs" : [ "vname" ]},
    "eventlist"                 : { "rows"  : None, 
                                    "tag"   : "events",
                                    "attrs" : [ "vname" ]},
    "event_groups"              : { "rows"  : None,
                                    "tag"   : "event_groups",
                                    "attrs" : [ "group_name", "agent-name" ]},
    "virt_firewalls"            : { "rows"  : None,
                                    "tag"   : "virt_firewalls",
                                    "attrs" : [ "fwname", "type", "style" ]},
    "firewall_rules"            : { "rows"  : None,
                                    "tag"   : "firewall_rules",
                                    "attrs" : [ "fwname", "ruleno", "rule" ]},
    "virt_tiptunnels"           : { "rows"  : None,
                                    "tag"   : "tiptunnels",
                                    "attrs" : [ "host", "vnode" ]},
    }
    
# Base class for emulab specific exceptions.
class EmulabError(Exception):
    pass

# Exception thrown when logins are not allowed.
class NoLoginsError(EmulabError):
    pass

# Exception thrown an unknown user tries to import this module.
class UnknownUserError(EmulabError):
    pass

# Exception thrown when a timer expires.
class TimedOutError(EmulabError):
    pass

def TimeoutHandler(signum, frame):
    raise TimedOutError('Timer Expired')

def logit(debug, msg):
    if debug:
        print(msg)
        pass
    else:
        syslog.syslog(syslog.LOG_INFO, msg);
        pass
    return

#
# Arguments to methods are passed as a Dictionary. This converts to a XML
# "struct" which in Perl/PHP/Ruby would be a hash. So, a client written in
# pretty much any language should be able to talk to this class.
#
#
# A helper function for checking required arguments.
#
def CheckRequiredArgs(argdict, arglist):
    # proj,group,exp are aliases for pid,gid,eid
    if ("pid" in argdict and "proj" not in argdict):
        argdict["proj"] = argdict["pid"]
        pass
    if ("gid" in argdict and "group" not in argdict):
        argdict["group"] = argdict["gid"]
        pass
    if ("eid" in argdict and "exp" not in argdict):
        argdict["exp"] = argdict["eid"]
        pass

    # Okay, now check.
    for arg in arglist:
        if arg not in argdict:
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Must supply '" + arg + "'")
        pass
    return None

#
# Check user permission to access a project.
#
def CheckProjPermission(uid_idx, pid):
    if not re.match("^[-\w]*$", pid):
        return EmulabResponse(RESPONSE_BADARGS,
                              output="Illegal characters in project ID!")

    res = DBQueryFatal("SELECT trust FROM group_membership "
                       "WHERE uid_idx=%s and pid=%s and gid=%s and trust!='none'",
                       (uid_idx, pid, pid))

    if len(res) == 0:
        return EmulabResponse(RESPONSE_FORBIDDEN,
                              output=("You do not have permission to " +
                                      "access project: " + pid))
    
    return None

def GetProjects(uid_idx):
    res = DBQueryFatal("SELECT distinct pid FROM group_membership "
                       "WHERE uid_idx=%s",
                       (uid_idx,))

    return [x[0] for x in res]


#
# Check user permission to access an experiment.
# 
def CheckExptPermission(uid_idx, pid, eid):
    if not (re.match("^[-\w]*$", pid) and
            re.match("^[-\w]*$", eid)):
        return EmulabResponse(RESPONSE_BADARGS,
                  output="Illegal characters in project and/or experiment IDs!")
    
    res = DBQueryFatal("SELECT gid FROM experiments "
                       "WHERE pid=%s and eid=%s",
                       (pid, eid))

    if len(res) == 0:
        return EmulabResponse(RESPONSE_ERROR,
                              output="No such experiment: " +
                              pid + "/" + eid)

    gid = res[0][0]
    
    res = DBQueryFatal("SELECT trust FROM group_membership "
                       "WHERE uid_idx=%s and pid=%s and gid=%s",
                       (uid_idx, pid, gid))

    if len(res) == 0:
        return EmulabResponse(RESPONSE_FORBIDDEN,
                              output=("You do not have permission to " +
                                      "access experiment: " + pid + "/" + eid))
    return None

#
# Check user permission to access a node.
# 
def CheckNodePermission(uid_idx, node):
    res = DBQueryFatal("SELECT e.pid,e.eid FROM reserved AS r "
                       "left join experiments as e on "
                       "     e.pid=r.pid and e.eid=r.eid "
                       "WHERE r.node_id=%s",
                       (node,))
    
    if len(res) == 0:
        return EmulabResponse(RESPONSE_ERROR,
                              output="No such node: " + node)

    return CheckExptPermission(uid_idx, res[0][0], res[0][1])

#
# Check if user is an admin person
# 
def CheckIsAdmin(uid_idx):
    res = DBQueryFatal("SELECT admin FROM users "
                       "WHERE uid_idx=%s and status='active'",
                       (uid_idx,))
    
    if len(res) == 0:
        return EmulabResponse(RESPONSE_ERROR,
                              output="No such user: " + uid_idx)

    return res[0][0];

#
# Template lookup, by exptidx of an experiment.
#
def TemplateLookup(exptidx):
    res = DBQueryFatal("select parent_guid,parent_vers from "
                       "   experiment_template_instances "
                       "where exptidx=%s",
                       (exptidx,))
    
    if len(res) == 0:
        return None

    return (res[0][0], res[0][1])

#
# Get an experiment index.
#
def ExperimentIndex(pid, eid):
    res = DBQueryFatal("select idx from experiments "
                       "where pid=%s and eid=%s",
                       (pid, eid))
    
    if len(res) == 0:
        return None
    
    return res[0][0];

#
# This is a wrapper class so that you can invoke methods in dotted form.
# For example experiment.swapexp(...).
#
class EmulabServer:
    def __init__(self, uid, uid_idx, readonly=0, clientip=None, debug=0):
        self.readonly  = readonly;
        self.clientip  = clientip;
        self.debug     = debug;
        self.instances = {};
        self.uid_idx   = uid_idx;
        self.uid       = uid;

        self.instances["experiment"] = experiment(self);
        self.instances["template"]   = template(self);
        if readonly:
            return
        
        self.instances["emulab"]     = emulab(self);
        self.instances["user"]       = user(self);
        self.instances["fs"]         = fs(self);
        self.instances["imageid"]    = imageid(self);
        self.instances["osid"]       = osid(self);
        self.instances["node"]       = node(self);
        self.instances["elabinelab"] = elabinelab(self);
        self.instances["subboss"]    = subboss(self);
        self.instances["blob"]       = blob(self);
        self.instances["dataset"]    = dataset(self);
        self.instances["portal"]     = portal(self);
        return

    def __getattr__(self, name):
        dotted = name.split(".");
        if len(dotted) != 2:
            raise AttributeError("Bad name '%s'" % name)
        if dotted[0] not in self.instances:
            raise AttributeError("unknown method '%s' (readonly=%d)" %
                                 (name, self.readonly))
        
        return getattr(self.instances[dotted[0]], dotted[1]);
    pass

#
# This class implements the server side of the XMLRPC interface to emulab as a
# whole.
#
class emulab:
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    #
    # Get the global 'notice' message that is usually printed under the menu
    # on the web site.
    #
    def message(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        msg = TBGetSiteVar("web/message")

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=msg,
                              output=msg)

    #
    # Get the news items as a list of {subject,author,date,msgid} items for
    # dates between an option start and ending.
    #
    def news(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        # Process optional arguments.
        starting = None;
        if "starting" in argdict:
            if not re.match("^[-:\w]*$", str(argdict["starting"])):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="Improperly formed 'starting'!")
            starting = sqldate(argdict["starting"])
            pass

        ending = None
        if "ending" in argdict:
            if not re.match("^[-:\w]*$", str(argdict["ending"])):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="Improperly formed 'ending'!")
            ending = sqldate(argdict["ending"])
            pass

        # Construct the SQL date comparison
        if starting and ending:
            comparison = "BETWEEN %s and %s"
            sub = (starting, ending)
        elif starting:
            comparison = "> %s"
            pass
            sub = (starting,)
            pass
        elif ending:
            comparison = "< %s"
            sub = (ending,)
            pass
        else:
            comparison = ""
            sub = ()
            pass

        # Get the headlines and
        dbres = DBQueryFatal("SELECT subject,author,date,msgid FROM webnews "
                             "WHERE date "
                             + comparison
                             + " ORDER BY date DESC",
                             sub)

        # ... package them up
        result = []
        for res in dbres:
            tmp = {}
            tmp["subject"] = res[0]
            tmp["author"] = res[1]
            tmp["date"] = xmlrpclib.DateTime(
                time.strptime(str(res[2]), "%Y-%m-%d %H:%M:%S"))
            tmp["msgid"] = res[3]
            
            result.append(tmp)
            pass

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    def getareas(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        # Get the listing that is accessible to this user and
        res = DBQueryFatal("SELECT distinct building FROM obstacles")

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No areas?")

        result = {}
        for area in res:
            result[area[0]] = {
                "name" : area[0]
                }
            pass

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    def vision_config(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if not re.match("^[-:\w]*$", str(argdict["area"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed 'area'!")

        result = DBQuery("select * from cameras where building=%s",
                        (argdict["area"],),
                        asDict=True)
        
        if len(result) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Unknown area " + argdict["area"])

        result = [scrubdict(x, defaultvals={ "loc_x" : 0.0, "loc_y" : 0.0 })
                  for x in result]

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    def obstacle_config(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if not re.match("^[-:\w]*$", str(argdict["area"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed 'area'!")

        if "units" not in argdict:
            argdict["units"] = "pixels"
            pass
        
        res = DBQuery("select * from obstacles where building=%s",
                      (argdict["area"],),
                      asDict=True)

        ppm = DBQueryFatal("select pixels_per_meter from floorimages "
                           "where building=%s",
                           (argdict["area"],))
        
        if len(res) == 0 or len(ppm) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such area " + argdict["area"])

        ppm = ppm[0][0]

        for ob in res:
            if argdict["units"] == "meters":
                ob["x1"] = ob["x1"] / ppm
                ob["y1"] = ob["y1"] / ppm
                ob["z1"] = ob["z1"] / ppm
                ob["x2"] = ob["x2"] / ppm
                ob["y2"] = ob["y2"] / ppm
                ob["z2"] = ob["z2"] / ppm
                pass
            scrubdict(ob)
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS,
                              value=res,
                              output=str(res))
    
    pass


#
# This class implements the server side of the XMLRPC interface to user
# specific information.
#
class user:
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    #
    # Get the number of nodes this user is has allocated.
    #
    def nodecount(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        res = DBQueryFatal(
            "SELECT a.node_id FROM nodes AS a "
            "left join reserved as b on a.node_id=b.node_id "
            "left join node_types as nt on a.type=nt.type "
            "left join experiments as e on b.pid=e.pid and "
            " b.eid=e.eid "
            "WHERE e.expt_head_uid=%s and e.pid!='emulab-ops' "
            "  and a.role='testnode' and nt.class = 'pc'",
            (self.uid,))

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=len(res),
                              output=str(len(res)))

    #
    # Get the listing of projects/groups that this user is a member of and,
    # optionally, has the permission to perform some task.
    #
    def membership(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        permission = "readinfo"
        if "permission" in argdict:
            permission = argdict["permission"]
            pass

        # Convert the permission to a SQL condition.
        if permission == "readinfo":
            trust_clause = "trust!='none'"
            pass
        elif permission == "makegroup":
            trust_clause = "trust='project_root'"
            pass
        elif permission == "createexpt":
            trust_clause = ("(trust='project_root' or trust='group_root' or "
                            " trust='local_root')")
            pass
        elif permission == "makeosid" or permission == "makeimageid":
            # XXX Handle admin
            trust_clause = ("(trust='project_root' or trust='group_root' or "
                            " trust='local_root')")
            pass
        else:
            return EmulabResponse(RESPONSE_BADARGS,
                                  output=("Bad permission value: "
                                          + permission))

        res = DBQueryFatal("SELECT distinct pid,gid FROM group_membership "
                           "WHERE uid_idx=%s and "
                           + trust_clause
                           + " ORDER BY pid",
                           (self.uid_idx,))

        result = {}
        for proj in res:
            if proj[0] in result:
                # Add group to existing project list
                tmp = result[proj[0]]
                tmp.append(proj[1])
                pass
            else:
                # Add new project to root list
                tmp = [proj[1],]
                result[proj[0]] = tmp
                pass
            pass

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    #
    # Return collab password,
    #
    def collabpassword(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        res = DBQueryFatal("select mailman_password from users where uid_idx=%s",
                           (self.uid_idx,))

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such user!")

        passwd = res[0][0]
        return EmulabResponse(RESPONSE_SUCCESS, value=passwd, output=passwd)

    pass


#
# This class implements the server side of the XMLRPC interface to the emulab
# NFS exports.
#
class fs:
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    #
    # Check the accessibility of a path.
    #
    def access(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!");

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("permission", "path"))
        if (argerror):
            return argerror

        try:
            path = nfspath(argdict["path"]) # Scrub the path
            
            permission = argdict["permission"]

            # Convert the permission to a python compatible value.
            if permission == "read" or permission == "r":
                accessmode = os.R_OK
                pass
            elif permission == "write" or permission == "w":
                accessmode = os.W_OK
                pass
            elif permission == "execute" or permission == "x":
                accessmode = os.X_OK
                pass
            elif permission == "exists" or permission == "e":
                accessmode = os.F_OK
                pass
            else:
                return EmulabResponse(RESPONSE_BADARGS,
                                      output=("Bad permission value: "
                                              + permission))
            
            res = os.access(path, accessmode)

            return EmulabResponse(RESPONSE_SUCCESS,
                                  value=res,
                                  output=str(res))
        except OSError as e:
            return EmulabResponse(RESPONSE_ERROR,
                                  value=e,
                                  output=(e.strerror + ": " + e.filename))

        # Never reached...
        assert False
        pass

    #
    # Get a directory listing for a given path.
    #
    def listdir(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("path",))
        if (argerror):
            return argerror

        try:
            path = nfspath(argdict["path"]) # Scrub the path

            # Make sure the path is accessible,
            if not os.access(path, os.X_OK):
                raise OSError(errno.EPERM, "Path is not accessible", path)

            # ... get the directory listing, and
            res = os.listdir(path)

            # ... package it up into a platform independent from.
            result = []
            for entry in res:
                try:
                    st = os.stat(os.path.join(path, entry))
                    # The UID/GID will be meaningless to the other side,
                    # resolve them before sending it back.
                    try:
                        uname = pwd.getpwuid(st[stat.ST_UID])[0]
                        pass
                    except:
                        # Unknown UID, just send the number as a string
                        uname = str(st[stat.ST_UID])
                        pass
                    try:
                        gname = grp.getgrgid(st[stat.ST_GID])[0]
                        pass
                    except:
                        # Unknown GID, just send the number as a string
                        gname = str(st[stat.ST_GID])
                        pass
                    result.append((entry,
                                   filetype(st[stat.ST_MODE]),
                                   stat.S_IMODE(st[stat.ST_MODE]),
                                   uname,
                                   gname,
                                   st[stat.ST_SIZE],
                                   st[stat.ST_ATIME],
                                   st[stat.ST_MTIME],
                                   st[stat.ST_CTIME]))
                except OSError:
                    pass
                pass
            retval = EmulabResponse(RESPONSE_SUCCESS,
                                    value=result,
                                    output=str(result))
            pass
        except OSError as e:
            retval = EmulabResponse(RESPONSE_ERROR,
                                    value=e,
                                    output=(e.strerror + ": " + e.filename))
            pass

        return retval

    #
    # Get the list of potential NFS exports for an experiment.
    #
    def exports(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        # Start with the default set of exports, then
        res = [
            USERSROOT + "/" + self.uid, # XXX Use getpwuid() and handle admin
            SHAREROOT,
            ]

        # ... add the project/group listings.
        projs = DBQueryFatal("SELECT distinct pid,gid FROM group_membership "
                             "WHERE uid_idx=%s and trust!='none' ORDER BY pid",
                             (self.uid_idx,))

        for proj in projs:
            if proj[0] == proj[1]:
                res.append(PROJROOT + "/" + proj[0])
                if not SCRATCHROOT == "":
                    res.append(SCRATCHROOT + "/" + proj[0])
                    pass
                pass
            else:
                res.append(GROUPROOT + "/" + proj[0] + "/" + proj[1])
                pass
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS,
                              value=res,
                              output=str(res))

    pass


#
# This class implements the server side of the XMLRPC interface to image IDs.
#
class imageid:
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    def getlist(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        # Get the listing that is accessible to this user and
        res = DBQueryFatal(
            "SELECT distinct i.imagename,v.description FROM images as i "
            "left join image_versions as v on "
            "     v.imageid=o.imageid and v.version=i.version "
            "left join group_membership as g on g.pid=i.pid "
            "WHERE g.uid_idx=%s or v.global",
            (self.uid_idx,))

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No image ids?")

        # ... package it up.
        result = {}
        for image in res:
            tmp = {
                "imageid" : image[0],
                "description" : image[1],
                }
            result[image[0]] = tmp
            pass

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    def info(self, version, argdict):
        # Check for valid arguments.
        argerror = CheckRequiredArgs(argdict, ("proj", "imagename"))
        if argerror:
            return argerror

        permerror = CheckProjPermission(self.uid_idx, argdict["proj"])
        if permerror:
            return permerror

        if not re.match("^[-\w\.]*$", argdict["imagename"]):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed imagename!")

        res = DBQueryFatal("SELECT distinct v.*,i.locked FROM images as i "
                           "left join image_versions as v on "
                           "     v.imageid=i.imageid and v.version=i.version "
                           "where i.imagename=%s and i.pid=%s ",
                           (argdict["imagename"],
                            argdict["proj"]), True)

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Unknown Image ID?")

        image = res[0]
        result = {}
        result["imagename"] = image["imagename"]
        result["imageid"]   = image["imageid"]
        result["version"]   = image["version"]
        result["ready"]     = image["ready"]
        result["isdataset"] = image["isdataset"]
        if image["locked"]:
            result["locked"] = image["locked"]
        else:
            result["locked"] = ""
            pass

        # No fast polling;
        time.sleep(2)
            
        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result, output=str(result))

    pass


#
# This class implements the server side of the XMLRPC interface to OS IDs.
#
class osid:
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    def getlist(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        # Get the listing that is accessible to this user and
        res = DBQueryFatal("SELECT distinct v.* FROM os_info as o "
                           "left join os_info_versions as v on "
                           "     v.osid=o.osid and v.vers=o.version "
                           "left join group_membership as g on g.pid=o.pid "
                           "where (g.uid_idx=%s or v.shared=1) "
                           "group by o.pid,o.osname",
                           (self.uid_idx,),
                           True)

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No OS IDs?")

        # ... package it up.
        result = {}
        for osid in res:
            # XXX Legacy stuff...
            osid["fullosid"] = osid["osid"]
            osid["osid"] = osid["osname"]

            if "OS" not in osid or len(osid["OS"]) == 0:
                osid["OS"] = "(None)"
                pass

            result[osid["osid"]] = scrubdict(osid)
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output="")
    
    def info(self, version, argdict):
        # Check for valid arguments.
        argerror = CheckRequiredArgs(argdict, ("osid",))
        if (argerror):
            return argerror

        if not re.match("^[-\w\.]*$", argdict["osid"]):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed osid!")

        # Get the listing that is accessible to this user and
        res = DBQueryFatal("SELECT distinct v.* FROM os_info as o "
                           "left join os_info_versions as v on "
                           "     v.osid=o.osid and v.vers=o.version "
                           "left join group_membership as g on g.pid=o.pid "
                           "where (g.uid_idx=%s or v.shared=1) and "
                           "      (o.osname=%s or o.osid=%s) "
                           "group by o.pid,o.osname",
                           (self.uid_idx, argdict["osid"], argdict["osid"]),
                           True)

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Unknown OS ID?")

        osid = res[0]
        osid["fullosid"] = osid["osid"]
        osid["osid"] = osid["osname"]
        
        if "OS" not in osid or len(osid["OS"]) == 0:
            osid["OS"] = "(None)"
            pass

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=scrubdict(osid),
                              output=str(osid))

    pass


#
# This class implements the server side of the XMLRPC interface to experiments.
#
class experiment:
    ##
    # Initialize the object.  Currently only sets the objects 'VERSION' value.
    #
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    ##
    # Echo a message, basically, prepend the host name to the parameter list.
    #
    # @param args The argument list to echo back.
    # @return The 'msg' value with this machine's name prepended.
    #
    def echo(self, version, argdict):
        if "str" not in argdict:
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Must supply a string to echo!")
        
        return EmulabResponse(RESPONSE_SUCCESS, 0,
                             socket.gethostname() + ": " + str(version)
                             + " " + argdict["str"])

    #
    # Get the physical/policy constraints for experiment parameters.
    #
    def constraints(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        result = {
            "idle/threshold" : TBGetSiteVar("idle/threshold"),
            # XXX Add more...
            }
        
        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    #
    # Get the list of experiments where the user is the head.
    #
    def getlist(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        # Figure out the format for the returned data.
        if "format" in argdict:
            format = argdict["format"]
            pass
        else:
            format = "brief"
            pass

        # XXX Let the user specify the pid/gid
        dbres = DBQueryFatal("SELECT e.pid,e.gid,e.eid,e.expt_name,e.state,"
                             "e.expt_head_uid,e.minimum_nodes,e.maximum_nodes,"
                             "count(r.node_id) as actual_nodes "
                             "  FROM experiments AS e "
                             "left join reserved as r on e.pid=r.pid and "
                             "  e.eid=r.eid "
                             "WHERE e.expt_head_uid=%s "
                             "GROUP BY e.pid,e.eid",
                             (self.uid,))

        # Build a dictionary of projects that refer to a dictionary of groups
        # that refer to a list of experiments in that group.
        result = {}
        for res in dbres:
            # Get everything from the DB result,
            pid = res[0]
            gid = res[1]
            eid = res[2]
            desc = res[3]
            state = res[4]
            expt_head = res[5]
            minimum_nodes = res[6]
            maximum_nodes = res[7]
            actual_nodes = res[8]
            # ... make sure 'result' has the proper slots,
            if pid not in result:
                result[pid] = {
                    gid : list()
                    }
                pass
            elif gid not in result[pid]:
                result[pid][gid] = list()
                pass

            # ... drop the data into place, and
            expdata = None
            if format == "brief":
                expdata = eid;
                pass
            elif format == "full":
                expdata = scrubdict({
                    "pid" : pid,
                    "gid" : gid,
                    "name" : eid,
                    "description" : desc,
                    "state" : state,
                    "expt_head" : expt_head,
                    "minimum_nodes" : minimum_nodes,
                    "maximum_nodes" : maximum_nodes,
                    "actual_nodes" : actual_nodes,
                    })
                pass

            # ... append it to the group list.
            result[pid][gid].append(expdata)
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    #
    # Start an experiment using batchexp. We get the NS file inline, which
    # we have to write to a temp file first. 
    #
    def batchexp(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        nsfilename = None
        argstr     = "-q -R"
        extrainfo  = False
        
        for opt, val in argdict.items():
            if opt == "batch":
                if not xbool(val):
                    argstr += " -i"
                    pass
                pass
            elif opt == "description":
                argstr += " -E "
                argstr += escapeshellarg(val)
                pass
            elif opt == "group":
                argstr += " -g "
                argstr += escapeshellarg(val)
                pass
            elif opt == "exp":
                argstr += " -e "
                argstr += escapeshellarg(val)
                pass
            elif opt == "proj":
                argstr += " -p "
                argstr += escapeshellarg(val)
                pass
            elif opt == "swappable":
                if not xbool(val):
                    if "noswap_reason" not in argdict:
                        return EmulabResponse(RESPONSE_BADARGS,
                                       output="Must supply noswap reason!");
                    argstr += " -S "
                    argstr += escapeshellarg(argdict["noswap_reason"])
                    pass
                pass
            elif opt == "noswap_reason":
                pass
            elif opt == "idleswap":
                if val == 0:
                    if "noidleswap_reason" not in argdict:
                        return EmulabResponse(RESPONSE_BADARGS,
                                      output="Must supply noidleswap reason!");
                    argstr += " -L "
                    argstr += escapeshellarg(argdict["noidleswap_reason"])
                    pass
                else:
                    argstr += " -l "
                    argstr += escapeshellarg(str(val))
                    pass
                pass
            elif opt == "noidleswap_reason":
                pass
            elif opt == "autoswap" or opt == "max_duration":
                argstr += " -a "
                argstr += escapeshellarg(str(val))
                pass
            elif opt == "noswapin":
                if xbool(val):
                    argstr += " -f "
                    pass
                pass
            elif opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "nsfilepath":
                # Backend script will verify this local path. 
                nsfilename = escapeshellarg(val)
                pass
            elif opt == "nsfilestr":
                nsfilestr = val
            
                if len(nsfilestr) > (1024 * 512):
                    return EmulabResponse(RESPONSE_TOOBIG,
                                         output="NS File way too big!");
        
                (nsfp, nsfilename) = writensfile(nsfilestr)
                if not nsfilename:
                    return EmulabResponse(RESPONSE_SERVERERROR,
                                         output="Server Error")
                pass
            elif opt == "noemail":
                if xbool(val):
                    argstr += " -N "
                    pass
                pass
            elif opt == "extrainfo":
                if xbool(val):
                    argstr += " -X "
                    extrainfo = True
                    pass
                pass
            pass


        if nsfilename:
            argstr += " " + nsfilename
            pass

        (exitval, output, errout) = runcommand(TBDIR + "/bin/batchexp " + argstr, 
                                               separate_stderr=extrainfo);
        if exitval:
            if extrainfo:
                try:
                    value = xmlrpclib.loads(output)[0][0]
                except:
                    output = errout + output
                    return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
                value["exitval"] = exitval >> 8
                output = value["output"]
                del value["output"]
                value["errout"] = errout
                return EmulabResponse(RESPONSE_ERROR, value, output=output)
            else:
                return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # startexp is an alias for batchexp.
    # 
    def startexp(self, version, argdict):
        return self.batchexp(version, argdict)

    #
    # swap an experiment using swapexp. 
    #
    def swapexp(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp", "direction"))
        if (argerror):
            return argerror

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        if not (argdict["direction"] == "in" or
                argdict["direction"] == "out"):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="direction must be 'in' or 'out'");

        argstr = "-q"
        extrainfo = False

        for opt, val in argdict.items():
            if opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "noemail":
                if xbool(val):
                    argstr += " -N "
                    pass
                pass
            elif opt == "extrainfo":
                if xbool(val):
                    argstr += " -X "
                    extrainfo = True
                    pass
                pass
            pass

        argstr += " -s " + escapeshellarg(argdict["direction"])
        argstr += " " + escapeshellarg(argdict["proj"])
        argstr += " " + escapeshellarg(argdict["exp"])

        (exitval, output, errout) = runcommand(TBDIR + "/bin/swapexp " + argstr,
                                               separate_stderr=extrainfo);
        if exitval:
            if extrainfo:
                try:
                    value = xmlrpclib.loads(output)[0][0]
                except:
                    output = errout + output
                    return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
                value["exitval"] = exitval >> 8
                output = value["output"]
                del value["output"]
                value["errout"] = errout
                return EmulabResponse(RESPONSE_ERROR, value, output=output)
            else:
            	return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # modify an experiment using swapexp. We get the NS file inline, which
    # we have to write to a temp file first. 
    #
    def modify(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        nsfilename = None
        argstr     = "-q"
        extrainfo  = False
        
        for opt, val in argdict.items():
            if opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "reboot":
                if xbool(val):
                    argstr += " -r "
                    pass
                pass
            elif opt == "restart_eventsys":
                if xbool(val):
                    argstr += " -e "
                    pass
                pass
            elif opt == "nsfilepath":
                # Backend script will verify this local path. 
                nsfilename = escapeshellarg(val)
                pass
            elif opt == "nsfilestr":
                nsfilestr = val
            
                if len(nsfilestr) > (1024 * 512):
                    return EmulabResponse(RESPONSE_TOOBIG,
                                         output="NS File way too big!");
        
                (nsfp, nsfilename) = writensfile(nsfilestr)
                if not nsfilename:
                    return EmulabResponse(RESPONSE_SERVERERROR,
                                         output="Server Error")
                pass
            elif opt == "noemail":
                if xbool(val):
                    argstr += " -N "
                    pass
                pass
            elif opt == "extrainfo":
                if xbool(val):
                    argstr += " -X "
                    extrainfo = True
                    pass
                pass
            pass

        argstr += " -s modify"
        argstr += " " + escapeshellarg(argdict["proj"])
        argstr += " " + escapeshellarg(argdict["exp"])

        if nsfilename:
            argstr += " " + nsfilename
            pass

        (exitval, output, errout) = runcommand(TBDIR + "/bin/swapexp " + argstr, 
                                               separate_stderr=extrainfo)
        if exitval:
            if extrainfo:
                try:
                    value = xmlrpclib.loads(output)[0][0]
                except:
                    output = errout + output
                    return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
                value["exitval"] = exitval >> 8
                output = value["output"]
                del value["output"]
                value["errout"] = errout
                return EmulabResponse(RESPONSE_ERROR, value, output=output)
            else:
            	return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # end an experiment using endexp.
    #
    def endexp(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        argstr = "-q"
        for opt, val in argdict.items():
            if opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "noemail":
                if xbool(val):
                    argstr += " -N "
                    pass
                pass
            pass

        argstr += " " + escapeshellarg(argdict["proj"])
        argstr += "/" + escapeshellarg(argdict["exp"])

        (exitval, output) = runcommand(TBDIR + "/bin/endexp " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Get textual info from tbreport and send back as string
    #
    def history(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        res = {}
        dbres = DBQuery(
            "SELECT * FROM experiment_stats "
            "WHERE pid=%s and eid=%s ORDER by exptidx desc",
            (argdict["proj"], argdict["exp"]),
            asDict=True)

        if len(dbres) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment!")
        
        res["stats"] = scrubdict(dbres[0])
        dbres = DBQuery(
            "SELECT er.*,ts.start_time,ts.end_time,ts.action,ts.idx as tidx "
            "FROM experiments as e "
            "LEFT JOIN experiment_resources as er on e.idx=er.exptidx "
            "LEFT JOIN testbed_stats as ts on ts.rsrcidx=er.idx "
            "WHERE e.pid=%s and e.eid=%s",
            (argdict["proj"], argdict["exp"]),
            asDict=True)
        for er in dbres:
            er["thumbnail"] = xmlrpclib.Binary(er["thumbnail"])
            pass
        res["resources"] = [scrubdict(x) for x in dbres]

        return EmulabResponse(RESPONSE_SUCCESS, value=res)
        
    #
    # Get textual info from tbreport and send back as string
    #
    def expinfo(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp", "show"))
        if (argerror):
            return argerror

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        argstr = ""
        tokens = argdict["show"].split(",")
        for show in tokens:
            if show == "nodeinfo":
                argstr += " -n"
                pass
            elif show == "mapping":
                argstr += " -m"
                pass
            elif show == "linkinfo":
                argstr += " -l"
                pass
            elif show == "shaping":
                argstr += " -d"
                pass
            pass

        argstr += " " + escapeshellarg(argdict["proj"])
        argstr += " " + escapeshellarg(argdict["exp"])

        (exitval, output) = runcommand(TBDIR + "/bin/tbreport " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    def metadata(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        res = DBQueryFatal("SELECT * FROM experiments WHERE pid=%s and eid=%s",
                           (argdict["proj"], argdict["exp"]),
                           True)

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment?")

        res = scrubdict(res[0], [
            "expt_locked",
            "testdb",
            "logfile_open",
            "prerender_pid",
            "keyhash",
            "eventkey",
            "sim_reswap_count",
            "elab_in_elab",
            "locpiper_port",
            "locpiper_pid",
            "usemodelnet",
            "priority",
            "modelnet_edges",
            "modelnet_cores",
            "elabinelab_nosetup",
            "event_sched_pid",
            "wa_bw_solverweight",
            "wa_plr_solverweight",
            "wa_delay_solverweight",
            ])
        
        vue = DBQueryFatal("SELECT name,value FROM virt_user_environment "
                           "WHERE pid=%s and eid=%s order by idx",
                           (argdict["proj"], argdict["exp"]),
                           True)

        res["user_environment"] = vue

        return EmulabResponse(RESPONSE_SUCCESS, value=res, output=str(res))

    #
    # Return the state of an experiment.
    #
    def state(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")

        #
        # Check permission.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        res = DBQueryFatal("select state from experiments "
                           "where pid=%s and eid=%s",
                           (argdict["proj"], argdict["exp"]))

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment!")

        state = res[0][0]
        return EmulabResponse(RESPONSE_SUCCESS, value=state, output=state)

    #
    # Wait for an experiment to reach a state; this is especially useful
    # with batch experiments. There are probably race conditions inherent
    # in this stuff, but typical usage should not encounter them, I hope.
    #
    def statewait(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        argerror = CheckRequiredArgs(argdict, ("proj", "exp", "state"))
        if (argerror):
            return argerror

        # Check for well formed proj/exp and
        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")

        # ... timeout arguments.
        if ("timeout" in argdict and
            isinstance(argdict["timeout"], str) and
            not re.match("^[\d]*$", argdict["timeout"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed timeout!")

        # Make sure the state argument is a list.
        if (not isinstance(argdict["state"], list)):
            argdict["state"] = [argdict["state"],]
            pass
        
        res = DBQueryFatal("select state from experiments "
                           "where pid=%s and eid=%s",
                           (argdict["proj"], argdict["exp"]))

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment: " +
                                  argdict["proj"] + "/" + argdict["exp"])

        #
        # Check permission.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        #
        # First, see if the experiment is already in the desired state,
        #
        state = res[0][0]
        if (state in argdict["state"]):
            return EmulabResponse(RESPONSE_SUCCESS, value=state, output=state)

        # ... subscribe to the event, and then
        try:
            import tbevent
            pass
        except ImportError as e:
            return EmulabResponse(RESPONSE_ERROR, output="System Error")

        at = tbevent.address_tuple()
        at.objtype = "TBEXPTSTATE"
        at.objname = argdict["proj"] + "/" + argdict["exp"]
        at.expt    = argdict["proj"] + "/" + argdict["exp"]
        at.host    = BOSSNODE

        try:
            mc = tbevent.EventClient(server="localhost", port=BOSSEVENTPORT)
            mc.subscribe(at)
            pass
        except:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Could not connect to Event System")

        # ... check the state again in case it changed between the first
        # check and the subscription.
        res = DBQueryFatal("select state from experiments "
                           "where pid=%s and eid=%s",
                           (argdict["proj"], argdict["exp"]))

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment: " +
                                  argdict["proj"] + "/" + argdict["exp"])

        state = res[0][0]
        if (state in argdict["state"]):
            return EmulabResponse(RESPONSE_SUCCESS, value=state, output=state)

        if ("timeout" in argdict):
            signal.signal(signal.SIGALRM, TimeoutHandler)
            signal.alarm(int(argdict["timeout"]))
            pass

        # Need to wait for an event.
        try:
            while True:
                ev = mc.poll()

                if ev == None:
                    time.sleep(1) # Slow down the polling.
                    continue

                # ... check if it is one the user cares about.
                if ((argdict["state"] == []) or
                    (ev.getEventType() in argdict["state"])):
                    retval = ev.getEventType()
                    break

                pass
            pass
        except TimedOutError as e:
            return EmulabResponse(RESPONSE_TIMEDOUT,
                                  output=("Timed out waiting for states: "
                                          + repr(argdict["state"])))

        if ("timeout" in argdict):
            signal.alarm(0)
            pass

        del(mc)
        
        return EmulabResponse(RESPONSE_SUCCESS, value=retval, output=retval)

    #
    # Wrap up above for a simple "waitforactive" to avoid leaking more
    # goo out then needed (eventstates).
    #
    def waitforactive(self, version, argdict):
        argdict["state"] = "active";
        return self.statewait(version, argdict);
        
    #
    # Return the node/link mappings for an experiment.
    #
    def info(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp", "aspect"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Illegal characters in arguments!")

        #
        # Check permission.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        res = DBQueryFatal("select state from experiments "
                           "where pid=%s and eid=%s",
                           (argdict["proj"], argdict["exp"]))

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment!")
        state   = res[0][0]
        result  = {}
        mapping = None

        if (state == "active" or
            state == "activating" or
            state == "modify_reparse"):
            dbres = DBQuery(
                "select r.vname,r.node_id,n.type,n.def_boot_osid,ns.status,"
                "n.eventstate,"
                "(unix_timestamp(now()) - unix_timestamp( "
                "greatest(na.last_tty_act,na.last_net_act,na.last_cpu_act,"
                "na.last_ext_act))),ni.load_1min,ni.load_5min,ni.load_15min,"
                "n.phys_nodeid,r.erole"
                "  from reserved as r "
                "left join nodes as n on r.node_id=n.node_id "
                "left join node_status as ns on ns.node_id=n.node_id "
                "left join node_activity as na on na.node_id=n.node_id "
                "left join node_idlestats as ni on ni.node_id=n.node_id "
                "where r.pid=%s and r.eid=%s "
                "order by r.vname",
                (argdict["proj"], argdict["exp"]))
            osmappings = {}
            mapping = {}
            for res in dbres:
                tmp = {}
                tmp["name"] = res[0]
                tmp["node"] = res[1]
                tmp["type"] = res[2]
                tmp["pnode"] = res[10]
                if res[3] not in osmappings:
                    osres = DBQuery(
                        "SELECT osname from os_info where osid=%s", (res[3],))
                    osmappings[res[3]] = osres[0][0]
                    pass
                tmp["osid"] = osmappings[res[3]]
                tmp["status"] = res[4]
                if res[5]:
                    tmp["eventstatus"] = res[5]
                    pass
                if res[6]:
                    tmp["idle"] = res[6]
                    pass
                if res[7]:
                    tmp["load_1min"] = res[7]
                    pass
                if res[8]:
                    tmp["load_5min"] = res[8]
                    pass
                if res[9]:
                    tmp["load_15min"] = res[9]
                    pass
                tmp["erole"] = res[11]
                mapping[res[0]] = scrubdict(tmp,
                                            defaultvals={ "status" : "up" })
                pass
            pass

        if argdict["aspect"] == "mapping":
            if (state != "active" and
                state != "activating" and
                state != "modify_reparse"):
                return EmulabResponse(RESPONSE_ERROR,
                                      output="Experiment is not active!")
            # Just return the mapping above
            result = scrubdict(mapping)
            pass
        elif argdict["aspect"] == "links":
            dbres = DBQueryFatal("SELECT vname,ips from virt_nodes "
                                 "where pid=%s and eid=%s",
                                 (argdict["proj"], argdict["exp"]))
            ipmap = {}
            for res in dbres:
                for ipinfo in str.split(res[1], " "):
                    if len(ipinfo) > 0:
                        port, ip = str.split(ipinfo, ":")
                        ipmap[res[0] + ":" + port] = ip
                        pass
                    pass
                pass
            
            dbres = DBQuery("select vname,member,mask,delay,bandwidth, "
                            "       lossrate,rdelay,rbandwidth,rlossrate "
                            "from virt_lans where pid=%s and eid=%s "
                            "order by vname,member",
                            (argdict["proj"], argdict["exp"]))

            if len(dbres) > 0:
                for res in dbres:
                    tmp = {}
                    tmp["name"]        = res[0]
                    tmp["member"]      = res[1]
                    tmp["ipaddr"]      = ipmap[res[1]]
                    tmp["mask"]        = res[2]
                    tmp["delay"]       = res[3]
                    tmp["bandwidth"]   = int(res[4])
                    tmp["plr"]         = res[5]
                    tmp["r_delay"]     = res[6]
                    tmp["r_bandwidth"] = int(res[7])
                    tmp["r_plr"]       = res[8]
                    result[res[1]]     = tmp
                    pass
                pass
            pass
        elif argdict["aspect"] == "physical":
            result = {
                "nodes" : [],
                "interfaces" : [],
                }
            
            dbres = DBQuery("SELECT * FROM reserved "
                            "WHERE pid=%s and eid=%s",
                            (argdict["proj"], argdict["exp"]),
                            asDict=True)
            for node in dbres:
                result["nodes"].append(scrubdict(node, [
                    "rsrv_time",
                    "old_pid",
                    "old_eid"
                    ]))
                pass
            dbres = DBQuery("SELECT i.* FROM reserved as r "
                            "LEFT JOIN interfaces as i on r.node_id=i.node_id "
                            "WHERE r.pid=%s and r.eid=%s "
                            "and i.ip is not NULL and i.ip!=''",
                            (argdict["proj"], argdict["exp"]),
                            asDict=True)
            for intf in dbres:
                result["interfaces"].append(scrubdict(intf))
                pass
            dbres = DBQuery("SELECT i.* FROM reserved as r "
                            "LEFT JOIN vinterfaces as i "
                            " on r.node_id=i.node_id "
                            "WHERE r.pid=%s and r.eid=%s "
                            "and i.ip is not NULL and i.ip!=''",
                            (argdict["proj"], argdict["exp"]),
                            asDict=True)
            for intf in dbres:
                result["interfaces"].append(scrubdict(intf))
                pass

            pass
        elif argdict["aspect"] == "traces":
            result = []
            dbres = DBQuery("SELECT t.*,r.vname as delayvname "
                            "FROM traces as t "
                            "left join reserved as r on t.node_id=r.node_id "
                            "WHERE r.pid=%s and r.eid=%s",
                            (argdict["proj"], argdict["exp"]),
                            asDict=True)
            for trace in dbres:
                result.append(scrubdict(trace))
                pass
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS, value=result, output="")

    #
    # nscheck an NS file.
    #
    def nscheck(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argstr = ""

        if "nsfilestr" in argdict:
            nsfilestr = argdict["nsfilestr"]
            
            if len(nsfilestr) > (1024 * 512):
                return EmulabResponse(RESPONSE_TOOBIG,
                                     output="NS File way too big!");
        
            (nsfp, nsfilename) = writensfile(nsfilestr)
            if not nsfilename:
                return EmulabResponse(RESPONSE_SERVERERROR,
                                      output="Server Error")

            argstr += nsfilename
            pass
        elif "nsfilepath" in argdict:
            # Backend script will verify this local path. 
            argstr += escapeshellarg(argdict["nsfilepath"])
            pass
        else:
            return EmulabResponse(RESPONSE_BADARGS,
                                 output="Must supply an NS file to check!");
        
        (exitval, output) = runcommand(TBDIR + "/bin/nscheck " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Delay configuration
    #
    def delay_config(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict,
                                     ("proj", "exp", "link", "params"))
        if (argerror):
            return argerror

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        argstr = ""
        for opt, val in argdict.items():
            if opt == "persist":
                if xbool(val):
                    argstr += " -m "
                    pass
                pass
            elif opt == "bridge":
                if xbool(val):
                    argstr += " -b "
                    pass
                pass
            elif opt == "src":
                argstr += " -s "
                argstr += escapeshellarg(val)
                pass
            pass

        argstr += " " + escapeshellarg(argdict["proj"])
        argstr += " " + escapeshellarg(argdict["exp"])
        argstr += " " + escapeshellarg(argdict["link"])

        for opt, val in argdict["params"].items():
            argstr += " " + escapeshellarg(opt + "=" + str(val))
            pass
        
        (exitval, output) = runcommand(TBDIR + "/bin/delay_config " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Wireless link configuration
    #
    def link_config(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict,
                                     ("proj", "exp", "link", "params"))
        if (argerror):
            return argerror

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        argstr = ""
        for opt, val in argdict.items():
            if opt == "persist":
                if xbool(val):
                    argstr += " -m "
                    pass
                pass
            elif opt == "src":
                argstr += " -s "
                argstr += escapeshellarg(val)
                pass
            pass

        argstr += " " + escapeshellarg(argdict["proj"])
        argstr += " " + escapeshellarg(argdict["exp"])
        argstr += " " + escapeshellarg(argdict["link"])

        for opt, val in argdict["params"].items():
            argstr += " " + escapeshellarg(opt + "=" + str(val))
            pass
        
        (exitval, output) = runcommand(TBDIR + "/bin/link_config " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # iwconfig is an alias for link_config
    # 
    def iwconfig(self, version, argdict):
        return self.link_config(version, argdict)

    #
    # Reboot all nodes in an experiment.
    #
    def reboot(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        argstr = ""
        for opt, val in argdict.items():
            if opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "power":
                if xbool(val):
                    argstr += " -f "
                    pass
                pass
            elif opt == "reconfig":
                if xbool(val):
                    argstr += " -c "
                    pass
                pass
            pass
        
        argstr += " -e "
        argstr += escapeshellarg(argdict["proj"] + "," + argdict["exp"])
        
        (exitval, output) = runcommand(TBDIR + "/bin/node_reboot " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Reload all nodes in an experiment.
    #
    def reload(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        argstr = ""
        for opt, val in argdict.items():
            if opt == "wait":
                if not xbool(val):
                    argstr += " -s "
                    pass
                pass
            elif opt == "bootwait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "imageproj":
                argstr += " -p "
                argstr += escapeshellarg(val)
                pass
            elif opt == "imagename":
                argstr += " -i "
                argstr += escapeshellarg(val)
                pass
            elif opt == "imageid":
                argstr += " -m "
                argstr += escapeshellarg(val)
                pass
            elif opt == "reboot":
                if not xbool(val):
                    argstr += " -r "
                    pass
                pass
            elif opt == "usecurrent":
                if xbool(val):
                    argstr += " -c "
                    pass
                pass
            elif opt == "force":
                if xbool(val):
                    argstr += " -P "
                    pass
                pass
            pass

        argstr += " -e "
        argstr += escapeshellarg(argdict["proj"] + "," + argdict["exp"])
        
        (exitval, output) = runcommand(TBDIR + "/bin/os_load " + argstr)

        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Download experiment topology.
    #
    def virtual_topology(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                 output="Client version mismatch!");
            pass

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Illegal characters in arguments!")

        #
        # Check permission.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        res = DBQuery("SELECT * FROM experiments "
                      "WHERE pid=%s and eid=%s",
                      (argdict["proj"], argdict["exp"]), asDict=True);

        #
        # Convert NULL to ""
        #
        for key, val in res[0].items():
            
            if val == None:
                res[0][key] = ""
                pass
            elif isinstance(val, datetime.datetime):
                res[0][key] = xmlrpclib.DateTime(
                    time.strptime(str(val), "%Y-%m-%d %H:%M:%S"))
                pass
            pass

        result   = {}
        result["experiment"] = {}
        result["experiment"]["settings"] = res[0];

        #
        # Get the rest of the virtual tables.
        # 
        for key, val in virtual_tables.items():
            if key == "experiments":
                continue

            tag  = val["tag"]
            rows = []

            if "tables" in argdict and (tag not in argdict["tables"]):
                continue
            
            if "exclude" in argdict and (tag in argdict["exclude"]):
                continue
            
            res = DBQuery("SELECT * FROM " + key + " " +
                          "WHERE pid=%s and eid=%s",
                          (argdict["proj"], argdict["exp"]), asDict=True);

            if len(res) > 0:
                for row in res:
                    #
                    # Convert NULL to ""
                    #
                    for key2, val2 in list(row.items()):
                        if key2 in ("pid", "eid"):
                            del row[key2]
                            pass
                        elif val2 == None:
                            row[key2] = ""
                            pass
                        elif isinstance(val2, datetime.datetime):
                            row[key2] = xmlrpclib.DateTime(
                                time.strptime(str(val2), "%Y-%m-%d %H:%M:%S"))
                            pass
                        pass

                    rows.append(row)
                    pass
                pass
            
            result["experiment"][tag] = rows
            pass

        result = (result,)
        
        return EmulabResponse(RESPONSE_SUCCESS, value=result, output="")
    
    def virtual_topology_xml(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                 output="Client version mismatch!");
            pass

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Illegal characters in arguments!")

        #
        # Check permission. 
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        argstr  = ""
        argstr += " " + escapeshellarg(argdict["proj"])
        argstr += " " + escapeshellarg(argdict["exp"])
        
        (exitval, output) = runcommand(TBDIR + "/libexec/xmlconvert " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, value=output, output="")
    
    #
    # Return the visualization data for the experiment.
    #
    def getviz(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")

        #
        # Check permission. 
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        dbres = DBQueryFatal("select vname,vis_type,x,y from vis_nodes "
                             "where pid=%s and eid=%s",
                             (argdict["proj"], argdict["exp"]))

        if len(dbres) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment!")

        result = {}
        for res in dbres:
            tmp = {}
            tmp["name"] = res[0]
            tmp["type"] = res[1]
            tmp["x"] = res[2]
            tmp["y"] = res[3]
            result[res[0]] = tmp
            pass

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    #
    # Return the thumbnail image of experiment's topology.
    #
    def thumbnail(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        # Check for valid arguments.
        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        dbres = DBQueryFatal(
            "select s.rsrcidx from experiments as e "
            "left join experiment_stats as s on s.exptidx=e.idx "
            "where e.pid=%s and e.eid=%s",
            (argdict["proj"], argdict["exp"]))

        if len(dbres) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment!")
        
        dbres = DBQueryFatal(
            "select thumbnail from experiment_resources "
            "where idx=%s",
            (dbres[0][0],))

        # The return is a PNG, which needs to be encoded as base64 before
        # sending over XML-RPC.
        result = xmlrpclib.Binary(dbres[0][0])
        
        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output="ok")

    #
    # Return the nsfile for the experiment.
    #
    def nsfile(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        # Check for valid arguments.
        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        dbres = DBQueryFatal(
            "select i.input from experiments as e "
            "left join experiment_stats as s on s.exptidx=e.idx "
            "left join experiment_resources as r on r.idx=s.rsrcidx "
            "left join experiment_input_data as i on i.idx=r.input_data_idx "
            "where e.pid=%s and e.eid=%s",
            (argdict["proj"], argdict["exp"]))

        if len(dbres) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment!")
        
        result = dbres[0][0]
        
        return EmulabResponse(RESPONSE_SUCCESS,
                              value=str(result),
                              output="ok")

    #
    # Control the event system.
    #
    def eventsys_control(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp", "action"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"]) and
                re.match("^[-\w]*$", argdict["action"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp/op!")

        if not (argdict["action"] == "start" or
                argdict["action"] == "stop" or
                argdict["action"] == "replay"):
            return EmulabResponse(RESPONSE_BADARGS,
                               output="action must be one of start|stop|replay")

        #
        # Check permission. 
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        argstr  = ""
        argstr += " " + escapeshellarg(argdict["action"])
        argstr += " " + escapeshellarg(argdict["proj"])
        argstr += "," + escapeshellarg(argdict["exp"])
        
        (exitval, output) = runcommand(TBDIR + "/bin/eventsys_control "
                                       + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, value=exitval, output="")

    #
    # savelogs. What a silly thing to do.
    # 
    def savelogs(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                 output="Client version mismatch!");
            pass

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Illegal characters in arguments!")

        #
        # Check permission. 
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        argstr  = ""
        argstr += " " + escapeshellarg(argdict["proj"])
        argstr += " " + escapeshellarg(argdict["exp"])
        
        (exitval, output) = runcommand(TBDIR + "/bin/savelogs " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, value=exitval, output="")
    
    #
    # portstats
    # 
    def portstats(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                 output="Client version mismatch!");
            pass

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        #
        # Pass the whole thing off to the backend script. It would be nice
        # to do this differently, but too much trouble.
        #
        proj   = None;
        expt   = None;
        argstr = ""
        for opt, val in argdict.items():
            if opt == "errors-only":
                if xbool(val):
                    argstr += " -e "
                    pass
                pass
            elif opt == "all":
                if xbool(val):
                    argstr += " -a "
                    pass
                pass
            elif opt == "clear":
                if xbool(val):
                    argstr += " -z "
                    pass
                pass
            elif opt == "quiet":
                if xbool(val):
                    argstr += " -q "
                    pass
                pass
            elif opt == "absolute":
                if xbool(val):
                    argstr += " -c "
                    pass
                pass
            elif opt == "physnames":
                if xbool(val):
                    argstr += " -p "
                    pass
                pass
            elif opt == "control-net":
                if xbool(val):
                    argstr += " -C "
                    pass
                pass
            elif opt == "proj":
                proj = val;
                pass
            elif opt == "exp":
                expt = val;
                pass
            pass

        if (proj or expt):
            if ((not (proj and expt)) or "physnames" in argdict):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="pid/eid/physnames")
            argstr += " " + escapeshellarg(proj);
            argstr += " " + escapeshellarg(expt);
            pass

        for name in argdict["nodeports"]:
            argstr += " " + escapeshellarg(name);
            pass
        
        (exitval, output) = runcommand(TBDIR + "/bin/portstats " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, value=exitval, output=output)
    
    #
    # readycount
    # 
    def readycount(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                 output="Client version mismatch!");
            pass

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        #
        # Pass the whole thing off to the backend script. It would be nice
        # to do this differently, but too much trouble.
        #
        proj   = None;
        expt   = None;
        argstr = ""
        for opt, val in argdict.items():
            if opt == "set":
                if xbool(val):
                    argstr += " -s "
                    pass
                pass
            elif opt == "clear":
                if xbool(val):
                    argstr += " -c "
                    pass
                pass
            elif opt == "list":
                if xbool(val):
                    argstr += " -l "
                    pass
                pass
            elif opt == "physnames":
                if xbool(val):
                    argstr += " -p "
                    pass
                pass
            elif opt == "proj":
                proj = val;
                pass
            elif opt == "exp":
                expt = val;
                pass
            pass

        if (proj or expt):
            if ((not (proj and expt)) or "physnames" in argdict):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="pid/eid/physnames")
            argstr += " " + escapeshellarg(proj);
            argstr += " " + escapeshellarg(expt);
            pass

        for name in argdict["nodes"]:
            argstr += " " + escapeshellarg(name);
            pass
        
        (exitval, output) = runcommand(TBDIR + "/bin/readycount " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, value=exitval, output=output)

    #
    # Get event agent list for event scheduler.
    #
    def event_agentlist(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")

        #
        # Check permission. 
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        #
        # We return the result as a list of lists.
        #
        result = []

        res = DBQuery("select vi.vname,vi.vnode,r.node_id,o.type "
                      " from virt_agents as vi "
                      "left join reserved as r on "
                      " r.vname=vi.vnode and r.pid=vi.pid and "
                      " r.eid=vi.eid "
                      "left join event_objecttypes as o on "
                      " o.idx=vi.objecttype "
                      "where vi.pid=%s and vi.eid=%s",
                      (argdict["proj"], argdict["exp"]))

        for agent in res:
            if agent[1] == "ops":
                nodeid = "ops"

                ipres = DBQuery("select IP from interfaces "
                                "where node_id=%s and role='ctrl'",
                                (nodeid,))

                if not ipres or len(ipres) == 0:
                    continue

                ipaddr = ipres[0][0]
                if not ipaddr:
                    ipaddr = ""
                    pass
                pass
            elif agent[2] == None:
                nodeid = ""
                ipaddr = ""
                pass
            else:
                ipres = DBQuery("select IP from nodes as n2 "
			 "left join nodes as n1 on n1.node_id=n2.phys_nodeid "
			 "left join interfaces as i on "
			 "i.node_id=n1.node_id and i.role='ctrl' "
			 "where n2.node_id=%s",
                         (agent[2],))

                if not ipres or len(ipres) == 0:
                    continue

                ipaddr = ipres[0][0]
                if not ipaddr:
                    ipaddr = ""
                    pass
                nodeid = agent[2]
                pass 
            
            result.append((agent[0], agent[1], nodeid, ipaddr, agent[3]))
            pass

        return EmulabResponse(RESPONSE_SUCCESS, value=result)
    
    #
    # Get event group list for event scheduler.
    #
    def event_grouplist(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")

        #
        # Check permission. 
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        #
        # We return the result as a list of lists.
        #
        result = []

        res = DBQuery("select group_name,agent_name from event_groups "
                      "where pid=%s and eid=%s",
                      (argdict["proj"], argdict["exp"]))

        for group in res:
            result.append((group[0], group[1]))
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS, value=result)
    
    #
    # Get event list for event scheduler.
    #
    def event_eventlist(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")

        #
        # Check permission. 
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        #
        # We return the result as a list of lists.
        #
        result = []

        res = DBQuery("SELECT ex.idx,ex.time,ex.vname,"
                      "ot.type,et.type,ex.arguments,ex.parent,etr.type "
                      "FROM eventlist AS ex "
                      "LEFT JOIN event_triggertypes AS etr ON "
                      "ex.triggertype=etr.idx "
                      "LEFT JOIN event_eventtypes AS et ON "
                      " ex.eventtype=et.idx "
                      "LEFT JOIN event_objecttypes AS ot ON "
                      " ex.objecttype=ot.idx "
                      "WHERE ex.pid=%s AND ex.eid=%s AND ot.type!='TIME' "
                      "ORDER BY ex.time,ex.idx ASC",
                      (argdict["proj"], argdict["exp"]))

        for event in res:
            result.append((str(event[0]), str(event[1]), event[2],
                           event[3], event[4], event[5], event[6], event[7]));
            pass

        return EmulabResponse(RESPONSE_SUCCESS, value=result)

    def event_time_start(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror
        
        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")

        tl_clause = ""
        tl_insert = ""
        if "timeline" in argdict:
            if not re.match("^[-\w]*$", argdict["timeline"]):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="Improperly formed timeline!")
            else:
                tl_clause = " and parent='%s'" % (argdict["timeline"],)
                tl_insert = ",parent='%s'" % (argdict["timeline"],)
                pass
            pass

        exptidx = ExperimentIndex(argdict["proj"], argdict["exp"])
        if exptidx == None:
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="No such experiment")
        
        #
        # Check permission. 
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        if "time" in argdict:
            value = float(argdict["time"])
            
            # XXX remove hardcoded event/object types.
            DBQueryFatal("DELETE FROM eventlist WHERE "
                         "pid=%s and eid=%s and objecttype=3 and eventtype=1"
                         + tl_clause,
                         (argdict["proj"], argdict["exp"]))

            if value > 0:
                DBQueryFatal("INSERT INTO eventlist SET "
                             "exptidx=%s,pid=%s,eid=%s,objecttype=3,"
                             "eventtype=1,arguments=%s" + tl_insert,
                             (exptidx, argdict["proj"], argdict["exp"], value))
                pass
            
            result = "ok"
            pass
        else:
            result = DBQueryFatal("SELECT parent,arguments FROM eventlist "
                                  "WHERE pid=%s and eid=%s and objecttype=3 "
                                  "and eventtype=1",
                                  (argdict["proj"], argdict["exp"]),
                                  True)

            if len(result) == 0:
                return EmulabResponse(RESPONSE_ERROR,
                                      output="Event time has not started yet")
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS, output=repr(result), value=result)
    
    #
    # Return DP info.
    #
    def dpinfo(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror):
            return argerror
        
        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")

        #
        # Check permission. 
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        res = DBQuery("SELECT dpdb,dpdbname FROM experiments "
                      "WHERE pid=%s and eid=%s",
                      (argdict["proj"], argdict["exp"]));

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment!")
        result  = {}
        result["dbname"] = res[0][1];
        if result["dbname"] == None:
            result["dbname"] = ""
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS, value=result, output=str(result))
    pass

#
# This class implements the server side of the XMLRPC interface to nodes.
#
class node:
    ##
    # Initialize the object.  Currently only sets the objects 'VERSION' value.
    #
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    #
    # Get the number of free nodes.
    #
    def available(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        if "class" not in argdict:
            argdict["class"] = "pc"
            pass

        if not re.match("^[-\w]*$", str(argdict["class"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed node class")
        
        type_test = ""
        if "type" in argdict:
            if not re.match("^[-\w]*$", str(argdict["type"])):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="Improperly formed node type")
            
            type_test = " and nt.type='%s'" % (str(argdict["type"]),)
            pass

        pid_clause = ""
        if "proj" in argdict:
            permerror = CheckProjPermission(self.uid_idx, argdict["proj"])
            if permerror:
                return permerror

            pid_clause = " or p.pid='%s'" % (str(argdict["proj"]),)
            pass

        intf_join = ""
        intf_clause = ""
        if "nic" in argdict:
            nic = argdict["nic"]
            if "wireless" in nic:
                intf_join = (
                    "left join interfaces as i on a.node_id=i.node_id "
                    "left join interface_types as it on "
                    "  i.interface_type=it.type ")
                intf_clause = " and i.role='expt' and it.connector='Wireless'"
                pass
            pass
        
        res = DBQueryFatal("SELECT distinct count(a.node_id) FROM nodes AS a "
                           "left join reserved as b on a.node_id=b.node_id "
                           "left join node_types as nt on a.type=nt.type "
                           "left join nodetypeXpid_permissions as p "
                           "  on a.type=p.type "
                           + intf_join +
                           "WHERE b.node_id is null and a.role='testnode' "
                           "  and nt.class=%s and "
                           "      (p.pid is null" + pid_clause + ") and "
                           "      (a.eventstate='ISUP' or "
                           "       a.eventstate='PXEWAIT')"
                           + type_test
                           + intf_clause,
                           (argdict["class"],))

        if len(res) == 0:
            result = 0
            pass
        else:
            result = int(res[0][0])
            pass

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    def getlist(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
 
        if "class" in argdict:
            if not re.match("^[-\w]*$", str(argdict["class"])):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="Improperly formed node class")
            
            class_test = " and nt.class='"+str(argdict["class"])+"'"
            pass
        else:
            class_test = " and nt.class!='pcplabphys'"
            pass

        type_test = ""
        if "type" in argdict:
            if not re.match("^[-\w]*$", str(argdict["type"])):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="Improperly formed node type")
            
            type_test = " and nt.type='%s'" % (str(argdict["type"]),)
            pass

        pid_clause = ""
        pid_clause_list = ""
        if "proj" in argdict:
            permerror = CheckProjPermission(self.uid_idx, argdict["proj"])
            if permerror:
                return permerror

            pid_clause_list = "'" + str(argdict["proj"]) + "'"
            pid_clause = " or p.pid='%s'" % (str(argdict["proj"]),)
            pass
        else:
            pid_clause_list = ",".join([("'" + x + "'")
                                        for x in GetProjects(self.uid_idx)])
            pid_clause = (" or p.pid in (" + pid_clause_list + ")")
            pass

        node_clause = ""
        if "nodes" in argdict:
            if not re.match("^[-\w]+(,[-\w]+)*$", str(argdict["nodes"])):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="Bad chars in node list!")

            nodestr = "','".join(str(argdict["nodes"]).split(","))
            node_clause = " and a.node_id in ('" + nodestr + "') "
            pass

        res = DBQueryFatal(
            "SELECT a.node_id,a.type, "
            "  b.node_id is null or (b.pid=%s and b.eid=%s), "
            "  a.eventstate in ('ISUP','PXEWAIT','POWEROFF'), "
            "  wn.site, "
            "  nfcpu.weight, "
            "  '' as old_auxtype, "
            "  wn.hostname, "
            "  a.reserved_pid is null or a.reserved_pid in "
            "    (" + pid_clause_list + ") "
            "FROM nodes AS a "
            "left join reserved as b on a.node_id=b.node_id "
            "left join node_types as nt on a.type=nt.type "
            "left join nodetypeXpid_permissions as p on a.type=p.type "
            "left join widearea_nodeinfo as wn on wn.node_id=a.phys_nodeid "
            "left join node_features as nfcpu on (nfcpu.node_id=a.phys_nodeid "
            "  and nfcpu.feature='+load') "
            "WHERE a.role='testnode' "
            "  "+ class_test +" and "
            "  (p.pid is null" + pid_clause + ") "
            "  "+ type_test +" "+ node_clause +
            "group by a.node_id",
            (TBOPSPID, 'plabnodes'))
        
        if len(res) == 0:
            result = {}
            pass
        else:
            # compute the set of types in the result list, because
            # we'll want to run reservation admission control against
            # each type
            freecounts = {}
            for row in res:
                freecounts[ row[ 1 ] ] = 0

            predict_cmd = [ PREDICT, "-n" ]
                
            if "start" in argdict:
                if not re.match( "^[-:0-9 ]+*$", str( argdict[ "start" ] ) ):
                    return EmulabResponse( RESPONSE_BADARGS,
                                           output="Bad chars in start time" )
                predict_cmd.append( "-t " + argdict[ "start" ] )
            
            if "duration" in argdict:
                if not re.match( "^[0-9]+*$", str( argdict[ "duration" ] ) ):
                    return EmulabResponse( RESPONSE_BADARGS,
                                           output="Bad chars in duration" )
                predict_cmd.append( "-D" )
                predict_cmd.append( argdict[ "duration" ] )
            else:
                # use 75 hours if not specified, since that's the CHPC default
                predict_cmd.append( "-D" )
                predict_cmd.append( "75" )

            for t in freecounts:
                freecounts[ t ] = int( subprocess.check_output( predict_cmd + [ t ] ) )
            
            result = {}
            # gotta enumerate the list of nodes of this type that are avail
            for row in res:
                avail = row[2] == 1 and row[3] == 1 and row[8] == 1 and freecounts[ row[ 1 ] ] > 0
                result[row[0]] = {
                    "node_id" : row[0],
                    "type" : row[1],
                    "free" : avail,
                    }
                if row[4]:
                    result[row[0]]["site"] = row[4]
                    pass
                if row[5] and row[5] != "":
                    result[row[0]]["cpu"] = row[5]
                    pass
                if row[6] and row[6] != "":
                    result[row[0]]["auxtypes"] = row[6]
                    pass
                if row[7] and row[7] != "":
                    result[row[0]]["hostname"] = row[7]
                    pass
                if avail:
                    freecounts[ row[ 1 ] ] -= 1
                pass
            pass

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    def typeinfo(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if "type" in argdict:
            if not re.match("^[-\w]*$", str(argdict["type"])):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="Improperly formed node type")
            
            type_test = " and type='%s'" % (str(argdict["type"]),)
            pass
        else:
            type_test = ""
            pass

        res = DBQuery("SELECT distinct nt.* FROM node_types as nt "
                      "left join nodetypeXpid_permissions as p "
                      "  on nt.type=p.type "
                      "left join group_membership as m on m.uid_idx=%s "
                      "WHERE (p.pid is null or p.pid=m.pid) and "
                      " nt.isdynamic=0 and nt.class not in ("
                      " 'pcplabphys','switch','shark','power','misc')"
                      + type_test,
                      (self.uid_idx,),
                      asDict=True)

        if len(res) == 0:
            result = {}
            pass
        else:
            result = {}
            for re in res:
                result[re["type"]] = scrubdict(re, prunelist=["ismodelnet"])
                pass
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))

    #
    # Get the console parameters.
    #
    def console(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        argerror = CheckRequiredArgs(argdict, ("node",))
        if (argerror):
            return argerror

        if not re.match("^[-\w]*$", str(argdict["node"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed node value!")

        if not CheckIsAdmin(self.uid_idx):
            # XXX Refactor the trust stuff
            res = DBQueryFatal("SELECT e.pid,e.gid FROM reserved AS r "
                               "left join experiments as e on "
                               "     e.pid=r.pid and e.eid=r.eid "
                               "WHERE r.node_id=%s",
                               (argdict["node"],))

            if len(res) == 0:
                return EmulabResponse(RESPONSE_ERROR,
                                      output="No permission to access node: " +
                                      argdict["node"])

            trust = DBQueryFatal("SELECT trust FROM group_membership "
                                 "WHERE uid_idx=%s and pid=%s and gid=%s",
                                 (self.uid_idx, res[0][0], res[0][1]))

            if len(trust) == 0:
                return EmulabResponse(
                    RESPONSE_FORBIDDEN,
                    output=("You do not have permission to access: "
                            + argdict["node"]))

            tstates = DBQueryFatal("SELECT taint_states FROM nodes "
                                   "WHERE node_id=%s AND taint_states "
                                   "IS NOT NULL",
                                   (argdict["node"],))

            if len(tstates):
                for taint in tstates[0][0].split(","):
                    if (taint in ("useronly","blackbox")):
                        return EmulabResponse(
                            RESPONSE_FORBIDDEN,
                            output=("Node is restricted - console access "
                                    "forbidden: " + argdict["node"]))

            pass

        res = DBQueryFatal("SELECT server,portnum,keylen,keydata "
                           "FROM tiplines WHERE node_id=%s",
                           (argdict["node"],))
        
        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such node: " + argdict["node"])

        sha_fp = open("/usr/testbed/etc/capture.fingerprint").read()
        sha_fp = sha_fp.split("=")[1].strip().replace(":", "")
        
        sha1_fp = open("/usr/testbed/etc/capture.sha1fingerprint").read()
        sha1_fp = sha1_fp.split("=")[1].strip().replace(":", "")
        
        result = {
            "server" : res[0][0],
            "portnum" : res[0][1],
            # "keylen" : res[0][2],
            "keydata" : res[0][3],
            "certsha" : sha_fp,
            "certsha1" : sha1_fp,
            }

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result)

    def sshdescription(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        argerror1 = CheckRequiredArgs(argdict, ("node",))
        argerror2 = CheckRequiredArgs(argdict, ("proj", "exp"))
        if (argerror1 and argerror2):
            return argerror1

        if ("node" in argdict and
            not re.match("^[-\w]*$", str(argdict["node"]))):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed node value!")
        elif "node" in argdict:
            # XXX Refactor the trust stuff
            res = DBQueryFatal("SELECT e.pid,e.gid,e.eid FROM reserved AS r "
                               "left join experiments as e on "
                               "     e.pid=r.pid and e.eid=r.eid "
                               "WHERE r.node_id=%s",
                               (argdict["node"],))
            
            if len(res) == 0:
                return EmulabResponse(RESPONSE_ERROR,
                                      output="No such node: " +
                                      argdict["node"])
            pid = res[0][0]
            gid = res[0][1]
            eid = res[0][2]
            clause = "n.node_id=%s"
            clause_args = (argdict["node"],)
            pass
        
        if ("proj" in argdict and
            not (re.match("^[-\w]*$", argdict["proj"]) and
                 re.match("^[-\w]*$", argdict["exp"]))):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed proj/exp!")
        elif "proj" in argdict:
            pid = argdict["proj"]
            eid = argdict["exp"]
            res = DBQueryFatal("SELECT gid,state FROM experiments "
                               "WHERE pid=%s and eid=%s",
                               (pid, eid))
            if len(res) == 0:
                return EmulabResponse(RESPONSE_ERROR,
                                      output="No such experiment: %s/%s" %
                                      (pid, eid))
            if res[0][1] not in ("activating", "active", "modify_reparse"):
                return EmulabResponse(RESPONSE_ERROR,
                                      output="Experiment is not active")
            gid = res[0][0]
            clause = "r.pid=%s and r.eid=%s"
            clause_args = (pid, eid)
            pass

        trust = DBQueryFatal("SELECT trust FROM group_membership "
                             "WHERE uid_idx=%s and pid=%s and gid=%s",
                             (self.uid_idx, pid, gid))

        if len(trust) == 0:
            return EmulabResponse(
                RESPONSE_FORBIDDEN,
                output=("You do not have permission to access: "
                        + argdict["node"]))

        res = DBQueryFatal("select n.node_id,n.jailflag,n.sshdport, "
                           "       r.vname,r.pid,r.eid, "
                           "       t.isvirtnode,t.isremotenode,t.isplabdslice "
                           " from nodes as n "
                           "left join reserved as r on n.node_id=r.node_id "
                           "left join node_types as t on t.type=n.type "
                           "where " + clause,
                           clause_args)

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such node: " + argdict["node"])

        result = {}
        for node in res:
            node_id = node[0]
            jailflag = node[1]
            sshdport = node[2]
            vname = node[3]
            pid = node[4]
            eid = node[5]
            isvirt = node[6]
            isremote = node[7]
            isplab = node[8]
            
            node_data = {
                "hostname" : vname + "." + eid + "." + pid + "." + OURDOMAIN,
                }
            
            if isvirt:
                if isremote:
                    if jailflag or isplab:
                        node_data["port"] = sshdport
                        pass
                    pass
                else:
                    node_data["gateway"] = USERNODE
                    pass
                pass
            result[node_id] = node_data
            pass

        if "node" in argdict:
            result = result[argdict["node"]]
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))
    
    #
    # Get the ssh host keys
    #
    def hostkeys(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        argerror = CheckRequiredArgs(argdict, ("node",))
        if (argerror):
            return argerror

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        if not re.match("^[-\w]*$", str(argdict["node"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed node value!")
        
        # XXX Refactor the trust stuff
        res = DBQueryFatal("SELECT e.pid,e.gid FROM reserved AS r "
                           "left join experiments as e on "
                           "     e.pid=r.pid and e.eid=r.eid "
                           "WHERE r.node_id=%s",
                           (argdict["node"],))

        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such node: " + argdict["node"])

        trust = DBQueryFatal("SELECT trust FROM group_membership "
                             "WHERE uid_idx=%s and pid=%s and gid=%s",
                             (self.uid_idx, res[0][0], res[0][1]))

        if len(trust) == 0:
            return EmulabResponse(
                RESPONSE_FORBIDDEN,
                output=("You do not have permission to access: "
                        + argdict["node"]))

        res = DBQueryFatal("SELECT sshrsa_v1,sshrsa_v2,sshdsa_v2,sfshostid "
                           "FROM node_hostkeys WHERE node_id=%s",
                           (argdict["node"],))
        
        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such node: " + argdict["node"])

        result = {}
        if res[0][0]:
            result["sshrsa_v1"] = res[0][0]
            pass
        if res[0][1]:
            result["sshrsa_v2"] = res[0][1]
            pass
        if res[0][2]:
            result["sshdsa_v2"] = res[0][2]
            pass
        if res[0][3]:
            result["sfshostid"] = res[0][3]
            pass

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result,
                              output=str(result))


    #
    # reboot nodes
    #
    def reboot(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("nodes",))
        if (argerror):
            return argerror

        argstr = ""
        doslow = 0
        for opt, val in argdict.items():
            if opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "power":
                if xbool(val):
                    argstr += " -f "
                    pass
                pass
            elif opt == "slow":
                if xbool(val):
                    doslow = 1
                    pass
                pass
            elif opt == "reconfig":
                if xbool(val):
                    argstr += " -c "
                    pass
                pass
            pass

        tokens = re.split(r'[ \t\n,]+', argdict["nodes"])
        
        for token in tokens:
            #if len(token) > 0:
            argstr += " " + escapeshellarg(token)
            #pass
            pass

        if doslow:
            (exitval, output) = runcommand(TBDIR + "/bin/power off " + argstr)
            if exitval:
                return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
            time.sleep(30)
            (exitval, output) = runcommand(TBDIR + "/bin/power on " + argstr)
            if exitval:
                return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
            pass
        else:
            (exitval, output) = runcommand(TBDIR + "/bin/node_reboot " + argstr)
            output += argstr
            if exitval:
                return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
            pass

        # NB: the actual output makes the XML parsers choke and die.
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # create_image.
    #
    def create_image(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("imagename", "node"))
        if (argerror):
            return argerror

        argstr = ""
        for opt, val in argdict.items():
            if opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            pass

        argstr += " " + escapeshellarg(argdict["imagename"])
        argstr += " " + escapeshellarg(argdict["node"])

        (exitval, output) = runcommand(TBDIR + "/sbin/clone_image " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Reload nodes.
    #
    def reload(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("nodes",))
        if (argerror):
            return argerror

        argstr = ""
        for opt, val in argdict.items():
            if opt == "wait":
                if not xbool(val):
                    argstr += " -s "
                    pass
                pass
            elif opt == "bootwait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "imageproj":
                argstr += " -p "
                argstr += escapeshellarg(val)
                pass
            elif opt == "imagename":
                argstr += " -i "
                argstr += escapeshellarg(val)
                pass
            elif opt == "imageid":
                argstr += " -m "
                argstr += escapeshellarg(val)
                pass
            elif opt == "reboot":
                if not xbool(val):
                    argstr += " -r "
                    pass
                pass
            elif opt == "usecurrent":
                if xbool(val):
                    argstr += " -c "
                    pass
                pass
            elif opt == "force":
                if xbool(val):
                    argstr += " -P "
                    pass
                pass
            pass

        tokens = argdict["nodes"].split(",")
        for token in tokens:
            argstr += " " + escapeshellarg(token)
            pass

        (exitval, output) = runcommand(TBDIR + "/bin/os_load " + argstr)

        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Turn on/off admin mode (boot into FreeBSD MFS).
    #
    def adminmode(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("mode", "node"))
        if (argerror):
            return argerror

        if (argdict["mode"] != "on" and
            argdict["mode"] != "off"):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="mode must be on or off")

        argstr = ""
        for opt, val in argdict.items():
            if opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "reboot":
                if not xbool(val):
                    argstr += " -n "
                    pass
                pass
            pass

        argstr += " " + escapeshellarg(argdict["mode"]);
        argstr += " " + escapeshellarg(argdict["node"]);

        (exitval, output) = runcommand(TBDIR + "/bin/node_admin " + argstr)

        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    def tbuisp(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("op", "filestr", "nodes"))
        if (argerror):
            return argerror

        (fp, filename) = writensfile(argdict["filestr"].data)

        argstr = escapeshellarg(argdict["op"])
        argstr += " " + filename
        argstr += " " + " ".join(map(escapeshellarg,argdict["nodes"]))

        (exitval, output) = runcommand(TBDIR + "/bin/tbuisp " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)

        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    def statewait(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("node", "state"))
        if (argerror):
            return argerror

        # Check for well formed proj/exp and
        if not (re.match("^[-\w]*$", argdict["node"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed node value!")

        # ... timeout arguments.
        if ("timeout" in argdict and
            isinstance(argdict["timeout"], str) and
            not re.match("^[\d]*$", argdict["timeout"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed timeout!")

        # Make sure the state argument is a list.
        if (not isinstance(argdict["state"], list)):
            argdict["state"] = [argdict["state"],]
            pass
        
        #
        # Check permission.
        #
        permerror = CheckNodePermission(self.uid_idx, argdict["node"])
        if (permerror):
            return permerror

        res = DBQueryFatal(
            "select ns.status,n.eventstate from node_status as ns "
            "left join nodes as n on n.node_id=ns.node_id "
            "where ns.node_id=%s",
            (argdict["node"],))
        
        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such node: " + argdict["node"])

        # First, see if the node is already in the desired state,
        status = res[0][0]
        eventstate = res[0][1]
        if (status == "up" and eventstate in argdict["state"]):
            return EmulabResponse(RESPONSE_SUCCESS,
                                  value=eventstate,
                                  output=eventstate)

        # ... subscribe to the event, and then
        try:
            import tbevent
            pass
        except ImportError as e:
            return EmulabResponse(RESPONSE_ERROR, output="System Error")

        at = tbevent.address_tuple()
        at.objtype = "TBNODESTATE"
        at.objname = argdict["node"]
        at.host    = BOSSNODE

        try:
            mc = tbevent.EventClient(server="localhost", port=BOSSEVENTPORT)
            mc.subscribe(at)
            pass
        except:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Could not connect to Event System")

        # ... check the state again in case it changed between the first
        # check and the subscription.
        res = DBQueryFatal(
            "select ns.status,n.eventstate from node_status as ns "
            "left join nodes as n on n.node_id=ns.node_id "
            "where ns.node_id=%s",
            (argdict["node"],))
        
        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such node: " + argdict["node"])

        if ("timeout" in argdict):
            signal.signal(signal.SIGALRM, TimeoutHandler)
            signal.alarm(int(argdict["timeout"]))
            pass

        status = res[0][0]
        eventstate = res[0][1]
        if (status == "up" and eventstate in argdict["state"]):
            return EmulabResponse(RESPONSE_SUCCESS,
                                  value=eventstate,
                                  output=eventstate)
        
        # Need to wait for an event.
        try:
            while True:
                ev = mc.poll()

                if ev == None:
                    time.sleep(1) # Slow down the polling.
                    continue

                # ... check if it is one the user cares about.
                if ((argdict["state"] == []) or
                    (ev.getEventType() in argdict["state"])):
                    retval = ev.getEventType()
                    break

                pass
            pass
        except TimedOutError as e:
            return EmulabResponse(RESPONSE_TIMEDOUT,
                                  output=("Timed out waiting for states: "
                                          + repr(argdict["state"])))

        if ("timeout" in argdict):
            signal.alarm(0)
            pass

        del(mc)
        
        return EmulabResponse(RESPONSE_SUCCESS, value=retval, output=retval)

    #
    # Get widearea node configuration params, returned as a dict.
    #
    def waconfig(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        argerror = CheckRequiredArgs(argdict, ("node",))
        if (argerror):
            return argerror

        if not re.match("^[-\w]*$", str(argdict["node"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed node value!")

        if not CheckIsAdmin(self.uid_idx):
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No permission to access node: " +
                                  argdict["node"])
            pass

        res = DBQueryFatal("select wni.hostname,wni.bwlimit,wni.privkey,"
                           "  wni.IP,wni.gateway,wni.dns,wni.boot_method,"
                           "  i.mac,i.mask"
                           " from widearea_nodeinfo as wni"
                           " left join interfaces as i"
                           "   on wni.node_id=i.node_id"
                           " where wni.node_id=%s and i.role=%s",
                           (argdict["node"],'ctrl'))
        
        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such widearea node: %s" \
                                  % (argdict["node"],))
        elif len(res) > 1:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Multiple matches for node: %s" \
                                  % (argdict["node"],))

        row = res[0]

        retval = dict({})
        retval['WA_BOOTMETHOD'] = row[6]
        try:
            retval['WA_HOSTNAME'] = row[0].split('.',1)[0]
        except:
            retval['WA_HOSTNAME'] = row[0]
        try:
            retval['WA_DOMAIN'] = row[0].split('.',1)[1]
        except:
            retval['WA_DOMAIN'] = ""

        if row[6] == 'static':
            retval['WA_MAC'] = row[7]
            retval['WA_IP_ADDR'] = row[3]
            retval['WA_IP_NETMASK'] = row[8]
            retval['WA_IP_GATEWAY'] = row[4]
            retval['WA_IP_DNS1'] = row[5]
            retval['WA_IP_DNS2'] = "198.22.255.3"
            pass

        if row[1] and not row[1] == 0:
            retval['WA_BWLIMIT'] = row[1]

        retval['PRIVKEY'] = row[2]
        
        return EmulabResponse(RESPONSE_SUCCESS,value=retval)
    
    #
    # Verify request to download a tar/rpm file.
    #
    def spewrpmtar_verify(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("file", "node", "key"))
        if (argerror):
            return argerror

        if not re.match("^[-\w]*$", str(argdict["node"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed node value!")
        if not re.match("^[-\w]*$", str(argdict["key"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed key value!")

        argstr = ""
        argstr += " " + escapeshellarg(argdict["key"]);
        argstr += " " + escapeshellarg(argdict["node"]);
        argstr += " " + escapeshellarg(argdict["file"]);

        (exitval, output) = runcommand(TBDIR + "/libexec/spewrpmtar_verify " +
                                       argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    pass

#
# Hack class to get subbosses working... Note that nothing we do
# in this class can damage anything or mess up anything outside the expt.
#
class subboss:
    ##
    # Initialize the object.  Currently only sets the objects 'VERSION' value.
    #
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        self.clientip = server.clientip;
        self.pid      = None;
        self.eid      = None;
        return

    #
    # Anything we do from this class has to be called by a node,
    # that node must be reserved, a subboss, and assigned to an
    # active experiment.  
    #
    def verifystuff(self):
        if self.clientip == None:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="SSL connections only")

        res = DBQueryFatal("select i.node_id,r.erole "
                           "  from interfaces as i "
                           "left join reserved as r on r.node_id=i.node_id "
                           "where i.IP=%s and i.role='ctrl'",
                           (self.clientip,))
        
        # IP must map to a node.
        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such node for IP: " +
                                  self.clientip)
        
        # Node must be reserved.
        if res[0][1] == None:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Node is not reserved: " + res[0][0])
        
        # Must be a subboss.
        if res[0][1] != "subboss":
            return EmulabResponse(RESPONSE_FORBIDDEN,
                                  output="Not a subboss");
        
        if self.uid != SUBBOSS_UID:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                                  output="Invalid UID")
        
        return None;
    #
    # Return info for a particular image on a given subboss
    # 
    def get_load_address(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("subboss_id", "imageid",))
        if (argerror):
            return argerror
        
        if not re.match("^[-\@\w\+\.]*$", str(argdict["imageid"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed imageid value!")
        
        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror

        lock_subboss_image_table()

        res = DBQueryFatal("select load_address,frisbee_pid "
                           " from subboss_images "
                           "where imageid=%s and subboss_id=%s",
                           (str(argdict["imageid"]), argdict["subboss_id"]))

        if len(res) == 0:
            unlock_tables()
            return EmulabResponse(RESPONSE_ERROR, output="No such image")

        unlock_tables()
        result = {}
        result["address"] = res[0][0]
        result["frisbee_pid"] = res[0][1]

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=result, output=str(result))


    #
    # Return a multicast_address for subboss_frisbeed
    # 
    def allocate_load_address(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("subboss_id", "imageid",))
        if (argerror):
            return argerror
        
        if not re.match("^[-\@\w\+\.]*$", str(argdict["imageid"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed imageid value!")

        
        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror

        status, msg = next_mcast_address()
        if not status:
            return EmulabResponse(RESPONSE_ERROR, output=msg)
        else:
            mcast_address = msg

        lock_subboss_image_table()

        res = DBQueryFatal("select load_address,frisbee_pid "
                           " from subboss_images"
                           "where subboss_id=%s and imageid=%s",
                           (argdict["subboss_id"], str(argdict["imageid"])))
        if len(res) == 0:
            # This pair doesn't exist in the table yet.  Better insert it
            res = DBQueryFatal("insert into subboss_images "
                               " values (%s,%s,'',0,1,0)",
                               (argdict["subboss_id"], argdict["imageid"]))
        elif res[0][0] != "":
            # Subboss is already running a frisbeed for this image,
            # so just update the busy flag
            subboss_image_set_busy(argdict["subboss_id"],
                                      argdict["imageid"])
            unlock_tables()
            return EmulabResponse(RESPONSE_ERROR,
                                     output="Frisbee server already running")
        elif res[0][1] != 0:
            unlock_tables()
            return EmulabResponse(RESPONSE_ERROR,
                                     output="Bad DB state: "
                                     "frisbeed PID without load_address")


        res = DBQueryFatal("update subboss_images "
                           " set load_address = %s, load_busy = 1 "
                           "where subboss_id=%s and imageid=%s",
                           (mcast_address,
                            argdict["subboss_id"], argdict["imageid"]))
        unlock_tables()

        return EmulabResponse(RESPONSE_SUCCESS,
                              value=mcast_address, output=mcast_address)

    #
    # Reset a subboss image entry; called when frisbeed is no longer needed
    # 
    def clear_load_address(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("subboss_id", "imageid",))
        if (argerror):
            return argerror
        
        if not re.match("^[-\@\w\+\.]*$", str(argdict["imageid"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed imageid value!")
        
        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror

        lock_subboss_image_table()

        res = DBQueryFatal("select load_address,frisbee_pid "
                           " from subboss_images "
                           "where subboss_id=%s and imageid=%s",
                           (argdict["subboss_id"], str(argdict["imageid"])))
        if len(res) == 0:
            unlock_tables()
            return EmulabResponse(RESPONSE_ERROR, output="No such image")

        res = DBQueryFatal("update subboss_images "
                           " set load_address='',frisbee_pid=0, load_busy=0 "
	                       "where subboss_id=%s and imageid=%s",
                           (argdict["subboss_id"], str(argdict["imageid"])))
        unlock_tables()

        return EmulabResponse(RESPONSE_SUCCESS)

    #
    # Set process ID for subboss frisbeed
    # 
    def set_frisbee_pid(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict,
                                     ("subboss_id", "imageid", "frisbee_pid"))
        if (argerror):
            return argerror
        
        if not re.match("^[-\@\w\+\.]*$", str(argdict["imageid"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed imageid value!")
        
        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror

        lock_subboss_image_table()

        res = DBQueryFatal("select load_address,frisbee_pid "
                           " from subboss_images "
		          "where subboss_id=%s and imageid=%s",
                           (argdict["subboss_id"], str(argdict["imageid"])))
        if len(res) == 0:
            unlock_tables()
            return EmulabResponse(RESPONSE_ERROR, output="No such image")
        elif res[0][0] == "":
            unlock_tables()
            return EmulabResponse(RESPONSE_ERROR,
                                     output="No address for image")

        res = DBQueryFatal("update subboss_images "
                           " set frisbee_pid=%s "
                           "where subboss_id=%s and imageid=%s",
                           (argdict["frisbee_pid"], argdict["subboss_id"],
                            str(argdict["imageid"])))
        unlock_tables()

        return EmulabResponse(RESPONSE_SUCCESS)

    #
    # Set sync flag for an image
    # 
    def set_sync_flag(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict,
                                     ("subboss_id", "imageid", "sync"))
        if (argerror):
            return argerror
        
        if not re.match("^[-\@\w\+\.]*$", str(argdict["imageid"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed imageid value!")
        
        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror

        lock_subboss_image_table()

        res = DBQueryFatal("select sync from subboss_images "
                           "where subboss_id=%s and imageid=%s",
                           (argdict["subboss_id"], str(argdict["imageid"])))
        if len(res) == 0:
            # This pair doesn't exist in the table yet.  Better insert it
            res = DBQueryFatal("insert into subboss_images "
                               " values (%s,%s,'',0,0,%d)",
                               (argdict["subboss_id"],
                                str(argdict["imageid"]), argdict["sync"]))
        else:
            res = DBQueryFatal("update subboss_images "
                                   " set sync=%s "
                                   "where subboss_id=%s and imageid=%s",
                                   (argdict["sync"], argdict["subboss_id"],
                                    str(argdict["imageid"])))
        unlock_tables()

        return EmulabResponse(RESPONSE_SUCCESS)

    #
    # See if subboss image 'busy' flag is set;
    # indicates frisbeed should run again
    # 
    def image_requested(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("subboss_id", "imageid"))
        if (argerror):
            return argerror
        
        if not re.match("^[-\@\w\+\.]*$", str(argdict["imageid"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed imageid value!")
        
        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror

        lock_subboss_image_table()
        busy = 0

        res = DBQueryFatal("select load_address,frisbee_pid,load_busy "
                           " from subboss_images "
                           "where subboss_id=%s and imageid=%s",
                           (argdict["subboss_id"], str(argdict["imageid"])))
        if len(res) == 0:
            unlock_tables()
            return EmulabResponse(RESPONSE_ERROR, output="No such image")
        elif res[0][0] == "":
            unlock_tables()
            return EmulabResponse(RESPONSE_ERROR,
                                     output="No address for image")
        elif res[0][1] == 0:
            unlock_tables()
            return EmulabResponse(RESPONSE_ERROR,
                                     output="PID not set for image")

        if res[0][2] > 0:
            busy = 1
            res = DBQueryFatal("update subboss_images "
                                  " set load_busy=0 "
                                  "where subboss_id=%s and imageid=%s",
                                  (argdict["subboss_id"],
                                   str(argdict["imageid"])))

        unlock_tables()

        return EmulabResponse(RESPONSE_SUCCESS, value=busy, output=str(busy))

    #
    # Fire up a frisbeed for an image,
    # This is essentially the same as the frisbeelauncher method for
    # elabinelab
    # 
    def frisbeelauncher(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("imageid",))
        if (argerror):
            return argerror
        
        if not re.match("^[-\@\w\+\.]*$", str(argdict["imageid"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed imageid value!")
        
        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror
        
        argstr = escapeshellarg(str(argdict["imageid"]))
        
	# We need admin privileges for non-global images since elabman won't
	# belong to any projects.  We've already checked to make sure the user
	# has permission to load the image in libosload so we don't need to
	# check again in frisbeelauncher.  Only a subboss can make this request
	# anyway.
        (exitval, output) = runcommand(TBDIR +
                                     "/sbin/subboss_wrapper frisbeelauncher " +
                                     argstr)

        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        #
        # Success. Must get the loadinfo out of the DB so we can pass it back.
        #
        res = DBQueryFatal("select load_address "
                           " from frisbee_blobs where imageid=%s",
                           (str(argdict["imageid"]),))
        
        # Hmm, something went wrong?
        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Imageid is gone: " +
                                  argdict["imageid"])
        
        if (res[0][0] == None or res[0][0] == ""):
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No load_address in DB: " +
                                  argdict["imageid"])
        
        return EmulabResponse(RESPONSE_SUCCESS, str(res[0][0]), output=output)
    

#
# Hack class to get ElabInElab limping along ... Note that nothing we do
# in this class can damage anything or mess up anything outside the expt.
#
class elabinelab:
    ##
    # Initialize the object.  Currently only sets the objects 'VERSION' value.
    #
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        self.clientip = server.clientip;
        self.pid      = None;
        self.eid      = None;
        self.node     = None;
        return

    #
    # Anything we do from this class has to include pid/eid, and that
    # pid/eid has to have it elabinelab bit set, and the uid of the
    # user invoking the method has to be the creator of the experiment.
    # This might seem overly pedantic, but its probably how it would
    # look if this was a standalone RPC server supporting elabinelab.
    #
    def verifystuff(self):
        if self.clientip == None:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="SSL connections only")
            
        res = DBQueryFatal("select i.node_id,r.pid,r.eid,"
                           "       e.elab_in_elab,e.state,e.expt_head_uid, "
                           "       r.inner_elab_role "
                           "  from interfaces as i "
                           "left join reserved as r on r.node_id=i.node_id "
                           "left join experiments as e on e.pid=r.pid and "
                           "     e.eid=r.eid "
                           "where i.IP=%s and i.role='ctrl'",
                           (self.clientip,))
        
        # IP must map to a node.
        if len(res) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such node for IP: " +
                                  self.clientip)
        
        # Node must be reserved.
        if res[0][1] == None:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Node is not reserved: " + res[0][0])
        
        # Needed below
        self.pid = res[0][1]
        self.eid = res[0][2]
        
        # Must be an ElabInElab experiment.
        if int(res[0][3]) != 1:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                                  output="Not an elabinelab experiment: " +
                                  res[0][1] + "/" + res[0][2]);
        
        # Experiment must be active (not swapping out).
        if (not (res[0][4] == "active" or res[0][4] == "activating")):
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Experiment is not active: " +
                                  res[0][1] + "/" + res[0][2]);
        
        # SSL certificate of caller must map to uid of experiment creator.
        if res[0][5] != self.uid:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                                  output="Must be creator to access " +
                                  "elabinelab method for " +
                                  res[0][1] + "/" + res[0][2]);
        
        # Must be the boss node that is making the request.
        if (not (res[0][6] == "boss" or res[0][6] == "boss+router"
            or res[0][6] == "boss+fs+router")):
            return EmulabResponse(RESPONSE_FORBIDDEN,
                                  output="Must be boss node accessing " +
                                  "elabinelab method for " +
                                  res[0][1] + "/" + res[0][2]);
        
        self.node = res[0][0];

        return None;

    #
    # Power cycle a node.
    # 
    def power(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("nodes", "op"))
        if (argerror):
            return argerror

        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror

        if (argdict["op"] != "on" and
            argdict["op"] != "off" and
            argdict["op"] != "cycle"):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="op must be on, off or cycle")

        argstr = argdict["op"];
        tokens = argdict["nodes"].split(",")
        for token in tokens:
            argstr += " " + escapeshellarg(token)
            pass

        (exitval, output) = runcommand(TBDIR + "/bin/power " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)
    
    #
    # node tip acl stuff so inner console link works, redirecting user
    # to where the real console is (outer emulab).
    # 
    def console(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("node",))
        if (argerror):
            return argerror

        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror

        #
        # Funnel up to node.console() routine
        # 
        node_instance = node(self.server);
        
        return node_instance.console(version, argdict);
    
    def vlansv3(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("xmldoc",))
        if (argerror):
            return argerror

        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror

        #
        # We get an xmldoc as the argument, which we give to the proxy
        # to decode on its own. Easier then trying to decode a bunch
        # of stuff to pass on the commandline.
        #
        (xmlfp, xmlfilename) = writensfile(argdict["xmldoc"]);
        if not xmlfilename:
            return EmulabResponse(RESPONSE_SERVERERROR, output="Server Error")

        #
        # Create a temporary file for the output.
        #
        (outfp, outfilename) = writensfile("");
        if not outfilename:
            return EmulabResponse(RESPONSE_SERVERERROR, output="Server Error")

        argstr  = "-o " + outfilename + " ";
        argstr += "-p " + self.pid + " -e " + self.eid + " " + xmlfilename;

        (exitval,output) = runcommand("/usr/testbed/sbin/snmpit.proxyv3 " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)

        #
        # Results are in the outfile.
        #
        stuff = ""
        for l in outfp:
            stuff += _bytes2str(l)
            pass
        
        return EmulabResponse(RESPONSE_SUCCESS, value=stuff, output=output)

    #
    # Fire up a frisbeed for an image,
    # 
    def frisbeelauncher(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("imageid",))
        if (argerror):
            return argerror
        
        if not re.match("^[-\@\w\+\.]*$", str(argdict["imageid"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed imageid value!")
        
        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror
        
        argstr = escapeshellarg(str(argdict["imageid"]))
        
        (exitval, output) = runcommand(TBDIR + "/sbin/frisbeehelper -n " +
                                       self.node + " " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        #
        # Success. Load address was output so parse it out.
        #
        m = re.search("^Address is (.*)$", output)
        if m == None or m.group(1) == None:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Could not image info for: " +
                                  argdict["imageid"])
        addr = m.group(1)
        return EmulabResponse(RESPONSE_SUCCESS, value=str(addr))
    
    #
    # Return the equivalent of what switchmac does. This is used so that
    # nodes can be added to an inner emulab in mostly the same fashion as
    # the outer emulab, but without having to talk to the switch directly.
    # 
    def switchmac(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))
        
        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror
        
        dbres = DBQueryFatal("select elabinelab_singlenet from experiments "
                             "where pid=%s and eid=%s",
                             (self.pid,self.eid,))

        if len(dbres) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment!")

        singlenet = int(dbres[0][0]);
        
        #
        # Okay, lets grab what we need. This code is going to return the
        # equiv of what the switchmac script does, but with a few minor
        # changes.
        #
        dbres = DBQueryFatal("select r.node_id,i.mac,i.iface,i.role,"
                             "  s.node_id2,s.card2,s.port2,i.IP "
                             "from reserved as r "
                             "left join interfaces as i on "
                             "   i.node_id=r.node_id "
                             "left join wires as s on s.node_id1=i.node_id "
                             "   and s.iface1=i.iface "
                             "where r.pid=%s and r.eid=%s "
                             "   and r.inner_elab_role='node' "
			     "   and s.node_id2!='' "
                             "order by r.node_id,i.iface",
                             (self.pid,self.eid,))
        
        result = {}
        for res in dbres:
            tmp = {}

            #
            # The current control network becomes the outer control network.
            # The experimental network with an IP assigned becomes the
            # inner control network.  Interfaces other than experimental
            # or control (e.g., fake IXP interfaces) are ignored.
            #
            role = res[3]
            IP   = res[7]

            if not singlenet:
                if role == "ctrl":
                    role = "outer_ctrl"
                    pass
                elif role == "expt" and IP != "":
                    role = "ctrl"
                    pass
                pass
            elif role != "expt" and role != "ctrl":
                continue
            
            tmp["mac"]         = res[1]
            tmp["iface"]       = res[2]
            tmp["role"]        = role
            tmp["switch_id"]   = res[4]
            tmp["switch_card"] = res[5]
            tmp["switch_port"] = res[6]
            result[res[1]]     = tmp;
            pass
        return EmulabResponse(RESPONSE_SUCCESS, result, output=str(result))
    
    #
    # Return some stuff about a newnode so that the inner newnode path
    # can operate properly
    #
    def newnode_info(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))
        
        argerror = CheckRequiredArgs(argdict, ("mac",))
        if (argerror):
            return argerror

        if not re.match("^[\w]*$", str(argdict["mac"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed mac value!")
        
        verifyerror = self.verifystuff();
        if (verifyerror):
            return verifyerror

        #
        # First map the mac to a node by looking in the interfaces table.
        #
        dbres = DBQueryFatal("select node_id,role,IP from interfaces "
                             "where mac=%s",
                             (argdict["mac"],))
        
        # Hmm, something went wrong?
        if len(dbres) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="Cannot map MAC to nodeid")

        nodeid = dbres[0][0]

        dbres = DBQueryFatal("select i.mac,i.role,i.IP "
                             "    from interfaces as i "
                             "where node_id=%s ",
                             (nodeid,))
        
        result = {}
        result["nodeid"] = nodeid
        result["type"]   = ""
        interfaces       = {}
        
        for res in dbres:
            tmp = {}

            #
            # The current control network becomes the outer control network.
            # The experimental network with an IP assigned becomes the
            # inner control network.
            #
            imac  = res[0]
            role  = res[1]
            IP    = res[2]
            
            if role == "ctrl":
                role = "outer_ctrl"
                pass
            elif role == "expt" and IP != "":
                role = "ctrl"
                pass
            
            tmp["role"]        = role
            tmp["IP"]          = IP
            interfaces[imac] = tmp
            pass
        
        result["interfaces"] = interfaces
         
        return EmulabResponse(RESPONSE_SUCCESS, result, output=str(result))
    pass


#
# This class implements the server side of the XMLRPC interface to experiments.
#
class template:
    ##
    # Initialize the object.  Currently only sets the objects 'VERSION' value.
    #
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    def addprogevent(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict,
                                     ("proj", "exp", "when", "vnode", "cmd"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["proj"]) and
                re.match("^[-\w]*$", argdict["exp"]) and
                re.match("^[-\w]*$", argdict["vnode"]) and
                re.match("^[-\w]*$", argdict["when"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed arguments")

        #
        # Check permission. This will check proj/exp for illegal chars.
        #
        permerror = CheckExptPermission(self.uid_idx,
                                        argdict["proj"], argdict["exp"])
        if (permerror):
            return permerror

        # Need to pass experiment index to script.
        dbres = DBQueryFatal("SELECT idx FROM experiments "
                             "WHERE pid=%s and eid=%s",
                             (argdict["proj"], argdict["exp"]))
        
        if len(dbres) == 0:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such experiment!")
        exptidx = dbres[0][0]
        (guid,version) = TemplateLookup(exptidx)
        if guid == None:
            return EmulabResponse(RESPONSE_ERROR,
                                  output="No such template instance")

        argstr  = " -a addevent " + str(guid) + "/" + str(version)
        argstr += " -i " + str(exptidx)
        argstr += " -t " + str(argdict["when"])
        argstr += " -n " + argdict["vnode"]
        argstr += " -c " + escapeshellarg(argdict["cmd"])
        
        (exitval, output) = runcommand(TBDIR +
                                       "/bin/template_control " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Commit (modify) a template.
    #
    def template_commit(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argstr  = "-q"

        for opt, val in argdict.items():
            if opt == "exp":
                argstr += " -e "
                argstr += escapeshellarg(val)
                pass
            elif opt == "proj":
                argstr += " -p "
                argstr += escapeshellarg(val)
                pass
            elif opt == "description":
                argstr += " -E "
                argstr += escapeshellarg(val)
                pass
            elif opt == "tid":
                argstr += " -t "
                argstr += escapeshellarg(val)
                pass
            elif opt == "tag":
                argstr += " -r "
                argstr += escapeshellarg(val);
                pass
            pass

        if "guid" in argdict:
            if not (re.match("^[-\w\/]*$", argdict["guid"])):
                return EmulabResponse(RESPONSE_BADARGS,
                                      output="Improperly formed arguments")

            argstr += " "
            argstr += str(argdict["guid"])
            pass
        elif "path" in argdict:
            argstr += " -q -f "
            argstr += escapeshellarg(argdict["path"]);
            pass
        
        (exitval, output) = runcommand(TBDIR +
                                       "/bin/template_commit " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Checkout a template.
    #
    def checkout(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("guid", "path"))
        if (argerror):
            return argerror

        if not (re.match("^[-\w\/]*$", argdict["guid"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed arguments")

        argstr  = "-q -f " + escapeshellarg(argdict["path"])
        argstr += " " + escapeshellarg(argdict["guid"])

        (exitval, output) = runcommand(TBDIR +
                                       "/bin/template_checkout " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Export a template.
    #
    def export(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("instance",))
        if (argerror):
            return argerror

        if not (re.match("^[-\w]*$", argdict["instance"])):
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Improperly formed arguments")

        argstr  = "-q"

        for opt, val in argdict.items():
            if opt == "instance":
                argstr += " -i "
                argstr += escapeshellarg(val)
                pass
            elif opt == "run":
                argstr += " -r "
                argstr += escapeshellarg(val)
                pass
            pass

        (exitval, output) = runcommand(TBDIR +
                                       "/bin/template_export " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Instantiate a template.
    #
    def instantiate(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("guid", "exp"))
        if (argerror):
            return argerror
        
        xmlfilename = None
        argstr      = "-q"
        
        for opt, val in argdict.items():
            if opt == "batch":
                if not xbool(val):
                    argstr += " -b"
                    pass
                pass
            elif opt == "preload":
                if not xbool(val):
                    argstr += " -p"
                    pass
                pass
            elif opt == "description":
                argstr += " -E "
                argstr += escapeshellarg(val)
                pass
            elif opt == "swappable":
                if not xbool(val):
                    if "noswap_reason" not in argdict:
                        return EmulabResponse(RESPONSE_BADARGS,
                                       output="Must supply noswap reason!");
                    argstr += " -S "
                    argstr += escapeshellarg(argdict["noswap_reason"])
                    pass
                pass
            elif opt == "noswap_reason":
                pass
            elif opt == "idleswap":
                if val == 0:
                    if "noidleswap_reason" not in argdict:
                        return EmulabResponse(RESPONSE_BADARGS,
                                      output="Must supply noidleswap reason!");
                    argstr += " -L "
                    argstr += escapeshellarg(argdict["noidleswap_reason"])
                    pass
                else:
                    argstr += " -l "
                    argstr += escapeshellarg(str(val))
                    pass
                pass
            elif opt == "noidleswap_reason":
                pass
            elif opt == "autoswap" or opt == "max_duration":
                argstr += " -a "
                argstr += escapeshellarg(str(val))
                pass
            elif opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "xmlfilepath":
                # Backend script will verify this local path. 
                xmlfilename = escapeshellarg(val)
                pass
            elif opt == "xmlfilestr":
                xmlfilestr = val
            
                if len(xmlfilestr) > (1024 * 512):
                    return EmulabResponse(RESPONSE_TOOBIG,
                                         output="XML File way too big!");
        
                (xmlfp, xmlfilename) = writensfile(xmlfilestr)
                if not xmlfilename:
                    return EmulabResponse(RESPONSE_SERVERERROR,
                                         output="Server Error")
                pass
            pass

        if xmlfilename:
            argstr += " -x " + xmlfilename
            pass

        argstr += " -e " + escapeshellarg(argdict["exp"])
        argstr += " " + escapeshellarg(argdict["guid"])

        (exitval, output) = runcommand(TBDIR +
                                       "/bin/template_instantiate " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # swapin a preloaded template instance
    #
    def swapin(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("guid", "exp"))
        if (argerror):
            return argerror

        argstr = "-q"
        for opt, val in argdict.items():
            if opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "quiet":
                if xbool(val):
                    argstr += " -q "
                    pass
                pass
            pass

        argstr += " -e " + escapeshellarg(argdict["exp"])
        argstr += " " + escapeshellarg(argdict["guid"])

        (exitval, output) = runcommand(TBDIR +
                                       "/bin/template_swapin " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)
    pass

    #
    # Start a new run
    #
    def newrun(self, action, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("exp", ))
        if (argerror):
            return argerror

        pid         = None
        xmlfilename = None
        argstr      = "-q"
        
        for opt, val in argdict.items():
            if opt == "description":
                argstr += " -E "
                argstr += escapeshellarg(val)
                pass
            elif opt == "clear":
                argstr += " -c "
                pass
            elif opt == "runid":
                argstr += " -r "
                argstr += escapeshellarg(val)
                pass
            elif opt == "pid":
                pid = escapeshellarg(val)
                pass
            elif opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "modify":
                if xbool(val):
                    argstr += " -m "
                    pass
                pass
            elif opt == "params":
                argstr += " -y "
                argstr += escapeshellarg(val)
                pass
            elif opt == "xmlfilepath":
                # Backend script will verify this local path. 
                xmlfilename = escapeshellarg(val)
                pass
            elif opt == "xmlfilestr":
                xmlfilestr = val
            
                if len(xmlfilestr) > (1024 * 512):
                    return EmulabResponse(RESPONSE_TOOBIG,
                                         output="XML File way too big!");
        
                (xmlfp, xmlfilename) = writensfile(xmlfilestr)
                if not xmlfilename:
                    return EmulabResponse(RESPONSE_SERVERERROR,
                                         output="Server Error")
                pass
            pass

        if pid == None and "guid" not in argdict:
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Must supply pid or guid")

        if xmlfilename:
            argstr += " -x " + xmlfilename
            pass

        argstr += " -e " + escapeshellarg(argdict["exp"])
        argstr += " -a " + action + " "

        if pid == None:
            argstr += " " + escapeshellarg(argdict["guid"])
            pass
        else:
            argstr += " -p " + pid
            pass

        (exitval, output) = runcommand(TBDIR +
                                       "/bin/template_exprun " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    def startrun(self, version, argdict):
        return self.newrun("start", version, argdict)
                
    def modrun(self, version, argdict):
        return self.newrun("modify", version, argdict)
    
    #
    # Stop current run.
    #
    def stoprun(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("exp",))
        if (argerror):
            return argerror
        
        pid    = None
        argstr = "-q"
        
        for opt, val in argdict.items():
            if opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            elif opt == "token":
                argstr += " -t "
                argstr += escapeshellarg(val)
                pass
            elif opt == "quiet":
                if xbool(val):
                    argstr += " -q "
                    pass
                pass
            elif opt == "ignoreerrors":
                if xbool(val):
                    argstr += " -i "
                    pass
                pass
            elif opt == "pid":
                pid = escapeshellarg(val)
                pass
            pass
        
        if pid == None and "guid" not in argdict:
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Must supply pid or guid")

        argstr += " -e " + escapeshellarg(argdict["exp"])
        argstr += " -a stop"
        
        if pid == None:
            argstr += " " + escapeshellarg(argdict["guid"])
            pass
        else:
            argstr += " -p " + pid
            pass
        
        (exitval, output) = runcommand(TBDIR +
                                       "/bin/template_exprun " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Terminate an instance
    #
    def swapout(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")
        
        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("guid", "exp"))
        if (argerror):
            return argerror

        argstr = "-q"
        for opt, val in argdict.items():
            if opt == "wait":
                if xbool(val):
                    argstr += " -w "
                    pass
                pass
            pass

        argstr += " -e " + escapeshellarg(argdict["exp"])
        argstr += " " + escapeshellarg(argdict["guid"])

        (exitval, output) = runcommand(TBDIR +
                                       "/bin/template_swapout " + argstr)
        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)
    pass

#
# This class implements the server side of the XMLRPC interface to blobs.
#
class blob:
    ##
    # Initialize the object.
    #
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    def mkblob( self, version, argdict ):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))
        
        argerror = CheckRequiredArgs(argdict, ("filename",))
        if (argerror):
            return argerror

        (exitval, output) = runcommand( TBDIR + "/bin/mkblob " + self.uid + " " + argdict[ "filename" ] )

        if exitval:
            return EmulabResponse( RESPONSE_ERROR, exitval >> 8, output=output )
        else:
            return EmulabResponse( RESPONSE_SUCCESS, value=0, output=output )

    def rmblob( self, version, argdict ):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))
        
        argerror = CheckRequiredArgs(argdict, ("uuid",))
        if (argerror):
            return argerror

        (exitval, output) = runcommand( TBDIR + "/bin/rmblob " + self.uid + " " + argdict[ "uuid" ] )

        if exitval:
            return EmulabResponse( RESPONSE_ERROR, exitval >> 8, output=output )
        else:
            return EmulabResponse( RESPONSE_SUCCESS, value=0, output=output )

#
# This class implements the server side of the XMLRPC interface to datasets,
# aka leases, aka persistent blockstores.
#
class dataset:
    ##
    # Initialize the object.
    #
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    def create( self, version, argdict ):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))
        
        argerror = CheckRequiredArgs(argdict, ("size","dataset"))
        if (argerror):
            return argerror

        #
        # Pass the whole thing off to the backend script. It would be nice
        # to do this differently, but too much trouble.
        #
        argstr = ""
        for opt, val in argdict.items():
            if opt == "noapprove":
                if xbool(val):
                    argstr += " -U "
                    pass
                pass
            elif opt == "size":
                argstr += " -s "
                argstr += escapeshellarg(val)
                pass
            elif opt == "type":
                argstr += " -t "
                argstr += escapeshellarg(val)
                pass
            elif opt == "fstype":
                argstr += " -f "
                argstr += escapeshellarg(val)
                pass
            elif opt == "expire":
                argstr += " -e "
                argstr += escapeshellarg(val)
                pass
            pass
        argstr += " " + escapeshellarg(argdict["dataset"])

        (exitval, output) = runcommand( TBDIR + "/bin/createdataset " + argstr)

        if exitval:
            return EmulabResponse( RESPONSE_ERROR, exitval >> 8, output=output )
        else:
            return EmulabResponse( RESPONSE_SUCCESS, value=0, output=output )

    def delete( self, version, argdict ):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))
        
        argerror = CheckRequiredArgs(argdict, ("dataset",))
        if (argerror):
            return argerror

        #
        # Pass the whole thing off to the backend script. It would be nice
        # to do this differently, but too much trouble.
        #
        argstr = ""
        for opt, val in argdict.items():
            if opt == "force":
                if xbool(val):
                    argstr += " -f "
                    pass
                pass
            pass
        argstr += " " + escapeshellarg(argdict["dataset"])

        (exitval, output) = runcommand( TBDIR + "/bin/deletelease " + argstr)

        if exitval:
            return EmulabResponse( RESPONSE_ERROR, exitval >> 8, output=output )
        else:
            return EmulabResponse( RESPONSE_SUCCESS, value=0, output=output )

    def extend( self, version, argdict ):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))
        
        argerror = CheckRequiredArgs(argdict, ("dataset",))
        if (argerror):
            return argerror

        #
        # Pass the whole thing off to the backend script.
        #
        argstr = escapeshellarg(argdict["dataset"])

        (exitval, output) = runcommand( TBDIR + "/bin/extendlease " + argstr)

        if exitval:
            return EmulabResponse( RESPONSE_ERROR, exitval >> 8, output=output )
        else:
            return EmulabResponse( RESPONSE_SUCCESS, value=0, output=output )

    def getlist( self, version, argdict ):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))
        
        #
        # Pass the whole thing off to the backend script. It would be nice
        # to do this differently, but too much trouble.
        #
        argstr = ""
        for opt, val in argdict.items():
            if opt == "limits":
                if xbool(val):
                    argstr += " -D "
                    pass
                pass
            elif opt == "all":
                if xbool(val):
                    argstr += " -a "
                    pass
                pass
            elif opt == "verbose":
                if xbool(val):
                    argstr += " -l "
                    pass
                pass
            elif opt == "proj":
                argstr += " -p "
                argstr += escapeshellarg(val)
                pass
            elif opt == "user":
                argstr += " -u "
                argstr += escapeshellarg(val)
                pass
            pass

        for name in argdict["datasets"]:
            argstr += " " + escapeshellarg(name);
            pass
        
        (exitval, output) = runcommand(TBDIR + "/bin/showlease " + argstr)

        if exitval:
            return EmulabResponse( RESPONSE_ERROR, exitval >> 8, output=output )
        else:
            return EmulabResponse( RESPONSE_SUCCESS, value=0, output=output )

#
# This class implements the server side of the XMLRPC interface to the Portal
#
class portal:
    ##
    # Initialize the object.  Currently only sets the objects 'VERSION' value.
    #
    def __init__(self, server):
        self.server   = server
        self.readonly = server.readonly
        self.uid      = server.uid
        self.uid_idx  = server.uid_idx
        self.debug    = server.debug
        self.VERSION  = VERSION
        return

    ##
    # Echo a message, basically, prepend the host name to the parameter list.
    #
    # @param args The argument list to echo back.
    # @return The 'msg' value with this machine's name prepended.
    #
    def echo(self, version, argdict):
        if "str" not in argdict:
            return EmulabResponse(RESPONSE_BADARGS,
                                  output="Must supply a string to echo!")
        
        return EmulabResponse(RESPONSE_SUCCESS, 0,
                              socket.gethostname() + ": " + str(version)
                            + " " + argdict["str"])
        pass

    #
    # Start a portal experiment.
    #
    def startExperiment(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("proj", "profile"))
        if (argerror):
            return argerror

        argstr     = ""
        profile    = None
        
        for opt, val in argdict.items():
            if opt == "name":
                argstr += " --name "
                argstr += escapeshellarg(val)
                pass
            elif opt == "proj":
                argstr += " --project "
                argstr += escapeshellarg(val)
                pass
            elif opt == "duration":
                argstr += " --duration "
                argstr += escapeshellarg(val)
                pass
            elif opt == "start":
                argstr += " --start "
                argstr += escapeshellarg(val)
                pass
            elif opt == "stop":
                argstr += " --stop "
                argstr += escapeshellarg(val)
                pass
            elif opt == "paramset":
                argstr += " --paramset "
                argstr += escapeshellarg(val)
                pass
            elif opt == "bindings":
                argstr += " --bindings "
                bindings = val
            
                if len(bindings) > (1024 * 16):
                    return EmulabResponse(RESPONSE_TOOBIG,
                                         output="Bindings way too big!");
        
                (fp, filename) = writensfile(bindings)
                if not filename:
                    return EmulabResponse(RESPONSE_SERVERERROR,
                                         output="Server Error")

                argstr += escapeshellarg(filename)
                pass
            elif opt == "refspec":
                argstr += " --refspec "
                argstr += escapeshellarg(val)
                pass
            elif opt == "aggregate":
                argstr += " -a "
                argstr += escapeshellarg(val)
                pass
            elif opt == "nopending":
                argstr += " -P "
                pass
            elif opt == "noemail":
                argstr += " -s "
                pass
            elif opt == "profile":
                profile = val
                pass
            pass
        
        argstr += " "
        argstr += escapeshellarg(profile)
        
        (exitval, output) = runcommand(TBDIR +
                                       "/bin/start-experiment " + argstr)

        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)

    #
    # Terminate a portal experiment.
    #
    def terminateExperiment(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("experiment",))
        if (argerror):
            return argerror

        argstr     = "terminate "
        experiment = None
        
        for opt, val in argdict.items():
            if opt == "experiment":
                experiment = val
                pass
            pass
        
        argstr += escapeshellarg(experiment)
        # Tell manage_instance to do permission checks.
        argstr += " -X "
        
        (exitval, output) = runcommand(TBDIR +
                                       "/bin/manage_instance " + argstr)

        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)


    #
    # Extend a portal experiment.
    #
    def extendExperiment(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("experiment","wanted","reason"))
        if (argerror):
            return argerror

        argstr     = "extend "
        experiment = None
        wanted     = None
        reason     = ""
        
        for opt, val in argdict.items():
            if opt == "experiment":
                experiment = val
                pass
            elif opt == "wanted":
                wanted = val
                pass
            elif opt == "reason":
                reason = val
                if len(reason) > (1024 * 2):
                    return EmulabResponse(RESPONSE_TOOBIG,
                                         output="Reason is way too big!");
                pass
            pass
        
        argstr += escapeshellarg(experiment)
        (fp, filename) = writensfile(reason)
        if not filename:
            return EmulabResponse(RESPONSE_SERVERERROR, output="Server Error")
        argstr += " -X -f " + escapeshellarg(filename) + " "
        argstr += escapeshellarg(wanted)
        
        (exitval, output) = runcommand(TBDIR +
                                       "/bin/manage_instance " + argstr)

        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)


    #
    # Portal experiment status
    #
    def experimentStatus(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("experiment",))
        if (argerror):
            return argerror

        argstr     = " -X "
        experiment = None
        
        for opt, val in argdict.items():
            if opt == "experiment":
                experiment = val
                pass
            elif opt == "asjson":
                argstr += " -j "
                pass
            elif opt == "refresh":
                argstr += " -r "
                pass
            pass
        
        argstr = "status " + escapeshellarg(experiment) + argstr

        # Slow down the polling.
        time.sleep(3)
        
        (exitval, output) = runcommand(TBDIR +
                                       "/bin/manage_instance " + argstr)

        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output, output=output)

    #
    # Portal experiment manifests
    #
    def experimentManifests(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("experiment",))
        if (argerror):
            return argerror

        argstr     = "dumpmanifests "
        experiment = None
        
        for opt, val in argdict.items():
            if opt == "experiment":
                experiment = val
                pass
            pass
        
        argstr += escapeshellarg(experiment)
        # Tell manage_instance to do permission checks.
        argstr += " -X -j "

        (exitval, output) = runcommand(TBDIR +
                                       "/bin/manage_instance " + argstr)

        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output, output=output)
    
    #
    # Reboot nodes in a portal experiment.
    #
    def reboot(self, version, argdict):
        if version != self.VERSION:
            return EmulabResponse(RESPONSE_BADVERSION,
                                  output="Client version mismatch!")

        if self.readonly:
            return EmulabResponse(RESPONSE_FORBIDDEN,
                              output="Insufficient privledge to invoke method")
        
        try:
            checknologins()
            pass
        except NoLoginsError as e:
            return EmulabResponse(RESPONSE_REFUSED, output=str(e))

        argerror = CheckRequiredArgs(argdict, ("experiment",))
        if (argerror):
            return argerror

        method     = "reboot"
        experiment = None
        nodes      = ""

        for opt, val in argdict.items():
            if opt == "experiment":
                experiment = val
                pass
            elif opt == "power":
                method = "powercycle"
                pass
            elif opt == "nodes":
                tokens = val.split(",")
                for token in tokens:
                    nodes += " " + escapeshellarg(token)
                    pass
                pass
            pass

        argstr  = method + " "
        argstr += escapeshellarg(experiment)
        argstr += " -X " + nodes

        logit(0, argstr);
        
        (exitval, output) = runcommand(TBDIR +
                                       "/bin/manage_instance " + argstr)

        if exitval:
            return EmulabResponse(RESPONSE_ERROR, exitval >> 8, output=output)
        
        return EmulabResponse(RESPONSE_SUCCESS, output=output)


#
# Utility functions
#

#
# escapeshellarg() adds single quotes around a string and quotes/escapes any
# existing single quotes allowing string to be passed directly to a shell
# function and having it be treated as a single safe argument.
#
def escapeshellarg(s):
    s2 = ""

    for c in s:
        if c == '\'':
            s2 = s2 + '\'\\\''
        s2 = s2 + c

    return '\'' + s2 + '\''

def _str2bytes(maybe_str):
    if not isinstance(maybe_str,bytes) and isinstance(maybe_str,str):
        maybe_str = maybe_str.encode()
    return maybe_str

def _bytes2str(maybe_bytes):
    if isinstance(maybe_bytes,bytes) and not isinstance(maybe_bytes,str):
        maybe_bytes = maybe_bytes.decode()
    return maybe_bytes

#
# Run a command. args is a list of strings to pass as arguments to cmd.
# Return the exitcode and the output as a tuple.
#
def runcommand(cmd, separate_stderr=None):
    if separate_stderr == True:
        p = subprocess.Popen(cmd, stdin=None, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True, close_fds=True)
        (stdoutdata, stderrdata) = p.communicate()
        return (p.returncode << 8, _bytes2str(stdoutdata), _bytes2str(stderrdata))
    elif separate_stderr == False:
        p = subprocess.Popen(cmd, stdin=None, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=True, close_fds=True)
        (stdoutdata, stderrdata) = p.communicate()
        return (p.returncode << 8, _bytes2str(stdoutdata), _bytes2str(stderrdata))
    else:
        p = subprocess.Popen(cmd, stdin=None, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, shell=True, close_fds=True)
        (stdoutdata, stderrdata) = p.communicate()
        return (p.returncode << 8, _bytes2str(stdoutdata))

def writensfile(mystr):
    tempfile.tempdir = "/var/tmp"
    try:
        fp = tempfile.NamedTemporaryFile(prefix="php")
        fp.write(_str2bytes(mystr))
        fp.flush()

    except:
        SENDMAIL(TBOPS, "writensfile failed",
                 "Could not write temporary NS file:\n" +
                 "%s:%s" % (sys.exc_info()[0], sys.exc_info()[1]))
        return None

    # Yuck. Need to maintain a ref so that the file is not deleted!
    return (fp, fp.name)

#
# Check for no logins.
#
def checknologins():
    if TBGetSiteVar("web/nologins") != "0":
        raise NoLoginsError(TBGetSiteVar("web/message"))
    return

#
# A helper function for getting a site variable.
#
def TBGetSiteVar(name):
    res = DBQueryFatal("SELECT value,defaultvalue FROM sitevariables "
                       "WHERE name=%s",
                       (name,))

    if len(res) == 0:
        raise ValueError("Unknown site variable: " + str(name))

    if res[0][0]:
        retval = res[0][0]
        pass
    else:
        retval = res[0][1]
        pass

    return retval

#
# Convert a file mode mask into something human readable and cross-platform.
#
def filetype(mode):
    if stat.S_ISDIR(mode):
        retval = "d"
        pass
    elif stat.S_ISCHR(mode):
        retval = "c"
        pass
    elif stat.S_ISBLK(mode):
        retval = "b"
        pass
    elif stat.S_ISREG(mode):
        retval = "f"
        pass
    elif stat.S_ISFIFO(mode):
        retval = "q"
        pass
    elif stat.S_ISLNK(mode):
        retval = "l"
        pass
    elif stat.S_ISSOCK(mode):
        retval = "s"
        pass
    else:
        retval = "u"
        pass
    return retval    

#
# A helper function for converting a value into a SQL date string.
#
def sqldate(value):
    if isinstance(value, xmlrpclib.DateTime):
        value = time.strptime(str(value), "%Y%m%dT%H:%M:%S")
        value = time.strftime("%Y-%m-%d %H:%M:%S", value)
        pass
    return value

#
# A helper function for converting an XMLRPC value into a boolean.
#
def xbool(value):
    retval = value
    if value:
        # XXX handle uppercase strings...
        if (value == True or
            value == "true" or
            value == "yes" or
            value == "on" or
            value == "1"):
            retval = True
            pass
        else:
            retval = False
            pass
        pass
    return retval

#
# Check for an acceptable NFS path.
#
def nfspath(value):
    retval = os.path.realpath(value)

    found = False
    for export in NFS_EXPORTS:
        if export != "" and retval.startswith(export):
            found = True
            break
        pass

    if not found:
        raise OSError(errno.EPERM, "Path is not an NFS export", value)

    return retval

##
# Scrub a dictionary returned by an SQL query so that it can be sent through
# the XML-RPC marshaller without error.
#
# @param retval The dictionary to scrub.
# @param prunelist A list of keys to prune from the dictionary.
# @return retval
#
def scrubdict(retval, prunelist=[], defaultvals={}):
    for key in list(retval):
        if (retval[key] == None) or key in prunelist:
            if key in defaultvals:
                retval[key] = defaultvals[key]
                pass
            else:
                del retval[key]
                pass
            pass
        elif isinstance(retval[key], set):
            retval[key] = list(retval[key])
            pass
        elif isinstance(retval[key], datetime.datetime):
            retval[key] = xmlrpclib.DateTime(
                time.strptime(str(retval[key]), "%Y-%m-%d %H:%M:%S"))
            pass
        pass
    
    return retval

def subboss_image_set_busy(subboss, imageid):
	res = DBQueryFatal("update subboss_images set load_busy=1 where "
			   "imageid=%s and subboss_id=%s", (imageid, subboss))
	# XXX make sure update worked

#
# Get the next mcast address to use for frisbeed
# tables must be unlocked for this to work
#
def next_mcast_address():
	res = DBQueryFatal("update emulab_indicies set idx=LAST_INSERT_ID(idx+1) "
		           "where name='frisbee_index'")

	# XXX what if index doesn't exist yet?  should in practice though

	res = DBQueryFatal("select LAST_INSERT_ID()")
	idx = res[0][0] # XXX what is the right way to do this?

	dotted = list(map(int, BASEADDR.split(".")))
	if len(dotted) < 4:
		dotted.extend([1, 1, 1])
		dotted = dotted[0:4]

	dotted[3] += idx
	if dotted[3] > 254:
		dotted[2] += dotted[3] / 254
		dotted[3] = dotted[3] % 254 + 1

	if dotted[2] > 254:
		dotted[1] += dotted[2] / 254
		dotted[2] = dotted[2] % 254 + 1

	if dotted[1] > 254:
		return (False, "No more multicast addresses")

	port = int(BASEPORT) + (((dotted[2] << 8) | dotted[3]) & 0x7FFF)

	return (True, "%d.%d.%d.%d:%d" % (dotted[0], dotted[1], dotted[2], dotted[3], port))

#
# Locks the subboss_images table
#
def lock_subboss_image_table():
	return DBQueryFatal("lock tables subboss_images write")

#
# Unlocks any tables we've locked
#
def unlock_tables():
	return DBQueryFatal("unlock tables")
