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
sys.path.append("/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/lib/dslice")
sys.path.append("/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/lib/dslice/dslice")
sys.path.append("/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish/lib/dslice/HTMLgen")

import agent, agentproxy
import nodemgr, nodemgrproxy
import lease
import cPickle

from libtestbed import *

#
# output control vars
#
verbose = 0
debug = 0

#
# Constants
#
LEASELEN = 14*24*60*60   # Two weeks (maximum lease length)
AGENTIP = "dslice.planet-lab.org"
ELABPUBKEYFILE = "/root/.ssh/identity.pub"

# XXX: Create agent dictionary - one entry for each slice.
class mod_dslice:
    def __init__(self, keyfile = DEFAULT_DATA_PATH + "key.pem",
                 pubkeyfile = DEFAULT_DATA_PATH + "pubkey.pem",
                 certfile = DEFAULT_DATA_PATH + "cert.pem",
                 cacertfile = DEFAULT_DATA_PATH + "cacert.pem"):
        for file in (keyfile, pubkeyfile, certfile, cacertfile):
            if not os.path.exists(file):
                raise RuntimeError, "Key or cert %s does not exist" % file
        self.keyfile, self.pubkeyfile, self.certfile, self.cacertfile = \
                      keyfile, pubkeyfile, certfile, cacertfile
        self.__agentProxy = None
        self.__nodemgrProxies = {}
        self.modname = "mod_dslice"
        pass
    
    def createSlice(self, slice):
        privkey, pubkey = self.__genKeypair()
        return (1, cPickle.dumps((privkey, pubkey)), None)

    def deleteSlice(self, slice):
        return

    def renewSlice(self, slice):
        return (0, slice.slicemeta, None)

    def createNode(self, node):
        # Get a ticket, and redeem it for a vm lease
        privkey, pubkey = cPickle.loads(node.slice.slicemeta)
        agent = self.__createAgentProxy()
        tickets = tryXmlrpcCmd(agent.newtickets,
                               (node.slice.slicename,
                                1, LEASELEN, (node.IP,)))
        assert (len(tickets) == 1), "%d tickets returned" % len(tickets)
        ticketdata = tickets[0]
        if debug:
            print "Obtained ticket:"
            print ticketdata
            pass
        
        nodemgr = self.__createNodemgrProxy(node.IP)
        self.leasedata = None
        
        tries = DEF_TRIES
        while 1:
            TIMESTAMP("createnode %s try %d started." % (node.nodeid,
                                                         DEF_TRIES-tries+1))
            try:
                self.leasedata = tryXmlrpcCmd(nodemgr.newleasevm,
                                              (ticketdata,
                                               privkey,
                                               pubkey),
                                              inittries = tries,
                                              raisefault = True)
                pass
            
            # We may have actually gotten the lease/vm even though
            # the xmlrpc call appeared to fail.  We check for this
            # condition here, which will show up on subsequent allocation
            # attempts.
            except xmlrpclib.Fault, e:
                if e.faultString.find("already exists") != -1:
                    print "Lease for %s already exists; deleting." % \
                          node.nodeid
                    if self.freeNode(node):
                        raise RuntimeError, "Could not delete lingering " \
                              "lease for slice %s on %s" % \
                              (node.slice.slicename, node.nodeid)
                    pass
                
                if e.triesleft > 0:
                    tries = e.triesleft
                else:
                    raise
                
                pass
            
            # success
            else:
                break
            pass
        
        if debug:
            print "Obtained lease/vm:"
            print leasedata
            pass

        lease = lease.lease(leasedata)
        self.__addKey(node, ELABPUBKEYFILE)
        return (1, cPickle.dumps((ticketdata, leasedata)), lease.end_time)

    def freeNode(self, node):
        # Get node manager handle
        nodemgr = self.__createNodemgrProxy(node.IP)
        deleted = 0
        
        tries = DEF_TRIES
        while 1:
            TIMESTAMP("freenode %s try %d started." % (node.nodeid,
                                                       DEF_TRIES-tries+1))
            try:
                tryXmlrpcCmd(nodemgr.deletelease, node.slice.slicename,
                             inittries = tries, raisefault = 1)
                pass
            except xmlrpclib.Fault, e:
                if e.faultString.find("does not exist") != -1:
                    print "Lease for %s did not exist on node" % node.nodeid
                    deleted = 1
                    break
                elif e.triesleft > 0:
                    tries = e.triesleft
                else:
                    break
                pass
            except:
                print "Warning: couldn't delete the lease for %s on %s" % \
                      (node.slice.slicename, node.nodeid)
                tbstr = "".join(traceback.format_exception(*sys.exc_info()))
                SENDMAIL(TBOPS, "Sliver lease deletion failed on %s, "
                         "dslice %s" % (node.nodeid, node.slice.slicename),
                         "Sliver lease deletion failed:\n\n%s" % tbstr, TBOPS)
                break
            else:
                deleted = 1
                break
            pass
        return deleted

    def __addKey(self, node, identityfile):
        """
        Adds an ssh public key to the node.  Note that identityfile must
        be the path of the public key.  This must be done before any
        calls to becomeEmulba, addtoGroup, or unpackTgz, because those
        commands rely on ssh'ing into the node.  Note also that this
        should be one of the keys that ssh naturally knows about, or
        those commands will fail.
        """
        if verbose:
            print "Adding pubkey to node %s" % node.nodeid
            pass
        if not identityfile.endswith(".pub"):
            raise RuntimeError, "File %s doesn't look like a pubkey" % \
                  identityfile
        pubkey = file(identityfile, "rb").read().strip()
        nodemgr = self.__createNodemgrProxy(node.IP)
        ret = tryXmlrpcCmd(nodemgr.addkey, (node.slice.slicename, pubkey))
        if debug:
            print "Added key: %s" % `ret`
            pass
        return ret

    def renewNode(self, node, length = 0):
        """
        Renew the lease for node belonging to this instance.  Don't
        call this directly; instead, use Node.renew()
        """
        print "Renewing lease on Plab node %s." % node.nodeid
        ticketdata, leasedata = cPickle.loads(node.nodemeta)
        nodemgr = self.__createNodemgrProxy(node.IP)

        tries = DEF_TRIES
        while 1:
            TIMESTAMP("renewnode %s try %d started." % (node.nodeid,
                                                        DEF_TRIES-tries+1))
            try:
                self.leasedata = tryXmlrpcCmd(nodemgr.renewlease,
                                              node.slice.slicename,
                                              inittries = tries,
                                              raisefault = True)
            except xmlrpclib.Fault, e:
                if e.faultString.find("does not exist") != -1:
                    print "No lease found on %s for slice %s" % \
                          (node.nodeid, node.slice.slicename)
                    return 1
                elif e.triesleft > 0:
                    tries = e.triesleft
                else:
                    raise
            else:
                break

        if debug:
            print "Obtained new lease:"
            print self.leasedata
        self.lease = lease.lease(self.leasedata)
        return (1, cPickle.dumps((ticketdata, leasedata)), lease.end_time)

    def __genKeypair(self):
        """
        Generates a passphrase-less RSA keypair and returns the PEM
        format data to be stored in the slice's identity and
        identity.pub files.
        """
        # XXX This is a workaround for a bug in M2Crypto
        import tempfile

        if verbose:
            print "Generating slice keypair"
        # pdssi = Plab Dynamic Slice SSH Identity
        fname = tempfile.mktemp("pdssi%d" % os.getpid())
        if debug:
            print "Writing keypair to %s(.pub)" % fname
        if os.spawnlp(os.P_WAIT, "ssh-keygen",
                      "ssh-keygen", "-t", "rsa", "-b", "1024", "-P", "",
                      "-f", fname, "-q"):
            raise RuntimeError, "Error generating slice keypair"
        
        privkey = file(fname, "rb").read()
        pubkey = file(fname + ".pub", "rb").read()
        map(os.unlink, (fname, fname + ".pub"))
        
        return privkey, pubkey
        
        
        # Below here is the way it _should_ be done
        if verbose:
            print "Generating slice keypair"
        key = RSA.gen_key(1024, 35)    # OpenSSH ssh-keygen uses 35 for e

        privkeyio = cStringIO.StringIO()
        # Due to a current bug in M2Crypto, None cannot be passed as the
        # cipher; therefore, passphraseless keys cannot be generated
        key.save_key_bio(BIO.File(privkeyio), None)
        privkey = privkeyio.getvalue()

        pubkeyio = cStringIO.StringIO()
        key.save_pub_key_bio(BIO.File(pubkeyio))
        pubkey = pubkeyio.getvalue()

        return privkey, pubkey

    def __createAgentProxy(self, insecure = False):
        """
        Creates an agent proxy connected to the Plab central agent.
        Also caches the agent for later reuse.
        """
        if not self.__agentProxy:
            if verbose:
                print "Connecting to agent %s" % AGENTIP
            if insecure:
                args = (AGENTIP, agent.PORT)
            else:
                args = (AGENTIP, agent.PORT, agent.SSLPORT,
                        self.keyfile, self.certfile, self.cacertfile)
                self.__agentProxy = agentproxy.agentproxy(*args)
        return self.__agentProxy

    def __createNodemgrProxy(self, IP):
        """
        Creates a node manager proxy connected to this node's node
        manager.  Also caches the nodemgr for later reuse.
        """
        if not self.__nodemgrProxies[IP]:
            if verbose:
                print "Connecting to nodemgr on %s" % IP
            self.__nodemgrProxies[IP] = \
                                      nodemgrproxy.nodemgrproxy(IP,
                                                                nodemgr.PORT,
                                                                nodemgr.SSLPORT,
                                                                self.keyfile,
                                                                self.certfile,
                                                                self.cacertfile)
        return self.__nodemgrProxies[IP]

    
