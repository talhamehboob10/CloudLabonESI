# -*- python -*-
#
# Copyright (c) 2000-2004, 2006-2008, 2010 University of Utah and the Flux Group.
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

"""
Library for interfacing with Plab.  This abstracts out the concepts of
Plab central, slices, and nodes.  All data (except static things like
certificates) is kept in the Emulab DB.  Unlike the regular dslice
svm, this one supports dynamically changing which nodes are in a
slice.
"""

import sys
sys.path.append("/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/lib")

import os, time
import string
import traceback
import signal
import socket
import httplib
import xml.parsers.expat
import re
import calendar
import shlex

from popen2 import Popen4
from warnings import warn

#
# Testbed and DB access libs
#
from libtestbed import *
from libdb import *

#
# Plab modules to import
#
from mod_PLC import mod_PLC
from mod_dslice import mod_dslice
from mod_PLCNM import mod_PLCNM
from mod_PLC4 import mod_PLC4

agents = {'PLC'    : mod_PLC,
          'dslice' : mod_dslice,
          'PLCNM'  : mod_PLCNM,
          'PLC4'   : mod_PLC4}

#
# Initialize the AOP stuff
#
from aspects import wrap_around
from timer_advisories import initTimeAdvice, timeAdvice
initTimeAdvice("plabtiming")

#
# output control vars
#
verbose = 0
debug = 0

#
# Constants
#
DEF_AGENT = "PLC4";

RENEW_TIME = 2*24*60*60  # Renew two days before lease expires

RENEW_TIMEOUT = 1*60     # give the node manager a minute to respond to renew
FREE_TIMEOUT  = 1*60     # give the node manager a minute to respond to free
NODEPROBEINT  = 30

USERNODE = "ops.cloudlab.umass.edu"
TBOPS = "testbed-ops@ops.cloudlab.umass.edu"
MAILTAG = "UMASS"
SLICE_ALIAS_DIR = "/etc/mail/plab-slice-addrs"

DEFAULT_DATA_PATH = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/etc/plab"

RESERVED_PID = "emulab-ops"
RESERVED_EID = "hwdown"       # start life in hwdown
MONITOR_PID  = "emulab-ops"
MONITOR_EID  = "plab-monitor"

BOSSNODE_IP = "198.22.255.3"
# obviously this isn't really true, but we put plab/pgeni nodes on the .35
CONTROL_NETWORK = "155.98.35.0"
CONTROL_NETMASK = "255.255.255.0"
CONTROL_ROUTER = "198.22.255.1"

MAGIC_INET2_GATEWAYS = ("205.124.237.10",  "205.124.244.18",
                        "205.124.244.178", )
MAGIC_INET_GATEWAYS =  ("205.124.244.150", "205.124.239.185",
                        "205.124.244.154", "205.124.244.138",
                        "205.124.244.130", )
LOCAL_PLAB_DOMAIN = ".flux.utah.edu"
LOCAL_PLAB_LINKTYPE = "inet2"

# allowed nil/unknown values (sentinels).
ATTR_NIL_VALUES = ('None',)

# 'critical' node identifiers - those that are actually used to uniquely
# identify a planetlab node
ATTR_CRIT_KEYS = ('HNAME', 'IP', 'PLABID', 'MAC',)

# The amount by which latitude and longitude are allowed to differ before we
# classify them ask changed
LATLONG_DELTA = 0.001

PLABNODE = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/plabnode"
SSH = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/bin/sshtb"
NAMED_SETUP = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/named_setup"
PELAB_PUSH  = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/sbin/pelab_opspush"

ROOTBALL_URL = "http://localhost:1492/" # ensure this ends in a slash

DEF_SITE_XML = "/xml/sites.xml"
IGNORED_NODES_FILE = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/etc/plab/IGNOREDNODES"
ALLOWED_NODES_FILE = "/users/mshobana/CloudLabonESI/emulab-devel-new/emulab-devel/sample_build/etc/plab/ALLOWEDNODES"

BADSITECHARS = re.compile(r"\W+")
PLABBASEPRIO = 20000
PLAB_SVC_SLICENAME = "utah_svc_slice"
PLAB_SVC_SLICEDESC = "UMASS management service slice. Performs " \
                     "periodic checkins with UMASS central, and " \
                     "routes events for other UMASS slices. " \
                     "Slivers in this slice should only interact with " \
                     "other PLC-based nodes, and UMASS."
PLABMON_PID = "emulab-ops"
PLABMON_EID = "plab-monitor"
DEF_SLICE_DESC = "Slice created by UMASS"
DEF_EMULAB_URL = "http://www.cloudlab.umass.edu"

PLABEXPIREWARN = 1*WEEK        # one week advance warning for slice expiration.
NODEEXPIREWARN = 2*WEEK+2*DAY  # about two weeks advance warning for slivers.

#
# var to track failed renewals
#
failedrenew = []

#
# Disable line buffering
#
sys.stdout = os.fdopen(sys.stdout.fileno(), sys.stdout.mode, 0)

#
# Ensure SIGPIPE doesn't bite us:
#
signal.signal(signal.SIGPIPE, signal.SIG_IGN)

#
# Plab abstraction
#

#
# Multiple attribute change exception
#
class MultiChangeError(Exception):
    def __init__(self, nodeid, chattrs={}):
        self.nodeid = nodeid
        self.chattrs = chattrs
        pass
    pass

#
# Class responsible for parsing planetlab sites file
#
class siteParser:

    def __init__(self,plc):
        self.plc = plc
        self.parser = xml.parsers.expat.ParserCreate()
        self.parser.StartElementHandler = self.__site_start_elt
        self.parser.EndElementHandler = self.__site_end_elt
        self.__hosts = []
        self.__sitename = ""
        self.__latitude = 0
        self.__longitude = 0
        
    def getPlabNodeInfo(self):
        conn = httplib.HTTPSConnection(self.plc.url)
        conn.request("GET", DEF_SITE_XML)
        res = conn.getresponse()
        if res.status != 200:
            raise RuntimeError, "HTTP Error getting site list:\n" \
                  "Code: %d Reason: %s" % \
                  (res.status, res.reason)
        try:
            self.parser.ParseFile(res)
            pass
        except xml.parsers.expat.ExpatError, e:
            print "Error parsing XML file, lineno: %d, offset: %d:\n%s" % \
                  (e.lineno, e.offset, xml.parsers.expat.ErrorString(e.code))
            raise

        return self.__hosts

    def __site_start_elt(self, name, attrs):

        # XXX: how will this look for multiple plcs?
        if name == "PLANETLAB_SITES":
            pass
        
        elif name == "SITE":
            self.__sitename = attrs['SHORT_SITE_NAME']
            if attrs.has_key('LATITUDE'):
                self.__latitude = attrs['LATITUDE']
            else:
                self.__latitude = 0
            if attrs.has_key('LONGITUDE'):
                self.__longitude = attrs['LONGITUDE']
            else:
                self.__longitude = 0
            pass
        
        elif name == "HOST":
            if not attrs.has_key('MAC'):
                attrs['MAC'] = "None"
                pass
            if not attrs.has_key('BWLIMIT'):
                attrs['BWLIMIT'] = "-1"
                pass
            if not attrs.has_key('IP'):
                print "node %s did not have IP!" % attrs['NAME']
                pass
            else:
                adi = { 'HNAME'     : attrs['NAME'],
                        'IP'        : attrs['IP'],
                        'PLABID'    : attrs['NODE_ID'],
                        'MAC'       : attrs['MAC'],
                        'BWLIMIT'   : attrs['BWLIMIT'],
                        'SITE'      : self.__sitename,
                        'LATITUDE'  : self.__latitude,
                        'LONGITUDE' : self.__longitude
                        }
                if attrs.has_key('STATUS'):
                    adi['STATUS'] = attrs['STATUS']
                    pass

                self.__hosts.append(adi)
                pass
            pass
        
        else:
            print "Unknown element in site file: %s: %s" % (name, attrs)
            pass
        
        return

    def __site_end_elt(self, name):
        
        if name == "SITE":
            self.__sitename = "Unknown"
            self.__latitude = 0
            self.__longitude = 0
            pass
        return

    pass

#
# Class to pull node, nodenetwork, and site info from PLC via xmlrpc.  Its
# getPlabNodeInfo method returns in the same format as the original
# SiteParser.getPlabNodeInfo .
#
class XmlrpcNodeInfoFetcher:
    def __init__(self,plc):
        self.plc = plc
        # store the info
        self.__hosts = []
        self.__groups = dict({})

        which_agent = plc.getAttrVal("nmagent")
        if which_agent == None:
            which_agent = DEF_AGENT
            pass

        # grab a mod_PLC4 agent
        self.agent = agents[which_agent](plc)
        try:
            self.agent.setdebug(debug,verbose)
        except:
            pass

        pass

    def getPlabNodeGroupInfo(self,ignoreErrors=True):
        ngf = ['nodegroup_id','name','description','node_ids']
        ng = self.agent.getNodeGroups(outfilter=ngf)

        # build up our translation table
        pemap = dict({})
        qres = DBQueryFatal("select node_id,plab_id from plab_mapping")
        for (node_id,plab_id) in qres:
            pemap[plab_id] = node_id
            pass

        self.__groups = dict({})

        for n in ng:
            elab_nodes = []
            for plab_id in n['node_ids']:
                # we have to turn plab_id from planetlab's int into our 
                # varchars; sigh, legacy.
                elab_plab_id = str(plab_id)
                if pemap.has_key(elab_plab_id):
                    elab_nodes.append(pemap[elab_plab_id])
                    pass
                else:
                    print "%s not in pemap!" % elab_plab_id
                pass

            od = dict({ 'name':n['name'],'nodegroup_id':n['nodegroup_id'],
                        'description':n['description'],'node_ids':elab_nodes })

            self.__groups[n['nodegroup_id']] = od
            pass

        return self.__groups

    def getPlabNodeInfo(self,ignoreErrors=True):
        nif = ['nodenetwork_ids','boot_status','hostname','site_id','node_id']
        ni = self.agent.getNodes(outfilter=nif)

        # XXX: eventually will want to handle multiple interfaces
        nni_inf = dict({'is_primary' : True})
        nni_outf = ['ip','nodenetwork_id','mac','bwlimit']
        nni = self.agent.getNodeNetworks(infilter=nni_inf,outfilter=nni_outf)
        # index by nnid to make lookups easier
        nni_map = dict({})
        for n in nni:
            nni_map[n['nodenetwork_id']] = dict({ 'IP'      : n['ip'],
                                                  'MAC'     : n['mac'],
                                                  'BWLIMIT' : str(n['bwlimit']) })
            pass

        sif = ['site_id','longitude','latitude','abbreviated_name']
        si = self.agent.getSites(outfilter=sif)
        # index by sid
        si_map = dict({})
        for s in si:
            si_map[s['site_id']] = dict({ 'SITE' : s['abbreviated_name'],
                                          'LATITUDE' : s['latitude'],
                                          'LONGITUDE' : s['longitude'] })
            pass

        # now, munge into one list:
        for n in ni:
            #if n['hostname'].find('cc.gt') < 0:
            #    continue

            # check if we have site info for this node:
            if not si_map.has_key(n['site_id']):
                errstr = "could not find site for node %s" % n['hostname']
                if not ignoreErrors:
                    raise RuntimeError, "Error: %s" % errstr
                else:
                    print "Warning: %s" % errstr
                    pass
                continue

            # check if we have the primary nodenetwork for this node:
            nnid = -1
            for i in n['nodenetwork_ids']:
                if nni_map.has_key(i):
                    nnid = i
                    break
                pass
            if nnid < 0:
                errstr = "could not find network for node %s" % n['hostname']
                if not ignoreErrors:
                    raise RuntimeError, "Error: %s" % errstr
                else:
                    print "Warning: %s" % errstr
                    pass
                continue

            # now add the node:
            # note that we force some ints to strings because the xml file
            # siteParser didn't force them to ints.
            adi = { 'HNAME'     : n['hostname'],
                    'PLABID'    : str(n['node_id']),
                    'IP'        : nni_map[nnid]['IP'],
                    'MAC'       : nni_map[nnid]['MAC'],
                    'BWLIMIT'   : nni_map[nnid]['BWLIMIT'],
                    'SITE'      : si_map[n['site_id']]['SITE'],
                    'LATITUDE'  : si_map[n['site_id']]['LATITUDE'],
                    'LONGITUDE' : si_map[n['site_id']]['LONGITUDE'] }
            if n.has_key('boot_status'):
                adi['STATUS'] = n['boot_status']
                pass
            
            self.__hosts.append(adi)
            pass

        return self.__hosts
    
    pass


