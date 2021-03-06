# -*- python -*-
#
# Copyright (c) 2000-2003 University of Utah and the Flux Group.
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
sys.path.append("/users/mshobana/emulab-devel/build/lib")

import xmlrpclib
import getopt
import fcntl
import time
import calendar

from libtestbed import *

#
# output control vars
#
verbose = 0
debug = 0

#
# PLC constants
#
DEF_PLC_URI = "https://www.planet-lab.org/PLCAPI/"
DEF_PLC_USER = "lepreau@cs.utah.edu"
DEF_PLC_PASS = ""            # XXX: hardcoded, cleartext passwds bad.

MAX_PLC_LEASELEN = 2*30*24*60*60   # defined by PLC as two months
MIN_LEASE_ADDTIME = 23*60*60       # less than a day used? leave it be then..
MAX_LEASE_SLOP = 600 # (ten minutes)
MAX_CACHE_TIME = 3600 # (one hour)
DEF_PLC_SHARES = 30 # XXX: totally arbitrary

EMULABMAN_EMAIL = "emulabman@emulab.net"

PLC_LOCKFILE = "/tmp/.PLC-lock"
DEF_PLC_SPACING = 3 # seconds

#
# Reflective wrapper class for real PLCagent.
# This class forces global, mutually exclusive access to PLC
# function calls.
#
# XXX: Created per Jay's request, then deactivated per Jay's
# subsequent request.
#
class __PLCagent:
    
    class __PLCMutexMethod:
        def __init__(self, funcname, obj):
            self.__lockfile = open(PLC_LOCKFILE, "w")
            self.__meth = eval("obj.%s" % funcname)
            self.func_name = funcname
            return
        
        def __call__(self, *args):
            retval = None
            if debug:
                TIMESTAMP("Acquiring PLC lock")
                pass
            fcntl.lockf(self.__lockfile, fcntl.LOCK_EX)
            if debug:
                TIMESTAMP("Lock acquired.")
                pass
            time.sleep(DEF_PLC_SPACING)
            fcntl.lockf(self.__lockfile, fcntl.LOCK_UN)
            if debug:
                TIMESTAMP("PLC lock released")
                pass
            return self.__meth(*args)
        pass

    def __init__(self, *args):
        self.__myPLC = _PLCagent(*args)
        return

    def __getattr__(self, name):
        return self.__PLCMutexMethod(name, self.__myPLC)

#
# The real PLC agent.  Wraps up standard arguments to the
# PLC XMLRPC interface.
#
class PLCagent:
    def __init__(self, slicename,
                 uri = DEF_PLC_URI,
                 username = DEF_PLC_USER,
                 password = DEF_PLC_PASS):
        if not slicename:
            raise RuntimeError, "Must provide a slicename!"
        self.__slice = {}
        self.__slice['sliceName'] = slicename
        self.__auth = {}
        self.__auth['AuthMethod'] = "password"
        self.__auth['username'] = username
        self.__auth['AuthString'] = password
        try:
            self.__server = xmlrpclib.ServerProxy(uri)
        except:
            print "Failed to create XML-RPC proxy"
            raise
        return

    def getSliceName(self):
        return self.__slice['sliceName']

    def createSlice(self):
        return self.__server.createSlice(self.__slice, self.__auth)

    def deleteSlice(self):
        return self.__server.deleteSlice(self.__slice, self.__auth)

    def AssignNodes(self, nodelist):
        if type(nodelist) != tuple:
            nodelist = (nodelist,)
        nodes = {}
        nodes['nodeList'] = nodelist
        return self.__server.AssignNodes(self.__slice, self.__auth, nodes)
    
    def UnAssignNodes(self, nodelist):
        if type(nodelist) != tuple:
            nodelist = (nodelist,)
        nodes = {}
        nodes['nodeList'] = nodelist
        return self.__server.UnAssignNodes(self.__slice, self.__auth, nodes)

    def AssignUsers(self, userlist):
        if type(userlist) != tuple:
            userlist = (userlist,)
        users = {}
        users['userList'] = userlist
        return self.__server.AssignUsers(self.__slice, self.__auth, users)
    
    def UnAssignUsers(self, userlist):
        if type(userlist) != tuple:
            userlist = (userlist,)
        users = {}
        users['userList'] = userlist
        return self.__server.UnAssignUsers(self.__slice, self.__auth, users)

    def AssignShares(self, renewtime, numshares):
        shareinfo = {}
        shareinfo['renewTime'] = renewtime
        shareinfo['share'] = numshares
        return self.__server.AssignShares(self.__slice, self.__auth, shareinfo)

    def InstantiateSliver(self, nodelist):
        if type(nodelist) != tuple:
            nodelist = (nodelist,)
        nodes = {}
        nodes['nodeList'] = nodelist
        return self.__server.InstantiateSliver(self.__slice, self.__auth, nodes)

    def listSlice(self):
        return self.__server.listSlice(self.__auth)

    pass # end of PLCagent class


