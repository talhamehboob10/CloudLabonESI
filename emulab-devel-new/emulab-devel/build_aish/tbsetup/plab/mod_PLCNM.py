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
sys.path.append("/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/lib")

import xmlrpclib
import getopt
import fcntl
import time
import calendar
import cPickle
import os

from libtestbed import *
from aspects import wrap_around
from timer_advisories import timeAdvice

#
# output control vars
#
verbose = 0
debug = 0

#
# PLC constants
#
#DEF_PLC_URI = "https://www.planet-lab.org/PLCAPI/"
DEF_PLC_URI = "https://delta.cs.princeton.edu/PLCAPI/"
# these are now sucked in from a file
DEF_PLC_USER = ""
DEF_PLC_PASS = ""
DEF_PLC_PASS_FILE = "/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/etc/plab/plc.pw"

DEF_NM_PORT = "814"

#
# A bunch of time constants / intervals (in seconds)
#
MAX_PLC_LEASELEN = 2*MONTH-4*DAY   # defined by PLC as ~two months (56 days)
MIN_LEASE_WINDOW = 2*MONTH-11*DAY  # minimum time until expiration
MAX_LEASE_SLOP = 600 # (ten minutes)
MAX_CACHE_TIME = HOUR # (one hour)

EMULABMAN_EMAIL = "emulabman@emulab.net"

PLC_LOCKFILE = "/tmp/.PLC-lock"
DEF_PLC_SPACING = 3 # seconds

DEF_SLICE_DESC = "Slice created by Emulab"
DEF_EMULAB_URL = "http://www.emulab.net"

MAJOR_VERS = 1
MINOR_VERS = 0
MIN_REV    = 10

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


class NMagent:
    def __init__(self, IP, nodeid, nmport = DEF_NM_PORT):
        self.__server = xmlrpclib.ServerProxy("http://" + IP + ":" +
                                              nmport + "/")
        self.__vers = [0,0,0]
        self.IP = IP
        self.nodeid = nodeid
        pass

    def create_sliver(self, ticket):
        return self.__server.create_sliver(xmlrpclib.Binary(ticket))

    def delete_sliver(self, rcap):
        return self.__server.delete_sliver(rcap)

    def version(self):
        if self.__vers == [0,0,0]:
            res = self.__server.version()
            if type(res) == list and len(res) == 2 and res[0] == 0:
                verslist = res[1].split(".")
                major = verslist[0]
                minor, revision = verslist[1].split("-")
                self.__vers = [int(major), int(minor), int(revision)]
                pass
            pass
        return self.__vers

    def ping(self):
        try:
            res = self.__server.version()
            if type(res) == list and len(res) == 2 and res[0] == 0:
                return True
            pass
        except:
            if debug:
                traceback.print_exc()
                pass
            pass
        return False
    
    def getAgentClass(self):
        return self.__class__

    pass
#wrap_around(NMagent.create_sliver, timeAdvice)
#wrap_around(NMagent.delete_sliver, timeAdvice)


#
# The real PLC agent.  Wraps up standard arguments to the
# PLC XMLRPC interface.
#