class Plab:
    def __init__(self):
        pass

    def getPLCs(self):
        """
        Returns a list of PLC (name,idx) tuples currently in the Emulab db.
        """
        plcs = []
        res = DBQueryFatal("select plc_idx,plc_name from plab_plc_info")
        for (idx,name) in res:
            plcs.append((name,idx))
            pass
        return plcs

    def createSlices(self,pid,eid,stopOnFail=False):
        """
        Slice factory function that creates all slices necessary for an
        Emulab experiment.  If you want to be immediately notified if one of
        the slices cannot be created successfully, set the stopOnFail param.

        Note: if there are errors while creating and configuring some slices,
        those are returned via an exception.
        Any successfully-created slices are NOT torn down!  If you get an
        exception from this call, you should immediately call Plab.loadSlices,
        and call the destroySlice method on each slice returned by loadSlices.
        """

        # Since each experiment could have multiple slices, we figure out
        # which slices we're going to need, and we allow for the possibility
        # that there may already be an existing slice for this experiment
        # that can host some of its nodes.
        #
        # (XXX: for now, we're assuming that each experiment can have only one
        # slice per PLC (figuring out which nodes go to which slice at the
        # same PLC may not be needed ever, and is going to require lots more
        # config info.))

        slicelist = []
        failedslices = []

        # grab any existing slices and which plcs host them
        res = DBQueryFatal("select plc_idx,slicename"
                           "  from plab_slices"
                           " where pid=%s and eid=%s",
                           (pid,eid))
        existing = dict({})
        for (plcidx,slicename) in res:
            existing[plcidx] = slicename
            pass

        # grab which plcs we need a slice at, and the necessary info to create
        # a slicename
        res = DBQueryFatal("select ppi.plc_idx,ppi.def_slice_prefix"
                           " from reserved as r"
                           " left join nodes as n on r.node_id=n.node_id"
                           " left join node_types as nt on n.type=nt.type"
                           " left join plab_plc_info as ppi"
                           "   on nt.type=ppi.node_type"
                           " where r.pid=%s and r.eid=%s"
                           "   and ppi.plc_idx is not NULL"
                           " group by n.type",(pid,eid))
        for (plcidx,prefix) in res:
            plc,slicename = None,None

            # grab our plc so we can get config attrs
            try:
                plc = PLC(plcidx)
            except:
                raise

            # figure out how we're supposed to create this slice
            slice_create_method = plc.getAttrVal('slice_create_method')
            if not slice_create_method or slice_create_method == '':
                slice_create_method = 'singlesite'
                pass

            if existing.has_key(plcidx):
                slicename = existing[plcidx]
                pass
            else:
                # grab the exptidx; may need it
                res = DBQueryFatal("select idx from experiments"
                                   " where pid=%s and eid=%s",
                                   (pid,eid))
                if not len(res):
                    raise RuntimeError, \
                          "Didn't get any results while looking up info" \
                          " on experiment %s/%s" % (self.pid, self.eid)
                (exptidx,) = res[0]
                
                if slice_create_method == 'singlesite':
                    # name the slice using the prefix of our single site
                    slicename = "%s_elab_%d" % (prefix,exptidx)
                    pass
                elif slice_create_method == 'federate':
                    if debug:
                        print "Using 'federate' slice create method!"
                        pass
                    # use the prefix of the site for the pid containing
                    # this eid.
                    translator = EmulabPlcObjTranslator(plc)

                    if debug:
                        print "Synch'ing project %s" % str(pid)
                        pass
                    # ensure that project (site) is created and up to date
                    translator.syncObject('project',pid)

                    # ensure that all users in this project are members of the
                    # site, and that their info is up to date
                    res = DBQueryFatal("select uid from group_membership" \
                                       " where pid=%s",(pid,))
                    for row in res:
                        (p_uid,) = row
                        if debug:
                            print "Synch'ing user %s" % str(p_uid)
                            pass
                        translator.syncObject('user',p_uid)
                        pass

                    # now grab whatever site name we need:
                    site = translator.getPlabName('project',pid)

                    # have to get rid of dashes and make things lowercase.
                    slicename = "%s_%s" % (site,eid.lower().replace("-",""))

                    # NOTE: since we're mapping from the Emulab eid superset
                    # of slice names, check to ensure we're not duplicating
                    # a slicename already in use.  If we are, no problem;
                    # we just append "_%s" % eid_idx.
                    res = DBQueryFatal("select slicename from plab_slices" \
                                       " where pid=%s and slicename=%s",
                                       (pid,slicename))
                    if res and len(res) > 0:
                        slicename = "%s_%s" % (slicename,str(exptidx))
                        pass
                    pass
                pass

            slice = EmulabSlice(plc,slicename,pid=pid,eid=eid)
            try:
                slice.create()
            except:
                print "Create of slice %s at %s failed!" % (slice.slicename,
                                                            plc.name)
                if stopOnFail:
                    raise
                failedslices.append(slice.slicename)
                if debug:
                    traceback.print_exc()
                    pass
                continue
            slicelist.append(slice)
            pass

        if not failedslices == []:
            raise RuntimeError, "Could not create some slices: %s" \
                  % ','.join(failedslices)

        return slicelist

    def createSlice(self,pid,eid,plcidx,slicename):
        """
        Create only a single slice within an experiment.
        """
        plc = None
        try:
            plc = PLC(plcidx)
        except:
            raise

        slice = EmulabSlice(plc,slicename,pid=pid,eid=eid)

        try:
            slice.create()
        except:
            print "Creation of slice %s failed!" % slicename
            if debug:
                traceback.print_exc()
                pass
            raise

        return slice

    def createSliceDirect(self,plcidx,slicename,description,sliceurl=None,
                          userlist=[],nodelist=[],instmethod=None):
        """
        Slice factory function that doesn't use the Emulab db.
        """
        plc = None
        try:
            plc = PLC(plcidx)
        except:
            raise
        slice = Slice(plc,slicename,slicedescr=description,sliceurl=sliceurl,
                      userlist=userlist,nodelist=nodelist,
                      instmethod=instmethod)
        slice._create()
        return slice

    def loadSliceByNode(self, pid, eid, nodeid):
        """
        Slice factory function that loads the slice which contains the given
        nodeid and corresponds to the given pid/eid.
        """
        slice = None

        #
        # We want to have only one of each of monitoring and testing
        # experiments, but we want to have a slice from each PLC be "in"
        # that experiment.  Thus, we have to find out which plc the node
        # "belongs" to, and figure out which slice we care about based the
        # hosting plc.
        #
        res = DBQueryFatal("select ps.plc_idx,ps.slicename"
                           " from reserved as r"
                           " left join nodes as n on r.node_id=n.node_id"
                           " left join plab_mapping as pm"
                           "   on n.phys_nodeid=pm.node_id"
                           " left join plab_slices as ps"
                           "   on pm.plc_idx=ps.plc_idx"
                           " where r.node_id=%s and r.pid=%s and r.eid=%s"
                           "   and ps.pid=%s and ps.eid=%s",
                           (nodeid,pid,eid,pid,eid))
        if not res or len(res) <= 0:
            raise RuntimeError, "Could not find a slice for %s/%s/%s!" % \
                  (pid,eid,nodeid)
        if len(res) > 1:
            raise RuntimeError, "Found multiple slices for %s/%s/%s!" % \
                  (pid,eid,nodeid)
        (plcidx,slicename) = res[0]

        plc = None
        try:
            plc = PLC(plcidx)
        except:
            raise

        slice = EmulabSlice(plc,slicename,pid,eid)
        try:
            slice.load()
        except:
            print "Load of existing slice %s (%s) failed!" % (slice.slicename,
                                                              plc.name)
            if debug:
                traceback.print_exc()
                pass
            raise

        return slice

    def getSliceMapping(self,plcidx=None,pid=None,eid=None,slicename=None):
        """
        Returns a multi-level dict of plcidx->(pid,eid)s->slicename(s),
        possibly filtered by plcidx, pid, or eid.
        """
        retval = dict({})

        plc = None
        if plcidx:
            plc = PLC(plcidx)
            pass

        qstr = "select pid,eid,slicename,plc_idx from plab_slices"

        fclause = []
        fargs = []
        if pid:
            fclause.append("pid=%s")
            fargs.append(pid)
        if eid:
            fclause.append("eid=%s")
            fargs.append(eid)
        if plc:
            fclause.append("plc_idx=%s")
            fargs.append(plc.idx)
        if slicename:
            fclause.append("slicename=%s")
            fargs.append(slicename)

        args = [ qstr ]
        if len(fclause):
            qstr = "%s where %s" % (qstr," and ".join(fclause))
            args = [ qstr,tuple(fargs) ]
            pass

        res = DBQueryFatal(*args)

        for (pid,eid,slicename,plc_idx) in res:
            try:
                plc = PLC(plc_idx)
            except:
                raise "could not resolve plc_idx %d" % plc_idx
            
            if not retval.has_key(plc.name):
                retval[plc.name] = dict({})
                pass

            if not retval[plc.name].has_key((pid,eid)):
                retval[plc.name][(pid,eid)] = []
                pass

            retval[plc.name][(pid,eid)].append(slicename)
            pass

        return retval

    def loadSlices(self, pid, eid, stopOnFail=False):
        """
        Slice factory function that loads all slices necessary for an Emulab
        experiment.
        """
        slicelist = []

        # grab any existing slices and which plcs host them
        res = DBQueryFatal("select plc_idx,slicename"
                           "  from plab_slices"
                           " where pid=%s and eid=%s",
                           (pid,eid))

        for (plcidx,slicename) in res:
            plc = None
            try:
                plc = PLC(plcidx)
            except:
                raise
            
            # need to try to load and (re)configure an existing slice:
            slice = EmulabSlice(plc,slicename,pid,eid)
            try:
                slice.load()
            except:
                print "Load of existing slice %s failed!" % slice.slicename
                if debug:
                    traceback.print_exc()
                    pass
                if stopOnFail:
                    raise
                #failedslices.append(slice.slicename)
                continue
            slicelist.append(slice)
            pass
        
        return slicelist

    def loadSlice(self,pid,eid,plcidx,slicename):
        """
        Slice factory function that loads all slices necessary for an Emulab
        experiment.
        """
        slice = None
        plc = None
        try:
            plc = PLC(plcidx)
        except:
            raise
        
        slice = EmulabSlice(plc,slicename,pid,eid)
        try:
            slice.load()
        except:
            print "Load of existing slice %s failed!" % slice.slicename
            if debug:
                traceback.print_exc()
                pass
            raise
        
        return slice

    def loadSliceDirect(self,plcidx,slicename,slicedescr=None,sliceurl=None,
                        userlist=[],nodelist=[],instmethod=None):
        """
        Slice factory function that doesn't use the Emulab db.
        """
        plc = None
        try:
            plc = PLC(plcidx)
        except:
            raise
        slice = Slice(plc,slicename,slicedescr=slicedescr,sliceurl=sliceurl,
                      userlist=userlist,nodelist=nodelist,
                      instmethod=instmethod)
        slice.load()
        return slice

    def updateNodeGroupEntries(self,plcid,ignorenew = False):
        # grab our plc:
        plc = PLC(plcid)

        print "Synching %s node groups..." % plc.name
        print "Starting at %s." % time.strftime("%Y-%m-%d %H:%M:%S",
                                                time.localtime())

        method = plc.getAttrVal("syncmethod")
        if method == None:
            method = "xmlrpc"
            pass

        groups = None
        parser = None
        try:
            if method == "sitesxml":
                parser = siteParser(plc)
            elif method == "xmlrpc":
                parser = XmlrpcNodeInfoFetcher(plc)
            else:
                raise RuntimeError, "Unsupported update node method %s!" % \
                      method

            if callable(getattr(parser,'getPlabNodeGroupInfo')):
                groups = parser.getPlabNodeGroupInfo()
                pass
            if not groups == None:
                print "\nGot nodegroup list:"
                print str(groups)
                pass
            else:
                print "No way to get nodegroups; done."
                pass

            pass
        except:
            extype, exval, extrace = sys.exc_info()
            print "Error talking to agent: %s: %s" % (extype, exval)
            if debug:
                traceback.print_exc()
                pass
            
            print "Going back to sleep until next scheduled poll"
            return

        qres = DBQueryFatal("select nodegroup_idx from plab_nodegroups"
                            " where plc_idx=%s",(plc.idx,))
        existing = []
        for (idx,) in qres:
            existing.append(idx)
            pass

        new = groups.keys()

        # We take the easy way out for synch'ing: synch the groups, but
        # just wipe and rebuild the members table.  So, make that set of
        # operations appear atomic to any readers.
        DBQueryFatal("lock tables plab_nodegroups write,"
                     " plab_nodegroup_members write")

        try:
            # figure out groups that no longer exist and delete them
            delete = []
            for gid in existing:
                if not gid in new:
                    delete.append(gid)
                    pass
                pass
            for gid in delete:
                print "Removing nodegroup %d." % gid
                DBQueryFatal("delete from plab_nodegroup_members" \
                             " where plc_idx=%s and nodegroup_idx=%s",
                             (plc.idx,gid))
                DBQueryFatal("delete from plab_nodegroups" \
                             " where plc_idx=%s and nodegroup_idx=%s",
                             (plc.idx,gid))
                existing.remove(gid)
                pass
            
            # update existing/new groups
            for gid in new:
                # just delete all the member entries, then replace--it's easier
                DBQueryFatal("delete from plab_nodegroup_members" \
                             " where plc_idx=%s and nodegroup_idx=%s",
                             (plc.idx,gid))
                DBQueryFatal("replace into plab_nodegroups" \
                             " (plc_idx,nodegroup_idx,name,description)" \
                             " values (%s,%s,%s,%s)",
                             (plc.idx,gid,groups[gid]['name'],
                              groups[gid]['description']))
                for node_id in groups[gid]['node_ids']:
                    DBQueryFatal("replace into plab_nodegroup_members" \
                                 " (plc_idx,nodegroup_idx,node_id)" \
                                 " values (%s,%s,%s)",
                                 (plc.idx,gid,node_id))
                    pass
                pass
            pass
        except:
            print "Exception while talking to DB; there may be\n" \
                  "  unsynch'd state to cleanup!"
            traceback.print_exc()
            pass

        DBQueryFatal("unlock tables")

        return

    def updateNodeEntries(self, plcid, ignorenew = False):
        """
        Finds out which Plab nodes are available, and
        update the DB accordingly.  If ignorenew is True, this will only
        make sure that the data in the DB is correct, and not complete.
        If ignorenew is False (the default), this will do a complete
        update of the DB.  However, this can take some time, as
        information about new nodes (such as link type) must be
        discovered.

        Note that this seemingly innocent funciton actually does a lot of
        magic.  This is the main/only way that Plab nodes get into the
        nodes DB, and this list is updated dynamically.  It also gathers
        static data about new nodes.
        """

        # grab our plc:
        plc = PLC(plcid)

        print "Synching %s nodes..." % plc.name
        print "Starting at %s." % time.strftime("%Y-%m-%d %H:%M:%S",
                                                time.localtime())

        method = plc.getAttrVal("syncmethod")
        if method == None:
            method = "xmlrpc"
            pass

        avail = []
        avail_plab_ids = []
        parser = None
        try:
            if method == "sitesxml":
                parser = siteParser(plc)
            elif method == "xmlrpc":
                parser = XmlrpcNodeInfoFetcher(plc)
            else:
                raise RuntimeError, "Unsupported update node method %s!" % \
                      method

            avail = parser.getPlabNodeInfo()

            # save off the plab ids for quicker searching.
            for n in avail:
                avail_plab_ids.append(n['PLABID'])
                pass

            pass
        # XXX: rewrite to use more elegant exception info gathering.
        except:
            extype, exval, extrace = sys.exc_info()
            print "Error talking to agent: %s: %s" % (extype, exval)
            if debug:
                #print extrace
                traceback.print_exc()
                pass
            
            print "Going back to sleep until next scheduled poll"
            return

        if debug:
            print "Got advertisement list:"
            print str(avail)
            pass

        # We use nodetype because the plc name might have icky chars, or might
        # change -- but the nodetype will not.
        ignored_nodes = self.__readNodeFile("%s.%s" % (IGNORED_NODES_FILE,
                                                       plc.nodetype))
        allowed_nodes = self.__readNodeFile("%s.%s" % (ALLOWED_NODES_FILE,
                                                       plc.nodetype))

        # Enforce node limitations, if any.
        # XXX: This is ugly - maybe move to a separate function
        #      that takes a list of filter functions.  I know!!
        #      Create a generator out of a set of filter functions
        #      and the initial node list! :-)  Python geek points to me if
        #      I ever get around to it...  KRW
        if len(allowed_nodes) or len(ignored_nodes):
            allowed = []
            for nodeent in avail:
                if nodeent['PLABID'] in ignored_nodes:
                    continue
                elif len(allowed_nodes):
                    if nodeent['IP'] in allowed_nodes:
                        allowed.append(nodeent)
                        pass
                    pass
                else:
                    allowed.append(nodeent)
                    pass
                pass
            if verbose:
                print "Advertisements in allowed nodes list:\n%s" % allowed
                pass
            avail = allowed
            pass

        # Check for duplicate node attributes (sanity check)
        availdups = self.__findDuplicateAttrs(avail)
        if len(availdups):
            #SENDMAIL(TBOPS, "Duplicates in %s advertised node list" % plc.name,
            #         "Duplicate attributes:\n"
            #         "%s\n\n"
            #         "Let plab support know!" % availdups,
            #         TBOPS)
            #raise RuntimeError, \
            print "Warning: duplicate attributes in plab node listing:\n%s" \
                  % availdups

        # Get node info we already have.
        known = self.__getKnownPnodes(plc)
        known_plab_ids = []
        if debug:
            print "Got known pnodes:"
            print known
            pass

        for (nodeid,nodeent) in known.iteritems():
            known_plab_ids.append(nodeent['PLABID'])
            pass

        # Create list of nodes to add or update
        toadd    = []  # List of node entries to add to DB
        toupdate = []  # List of node entries to update in the DB
        todelete = []  # List of nodes to mark as "deleted"
        for nodeent in avail:
            # Replace sequences of bad chars in the site entity with
            # a single "-".
            nodeent['SITE'] = BADSITECHARS.sub("-", nodeent['SITE'])
            # Determine if we already know about this node.
            matchres = self.__matchPlabNode(nodeent, known)
            if not matchres:
                toadd.append(nodeent)
                pass
            elif len(matchres[1]):
                toupdate.append((nodeent,matchres))
                # since we may change a plabid for an existing node, don't
                # mark this one as deleted.
                if nodeent['PLABID'] in known_plab_ids:
                    known_plab_ids.remove(nodeent['PLABID'])
                    pass
                pass
            pass

        # mark nodes as deleted (for now, just means plab doesn't know about
        # them)
        for plabid in known_plab_ids:
            if not plabid in avail_plab_ids:
                todelete.append(plabid)
                pass
            pass

        # Process the list of nodes to add
        addstr = ""
        if len(toadd):
            # Are we ignoring new entries?
            if ignorenew:
                if verbose:
                    print "%d new Plab nodes, but ignored for now" % len(toadd)
                    pass
                pass
            # If not ignoring, do the addition/update.
            else:
                print "There are %d new Plab nodes." % len(toadd)
                for nodeent in toadd:
                    # Get the linktype here so we can report it in email.
                    self.__findLinkType(nodeent)
                    if debug:
                        print "Found linktype %s for node %s" % \
                              (nodeent['LINKTYPE'], nodeent['IP'])
                        pass
                    # Add the node.
                    self.__addNode(plc,nodeent)
                    # Add a line for the add/update message.
                    nodestr = "%s\t\t%s\t\t%s\t\t%s\t\t%s\n" % \
                              (nodeent['PLABID'],
                               nodeent['IP'],
                               nodeent['HNAME'],
                               nodeent['SITE'],
                               nodeent['LINKTYPE'])
                    addstr += nodestr
                    pass
                pass
            pass

        # Process node updates.
        updstr = ""
        chgerrstr = ""
        if len(toupdate):
            print "There are %d plab node updates." % len(toupdate)
            for (nodeent,(nodeid,diffattrs)) in toupdate:
                if debug:
                    print "About to update %s; new info %s; diff %s" \
                          % (str(nodeid),str(nodeent),str(diffattrs))
                try:
                    self.__updateNodeMapping(nodeid, diffattrs)
                    pass
                except MultiChangeError, e:
                    print "%s not updated: Too many attribute changes." % \
                          e.nodeid
                    chgerrstr += "%s:\n" % e.nodeid
                    for (attr,(old,new)) in e.chattrs.items():
                        chgerrstr += "\t%s:\t%s => %s\n" % (attr,old,new)
                        pass
                    chgerrstr += "\n"
                    continue
                self.__updateNode(plc, nodeid, nodeent)
                # Add a line for the add/update message.
                nodestr = nodeid + "\n"
                for (attr,(old,new)) in diffattrs.items():
                    nodestr += "\t%s:\t%s => %s\n" % (attr,old,new)
                    pass
                updstr += nodestr + "\n"
                pass
            pass

        # Do node features updates separately since very few nodes are usually
        # updated, whereas we must do status separately from other fields.
        # XXX: munge this in with other fields later.
        upfeatures = []
        for nodeent in avail:
            # Determine if we already know about this node.
            try:
                matchres = self.__matchPlabNode(nodeent, known)
                if matchres:
                    upfeatures.append((nodeent,matchres))
                    pass
                pass
            except:
                pass
            pass
        
        for (nodeent,(nodeid,other)) in upfeatures:
            self.__updateNodeFeatures(nodeid,nodeent)
            pass
        
        if chgerrstr:
            #SENDMAIL(TBOPS,
            #         "Two or more changes detected for some plab nodes",
            #         "Two or more distinguishing attributes have changed "
            #         "on the following planetlab nodes:\n\n%s\n" % chgerrstr,
            #         TBOPS)
            print "Warning: two or more distinguishing attributes have" \
                  " changed on the following planetlab nodes:\n\n%s\n" \
                  % chgerrstr,
            pass

        if len(toadd) or len(toupdate):
            # We need to update DNS since we've added hosts..
            print "Forcing a named map update ..."
            os.spawnl(os.P_WAIT, NAMED_SETUP, NAMED_SETUP)
            print "Pushing out site_mapping ..."
            os.spawnl(os.P_WAIT, PELAB_PUSH, PELAB_PUSH)
            # Now announce that we've added/updated nodes.
            #SENDMAIL(TBOPS,
            #         "Plab nodes have been added/updated in the DB.",
            #         "The following plab nodes have been added to the DB:\n"
            #         "PlabID\t\tIP\t\tHostname\t\tSite\t\tLinktype\n\n"
            #         "%s\n\n"
            #         "The following plab nodes have been updated in the DB:\n"
            #         "\n%s\n\n" % \
            #         (addstr, updstr),
            #         TBOPS)
            print "The following plab nodes have been added to the DB:\n" \
                  "PlabID\t\tIP\t\tHostname\t\tSite\t\tLinktype\n" \
                  "\n%s\n\n" \
                  "The following plab nodes have been updated in the DB:\n" \
                  "\n%s\n\n" % (addstr, updstr),
            print "Done adding new Plab nodes."
            pass

        # mark any nodes as deleted:
        if len(todelete) > 0:
            print "Marking %d nodes as deleted: %s" % (len(todelete),
                                                       str(todelete))
        for plabid in todelete:
            DBQueryFatal("update plab_mapping set deleted=1" \
                         " where plab_id=%s",(plabid,))
            pass

        return

    def __matchPlabNode(self, plabent, knownents):
        """
        Helper function.  Returns a two-element tuple or null.
        Null is returned when the node does not match any in the
        knownents list (none of it's attributes match those of any
        in the list).  If a match (or partial match) is found, a two
        element tuple is returned.  The first element is the emulab
        node id that matched, and the second is a dictionary containing
        thos elements that differed between the two (in the case of a
        partial match).
        """
        for nid in knownents:
            ent = knownents[nid]
            same = {}
            diff = {}
            for attr in ent:
                if ent[attr] in ATTR_NIL_VALUES:
                    continue
                elif (attr == "LATITUDE") or (attr == "LONGITUDE"):
                    # Special rules for latitude and longitude to avoid
                    # FP errors
                    nasty = False
                    try:
                        x = float(ent[attr])
                        x = float(plabent[attr])
                        pass
                    except:
                        nasty = True
                        pass
                    if (not nasty and ent[attr] != None and plabent[attr] != None) \
                           and (ent[attr] != "" and plabent[attr] != "") \
                           and ((float(ent[attr]) > \
                                 (float(plabent[attr]) + LATLONG_DELTA)) \
                                or (float(ent[attr]) < \
                                    (float(plabent[attr]) - LATLONG_DELTA))):
                        diff[attr] = (ent[attr], plabent[attr])
                    else:
                        same[attr] = ent[attr]
                        pass
                elif ent[attr] == plabent[attr]:
                    same[attr] = ent[attr]
                    pass
                else:
                    diff[attr] = (ent[attr], plabent[attr])
                    pass
                pass
            # Only consider these to be the same if at least one 'critical'
            # attr is the same
            if len(same):
                for attr in same:
                    if attr in ATTR_CRIT_KEYS:
                        return (nid, diff)
            pass
        return ()

    def __getKnownPnodes(self,plc):
        """
        getFree helper function.  Returns a dict of IP:node_id pairs
        for the Plab nodes that currently exist in the DB.
        """
        res = DBQueryFatal("select pm.node_id,pm.plab_id,pm.hostname,"
                           "pm.IP,pm.mac,wni.site,wni.latitude,"
                           "wni.longitude,wni.bwlimit"
                           " from plab_mapping as pm"
                           " left join widearea_nodeinfo as wni on"
                           "    pm.node_id = wni.node_id"
                           " where pm.plc_idx=%s",(plc.idx,))
        
        ret = {}
        for (nodeid, plabid, hostname, ip, mac, site,
             latitude, longitude, bwlimit) in res:
            #if hostname.find('cc.gt') < 0:
            #    continue
            ret[nodeid] = {'PLABID'    : plabid,
                           'HNAME'     : hostname,
                           'IP'        : ip,
                           'MAC'       : mac,
                           'SITE'      : site,
                           'LATITUDE'  : latitude,
                           'LONGITUDE' : longitude,
                           'BWLIMIT'   : bwlimit}
            pass
        # Check for duplicate node attributes: report any that are found.
        dups = self.__findDuplicateAttrs(ret.values())
        if len(dups):
            #SENDMAIL(TBOPS,
            #         "Duplicate %s node attributes in the DB!" % plc.name,
            #         "Duplicate node attrs:\n"
            #         "%s\n\n"
            #         "Fix up please!" % str(dups),
            #         TBOPS)
            #raise RuntimeError, \
            print "Warning: duplicate node attributes in DB:\n%s" % str(dups)
        return ret

    def __findDuplicateAttrs(self, nodelist):
        """
        Find duplicate node attributes in the node list passed in.
        """
        attrs = {}
        dups = {}
        
        for ent in nodelist:
            for attr in ATTR_CRIT_KEYS:
                entry = "%s:%s" % (attr, ent[attr])
                if attrs.has_key(entry) and \
                   ent[attr] not in ATTR_NIL_VALUES:
                    print "Duplicate node attribute: %s" % entry
                    if not dups.has_key(entry):
                        dups[entry] = [attrs[entry],]
                        pass
                    dups[entry].append(ent['PLABID'])
                else:
                    attrs[entry] = ent['PLABID']
                    pass
                pass
            pass
        return dups
        
    def __findLinkType(self, nodeent):
        """
        getFree helper function.  Figures out the link type of the given
        host.  This first performs a traceroute and checks for the U of
        U's I2 gateway to classify Internet2 hosts.  If this test fails,
        it checks if the hostname is international.  If this test fails,
        this simply specifies an inet link type.

        This can't detect DSL links..
        """
        # Is host international (or flux/emulab local)?
        from socket import gethostbyaddr, getfqdn, herror
        
        if not nodeent.has_key('HNAME'):
            try:
                (hname, ) = gethostbyaddr(ip)
                nodeent['HNAME'] = getfqdn(hname)
                pass
            except herror:
                nodeent['HNAME'] = nodeent['IP']
                print "Warning: Failed to get hostname for %s" % nodeent['IP']
                pass
            pass
        
        tld = nodeent['HNAME'].split(".")[-1].lower()
        if not tld in ("edu", "org", "net", "com", "gov", "us", "ca"):
            nodeent['LINKTYPE'] = "intl"
            return
        
        # Is it us?
        if nodeent['HNAME'].endswith(LOCAL_PLAB_DOMAIN):
            nodeent['LINKTYPE'] = LOCAL_PLAB_LINKTYPE
            return
        
        # Is host on I2?
        traceroute = os.popen("traceroute -nm 10 -q 1 %s" % nodeent['IP'])
        trace = traceroute.read()
        traceroute.close()

        for gw in MAGIC_INET2_GATEWAYS:
            if trace.find(gw) != -1:
                nodeent['LINKTYPE'] = "inet2"
                return

        for gw in MAGIC_INET_GATEWAYS:
            if trace.find(gw) != -1:
                nodeent['LINKTYPE'] = "inet"
                return
        else:
            print "Warning: Unknown gateway for host %s" % nodeent['IP']

        # We don't know - must manually classify.
        nodeent['LINKTYPE'] = "*Unknown*"
        return

    def __addNode(self, plc, nodeent):
        """
        updateNodeEntries() helper function.  Adds a new Plab pnode and
        associated vnode to the DB.  The argument is a dictionary containing
        the new node's attributes.
        """
        # Generate/grab variables to be used when creating the node.
        defosid, controliface = self.__getNodetypeInfo(plc)
        hostonly = nodeent['HNAME'].replace(".", "-")
        nidnum, priority = self.__nextFreeNodeid(plc)
        nodeid = "%s%d" % (plc.nodename_prefix, nidnum)
        vnodeprefix = "%svm%d" % (plc.nodename_prefix, nidnum)
        print "Creating pnode %s as %s, priority %d." % \
              (nodeent['IP'], nodeid, priority)

        # fixup MAC so it's not null, even if plab did not give us a MAC:
        if nodeent['MAC'] == None:
            nodeent['MAC'] = ''
            pass

        # Do the stuff common to both node addition and update first
        # Note that if this fails, we want the exception generated to
        # percolate up to the caller immediately, so don't catch it.
        self.__updateNode(plc, nodeid, nodeent)

        # Now perform stuff specific to node addition
        try:
            res_exptidx = TBExptIDX(RESERVED_PID, RESERVED_EID)
            mon_exptidx = TBExptIDX(MONITOR_PID, MONITOR_EID)
            
            DBQueryFatal("replace into nodes"
                         " (node_id, type, phys_nodeid, role, priority,"
                         "  op_mode, def_boot_osid,"
                         "  allocstate, allocstate_timestamp,"
                         "  eventstate, state_timestamp, inception)"
                         " values (%s, %s, %s, %s, %s,"
                         "  %s, %s, %s, now(), %s, now(), now())",
                         (nodeid, "%s%s" % (plc.nodetype,'phys'), nodeid,
                          'testnode', priority*100,
                          'ALWAYSUP', defosid,
                          'FREE_CLEAN',
                          'ISUP'))

            DBQueryFatal("replace into node_hostkeys"
                         " (node_id)"
                         " values (%s)",
                         (nodeid))

            DBQueryFatal("replace into node_utilization"
                         " (node_id)"
                         " values (%s)",
                         (nodeid))

            DBQueryFatal("replace into reserved"
                         " (node_id, exptidx, pid, eid, rsrv_time, vname)"
                         " values (%s, %s, %s, %s, now(), %s)",
                         (nodeid, res_exptidx,
                          RESERVED_PID, RESERVED_EID, hostonly))

            # XXX: This should probably be checked and updated if necessary
            #      when updating.
            DBQueryFatal("replace into node_auxtypes"
                         " (node_id, type, count)"
                         " values (%s, %s, %s)",
                         (nodeid,"%s%s" % (plc.nodetype,nodeent['LINKTYPE']),
                          1))
            
            DBQueryFatal("replace into node_auxtypes"
                         " (node_id, type, count)"
                         " values (%s, %s, %s)",
                         (nodeid, plc.nodetype, 1))
            
            DBQueryFatal("replace into node_status"
                         " (node_id, status, status_timestamp)"
                         " values (%s, %s, now())",
                         (nodeid, 'down'))

            DBQueryFatal("insert into plab_mapping"
                         " (node_id, plab_id, hostname, IP, mac, create_time,"
                         "  plc_idx)"
                         " values (%s, %s, %s, %s, %s, now(), %s)",
                         (nodeid, nodeent['PLABID'], nodeent['HNAME'],
                          nodeent['IP'], nodeent['MAC'], plc.idx))

            #
            # NowAdd the site_mapping entry for this node.
            #
            
            # See if we know about the associated site - grab idx if so
            siteidx = 0
            nodeidx = 1
            siteres = DBQueryFatal("select site_idx, node_idx"
                                   " from plab_site_mapping"
                                   " where site_name=%s and plc_idx=%s",
                                   (nodeent['SITE'],plc.idx));
            if len(siteres):
                # There are already nodes listed for this site, so get
                # the next node id.
                siteidx = siteres[0][0]
                for (foo, idx) in siteres:
                    if idx > nodeidx: nodeidx = idx
                    pass
                nodeidx += 1
                pass
            else:
                # No nodes listed for site, so get the largest site_idx
                # in the DB so far, and increment cuz we're going to add
                # a new one.
                maxres = DBQueryFatal("select MAX(site_idx) from "
                                      " plab_site_mapping")
                try:
                    if not maxres[0][0]:
                        siteidx = 1
                    else:
                        siteidx = int(maxres[0][0]) + 1
                        pass
                    pass
                except ValueError:
                    siteidx = 1
                    pass
                pass
            # Create site_mapping entry, optionally creating new site idx
            # via not specifying the site_idx field (field is auto_increment)
            DBQueryFatal("insert into plab_site_mapping "
                         " values (%s, %s, %s, %s, %s)",
                         (nodeent['SITE'], siteidx, nodeid, nodeidx, plc.idx))

            # Create a single reserved plab vnode for the managment sliver.
            n = 1
            vprio = (priority * 100) + n
            sshdport = 38000 + n
            vnodeid = "%s-%d" % (vnodeprefix, n)
            vnodetype = plc.nodetype
            if verbose:
                print "Creating vnode %s, priority %d" % (vnodeid, vprio)
                pass
                    
            DBQueryFatal("insert into nodes"
                         " (node_id, type, phys_nodeid, role, priority,"
                         "  op_mode, def_boot_osid, update_accounts,"
                         "  allocstate, allocstate_timestamp,"
                         "  eventstate, state_timestamp, sshdport)"
                         " values (%s, %s, %s, %s, %s,"
                         "  %s, %s, %s, %s, now(), %s, now(), %s)",
                         (vnodeid, vnodetype, nodeid, 'virtnode', vprio,
                          'PCVM', defosid, 1,
                          'FREE_CLEAN',
                          'SHUTDOWN', sshdport))

            DBQueryFatal("insert into node_hostkeys"
                         " (node_id)"
                         " values (%s)",
                         (vnodeid))
            
            DBQueryFatal("insert into node_status"
                         " (node_id, status, status_timestamp)"
                         " values (%s, %s, now())",
                         (vnodeid, 'up'))
            
            # Put the last vnode created into the special monitoring expt.
            DBQueryFatal("insert into reserved"
                         " (node_id, exptidx, pid, eid, rsrv_time, vname)"
                         " values (%s, %s, %s, %s, now(), %s)",
                         (vnodeid, mon_exptidx,
                          MONITOR_PID, MONITOR_EID, vnodeid))
            pass
        
        except:
            print "Error adding %s (%s) to DB: someone needs to clean up!" % \
                  (nodeid,plc.name)
            tbmsg = "".join(traceback.format_exception(*sys.exc_info()))
            SENDMAIL(TBOPS, "Error adding new %s node to DB: %s\n" % \
                     (plc.name,nodeid),
                     "Some operation failed while trying to add a"
                     " newly discovered plab node to the DB:\n %s"
                     "\n Please clean up!\n" % tbmsg, TBOPS)
            raise
        return

    def __updateNodeFeatures(self,nodeid,nodeent):
        """
        Record the status of this node in the node_features
        table.
        """
        # XXX Make this atomic
        #
        try:
            # Note that we have to pass '%' as an arg to DBQuery, sigh
            DBQueryFatal("delete from node_features where node_id=%s" \
                         " and feature like %s",
                         (nodeid,'plabstatus-%'))
            
            if nodeent.has_key('STATUS'):
                # Kind of a hack - we assume most people will want Production
                # nodes
                if nodeent['STATUS'] == "Production" :
                    weight = 0.0
                    pass
                else:
                    weight = 1.0
                    pass
                DBQueryFatal("insert into node_features" \
                             " (node_id, feature, weight)" \
                             " values (%s,%s,%s)",
                             (nodeid,
                              'plabstatus-%s' % nodeent['STATUS'],
                              weight))
                pass
            pass
        except:
            print "Error updating plab node STATUS feature " \
                  "for node %s!" % nodeid
            traceback.print_exc()
            
        
        return None
    
    def __updateNode(self, plc, nodeid, nodeent):
        """
        updateNodeEntries() helper function.  Updates attributes for plab
        nodes passed in via the nodeent argument.
        """
        # Get the name of the control interface for plab nodes.
        defosid, controliface = self.__getNodetypeInfo(plc)

        haslatlong = (('LATITUDE' in nodeent and 'LONGITUDE' in nodeent) and
            (nodeent['LATITUDE'] != 0 or nodeent['LONGITUDE'] != 0))
        try:
            DBQueryFatal("replace into widearea_nodeinfo"
                         " (node_id, contact_uid, contact_idx, hostname, site,"
                         "  latitude, longitude, bwlimit)"
                         " values (%s, %s, %s, %s, %s, %s, %s, %s)",
                         (nodeid, 'nobody', '0', nodeent['HNAME'],
                          nodeent['SITE'],
                          # Poor man's ternary operator
                          haslatlong and nodeent['LATITUDE'] or "NULL",
                          haslatlong and nodeent['LONGITUDE'] or "NULL",
                          nodeent['BWLIMIT']))

            DBQueryFatal("replace into interfaces"
                         " (node_id, card, port, IP, interface_type,"
                         " iface, role)"
                         " values (%s, %s, %s, %s, %s, %s, %s)",
                         (nodeid, 0, 1, nodeent['IP'], 'plab_fake',
                          controliface, 'ctrl'))

            DBQueryFatal("replace into interface_state"
                         " (node_id, card, port, iface)"
                         " values (%s, %s, %s, %s)",
                         (nodeid, 0, 1, controliface))

            # ensure to mark as undeleted...
            DBQueryFatal("update plab_mapping set deleted=0" \
                         " where node_id=%s",(nodeid,))
            pass
        except:
            print "Error updating PLAB node in DB: someone needs to clean up!"
            tbmsg = "".join(traceback.format_exception(*sys.exc_info()))
            SENDMAIL(TBOPS, "Error updating plab node in DB: %s\n" % nodeid,
                     "Some operation failed while trying to update"
                     " plab node %s in the DB:\n\n%s"
                     "\nPlease clean up!\n" % (nodeid, tbmsg), TBOPS)
            raise
        return


    def __updateNodeMapping(self, nodeid, chattrs):
        """
        Updates changed node attributes in the plab mapping table.
        """
        uid = os.getuid()
        dbuid = uid == 0 and "root" or UNIX2DBUID(uid)

        # mapping from attrs to column names
        attrmap = {'PLABID' : 'plab_id',
                   'HNAME'  : 'hostname',
                   'IP'     : 'IP',
                   'MAC'    : 'mac'}

        # Get the intersection of mapping (critical) keys with those that
        # have changed.
        changedcritkeys = set(ATTR_CRIT_KEYS) & set(chattrs.keys())
        # nothing to do if none of the mapping attributes have changed.
        if not changedcritkeys:
            return
        # If the node has more than two critical attrs that have changed,
        # then move it to hwdown and raise an exception.
        if len(changedcritkeys) > 2:
            crattrs = {}
            for chkey in changedcritkeys:
                crattrs[chkey] = chattrs[chkey]
                pass
            errmsg = "More than 2 plab node attrs have changed!\n\n%s\n\n" \
                     "%s has been moved to hwdown." % (crattrs, nodeid)
            MarkPhysNodeDown(nodeid)
            TBSetNodeLogEntry(nodeid, dbuid, TB_NODELOGTYPE_MISC, errmsg)
            raise MultiChangeError(nodeid, crattrs)

        # Update mapping table entry.
        updstr = ",".join(map(lambda x: "%s='%s'" %
                              (attrmap[x],chattrs[x][1]), changedcritkeys))
        DBQueryFatal("update plab_mapping set %s where node_id='%s'" %
                     (updstr, nodeid))
        updmsg = "Plab node %s attributes updated:\n\n%s" % (nodeid, chattrs)
        TBSetNodeLogEntry(nodeid, dbuid, TB_NODELOGTYPE_MISC, updmsg)

        # updateNodeEtries() already sends mail.
        #SENDMAIL(TBOPS,
        #         "Plab node %s attributes updated." % nodeid, updmsg, TBOPS)
        return

    def __getNodetypeInfo(self,plc):
        """
        addNode helper function.  Returns a (defosid, controliface) 
        tuple for the Plab pnode type.  Caches the result since
        it doesn't change.
        """
        if not hasattr(self, "__getNodetypeInfoCache"):
            if debug:
                print "Getting node type info"
                pass

            dbres = DBQueryFatal("select attrkey,attrvalue "
                                 " from node_type_attributes as a "
                                 " where type = '%s%s' and "
                                 "       (a.attrkey='default_osid' or "
                                 "        a.attrkey='control_interface') "
                                 " order by attrkey" % (plc.nodetype,'phys'))
            
            assert (len(dbres) == 2), "Failed to get node type info"
            attrdict = {}
            for attrkey, attrvalue in dbres:
                attrdict[attrkey] = attrvalue;
                pass
            self.__getNodetypeInfoCache = \
                                        (attrdict["default_osid"],
                                         attrdict["control_interface"])
            pass
        
        return self.__getNodetypeInfoCache

    def __nextFreeNodeid(self,plc):
        """
        addNode helper function.  Returns a (nodeid, priority) tuple of
        the next free nodeid and priority for Plab nodes.
        """
        if debug:
            print "Getting next free nodeid"
        DBQueryFatal("lock tables nextfreenode write")
        try:
            res = DBQueryFatal("select nextid, nextpri from nextfreenode"
                               " where nodetype = '%s'" % plc.nodetype)
            assert (len(res) == 1), "Unable to find next free nodeid"
            DBQueryFatal("update nextfreenode"
                         " set nextid = nextid + 1, nextpri = nextpri + 1"
                         " where nodetype = '%s'" % plc.nodetype)
            ((nodeid, priority), ) = res
            pass
        finally:
            DBQueryFatal("unlock tables")
            pass
        
        return nodeid, priority

    def __readNodeFile(self, filename):
        """
        Helper function - read in list of nodes from a file, seperated
        by arbitrary amounts of whitespace.  No comments allowed.
        """
        nodelist = []
        if os.access(filename, os.F_OK):
            nodefile = open(filename, "r+")
            nodelist = nodefile.read().split()
            nodefile.close()
            pass
        return nodelist

    def renew(self,plc=None,pid=None,eid=None,slicename=None,force=False):
        """
        Renews all of the Plab leases regardless of when they expire.  Note
        that all times are handled in the UTC time zone.  We don't trust
        MySQL to do the right thing with times (yet).
        """

        global failedrenew # XXX
        now = int(time.time())
        
        slicedict = self.getSliceMapping(plc,pid,eid,slicename)
        renewlist = []
        print "Renewing the following slices at %s:" % time.ctime()
        for (plcname,exptdict) in slicedict.iteritems():
            print "  %s:" % plcname
            for ((pid,eid),slicelist) in exptdict.iteritems():
                print "    %s/%s: %s" % (pid,eid,','.join(slicelist))
                for slice in slicelist:
                    renewlist.append((plcname,pid,eid,slice))
                pass
            pass
        print ""

        loadedSlices = {}
        newfail = []
        failsoon = []
        ret = 0
        
        for (plcname,pid,eid,slicename) in renewlist:
            try:
                slice = loadedSlices[(pid,eid,plcname,slicename)]
                pass
            except KeyError:
                slice = self.loadSlice(pid,eid,plcname,slicename)
                loadedSlices[(pid,eid,plcname,slicename)] = slice
                pass

            print "Renewing slice %s/%s in %s/%s at %s:" \
                  % (plcname,slicename,pid,eid,time.ctime())
            res = slice.renew(force=force,renewSlice=True,renewNodes=False)
            entry = (pid,eid,slice.slicename,slice.plc.name,slice.leaseend)

            if res > 0:
                print "Failed to renew slice lease for %s/%s in %s/%s" % \
                      (slice.plc.name,slice.slicename,pid,eid)
                if entry not in failedrenew:
                    newfail.append(entry)
                    pass
                if (slice.leaseend - now) < PLABEXPIREWARN:
                    failsoon.append(entry)
                    pass
                # skip node renewal
                print "Finished slice %s/%s in %s/%s at %s:" \
                      % (plcname,slicename,pid,eid,time.ctime())
                continue
            elif res == -1:
                # slice did not get renewed, so skip
                print "Failingly finished slice %s/%s in %s/%s at %s:" \
                      % (plcname,slicename,pid,eid,time.ctime())
                continue
            else:
                if entry in failedrenew:
                    failedrenew.remove(entry)
                    pass
                pass

            print "Renewing nodes in slice %s/%s in %s/%s at %s:" \
                  % (plcname,slicename,pid,eid,time.ctime())
            res = slice.renew(force=force,renewSlice=False,renewNodes=True)

            print "Finished slice %s/%s in %s/%s at %s:" \
                  % (plcname,slicename,pid,eid,time.ctime())

            pass

        if newfail:
            failedrenew += newfail
            failstr = ""
            for n in newfail:
                failstr += "Slice %s (%s) in %s/%s (expires: %s UTC)\n" % \
                           (n[:4] + (time.asctime(time.gmtime(n[4])),))
                pass
            
            SENDMAIL(TBOPS, "Lease renewal(s) failed",
                     "Failed to renew the following leases:\n%s" %
                     failstr + "\n\nPlease check the plabrenew log", TBOPS)
            pass

        if failsoon:
            failstr = ""
            for n in failsoon:
                failstr += "Slice %s (%s) in %s/%s: (expires: %s UTC)\n" % \
                           (n[:4] + (time.asctime(time.gmtime(n[4])),))
                pass
            SENDMAIL(TBOPS, "Warning: PLAB leases have expired, or will soon",
                     "The following plab leases have expired, or will soon:\n"
                     + failstr + "\n\nPlease look into it!", TBOPS)
            pass

        return
    
    pass # end class Plab