class mod_PLC:
    def __init__(self, noIS = True):
        self.modname = "mod_PLC"
        self.noIS = noIS
        self.__PLCagent = None
        self.__sliceexpdict = {}
        self.__sliceexptime = 0
        return

    def createSlice(self, slice):

        agent = self.__getAgent(slice.slicename)
        res = None
        now = calendar.timegm(time.gmtime())

        try:
            res = tryXmlrpcCmd(agent.createSlice)
            if debug:
                print res
                pass
            pass
        except:
            print "Failed to create slice %s" % slice.slicename
            raise
        
        try:
            res = tryXmlrpcCmd(agent.AssignUsers,
                               EMULABMAN_EMAIL)
            if debug:
                print res
                pass
            pass
        except:
            print "Failed to assign emulabman to slice %s" % slice.slicename
            raise
        
        try:
            res = tryXmlrpcCmd(agent.AssignShares,
                               (MAX_PLC_LEASELEN,
                                DEF_PLC_SHARES))
            if debug:
                print res
                pass
            pass
        except:
            print "Failed to assign shares to slice %s" % slice.slicename
            raise
        
        leaseend = now + MAX_PLC_LEASELEN
        return (res, None, leaseend)

    def deleteSlice(self, slice):
        agent = self.__getAgent(slice.slicename)
        tryXmlrpcCmd(agent.deleteSlice, OKstrs = ["does not exist"])
        pass

    def renewSlice(self, slice):
        agent = self.__getAgent(slice.slicename)
        ret = 0
        now = calendar.timegm(time.gmtime()) # make explicit that we want UTC
 
        # Get current PLC timeout for this slice
        leaseend = self.getSliceExpTime(slice.slicename)

        # Warn that we weren't able to get the exp. time from PLC,
        # but don't fail - try to renew anyway.
        if not leaseend:
            print "Couldn't get slice expiration time from PLC!"
            leaseend = slice.leaseend
            pass

        # Allow some slop in our recorded time versus PLC's.  This is necessary
        # since we calculate the expiration locally.  If we are off by too much
        # then adjust to PLC's recorded expiration.
        if abs(leaseend - slice.leaseend) > MAX_LEASE_SLOP:
            print "Warning: recorded lease for %s doesn't agree with PLC" % \
                  slice.slicename
            print "\tRecorded: %s  Actual: %s" % (slice.leaseend, leaseend)
            slice.leaseend = leaseend
            pass

        # Expired!  Just bitch about it; try renewal anyway.  The renewal
        # code in liabplab will send email.
        if leaseend < now:
            print "Slice %s (%s/%s) has expired!" % \
                  (slice.slicename, slice.pid, slice.eid)
            pass

        # Max out leaseend as far as (politically) possible
        addtime = now + MAX_PLC_LEASELEN - leaseend

        # If the lease is within delta of the max, don't bother.
        if addtime < MIN_LEASE_ADDTIME:
            print "Slice %s (%s/%s) doesn't need to be renewed" % \
                  (slice.slicename, slice.pid, slice.eid)
            return 1
        
        try:
            res = tryXmlrpcCmd(agent.AssignShares,
                               (addtime,
                                DEF_PLC_SHARES),
                               NOKstrs = ["does not Exist",
                                          "unknown within Planetlab"])
            ret = 1
            if debug:
                print "AssignShares returns: %s" % res
                pass
            pass
        except:
            print "Failed to extend lease for slice %s" % slice.slicename
            ret = 0
            pass
        else:
            # XXX: This may not be accurate - PLC _accumulates_ renewal time.
            slice.leaseend = now + addtime
            pass
        
        return ret

    def createNode(self, node):
        # add the node to the PLC slice.
        agent = self.__getAgent(node.slice.slicename)

        TIMESTAMP("createnode started on %s" % (node.nodeid))
                  
        res = tryXmlrpcCmd(agent.AssignNodes, node.IP,
                           OKstrs = ["already assigned"])
        if debug:
            print res
            pass

        if not self.noIS:
            # push changes out immediately.
            try:
                TIMESTAMP("InstantiateSliver() starting on %s." % node.nodeid)
                res = tryXmlrpcCmd(agent.InstantiateSliver, node.IP)
                TIMESTAMP("InstantiateSliver() complete on %s." % node.nodeid)
                if debug:
                    print res
                    pass
                pass
            except:
                print "Failed to instantiate sliver %s on slice %s" % \
                      (node.nodeid, node.slice.slicename)
                self.freeNode(node)
                raise
            pass
        
        return (res, None, None)

    def freeNode(self, node):
        agent = self.__getAgent(node.slice.slicename)
        res = None

        try:
            res = tryXmlrpcCmd(agent.UnAssignNodes, node.IP,
                               OKstrs = ["not assigned"])
            if debug:
                print res
                pass
            pass
        except:
            print "Failed to release node %s from slice %s" % \
                  (node.nodeid, node.slice.slicename)
            raise
        
        TIMESTAMP("freenode %s finished." % node.nodeid)
        return res

    def renewNode(self, node, length = 0):
        return(0,None,None)

    def getSliceExpTime(self, slicename):
        """
        Grab the expiration time for a slice according to PLC.
        Entries are cached for a time specified in this module by
        MAX_CACHE_TIME.  Returns seconds since the epoch in UTC.
        """
        agent = self.__getAgent(slicename)
        # Refresh the slice expiration cache if:
        # 1) cache is cold
        # 2) cache is too old
        # 3) given slice is not in cache
        if not self.__sliceexpdict or \
           self.__sliceexptime < time.time() - MAX_CACHE_TIME or \
           not self.__sliceexpdict.has_key(slicename):
            sdict = tryXmlrpcCmd(agent.listSlice)
            for entry in sdict:
                self.__sliceexpdict[entry['slicename']] = entry
                pass
            self.__sliceexptime = time.time()
            pass

        if not self.__sliceexpdict.has_key(slicename):
            print "Slice %s unknown to PLC" % slicename
            return None

        leaseend = self.__sliceexpdict[slicename]['expires']
        # leaseend = calendar.timegm(time.strptime(exptime, "%Y-%m-%d %H:%M:%S"))

        return leaseend

    def __getAgent(self, slicename):
        """
        Returns a PLC agent object for the specified slice.  May cache.
        """
        if not self.__PLCagent or \
           not self.__PLCagent.getSliceName() == slicename:
            self.__PLCagent = PLCagent(slicename)
            pass

        return self.__PLCagent

    pass # end of mod_PLC class