# XXX: a number of functions here need to be updated to cope with lists
# and tuples.
class PLCagent:
    def __init__(self, slicename,
                 uri = DEF_PLC_URI,
                 username = "",
                 password = ""):

        if username == "":
            username = mod_PLCNM.username
            pass
        if password == "":
            password = mod_PLCNM.password
            pass
        
        if not slicename:
            raise RuntimeError, "Must provide a slicename!"
        self.__slice = {}
        self.__slice['sliceName'] = slicename
        self.__slicename = slicename
        self.__auth = {}
        self.__auth['AuthMethod'] = "password"
        self.__auth['Username'] = username
        self.__auth['AuthString'] = password
        self.__auth['Role'] = "pi"
        self.__insmeth = "delegated"
        try:
            self.__server = xmlrpclib.ServerProxy(uri)
        except:
            print "Failed to create XML-RPC proxy"
            raise
        return

    def getSliceName(self):
        return self.__slice['sliceName']

    def SliceCreate(self):
        return self.__server.SliceCreate(self.__auth, self.__slicename)

    def SliceDelete(self):
        return self.__server.SliceDelete(self.__auth, self.__slicename)

    def SliceUpdate(self, slicedesc = DEF_SLICE_DESC,
                    sliceURL = DEF_EMULAB_URL):
        return self.__server.SliceUpdate(self.__auth, self.__slicename,
                                         sliceURL, slicedesc)

    def SliceRenew(self, expdate):
        return self.__server.SliceRenew(self.__auth, self.__slicename,
                                        expdate)

    def SliceNodesAdd(self, nodelist):
        if not type(nodelist) == list:
            nodelist = [nodelist,]
            pass
        return self.__server.SliceNodesAdd(self.__auth, self.__slicename,
                                           nodelist)
    
    def SliceNodesDel(self, nodelist):
        if not type(nodelist) == list:
            nodelist = [nodelist,]
        return self.__server.SliceNodesDel(self.__auth, self.__slicename,
                                           nodelist)

    def SliceNodesList(self):
        return self.__server.SliceNodesList(self.__auth, self.__slicename)

    def SliceUsersAdd(self, userlist):
        if type(userlist) != tuple:
            userlist = (userlist,)
        return self.__server.SliceUsersAdd(self.__auth, self.__slicename,
                                         userlist)
    
    def SliceUsersDel(self, userlist):
        if type(userlist) != tuple:
            userlist = (userlist,)
        return self.__server.SliceUsersDel(self.__auth, self.__slicename,
                                           userlist)
    def SliceUsersList(self):
        return self.__server.SliceUsersList(self.__auth, self.__slicename)

    def SliceGetTicket(self):
        return self.__server.SliceGetTicket(self.__auth, self.__slicename)

    def SliceSetInstantiationMethod(self):
        return self.__server.SliceSetInstantiationMethod(self.__auth,
                                                         self.__slicename,
                                                         self.__insmeth)

    def SliceInfo(self, slicelist=[]):
        return self.__server.SliceInfo(self.__auth, slicelist,
                                       False, False)

    pass # end of PLCagent class