# AOP wrappers for class Plab
wrap_around(Plab.createSlices, timeAdvice)


#
# PLC object: holds basic info and any attributes about a plc, plus
# an agent to talk to it.
#
class PLC:
    def __init__(self,plcid):
        self.id = plcid

        (self.idx,self.name,self.url,self.slice_prefix,self.nodename_prefix,
         self.nodetype,self.svcslice) = (None,None,None,None,None,None,None)

        self.agent = None
        self.extra_agents = []

        # initialize ourself
        self.__load()
        
        return

    def __load(self):
        """
        Load PLC config info from Emulab db.  If a slice was specified,
        load any special slice attributes that may override this PLC's
        default attributes.
        """
        # Figure out if we were given a plc idx or name; either is fine.
        wcstr = ""
        if type(self.id) == types.IntType or type(self.id) == types.LongType:
            wcstr = "plc_idx=%s"
            pass
        else:
            wcstr = "plc_name=%s"
            pass
        # Grab the default, necessary set of plc attributes.
        res = DBQueryFatal("select plc_idx,plc_name,api_url,def_slice_prefix,"
                           "  nodename_prefix,node_type,svc_slice_name"
                           " from plab_plc_info"
                           " where %s" % wcstr,(self.id,))

        if not len(res):
            raise RuntimeError, "Could not find PLC %s!" % str(self.id,)
        
        (self.idx,self.name,self.url,self.slice_prefix,self.nodename_prefix,
         self.nodetype,self.svcslice) = res[0]

        # Grab any attributes.
        res = DBQueryFatal("select slicename,nodegroup_idx,node_id,"
                           "  attrkey,attrvalue"
                           " from plab_attributes"
                           " where plc_idx=%s"
                           " order by slicename,nodegroup_idx,node_id",
                           (self.idx,))
        self.plcattrs = dict({})
        for (slicename,nodegroup_idx,node_id,k,v) in res:
            condlist = []
            if self.plcattrs.has_key(k):
                condlist = self.plcattrs[k]
            else:
                self.plcattrs[k] = condlist

            if slicename == "":
                slicename = None
            if node_id == "":
                node_id = None
            valdict = { 'slicename':slicename,'nodegroup_idx':nodegroup_idx,
                        'node_id':node_id,'value':v }

            condlist.append(valdict)
            pass

        # setup our agent(s):
        primary_agent = self.getAttrVal("primary_agent")
        if primary_agent == None:
            primary_agent = DEF_AGENT
            pass
        self.agent = agents[primary_agent](self)
        try:
            self.agent.setdebug(debug,verbose)
        except:
            pass

        return

    def getAttrVal(self,attrName,slice=None,node=None,required=False):
        """
        Attributes can be set for a PLC across a conditional slice, nodegroup,
        and node tuple.  The first attribute stored in the DB that matches at
        least the attrName, and matches the most slice,nodegroup,node
        conditions, is returned.
        Conditional values of 'None' can only match attribute conditions of
        None (NULL or '' in the db).  Conditional values that are not None
        can match attribute conditions of either None, or the value itself;
        however, direct value matches are preferred.
        """
        retval = None
        if self.plcattrs.has_key(attrName):
            condlist = self.plcattrs[attrName]

            # find the matching attribute:
            retval = None
            bestDirectMatch = 0
            bestAnyMatch = 0
            for c in condlist:
                dM,aM = 0,0

                # setup the real values we're going to test against.
                test_slicename = slice
                if slice:
                    test_slicename = slice.slicename
                test_nodegroups = []
                test_node = None
                if node:
                    test_nodegroups = node.nodegroups
                    test_node = node.phys_nodeid

                if c['slicename'] == test_slicename:
                    dM += 100
                    aM += 100
                elif not c['slicename']:
                    aM += 100
                elif c['slicename'] and test_slicename:
                    # skip this condvalue because neither element
                    # is None but they are unequal; thus, it cannot match.
                    continue

                if c['nodegroup_idx'] in test_nodegroups:
                    dM += 90
                    aM += 90
                elif not c['nodegroup_idx']:
                    aM += 90
                elif c['nodegroup_idx'] and len(test_nodegroups) > 0:
                    # same skip reasoning
                    continue

                if c['node_id'] == test_node:
                    dM += 80
                    aM += 80
                elif not c['node_id']:
                    aM += 80
                elif c['node_id'] and test_node:
                    # same skip reasoning
                    continue

                if (dM > bestDirectMatch) \
                       or (dM == bestDirectMatch and aM > bestAnyMatch):
                    retval = c['value']
                    bestDirectMatch = dM
                    bestAnyMatch = aM

                    #print "Declaring %s best match with %d/%d" \
                    #      % (str(retval),dM,aM)
                pass
            pass
        if not retval and required:
            raise RuntimeError, "Could not find attribute '%s'!" % attrName

        return retval

    # XXX: fix this to return different auth structures for different roles
    # (i.e., for privileged calls, use PI creds; for others, use user creds).
    def getAuthParameter(self):
        """
        Returns an authentication structure for making XMLRPC calls at PLC
        based on plc and slice attributes.
        """
        auth = dict({})
        errstr = "PLC %s" % self.name

        # Get the auth method.
        auth["AuthMethod"] = self.getAttrVal("auth_method",required=True)

        # Grab any necessary additional auth info based on the method.
        if auth["AuthMethod"] == "password":
            try:
                auth["Username"] = self.getAttrVal("username",required=True)
            except:
                raise RuntimeError, "Could not find username for %s" % errstr
            try:
                auth["AuthString"] = self.getAttrVal("password",required=True)
            except:
                raise RuntimeError, "Could not find username for %s" % errstr
            try:
                auth["Role"] = self.getAttrVal("role",required=True)
            except:
                raise RuntimeError, "Could not find role for %s" % errstr
            pass
        else:
            raise RuntimeError, "Unsupported auth_method '%s' for %s!" % \
                  (auth["AuthMethod"],errstr)

        return auth

    pass