class mod_PLCNM:
    username = ""
    password = ""
    
    def __init__(self):
        self.modname = "mod_PLCNM"
        self.__PLCagent = None
        self.__sliceexpdict = {}
        self.__sliceexptime = 0

        # try to grab the master account info from the file:
        try:
            file = open(DEF_PLC_PASS_FILE,'r')
            lines = file.readlines()
            mod_PLCNM.username = lines[0].strip('\n')
            mod_PLCNM.password = lines[1].strip('\n')
            pass
        except:
            print "Failed to retrive master passwd from %s" % DEF_PLC_PASS_FILE
            raise
        
        return

    def createSlice(self, slice):

        agent = self.__getAgent(slice.slicename)
        res = None
        now = calendar.timegm(time.gmtime())

        try:
            res = tryXmlrpcCmd(agent.SliceCreate)
            if debug:
                print "SliceCreate result: %s" % res
                pass
            pass
        except:
            print "Failed to create slice %s" % slice.slicename
            raise

        try:
            res = tryXmlrpcCmd(agent.SliceSetInstantiationMethod)
            if debug:
                print "SliceSetInstantiationMethod result: %s" % res
                pass
            pass
        except:
            print "Failed to set slice instantiation type to delegated"
            raise
        
        try:
            res = tryXmlrpcCmd(agent.SliceUsersAdd,
                               EMULABMAN_EMAIL)
            if debug:
                print "SliceUsersAdd result: %s" % res
                pass
            pass
        except:
            print "Failed to assign emulabman to slice %s" % slice.slicename
            raise

        # PLC has a limit on the size of XMLRPC responses, so trying to
        # get back a ticket with all Plab nodes included was getting truncated.
        # The workaround is to _not_ add _any_ nodes to the slice via PLC!
        #
        # Steve Muir sez:
        #  "tickets don't actually need any nodes in them, the PLC
        #  agent currently ignores the node list.  i suppose it's possible
        #  that in the future we might start checking the node list but my
        #  feeling is that we probably won't.  so in the short-term you can
        #  just leave the node list empty."

        #try:
        #    nodelist = map(lambda x: x[2], slice.getSliceNodes())
        #    res = tryXmlrpcCmd(agent.SliceNodesAdd, nodelist)
        #    if debug:
        #        print "SliceNodesAdd result: %s" % res
        #        pass
        #    pass
        #except:
        #    print "Failed to add nodes to slice %s" % slice.slicename
        #    raise

        try:
            res = tryXmlrpcCmd(agent.SliceUpdate, slice.description)
            if debug:
                print "SliceUpdate result: %s" % res
                pass
            pass
        except:
            print "Failed to update info for slice: %s" % slice.slicename
            raise
        
        try:
            PLCticket = tryXmlrpcCmd(agent.SliceGetTicket)
            if debug:
                print PLCticket
                pass
            pass
        except:
            print "Failed to get PLC ticket for slice %s" % slice.slicename
            raise
        
        leaseend = now + MAX_PLC_LEASELEN
        return (res, cPickle.dumps(PLCticket), leaseend)

    def deleteSlice(self, slice):
        agent = self.__getAgent(slice.slicename)
        tryXmlrpcCmd(agent.SliceDelete, OKstrs = ["does not exist"])
        pass

    def renewSlice(self, slice, force = False):
        agent = self.__getAgent(slice.slicename)
        ret = 0
        now = int(time.time()) # seconds since the epoch (UTC)
 
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
        # code in libplab will send email.
        if leaseend < now:
            print "Slice %s (%s/%s) has expired!" % \
                  (slice.slicename, slice.pid, slice.eid)
            pass

        # If the lease is at least as large as the minimum window,
        # don't bother renewing it.
        if leaseend - now > MIN_LEASE_WINDOW and not force:
            print "Slice %s (%s/%s) doesn't need to be renewed" % \
                  (slice.slicename, slice.pid, slice.eid)
            return 1

        # Max out leaseend as far as (politically) possible
        newleaseend = now + MAX_PLC_LEASELEN
        
        try:
            res = tryXmlrpcCmd(agent.SliceRenew,
                               newleaseend,
                               NOKstrs = ["does not exist"])
            # Get the updated ticket.
            slice.slicemeta = self.getSliceMeta(slice)
            ret = 1
            if debug:
                print "SliceRenew returns: %s" % res
                pass
            pass
        except:
            print "Failed to renew lease for slice %s" % slice.slicename
            traceback.print_exc()
            ret = 0
            pass
        else:
            slice.leaseend = newleaseend
            pass
        
        return ret

    def getSliceMeta(self, slice):
        agent = self.__getAgent(slice.slicename)
        
        try:
            PLCticket = tryXmlrpcCmd(agent.SliceGetTicket)
            if debug:
                print PLCticket
                pass
            pass
        except:
            print "Failed to get PLC ticket for slice %s" % slice.slicename
            raise

        return cPickle.dumps(PLCticket)

    def createNode(self, node):

        ticketdata = cPickle.loads(node.slice.slicemeta)
        agent  = NMagent(node.IP, node.nodeid)
                  
        #res = tryXmlrpcCmd(agent.SliceNodesAdd, node.IP,
        #                   OKstrs = ["already assigned"])
        #if debug:
        #    print res
        #    pass

        # Make sure node is running compatible interface
        try:
            vers = agent.version()
            pass
        except:
            print "Unable to check version on remote NM agent!"
            raise
        if vers[0] != MAJOR_VERS or vers[1] != MINOR_VERS \
               or vers[2] < MIN_REV:
            raise RuntimeError, \
                  "Remote node manager version incompatible on %s: %s" % \
                  (node.nodeid, ".".join(map(lambda x: str(x), vers)))
        pass

        try:
            res = tryXmlrpcCmd(agent.create_sliver, ticketdata)
            if debug:
                print res
                pass

            if not res[0] == 0:
                raise RuntimeError, "create_sliver failed: %d, %s" % \
                      (res[0], res[1])
            pass
        except:
            print "Failed to create sliver %s on slice %s" % \
                  (node.nodeid, node.slice.slicename)
            # XXX: Can we clean up on the plab side here?
            #      delete_sliver requires an rcap, but we don't have one
            #      in this case (since sliver creation failed).
            # self.freeNode(node)
            raise

        # send back the rcap
        return (res, cPickle.dumps(res[1][0]), node.slice.leaseend)

    def freeNode(self, node):
        rcap = cPickle.loads(node.nodemeta)
        agent = NMagent(node.IP, node.nodeid)
        res = None

        try:
            res = tryXmlrpcCmd(agent.delete_sliver, rcap)
            if debug:
                print res
                pass
            if not res[0] == 0:
                raise RuntimeError, "delete_sliver failed: %d" % res[0]
            pass
        except:
            print "Failed to release node %s from slice %s" % \
                  (node.nodeid, node.slice.slicename)
            raise
        
        return res

    def renewNode(self, node, length = 0):
        return  self.createNode(node)

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
            sdict = tryXmlrpcCmd(agent.SliceInfo)
            for entry in sdict:
                self.__sliceexpdict[entry['name']] = entry
                pass
            self.__sliceexptime = time.time()
            pass

        if not self.__sliceexpdict.has_key(slicename):
            print "Slice %s unknown to PLC" % slicename
            return None

        leaseend = self.__sliceexpdict[slicename]['expires']

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