class EmulabPlcObjTranslator:
    """
    This class provides a translation between Emulab objects and PLC objects.
    """
    def __init__(self,plc):
        self.plc = plc
        self.__allowed_objects = [ 'project','node','user' ]
        self.__mgmtOperations = { 'node': [ 'setstate' ] }
        pass

    def __checkMapByElabId(self,objtype,objid):
        qres = DBQueryFatal("select plab_id,plab_name from plab_objmap" \
                            " where objtype=%s and elab_id=%s",
                            (objtype,str(objid)))
        if len(qres) != 1:
            return (None,None)

        (id,name) = qres[0]
        # plab ids should be ints, but we left the db field type as a string
        # to support things more generally, if we ever need...
        try:
            id = int(id)
        except:
            pass

        return (id,name)

    def __checkMapByPlabName(self,objtype,objid):
        qres = DBQueryFatal("select elab_id from plab_objmap" \
                            " where objtype=%s and plab_name=%s",
                            (objtype,str(objid)))
        if len(qres) != 1:
            return (None,)

        return qres[0]

    def getPlabName(self,objtype,id):
        (id,name) = self.__checkMapByElabId(objtype,id)
        return name


    def getPlabId(self,objtype,id):
        (id,name) = self.__checkMapByElabId(objtype,id)
        return id

    def syncObject(self,objtype,objid):
        if not objtype in self.__allowed_objects:
            raise RuntimeError("unknown object type '%s'" % objtype)

        ss = self.plc.agent.syncSupport()
        if not ss or not objtype in ss:
            raise RuntimeError("plc agent '%s' does not support object '%s'" \
                               " sync!" % (self.plc.agent.__class__.__name__,
                                           objtype))

        if objtype == 'project':
            pd = self.__translateProject(objid)
            if debug:
                print "Translated pid '%s' to '%s'" % (objid,str(pd))
            retval = self.plc.agent.syncObject(objtype,pd)
            plab_name = pd['name']
        elif objtype == 'user':
            pd = self.__translateUser(objid)
            if debug:
                print "Translated user '%s' to '%s'" % (objid,str(pd))
            # note, we have to sync up sites (to ensure they're added!)
            for pid in pd['__emulab_pids']:
                self.syncObject('project',pid)
                pass
            del pd['__emulab_pids']
            retval = self.plc.agent.syncObject(objtype,pd)
            plab_name = pd['email']
        elif objtype == 'node':
            pd = self.__translateNode(objid)
            if debug:
                print "Translated node '%s' to '%s'" % (objid,str(pd))
            # note, we have to sync up sites (to ensure they're added!)
            for pid in pd['__emulab_pids']:
                self.syncObject('project',pid)
                pass
            del pd['__emulab_pids']
            retval = self.plc.agent.syncObject(objtype,pd)
            plab_name = pd['hostname']
            pass

        # update the objmap, just in case this is a new addition at plc
        try:
            DBQueryFatal("replace into plab_objmap" \
                         " (plc_idx,objtype,elab_id,plab_id,plab_name)" \
                         " values (%s,%s,%s,%s,%s)",
                         (self.plc.idx,objtype,objid,str(retval),plab_name))
        except Exception, ex:
            msg = "cleanup: object %s/%s synch at plc %s succeeded," \
                  " but objmap update failed: %s" \
                  % (objtype,str(objid),self.plc.name,str(ex))
            raise RuntimeError(msg)

        return

    def deleteObject(self,objtype,objid):
        if not objtype in self.__allowed_objects:
            raise RuntimeError("unknown object type '%s'" % objtype)

        ss = self.plc.agent.syncSupport()
        if not ss or not objtype in ss:
            raise RuntimeError("plc agent '%s' does not support object '%s'" \
                               " delete!" % (self.plc.agent.__class__.__name__,
                                             objtype))

        plab_id,plab_name = self.__checkMapByElabId(objtype,objid)

        if not plab_id:
            raise RuntimeError("could not find Emulab '%s' object '%s'" \
                               % (objtype,str(objid)))

        self.plc.agent.deleteObject(objtype,plab_id)

        # update the map:
        try:
            DBQueryFatal("delete from plab_objmap" \
                         " where plc_idx=%s and objtype=%s and elab_id=%s",
                         (self.plc.idx,objtype,objid))
        except Exception, ex:
            msg = "cleanup: object %s/%s delete at plc %s succeeded," \
                  " but objmap delete failed: %s" \
                  % (objtype,str(objid),self.plc.name,str(ex))
            raise RuntimeError(msg)

        return

    def manageObject(self,objtype,objid,op,opargs=[]):
        if not objtype in self.__allowed_objects:
            raise RuntimeError("unknown object type '%s'" % objtype)

        if not objtype in self.__mgmtOperations \
           and not op in self.__mgmtOperations[objtype]:
            raise RuntimeError("unknown management operation %s/%s" \
                               % (objtype,op))

        ss = self.plc.agent.syncSupport()
        if not ss or not objtype in ss:
            raise RuntimeError("plc agent '%s' does not support object '%s'" \
                               " delete!" % (self.plc.agent.__class__.__name__,
                                             objtype))

        plab_id,plab_name = self.__checkMapByElabId(objtype,objid)

        self.plc.agent.manageObject(objtype,plab_id,op,opargs)
        return

    # XXX This translation stuff ought to be split, with libplab getting the
    # data from the Emulab db, then passing it to the PLCagent to translate...
    # but unnecessary for now!
    def __translateProject(self,pid):
        """
        Returns a planetlab site object.
        """
        qres = DBQueryFatal("select pid_idx,name,URL from projects" \
                            " where pid=%s",(pid,))
        if len(qres) != 1:
            raise RuntimeError("could not find Emulab project '%s'" % pid)
        (pid_idx,pid_name,url) = qres[0]
        
        retval = dict({})

        plab_id,plab_name = self.__checkMapByElabId('project',pid)
        
        if plab_id and plab_name:
            retval['id'] = plab_id
            retval['name'] = plab_name
            pass
        else:
            retval['name'] = pid.lower().replace("-","")
            (tid,) = self.__checkMapByPlabName('project',retval['name'])
            tname = retval['name']

            append_digit = 0
            while tid != None:
                tname = "%s%d" % (retval['name'],append_digit)
                (tid) = self.__checkMapByPlabName('project',tname)
                append_digit += 1
                pass

            # ok, we have a unique name either way
            retval['name'] = tname
            pass

        retval['longitude'] = 0.1
        retval['latitude'] = 0.1
        retval['url'] = url

        return retval

    def __translateNode(self,nodeid):
        """
        Returns a planetlab node object (expressed as a dict of node
        properties).
        """
        retval = dict({})
        plab_id,plab_name = self.__checkMapByElabId('node',nodeid)
        if plab_id:
            retval['id'] = plab_id
            pass

        # XXX will eventually need more than just one public interface, but
        # this will do the trick for now...
        qres = DBQueryFatal("select wa.hostname,wa.bwlimit,wa.IP," \
                            "  i.mask,i.mac,wa.boot_method,wa.gateway,wa.dns" \
                            " from widearea_nodeinfo as wa" \
                            " left join interfaces as i on wa.IP=i.IP" \
                            " where wa.node_id=%s and i.node_id=%s",
                            (nodeid,nodeid))
        if len(qres) != 1:
            raise RuntimeError("could not find Emulab node '%s'" % nodeid)

        #
        # XXX: assume ipv4 for now
        #
        (hostname,bwlimit,IP,netmask,mac,boot_method,gateway,dns) = qres[0]

        # ensure boot_method is something sane.
        if not boot_method or boot_method == '':
            boot_method = 'dhcp'
            pass

        if not dns or dns == '':
            raise RuntimeError("translateNode: must set WA DNS!")

        # netmask must be set!
        if not netmask or netmask == '':
            raise RuntimeError("translateNode: ctrl netmask must be set!")
        elif dns.find(','):
            # allow multiple dns servers
            dns = dns.split(',')
            pass

        if mac == '':
            mac = None
            pass
        else:
            # translate from string sans colons
            mac = mac[0:2] + ":" + mac[2:4] + ":" + mac[4:6] + ":" + \
                  mac[6:8] + ":" + mac[8:10] + ":" + mac[10:12]
            pass

        sip = IP.split('.')
        smask = netmask.split('.')

        if not len(sip) == 4:
            raise RuntimeError("translateNode: improper WA IP!")
        else:
            sip = map(lambda(x): int(x),sip)
            pass
        if not len(smask) == 4:
            raise RuntimeError("translateNode: improper WA netmask!")
        else:
            smask = map(lambda(x): int(x),smask)
            pass

        n_network = "%s.%s.%s.%s" % (sip[0] & smask[0],sip[1] & smask[1],
                                     sip[2] & smask[2],sip[3] & smask[3])
        # keep the network bits but set host bits to 1s
        n_bcast = "%s.%s.%s.%s" % ((sip[0] & smask[0]) | (~smask[0] & 0xff),
                                   (sip[1] & smask[1]) | (~smask[1] & 0xff),
                                   (sip[2] & smask[2]) | (~smask[2] & 0xff),
                                   (sip[3] & smask[3]) | (~smask[3] & 0xff),)

        if bwlimit == '':
            bwlimit = None
            pass

        retval['hostname'] = hostname
        ctrl_network = { 'ip':IP,'bwlimit':bwlimit,'method':boot_method,
                         'network':n_network,'netmask':netmask,
                         'type':'ipv4','is_primary':True }
        # set the gateway and bcast addr if we're static:
        if boot_method == 'static':
            if not gateway or gateway == "":
                raise RuntimeError("translateNode: must set gateway when" \
                                   " boot_method=static!")
            else:
                ctrl_network['gateway'] = gateway
                ctrl_network['broadcast'] = n_bcast
                pass
            pass
        # setup dns
        if type(dns) == list:
            ctrl_network['dns1'] = dns[0]
            if len(dns) > 1:
                ctrl_network['dns2'] = dns[1]
                pass
            pass
        else:
            ctrl_network['dns1'] = dns
            pass
        # add mac if we have it (which we always do!)
        if mac:
            ctrl_network['mac'] = mac
            pass
        retval['networks'] = [ ctrl_network ]
        # put all nodes in the emulabops site
        retval['__emulab_pids'] = ['emulab-ops']
        retval['site'] = self.__translateProject('emulab-ops')['name']

        return retval

    def __translateUser(self,uid):
        """
        Returns a planetlab user object (expressed as a dict of user
        properties).
        """
        retval = dict({})
        plab_id,plab_name = self.__checkMapByElabId('user',uid)
        if plab_id:
            retval['id'] = plab_id
            pass
        
        # grab basic user details
        if uid.find("@") > -1:
            wherestr = "where u.usr_email=%s and u.status='active'"
        else:
            wherestr = "where u.uid=%s and u.status='active'"
            pass
        qres = DBQueryFatal("select u.uid,u.usr_name,u.usr_email,u.usr_URL," \
                            "  u.usr_phone,u.usr_pswd,admin" \
                            " from users as u %s" % (wherestr,),(uid,))
        if len(qres) != 1:
            raise RuntimeError("could not find user '%s'%" % uid)

        (uid,retval['name'],retval['email'],retval['url'],retval['phone'],
         retval['passwd'],admin) = qres[0]
        # for whatever reason, elabman isn't marked as admin, so special-case
        if uid == 'elabman':
            admin = 1
            pass

        # now find keys
        qres = DBQueryFatal("select pubkey from user_pubkeys where uid=%s",
                            (uid,))
        keys = []
        for row in qres:
            keys.append(row[0])
            pass
        retval['keys'] = keys

        # now determine permissions
        # NOTE: we map project_root,group_root->PI,local_root,user->user
        #   (and if the admin bit was set above, we set that role too)
        # This sucks since plab permissions are not per-site!
        qres = DBQueryFatal("select gm.pid,gm.trust"
                            " from users as u"
                            " left join group_membership as gm"
                            "   on u.uid_idx=gm.uid_idx"
                            " left join projects as p on gm.pid=p.pid"
                            " where u.uid=%s and u.status='active'"
                            "       and gm.gid=gm.pid",(uid,))
        roles = []
        pids = []
        max_trust = None
        for (pid,trust) in qres:
            if trust == "project_root" or trust == "group_root":
                max_trust = "pi"
            elif not max_trust == "pi" and (trust == "local_root"
                                            or trust == "user"):
                ptrust = "user"
            elif trust == "none":
                continue
            pids.append(pid)
            pass
        if max_trust == "pi":
            roles = ['pi','user']
        elif max_trust == "user":
            roles = ['user']
            pass
        if admin:
            roles.append('admin')
            roles.append('tech')
            pass
        retval['roles'] = roles

        # now site membership:
        # (we keep the emulab pids around so that if we synch on this object,
        #  we can synch the pids too so that they get created if they're not
        #  already)
        retval['__emulab_pids'] = pids
        retval['sites'] = []
        for pid in pids:
            retval['sites'].append(self.__translateProject(pid)['name'])
            pass

        return retval

    pass

class Slice:
    """
    This is a barebones slice class that knows just enough to talk to a PLC
    and do some basic operations on slices.  There are public member
    functions for each common operation, as well as private member functions
    which just call out to PLC via xmlrpc.  If you need to do more than just
    make the xmlrpc calls, you can extend the class and override the
    higher-level public functions with extra goop.
    """
    
    def __init__(self,plc,slicename,
                 slicedescr=DEF_SLICE_DESC,sliceurl=DEF_EMULAB_URL,
                 userlist=[],nodelist=[],instmethod=None):
        self.plc = plc
        self.slicename = slicename
        self.description = slicedescr
        self.sliceurl = sliceurl
        self.instmethod = instmethod
        self.userlist = userlist
        self.nodelist = nodelist

        # Rules for arguments.
        if plc == None:
            raise RuntimeError, "Must provide plc!"
        if slicename == None:
            raise RuntimeError, "Must provide slicename!"
        
        pass

    def create(self):
        print "(Directly) Creating slice %s at %s." % (self.slicename,
                                                       self.plc.name)
        self._create()
        return self._configure()

    def _create(self):
        try:
            res, self.slicemeta, self.leaseend = \
                 self.plc.agent.createSlice(self)

            #
            # Support for "compat" agents during PLC transition times.
            # We don't bother saving any of these tickets at this point.
            # The only point is to duplicate the state at the extra PLCs.
            #
            for extra_agent in self.plc.extra_agents:
                try:
                    extra_agent.createSlice(self)
                except:
                    print "Warning: extra agent failed in createSlice; " \
                          "\n  watch for inconsistent DB state!"
                    pass
                pass
            pass
        except:
            print "slice create(slice %s): exception\n%s" \
                  % (self.slicename,traceback.format_exc())
            
            self.plc.agent.deleteSlice(self)
            
            for extra_agent in self.plc.extra_agents:
                try:
                    extra_agent.deleteSlice(self)
                except:
                    print "Warning: extra agent failed in createSlice; " \
                          "\n  watch for inconsistent DB state!"
                    pass
                pass
            raise
        return

    def configure(self):
        print "(Directly) Configuring slice %s at %s." % (self.slicename,
                                                          self.plc.name)
        return self._configure()

    def _configure(self):
        try:
            res, self.slicemeta, self.leaseend = \
                 self.plc.agent.configureSlice(self)

            #
            # Support for "compat" agents during PLC transition times.
            # We don't bother saving any of these tickets at this point.
            # The only point is to duplicate the state at the extra PLCs.
            #
            for extra_agent in self.plc.extra_agents:
                try:
                    extra_agent.configureSlice(self)
                except:
                    print "Warning: extra agent failed in configureSlice; " \
                          "\n  watch for inconsistent DB state!"
                    pass
                pass
            pass
        except:
            print "slice configure(slice %s): exception\n%s" \
                  % (self.slicename,traceback.format_exc())
            raise
        return

    def load(self):
        print "(Directly) Loading slice info for %s at %s." % (self.slicename,
                                                               self.plc.name)
        return self._load()

    def _load(self):
        """
        Loads sliceinfo from PLC.
        """
        self.plc.agent.loadSliceInfo(self)
        pass

    def destroy(self):
        print "(Directly) Destroying slice %s at %s." % (self.slicename,
                                                         self.plc.name)
        self._destroy()
        pass

    def _destroy(self):
        try:
            self.plc.agent.deleteSlice(self)
            pass
        except:
            print "Failed to delete slice %s at %s!" % (self.slicename,
                                                        self.plc.idx)
            traceback.print_exc()
            pass

        for extra_agent in self.plc.extra_agents:
            try:
                extra_agent.deleteSlice(self)
            except:
                print "Warning: extra agent failed in deleteSlice; " \
                      "\n  watch for inconsistent DB state!"
                pass
            pass
        pass

    def renew(self, force=False, renewSlice=True, renewNodes=True):
        retval = 0
        if renewSlice:
            print "(Directly) Renewing lease for slice %s at %s." % \
                  (self.slicename,self.plc.name)
            retval = self._renew(force=force)
            pass

        # only renew if we got a new ticket!
        if retval == 0 and renewNodes:
            print "Renewing lease for slice nodes in %s at %s." \
                  % (self.slicename,self.plc.name)
            retval = self._renewNodes()
            pass

        return retval

    def _renew(self,force=False):
        ret = self.plc.agent.renewSlice(self, force)
        
        for extra_agent in self.plc.extra_agents:
            try:
                extra_agent.renewSlice(self)
            except:
                print "Warning: extra agent failed in renewSlice; " \
                      "\n  watch for inconsistent DB state!"
                pass
            pass
        return ret

    def _renewNodes(self):
        # Renew individual slivers, if necessary.  Any that fail to renew
        # and are close to expiration need to be noted.  They will be
        # reported after renewal has been attempted on all nodes.
        now = int(time.time())
        nodes = map(lambda x: x[0], self.getSliceNodes())
        reportfailed = []
        for nodeid in nodes:
            try:
                node = self.loadNode(nodeid)
                pass
            except AssertionError:
                print "Node %s doesn't really exist in %s (%s)" % \
                      (nodeid, self.slicename, self.plc.name)
                continue
            except:
                print "Unknown error loading node %s from slice %s (%s)" % \
                      (nodeid, self.slicename, self.plc.name)
                traceback.print_exc()
                continue
            if node.renew():
                print "Failed to renew node: %s (expires %s UTC)" % \
                      (nodeid, time.asctime(time.gmtime(node.leaseend)))
                print "Timediff: %s" % (node.leaseend - now)
                if node.leaseend - now < NODEEXPIREWARN:
                    reportfailed.append((nodeid, node.leaseend))
                    pass
                pass
            del node
            pass

        return reportfailed

    def createNode(self, nodeid, force=False):
        """
        Node factory function
        """
        node = Node(self, nodeid, usedb=False)
        node._create(force)
        return node

    def loadNode(self, nodeid):
        """
        Node factory function
        """
        node = Node(self, nodeid, usedb=False)
        node._load()
        return node

    def _updateSliceMeta(self):
        """
        Grab current slice metadata from Planetlab.
        """
        self.slicemeta = self.plc.agent.getSliceMeta(self)
        return self.slicemeta

    def updateSliceMeta(self):
        return self._updateSliceMeta()

    def getSliceNodes(self):
        """
        Return a tuple containing the nodes that belong to this slice
        """
        retval = []
        for n in self.nodelist:
            nn = Node(self,n,usedb=False)
            # Grab the IP and hostname
            retval.append([n,nn.IP,nn.hostname])
            pass
        return retval

    def getSliceNodeObjects(self):
        """
        Return a tuple containing node objects for nodes in this slice
        """
        retval = []
        for n in self.nodelist:
            nn = Node(self,n)
            # Grab the IP and hostname
            retval.append(nn)
            pass
        return retval

    def getSliceUsers(self):
        return self.userlist

    pass


#
# Emulab-specific operations and database use.
#
class EmulabSlice(Slice):
    """
    Emulab extensions to the basic slice object.  Mostly allows us to use
    the Emulab db as a cache for slice/sliver information, and to do other
    other Emulab-y things.
    """

    def __init__(self,plc,slicename,pid,eid):
        # holds the agent
        self.plc = plc
        self.slicename = slicename
        # Emulab pid/eid
        self.pid, self.eid = pid, eid
        # Emulab exptidx: loaded later.
        self.exptidx = None

        # Stuff we need to grab from the db:
        self.description = None
        self.sliceurl = DEF_EMULAB_URL
        self.instmethod = None
        self.userlist = None
        self.nodelist = None
        # Ticket for NM
        self.slicemeta = None
        # lease timeout
        self.leaseend = time.gmtime(time.time())

        # Rules for arguments.
        if plc == None:
            raise RuntimeError, "Must provide plc!"
        if slicename == None:
            raise RuntimeError, "Must provide slicename!"

        (self.is_created,self.is_configured,
         self.no_cleanup,self.no_destroy) = (0,0,0,0)

        return

    def _loadSliceStatusBits(self):
        # Don't fail if the slice isn't in the plab_slices table yet
        res = DBQueryFatal("select is_created,is_configured,"
                           "  no_cleanup,no_destroy"
                           " from plab_slices"
                           " where slicename=%s and plc_idx=%s",
                           (self.slicename,self.plc.idx))
        if len(res) == 1:
            (self.is_created,self.is_configured,
             self.no_cleanup,self.no_destroy) = res[0]
            pass
        pass

    def _saveSliceStatusBits(self):
        res = DBQueryFatal("update plab_slices set"
                           "  is_created=%s,is_configured=%s,"
                           "  no_cleanup=%s,no_destroy=%s"
                           " where slicename=%s and plc_idx=%s",
                           (self.is_created,self.is_configured,
                            self.no_cleanup,self.no_destroy,
                            self.slicename,self.plc.idx))
        pass
            
    def _preload(self):
        """
        Load bits, various other things, from db.
        """
        self.adminbit = 0
        if self.pid == PLABMON_PID and self.eid == PLABMON_EID:
            self.description = PLAB_SVC_SLICEDESC
            self.adminbit = 1
            pass

        # grab exptidx
        res = DBQueryFatal("select idx, expt_name from experiments "
                           " where pid=%s and eid=%s",
                           (self.pid, self.eid))
        if not len(res):
            raise RuntimeError, \
                  "Didn't get any results while looking up info on " \
                  "experiment %s/%s" % (self.pid, self.eid)
        (eindex,descr) = res[0]
        
        self.description = descr
        self.exptidx = eindex

        pass

    def create(self):
        """
        Creates a new slice that initially contains no nodes.  Don't call
        this directly, use a Plab factory function instead.
        This method uses bits in the plab_slices table to decide if it should
        really create the slice, or just configure it and its nodes.
        """
        print "Creating slice %s at %s." % (self.slicename,self.plc.name)
        self._preload()
        # If the slice is already in the plab_slices table, get info
        # about what we should/shouldn't do when setting it up.
        self._loadSliceStatusBits()

        # only do the create if the slice hasn't been created
        if not self.is_created:
            self._create()
            
            try:
                insertFieldsStr = "(exptidx,pid,eid,slicename,slicemeta," \
                                  "leaseend,admin,plc_idx)"
                insertValuesStr = "(%s, %s, %s, %s, %s, %s, %s, %s)"
                insertValuesTuple = (self.exptidx,self.pid,self.eid,
                                     self.slicename,self.slicemeta,
                                     time.strftime("%Y-%m-%d %H:%M:%S",
                                                   time.gmtime(self.leaseend)),
                                     self.adminbit,self.plc.idx)
                qstr = "replace into plab_slices " + insertFieldsStr + \
                       " values " + insertValuesStr
                #if debug:
                #    print "plab_slices insert: %s %s" % (str(qstr),
                #                                         str(insertValuesTuple))
                #    pass
                DBQueryFatal(qstr,insertValuesTuple)

                self.is_created = 1
                self._saveSliceStatusBits()
                pass
            except:
                self._destroy()
                DBQueryFatal("delete from plab_slices"
                             "  where slicename=%s and plc_idx=%s",
                             (self.slicename,self.plc.idx))
                raise
            pass
        else:
            print "  Not doing create for slice %s at %s (already exists)." % \
                  (self.slicename,self.plc.name)
            pass

        # now do the configure
        if not self.is_configured:
            self._configure()

            try:
                insertFieldsStr = "(exptidx,pid,eid,slicename,slicemeta," \
                                  "leaseend,plc_idx)"
                insertValuesStr = "(%s, %s, %s, %s, %s, %s, %s)"
                insertValuesTuple = (self.exptidx,self.pid,self.eid,
                                     self.slicename,self.slicemeta,
                                     time.strftime("%Y-%m-%d %H:%M:%S",
                                                   time.gmtime(self.leaseend)),
                                     self.plc.idx)
                qstr = "replace into plab_slices " + insertFieldsStr + \
                       " values " + insertValuesStr
                DBQueryFatal(qstr,insertValuesTuple)
                pass
            except:
                print "warning: failure while updating ticket for %s at %s" \
                      % (self.slicename,self.plc.name)
                pass

            # save bits regardless of possible db failure
            self.is_configured = 1
            self._saveSliceStatusBits()
            
            pass
        else:
            print "  Not doing configure for slice %s at %s " \
                  "(already configured)." % (self.slicename,self.plc.name)
            pass

        # Setup mailing alias for the slice.  All mail currently filters
        # in via the 'emulabman' alias.  A procmail filter there will
        # redirect it to the appropriate user.
        try:
            qres = DBQueryFatal("select u.uid, u.usr_email from users as u "
                                "left join experiments as e "
                                "on u.uid_idx = e.swapper_idx "
                                "where e.pid=%s and e.eid=%s",
                                (self.pid, self.eid))
            if not len(qres):
                raise RuntimeError, \
                      "Didn't get any results while looking up user info" \
                      " for experiment %s/%s" % (self.pid, self.eid)
            (username, usremail) = qres[0]
            command = "%s -host %s /bin/echo %s \> %s/%s" % \
                      (SSH, USERNODE, usremail,
                       SLICE_ALIAS_DIR, self.slicename)
            os.system(command)
        except:
            print "Could not setup email alias for slice %s at %s!" \
                  % (self.slicename,self.plc.name)
            traceback.print_exc()
            pass
        
        return

    def load(self):
        """
        Loads an already allocated slice from the DB.  Don't call this
        directly, use a Plab factory function instead.

        XXX This should probably be made lazy, since not all operations
        really need it
        """
        if verbose:
            print "Loading slice %s at %s." % (self.slicename,self.plc.name)
            pass
        
        self._preload()
        self._loadSliceStatusBits()

        res = DBQueryFatal("select slicemeta,leaseend "
                           " from plab_slices "
                           " where pid=%s and eid=%s and slicename=%s"
                           "  and plc_idx=%s",
                           (self.pid,self.eid,self.slicename,self.plc.idx))
        
        assert (len(res) > 0), \
               "Did not find slice %s (%s) for %s/%s" % (self.slicename,
                                                         self.plc.name,
                                                         self.pid,self.eid)
        assert (len(res) == 1), \
               "Multiple entries found for slice %s (%s) for %s/%s" % \
               (self.slicename,self.plc.name,self.pid,self.eid)
        ((self.slicemeta,leaseend),) = res
        try:
            self.leaseend = calendar.timegm(time.strptime(str(leaseend),
                                                          "%Y-%m-%d %H:%M:%S"))
        except:
            self.leaseend = 0
            print "Warning: could not load leaseend time from db for" \
                  " slice %s (%s) for %s/%s" % (self.slicename,self.plc.name,
                                                self.pid,self.eid)
            pass
        return

    def renew(self, force = False, renewSlice=True, renewNodes=True):
        """
        Renews slice lease.  We want this to be the maximum allowed by law...
        Store the expiration time in UTC.
        """
        retval = 0
        if renewSlice:
            print "Renewing lease for slice %s at %s" % (self.slicename,
                                                         self.plc.name)
            retval = self._renew(force=force)
        
            DBQueryFatal("update plab_slices "
                         "set slicemeta=%s,leaseend=%s"
                         " where slicename=%s and plc_idx=%s",
                         (self.slicemeta,
                          time.strftime("%Y-%m-%d %H:%M:%S",
                                        time.gmtime(self.leaseend)),
                          self.slicename,self.plc.idx))
            pass

        # only renew nodes if we got a new ticket
        if retval == 0 and renewNodes:
            print "Renewing lease for slice nodes in %s at %s" \
                  % (self.slicename,self.plc.name)
            reportfailed = self._renewNodes()

            # Report any nodes that are near to expiration
            if len(reportfailed) > 0:
                tbstr = ""
                for nodeid, leaseend in reportfailed:
                    tbstr += "Node: %s, Leaseend: %s UTC\n" % \
                             (nodeid, time.asctime(time.gmtime(leaseend)))
                    pass
                SENDMAIL(TBOPS, "Plab nodes in danger of expiration: %s/%s" % \
                         (self.pid, self.eid),
                         "The following slivers in %s/%s will expire "
                         "soon:\n\n%s" % \
                         (self.pid, self.eid, tbstr),
                         TBOPS)
            pass
        
        return retval

    def destroy(self):
        """
        Frees all nodes in this slice and destroys the slice.  Note
        that this will really pound the DB if there are many nodes left
        in the slice, but those should be removed by Emulab before the
        slice is destroyed.
        """
        print "Destroying slice %s at %s." % (self.slicename,self.plc.name)
        if not self.no_cleanup:
            nodeidlist = []
            res = DBQueryFatal("select node_id from plab_slice_nodes"
                               " where slicename=%s and plc_idx=%s",
                               (self.slicename,self.plc.idx))
            for (nodeid,) in res:
                nodeidlist.append(nodeid)
                pass
            
            print "\tRemoving any remaining nodes in slice..."
            for nid in nodeidlist:
                node = self.loadNode(nid)
                node.free()
                del node  # Encourage the GC'er
                pass

            # mark as unconfigured...
            self.is_configured = 0
            self._saveSliceStatusBits()
            pass
        else:
            print "  Not cleaning up nodes in slice %s at %s." % \
                  (self.slicename,self.plc.name)
            pass


        osigs = disable_sigs(TERMSIGS)
        
        if not self.no_destroy:
            self._destroy()

            try:
                print "\tRemoving slice DB entry."
                DBQueryFatal("delete from plab_slices where slicename = %s",
                             (self.slicename,))
            except:
                print "Error deleting slice from DB!"
                tbstr = "".join(traceback.format_exception(*sys.exc_info()))
                SENDMAIL(TBOPS, "Error deleting slice from DB",
                         "Slice deletion error:\n\n%s" % tbstr, TBOPS)
                enable_sigs(osigs)
                raise
            # mark as unconfigured and uncreated
            # XXX: this means that setting the is_configured bit at swapin
            # is useless if the slice is destroyed later.
            self.is_created = 0
            self.is_configured = 0
            self._saveSliceStatusBits()
            pass
        else:
            print "  Not destroying slice %s at %s." % \
                  (self.slicename,self.plc.name)
            pass

        # remove mail aliases
        try:
            command = "%s -host %s /bin/rm -f %s/%s" % \
                      (SSH, USERNODE, SLICE_ALIAS_DIR, self.slicename)
            os.system(command)
        except:
            print "Could not remove email alias for slice: %s!" % \
                  self.slicename
            traceback.print_exc()
            pass
    
        enable_sigs(osigs)
        pass

    def createNode(self, nodeid, force=False):
        """
        Node factory function
        """
        node = Node(self, nodeid)
        node._create(force)
        return node

    def loadNode(self, nodeid):
        """
        Node factory function
        """
        node = Node(self, nodeid)
        node._load()
        return node

    def updateSliceMeta(self):
        """
        Grab current slice metadata from Planetlab and store in db.
        """
        try:
            self._updateSliceMeta()
            DBQueryFatal("update plab_slices set slicemeta=%s"
                         " where slicename=%s and plc_idx=%s",
                         (self.slicemeta,self.slicename,self.plc.idx))
            pass
        except:
            print "Error updating slice metadata!"
            #traceback.print_exc()
            #tbstr = "".join(traceback.format_exception(*sys.exc_info()))
            #SENDMAIL(TBOPS, "Error updating slice metadata",
            #         "Slice metadata update error:\n\n%s" % tbstr, TBOPS)
            raise
        return self.slicemeta

    def getSliceNodes(self):
        # Grab set of plab nodes belonging to expt and their IPs:
        res = DBQueryFatal("select r.node_id, i.IP, w.hostname "
                           " from reserved as r "
                           " left join nodes as n1 "
                           "  on r.node_id = n1.node_id "
                           " left join nodes as n2 "
                           "  on n1.phys_nodeid = n2.node_id "
                                " left join widearea_nodeinfo as w "
                           "  on n2.node_id = w.node_id "
                           " left join interfaces as i "
                           "  on w.node_id = i.node_id "
                           " where r.pid=%s and r.eid=%s "
                           " and n1.type=%s and i.role=%s",
                           (self.pid,self.eid,self.plc.nodetype,"ctrl"))
        if not res or not len(res):
            res = []
            pass

        return res

    pass  # end of class Slice
# AOP wrappers for class Slice
wrap_around(Slice._create, timeAdvice)
wrap_around(Slice.destroy, timeAdvice)

# Helper regexps used in the Node class
VNODE_REG = re.compile("^[\w\d]+vm(\d+)\-(\d+)$")
PNODE_REG = re.compile("^plab(\d+)$")
IP_REG = re.compile("^(\d+)\.(\d+)\.(\d+)\.(\d+)$")
HOSTNAME_REG = re.compile("^([\d\w\-\.]+)$")

#
# Node abstraction
#
class Node:
    #
    # Note: you can now pass in an Emulab vnode or pnode, or a hostname or
    # IP address.
    # Also, note that passing in a pnode or hostname/IP forces usedb = False,
    # since most Emulab db entries depend on the vnodeid at this level.
    #
    def __init__(self, slice, nodeid, usedb = True, pollNode = False):
        self.usedb = usedb
        self.slice = slice
        self.nodeid = nodeid

        # Figure out what kind of nodeid we were given (how we do lookups
        # depends on it):
        if not self.usedb:
            if VNODE_REG.match(nodeid) != None:
                self.nidtype = 'v'
                pass
            elif IP_REG.match(nodeid) != None:
                self.nidtype = 'i'
                pass
            elif HOSTNAME_REG.match(nodeid) != None:
                self.nidtype = 'h'
                pass
            else:
                raise RuntimeError, "nodeid must be an Emulab vnode, " \
                      " a hostname, or IP address!"
            pass
        else:
            self.nidtype = 'v'
            pass
        
        (self.IP,self.hostname,self.phys_nodeid) = self.__findHostInfo()
        
        self.leaseend = 0
        self.nodemeta = None
        self.pollNode = pollNode
        # must be set in mod_<PLCAGENT>.createNode if you want to use
        # multiple rootball and triggering support
        self.nmagent = None

        self.nodegroups = []

        return

    def __logNodeHist(self,component,operation,status,msg):
        try:
            DBQueryFatal("insert into plab_nodehist values "
                         "(NULL,%s,%s,%s,%s,%s,%s,%s)",
                         (self.nodeid,self.phys_nodeid,
                          time.strftime("%Y-%m-%d %H:%M:%S",
                                        time.localtime(time.time())),
                          component,operation,status,str(msg)))
        except:
            # do nothing
            print "Warning: could not log (%s,%s,%s,%s) into plab_nodehist!" % \
                  (component,operation,status,msg)
            pass
        pass

    def __gcNode(self,add_remove):
        if add_remove:
            # add
            now = time.strftime("%Y-%m-%d %H:%M:%S",
                                time.localtime(time.time()))
            q = "replace into plab_sliver_garbage (pid,eid,exptidx," \
                "  slicename,node_id,phys_node_id,ctime,mtime)"\
                " values (%s,%s,%s,%s,%s,%s,%s,%s)"
            DBQueryWarn(q,(self.slice.pid,self.slice.eid,self.slice.exptidx,
                           self.slice.slicename,self.nodeid,self.phys_nodeid,
                           now,now))
        else:
            # remove, and don't worry about failed queries, since the garbage
            # collector will check for this case anyway.
            q = "delete from plab_sliver_garbage" \
                " where pid=%s and eid=%s and slicename=%s and node_id=%s"
            DBQuery(q,(self.slice.pid,self.slice.eid,self.slice.slicename,
                       self.phys_nodeid))
        
        pass

    def pingNM(self):
        isup = False
        try:
            isup = self.slice.plc.agent.pingNM(self)
        except:
            if debug:
                traceback.print_exc()
                pass
            pass
        if not isup:
            # Don't flood hist table with successful pings.
            self.__logNodeHist('node','nmping','failure','')
            pass
        return isup

    def pingNode(self,timeout=10):
        try:
            self.__execute("/bin/ping -o -t %d %s" % (timeout,self.IP))
            # Don't flood hist table with successful pings.
            return True
        except:
            pass
        self.__logNodeHist('node','ping','failure','')
        return False

    # XXX: may want to rethink signal handling here.
    def _create(self, force=False):
        """
        Creates a new node.  This physically allocates the node into the
        slice through the dslice agent and node manager.  Note that no
        node setup is performed.  Don't call this directly, use
        Slice.createNode instead.
        """

        if self.usedb:
            # First, make sure there isn't already an entry in the DB
            try:
                self._load()
            except:
                pass
            else:
                if force:
                    print "Node entry exists in DB, but creation forced anyway."
                else:
                    raise RuntimeError, "Entry for plab node %s already " \
                          "exists in the DB" % self.nodeid
                pass
            pass

        if self.usedb:
            # Note: whenever we create a plab sliver, we remove the node from
            # the plab_sliver_garbage table before even trying the create.
            # The reason for this is that even if the create never succeeds
            # in a swapin, there will be a corresponding free call for all
            # slivers that matter.
            self.__gcNode(False)
            pass

        print "Creating Plab node %s on %s." % (self.nodeid, self.IP)
        res = None
        try:
            res, self.nodemeta, self.leaseend = \
                 self.slice.plc.agent.createNode(self)
            if self.usedb:
                self.__logNodeHist('node','create','success','')
                pass
        except:
            if self.usedb:
                self.__logNodeHist('node','create','failure',
                                   traceback.format_exception(*sys.exc_info()))
                pass
            raise

        if self.usedb:
            DBQueryFatal("replace into plab_slice_nodes"
                         " (slicename, plc_idx, node_id,"
                         " nodemeta, leaseend)"
                         " values (%s, %s, %s, %s, %s)",
                         (self.slice.slicename, self.slice.plc.idx,
                          self.nodeid, self.nodemeta,
                          time.strftime("%Y-%m-%d %H:%M:%S",
                                        time.gmtime(self.leaseend))))
            pass

        # grab which nodegroups we're in:
        qres = DBQueryFatal("select nodegroup_idx"
                            " from plab_nodegroup_members"
                            " where node_id=%s",(self.phys_nodeid,))
        for (ngid,) in qres:
            if not ngid in self.nodegroups:
                self.nodegroups.append(ngid)
                pass
            pass
        
        if self.pollNode:
            TIMESTAMP("Waiting for %s to respond" % self.nodeid)
            while True:
                try:
                    self.__perform("/bin/true")
                    pass
                except:
                    time.sleep(NODEPROBEINT)
                    pass
                else: break
                pass
            TIMESTAMP("Node %s ready." % self.nodeid)
            pass        

        TIMESTAMP("createnode finished on %s." % self.nodeid)
        return
    
    def _load(self):
        """
        Loads an already allocated node from the DB.  Don't call this
        directly, use Slice.loadNode instead.
        """
        if not self.usedb:
            return
        
        if verbose:
            print "Loading node %s" % self.nodeid
        res = DBQueryFatal("select slicename, nodemeta, leaseend "
                           " from plab_slice_nodes where node_id = %s",
                           (self.nodeid))
        assert (len(res) > 0), \
               "Node %s (slice %s) not found" % \
               (self.nodeid, self.slice.slicename)
        assert (len(res) == 1), \
               "Multiple nodes found for nodeid %s" % self.nodeid
        ((slicename, self.nodemeta, leaseend), ) = res
        assert (slicename == self.slice.slicename), \
               "Node %s loaded by slice %s, but claims to be in slice %s" % \
               (self.nodeid, self.slice.slicename, slicename)
        if not leaseend:
            self.leaseend = 0
            pass
        else:
            self.leaseend = calendar.timegm(time.strptime(str(leaseend),
                                                          "%Y-%m-%d %H:%M:%S"))
            pass

        # finally, grab which nodegroups we're in:
        qres = DBQueryFatal("select nodegroup_idx"
                            " from plab_nodegroup_members"
                            " where node_id=%s",(self.phys_nodeid,))
        for (ngid,) in qres:
            if not ngid in self.nodegroups:
                self.nodegroups.append(ngid)
                pass
            pass
        
        return

    def free(self):
        """
        Frees the node and kills the VM.  Note that this does not
        shutdown anything inside the vserver.  Warning: forks a process
        to carry out the actual work!
        """
        res = ForkCmd(self._free, timeout=FREE_TIMEOUT,
                      disable_sigs_parent=TERMSIGS,
                      disable_sigs_child=TERMSIGS)
        return res[0] | res[1]
        
    def _free(self):
        """
        Frees the node and kills the VM.  Note that this does not
        shutdown anything inside the vserver.  Don't call this directly;
        instead, use Node.free()
        """
        deleted = 0
        TIMESTAMP("freenode %s started." % self.nodeid)
        print "Freeing Plab node %s." % self.nodeid

        if self.usedb:
            # Remove the DB entry first.
            try:
                DBQueryFatal("delete from plab_slice_nodes where node_id = %s",
                             (self.nodeid,))
            except:
                print "Uh oh, couldn't remove plab sliver record from the DB!"
                tbstr = "".join(traceback.format_exception(*sys.exc_info()))
                SENDMAIL(TBOPS, "Error: Couldn't remove plab vnode from DB",
                         "Unable to delete entry for sliver %s from the DB:"
                         "\n\n%s" % (self.nodeid, tbstr), TBOPS)
                pass
            pass

        deleted = 0
        try:
            deleted = self.slice.plc.agent.freeNode(self)
            if self.usedb:
                # Uncomment to increase logging
                #self.__logNodeHist('node','free','success','')
                pass
        except:
            # since the free failed, we need to add this
            # node to plab_sliver_garbage
            if self.usedb:
                self.__gcNode(True)
                self.__logNodeHist('node','free','failure',
                                   traceback.format_exception(*sys.exc_info()))
                pass
            raise
        
        TIMESTAMP("freenode %s finished." % self.nodeid)
        return not deleted

    def renew(self):
        """
        Renew the lease for this node.  Note that this method
        forks and runs another private method to actually do the
        work!
        """
        res = ForkCmd(self._renew, timeout = RENEW_TIMEOUT,
                      disable_sigs_parent = TERMSIGS)
        return res[0] | res[1]

    def _renew(self):
        res = None
        try:
            res, self.nodemeta, self.leaseend = \
                 self.slice.plc.agent.renewNode(self)
            if self.usedb:
                self.__logNodeHist('node','renew','success','')
                pass
        except:
            if self.usedb:
                self.__logNodeHist('node','renew','failure',
                                   traceback.format_exception(*sys.exc_info()))
                pass
            raise

        if self.usedb:
            DBQueryFatal("update plab_slice_nodes"
                         " set nodemeta = %s, leaseend = %s"
                         " where node_id = %s",
                         (self.nodemeta,
                          time.strftime("%Y-%m-%d %H:%M:%S",
                                        time.gmtime(self.leaseend)),
                          self.nodeid))
            pass
        
        TIMESTAMP("renewnode %s finished." % self.nodeid)
        return 0

    def start(self):
        """
        Start up this node via the NM Start call (start means run the main
        vserver init script).  Note that this method forks and runs another
        private method to actually do the work!
        """
        res = ForkCmd(self._start, timeout = RENEW_TIMEOUT,
                      disable_sigs_parent = TERMSIGS)
        return res[0] | res[1]

    def _start(self):
        res = None
        try:
            res = self.slice.plc.agent.startNode(self)
            if self.usedb:
                self.__logNodeHist('node','start','success','')
                pass
        except:
            if self.usedb:
                self.__logNodeHist('node','start','failure',
                                   traceback.format_exception(*sys.exc_info()))
                pass
            raise
        
        TIMESTAMP("startnode %s finished." % self.nodeid)
        return 0

    def stop(self):
        """
        Stop this node via the NM Start call (start means kill all processes
        in the vserver).  Note that this method forks and runs another
        private method to actually do the work!
        """
        res = ForkCmd(self._stop, timeout = RENEW_TIMEOUT,
                      disable_sigs_parent = TERMSIGS)
        return res[0] | res[1]

    def _stop(self):
        res = None
        try:
            res = self.slice.plc.agent.stopNode(self)
            if self.usedb:
                self.__logNodeHist('node','stop','success','')
                pass
        except:
            if self.usedb:
                self.__logNodeHist('node','stop','failure',
                                   traceback.format_exception(*sys.exc_info()))
                pass
            raise
        
        TIMESTAMP("stopnode %s finished." % self.nodeid)
        return 0

    def restart(self):
        """
        Restarts this node via the NM Start call (restart means kill all
        processes in the vserver and run /etc/rc.vinit).  Note that this
        method forks and runs another private method to actually do the work!
        """
        res = ForkCmd(self._restart, timeout = RENEW_TIMEOUT,
                      disable_sigs_parent = TERMSIGS)
        return res[0] | res[1]

    def _restart(self):
        res = None
        try:
            res = self.slice.plc.agent.restartNode(self)
            if self.usedb:
                self.__logNodeHist('node','restart','success','')
                pass
        except:
            if self.usedb:
                self.__logNodeHist('node','restart','failure',
                                   traceback.format_exception(*sys.exc_info()))
                pass
            raise
        
        TIMESTAMP("restartnode %s finished." % self.nodeid)
        return 0

    def emulabify(self):
        """
        Performs the necessary steps to turn this node into an
        Emulab/Plab node.  Primarily, this unpacks the magic files on to
        the node.
        """

        # check if we want to skip emulabify:
        do_emulabify = self.slice.plc.getAttrVal("emulabify",
                                                 slice=self.slice,node=self)
        if do_emulabify and (do_emulabify == "no" or do_emulabify == "NO"):
            return

        # grab rootballs that need to be installed in this slice
        rootballs = self.slice.plc.getAttrVal("rootballs",slice=self.slice,
                                              node=self,required=True)
        tmp = rootballs.split(',')
        rootballs = []
        for r in tmp:
            (ball,loc) = (r,None)
            if r.find(":") >= 0:
                (ball,loc) = r.split(':')
                pass
            rootballs.append((ball,loc))
            pass

        TIMESTAMP("emulabify started on %s." % self.nodeid)
        print "Setting up root access on %s ..." % self.nodeid

        # have to set us up with root before anything else
        try:
            self.__copy(DEFAULT_DATA_PATH + "/fixsudo.sh", "/tmp/fixsudo.sh",
                        tries=1000,interval=15)
            self.__perform("-tt sh /tmp/fixsudo.sh", quiet = True,
                           tries=3,interval=5)
            pass
        except RuntimeError:
            print "fixsudo failed on %s; attempting to carry on anyway.." % \
                  self.nodeid
            pass
        try:
            self.addToGroup(self.slice.slicename, "root")
            pass
        except RuntimeError:
            print "Adding slice user to 'root' group on %s failed; " \
                  "attempting to carry on anyway." % self.nodeid
            pass

        # now upload any rootballs
        print "Uploading rootballs to %s ..." % self.nodeid
        for (rootball,unpackdir) in rootballs:
            if not unpackdir:
                unpackdir = "/"
                pass
            # handle one special case...
            if unpackdir == '$HOME':
                unpackdir = "/home/%s" % self.slice.slicename
                pass
            
            try:
                self.unpackRootball(DEFAULT_DATA_PATH, rootball,
                                    destpath=unpackdir)
                if self.usedb:
                    #self.__logNodeHist('node','emulabify','success','')
                    pass
                pass
            except:
                if self.usedb:
                    self.__logNodeHist('node','emulabify','failure',
                                       traceback.format_exception(*sys.exc_info()))
                    pass
                raise
            pass

        # now run any postsetup commands:
        print "Running commands on %s" % self.nodeid
        commands = self.slice.plc.getAttrVal("commands",slice=self.slice,
                                             node=self)
        if commands:
            commands = commands.split(',')
            pass
        else:
            commands = []
            pass
        for command in commands:
            self.__perform(command)
            pass

        TIMESTAMP("emulabify finished on %s." % self.nodeid)
        pass

    def addToGroup(self, user, group):
        if verbose:
            print "Adding %s to group %s on node %s" % \
                  (user, group, self.nodeid)
        self.__perform("sudo /usr/sbin/usermod -G %s %s" % (group, user))

    def unpackRootball(self, rbpath, rbname, destpath = "/"):
        """
        Unpacks a locally stored gzip'd tarball to the specified path
        (default /) on the remote node.  Always done as remote root.
        """
        if verbose:
            print "Unpacking rootball %s to %s on %s" % \
                  (rbpath, destpath, self.nodeid)
        try:
            if debug:
                print "Trying to grab rootball through loopback service"
            self.__perform("sudo wget -t 1 -q -nH -P /tmp " +
                           ROOTBALL_URL + rbname)
        except RuntimeError:
            print "Warning: couldn't get rootball via local service on %s: " \
                  "Falling back to remote transfer." % self.nodeid
            self.__copy(rbpath + "/" + rbname, "/tmp/" + rbname)
            pass
            
        self.__perform("sudo tar -jxf /tmp/" + rbname + " -C %s" % destpath,
                       quiet = True)
        return

    def __perform(self, command, quiet = False, tries=1, interval=5):
        """
        Executes the given command on the remote node via sshtb, run as
        the slice user.
        """
        if debug:
            print "Performing '%s' on %s" % (command, self.nodeid)
        command = "%s -host %s %s" % (SSH, self.nodeid, command)
        (success,rtries) = (False,tries)
        while not success and rtries > 0:
            rtries -= 1
            try:
                retval = self.__execute(command, quiet)
                success = True
            except:
                if rtries == 0:
                    print "Warning: perform %s on %s failed after %d tries!" \
                              % (command,self.nodeid,tries)
                    raise
                else:
                    if debug:
                        print "Warning: perform %s on %s failed, try %d of %d" \
                              % (command,self.nodeid,tries-rtries,tries)
                        pass
                    try:
                        time.sleep(interval)
                    except:
                        pass
                    pass
                pass
            pass
        return retval
    
    def __copy(self, localfile, remotefile, quiet=False, tries=1, interval=5):
        """
        Copies a file from the local system to the remote node, doing so
        as the slice user.
        """
        if debug:
            print "Copying %s to %s on %s" % \
                  (localfile, remotefile, self.nodeid)
            pass
        (success,rtries) = (False,tries)
        while not success and rtries > 0:
            rtries -= 1
            try:
                # We're using rsync now.
                command = "rsync -e '%s -host' %s %s:%s" % \
                          (SSH, localfile, self.nodeid, remotefile)
                retval = self.__execute(command)
                success = True
            except:
                if rtries == 0:
                    print "Warning: copy %s to %s on %s failed after %d tries!" \
                              % (localfile,remotefile,self.nodeid,tries)
                    raise
                else:
                    if debug:
                        print "Warning: copy %s to %s on %s failed, try %d of %d" \
                              % (localfile,remotefile,self.nodeid,
                                 tries-rtries,tries)
                        pass
                    try:
                        time.sleep(interval)
                    except:
                        pass
                    pass
                pass
            pass
        return retval
    
    def __execute(self, command, quiet = False):
        """
        Executes the given command, optionally squelching the output.
        """
        # Split up the command into a list to exec (avoid
        # intermediate shell invocation).
        cmdlist = shlex.split(command)

        # Catch termination signals and kill child if we get one.
        def catchkill(signum, frame):
            if verbose:
                print "Received signal", signum, "while running command."
                pass
            e = OSError("Received signal %s" % signum)
            e.killed = 1
            raise e
        
        sig = {}
        sig["INT"]  = signal.signal(signal.SIGINT, catchkill)
        sig["TERM"] = signal.signal(signal.SIGTERM, catchkill)
        sig["HUP"]  = signal.signal(signal.SIGHUP, catchkill)

        # Now run the command, catching it's output and handling signals.
        cmdobj = Popen4(cmdlist)
        try:
            cmdout = cmdobj.fromchild.read()
            cmdstatus = cmdobj.wait()
            signal.signal(signal.SIGINT, sig["INT"])
            signal.signal(signal.SIGTERM, sig["TERM"])
            signal.signal(signal.SIGHUP, sig["HUP"])
            if (not quiet) and cmdout:
                print cmdout
                pass
            if cmdstatus:
                raise RuntimeError, "'%s' failed (excode: %s). output:\n%s" % \
                      (command, cmdstatus, cmdout)
            pass
        except OSError, e:
            if hasattr(e,"killed") and e.killed:
                print "Received kill while running: %s" % command
                try:
                    os.kill(cmdobj.pid, signal.SIGTERM)
                    cmdobj.wait()
                    pass
                except:
                    print "Got exception while trying to kill off child proc"
                    traceback.print_exc()
                    pass
                os._exit(256)
                pass
            else:
                print "Received unhandled OSError while running command"
                traceback.print_exc()
                signal.signal(signal.SIGINT, sig["INT"])
                signal.signal(signal.SIGTERM, sig["TERM"])
                signal.signal(signal.SIGHUP, sig["HUP"])
                raise e
            pass
        
        return

    def __findIP(self):
        """
        Figures out and returns the IP of the remote node.
        """
        if self.nidtype == 'v' or self.nidtype == 'p':
            res = DBQueryFatal("select i.IP from nodes as nv"
                               " left join interfaces as i on"
                               "  nv.phys_nodeid=i.node_id"
                               " where nv.node_id=%s"
                               " limit 1",
                               (self.nodeid))
            if (not res or len(res) == 0):
                # XXX: send email
                print "Warning: no IP found for nodeid %s" % self.nodeid
                IP = "0.0.0.0"
                pass
            else:
                ((IP, ), ) = res
                pass
            pass
        else:
            IP = socket.gethostbyname(self.nodeid)
            pass
        
        if debug:
            print "IP is %s for node %s" % (IP, self.nodeid)

        return IP

    def __findHostname(self):
        """
        Grabs the publicly-routable hostname of the remote node.
        """
        if self.nidtype == 'v' or self.nidtype == 'p':
            res = DBQueryFatal("select pm.hostname,i.IP from nodes as nv"
                               " left join interfaces as i"
                               "  on nv.phys_nodeid=i.node_id"
                               " left join plab_mapping as pm"
                               "  on i.IP=pm.IP"
                               " where nv.node_id='%s'" % (self.nodeid))
            if (not res or len(res) == 0):
                print "Warning: no hostname found for nodeid %s" % self.nodeid
                hostname = None
                pass
            else:
                ((hostname,IP),) = res
                pass
            pass
        elif self.nidtype == 'i':
            hostname = socket.gethostbyaddr(self.nodeid)
            pass
        else:
            hostname = self.nodeid
            pass
        
        if verbose:
            print "hostname is %s for node %s" % (hostname,IP)
            pass
        
        return hostname

    #
    # Returns (IP,hostname,phys_nodeid).
    #
    def __findHostInfo(self):
        """
        Grabs the publicly-routable IP and hostname of the remote node,
        and also our phys_nodeid for it.
        """
        if self.nidtype == 'v' or self.nidtype == 'p':
            res = DBQueryFatal("select i.IP,pm.hostname,nv.phys_nodeid "
                               " from nodes as nv"
                               " left join interfaces as i"
                               "  on nv.phys_nodeid=i.node_id"
                               " left join plab_mapping as pm"
                               "  on i.IP=pm.IP"
                               " where nv.node_id='%s'" % (self.nodeid))
            if (not res or len(res) == 0):
                print "Warning: no hostinfo found for nodeid %s" % self.nodeid
                (IP,hostname,phys_nodeid) = (None,None,None)
                pass
            else:
                ((IP,hostname,phys_nodeid),) = res
                pass
            pass
        elif self.nidtype == 'i':
            IP = self.nodeid
            hostname = socket.gethostbyaddr(IP)
            phys_nodeid = None
            pass
        else:
            hostname = self.nodeid
            IP = socket.gethostbyname(self.nodeid)
            phys_nodeid = None
            pass
        
        if verbose:
            print "hostname is %s for node %s" % (hostname,IP)
            pass
        
        return (IP,hostname,phys_nodeid)
    
    pass  # end of class Node
# AOP wrappers for class Node
wrap_around(Node._create, timeAdvice)
wrap_around(Node.free, timeAdvice)
wrap_around(Node.emulabify, timeAdvice)
