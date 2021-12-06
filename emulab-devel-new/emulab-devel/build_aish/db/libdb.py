# -*- python -*-
#
# Copyright (c) 2000-2015, 2020 University of Utah and the Flux Group.
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
# Database functions
#

from __future__ import print_function
import sys
import os, os.path
import pwd
import string
import types
import traceback

TBPATH = os.path.join("/users/achauhan/Cloudlab/CloudLabonESI/emulab-devel-new/emulab-devel/build_aish", "lib")
if TBPATH not in sys.path:
    sys.path.append(TBPATH)
    pass

import MySQLdb

from libtestbed import *

#
# Debug vars.
#
verbose = 0
debug = 0

# Constants
TBOPSPID               = "emulab-ops"
NODEDEAD_PID           = TBOPSPID
NODEDEAD_EID           = "hwdown"
TB_NODEHISTORY_OP_MOVE = "move"

# Node Log Types
TB_NODELOGTYPE_MISC    = "misc"
TB_NODELOGTYPES        = (TB_NODELOGTYPE_MISC, )
TB_DEFAULT_NODELOGTYPE = TB_NODELOGTYPE_MISC

# Node History Stuff.
TB_NODEHISTORY_OP_FREE  = "free"
TB_NODEHISTORY_OP_ALLOC	= "alloc"
TB_NODEHISTORY_OP_MOVE  = "move"

#
# DB variables.
#
__dbName = "tbdb"
__dbQueryMaxtries = 1
__dbConnMaxtries = 5
__dbMailOnFail = True
__dbFailMailAddr = TBOPS

# Multiple connections via slots.
__DB = dict({})
# Keep connection info around for reconnects.  Except we don't save passwords!
# If a connection required a password, we throw a ManualReconnectRequiredError.
__DBConnectArgs = dict({})

class ManualReconnectRequiredError(Exception):
    pass

def TBDBUnusedHandle():
    maxhandle = -1
    for k,v in __DB.items():
        if (type(k) == types.IntType) and k > maxhandle:
            maxhandle = k
            pass
        pass
    return maxhandle+1

#
# By default, connect to the Emulab db.  Also supports connections to other
# dbs.  If you specify a dbnum of None, we pick the first unused one and
# return it.
#
def TBDBConnect(dbnum=0,db=None,user=None,host=None,passwd=None):
    global __DB
    global __DBConnectArgs

    if dbnum == None:
        dbnum = TBDBUnusedHandle()

    if dbnum in __DB and __DB[dbnum] != None:
        return dbnum

    cargs = {}
    dbname = db
    if db == None:
        dbname = __dbName
    cargs['db'] = dbname
    dbuser = user
    if user == None:
        # Create a DB username for accounting purposes
        uid = os.getuid()
        try:
            name = pwd.getpwuid(uid)[0]
        except KeyError:
            name = "uid%d" % uid
        dbuser = "%s:%s:%d" % (sys.argv[0], name, os.getpid())
        
        if debug:
            print("Connecting to db %s (%d) as %s" % (dbname,dbnum,dbuser))
    cargs['user'] = dbuser
    if host != None:
        cargs['host'] = host
    if passwd != None:
        cargs['passwd'] = passwd

    if debug:
        print("About to try connect with args=%s" % str(cargs))
    
    # Connect, with retries
    for tries in range(__dbConnMaxtries):
        try:
            __DB[dbnum] = MySQLdb.connect(**cargs)
            # Delete the password if it exists, but make a record of it
            # so that we throw a "must manually reconnect" exception if
            # a reconnect happens.  Not ideal, but necessary.
            if 'passwd' in cargs:
                cargs['passwd'] = None
                pass
            # XXX we need this for mysql 5.5 and above to avoid metadata
            # lock hangs, even when using MyISAM tables.
            __DB[dbnum].autocommit(True)
            __DBConnectArgs[dbnum] = cargs
        except:
            if debug:
                traceback.print_exc()
            time.sleep(5)
        else:
            break
    else:
        raise RuntimeError("Cannot connect to DB %d after several " + \
              "attempts!" % (dbnum))

    return dbnum

def TBDBReconnect(retry = False,dbnum = 0,passwd=None):
    global __dbConnMaxtries, __DB
    
    if retry:
        tmpConnMaxtries = __dbConnMaxtries
        # "forever"
        __dbConnMaxtries = 10000
        pass

    # Force closed if not closed yet.
    try:
        __DB[dbnum].close()
    except:
        pass
    __DB[dbnum] = None

    tconnargs = __DBConnectArgs[dbnum].copy()
    if 'passwd' in tconnargs and tconnargs['passwd'] == None \
           and passwd == None:
        raise ManualReconnectRequiredError("This connection requires a passwd!")
    if passwd != None:
        tconnargs = __DBConnectArgs[dbnum].copy()
        tconnargs["passwd"] = passwd
        pass
    
    try:
        TBDBConnect(dbnum=dbnum,**tconnargs)
    except RuntimeError:
        # restore old value, even though the program will probably choose
        # to die if it can't reconnect...
        if retry:
            __dbConnMaxtries = tmpConnMaxtries
            pass
        raise RuntimeError("Cannot reconnect to DB %d after %d attempts!" \
              % (dbnum,__dbConnMaxtries))

    if retry:
        __dbConnMaxtries = tmpConnMaxtries
        pass

    return

#
# XXX: Ugh.
# The reason for this hack is the limited functionality across fork supported
# by MySQLdb.  The desire is that child processes, on their first query
# post-fork, should notice if they inherited the parent's connection, stop
# using that connection, and let its resources be garbage-collected, BUT NOT
# send a disconnect to the server.  Unfortunately, since MySQLdb takes all its
# functionality from a C wrapper around the MySQL libs, there is no way to both
# garbage-collect the resources and not officially disconnect.  If you set the
# connection obj to None, you call the destructor and this disconnects from the
# server.  No way to both dealloc the C resources and not disconnect.  There's
# a simple one-line fix to allow for this in the C wrapper (and better multi-
# line fixes), but I don't want to hack this in right now.
#

#
# Thus, processes that os.fork off children should call TBDBPreFork() just
# before the actual fork syscall.  Note that this method does not perform the
# fork; it merely forces a disconnect from the server.  Both the parent and the
# child will reconnect transparently upon the first query.  At this point, this
# is the best transparent sol'n, even though it's terrible!
# Of course, if you're not planning to 1) touch the connection, or 2) close
# all open filehandles in the child, you don't need to call this.
# WARNING: do not call this function if you have any connection state (i.e.,
# are in the middle of a transaction)!
#
def TBDBPreFork():
    unclosed = []
    for dbno in __DB.keys():
        if not TBDBDisconnect(dbnum=dbno):
            unclosed.append(dbno)
            pass
        pass
    if len(unclosed) > 0:
        # don't just null out object; this could perhaps fail if there's an
        # uncommitted transaction or something...
        raise RuntimeError("Could not close db connection(s) (%s) " + \
              "in prefork!" % (",".join(unclosed)))
    
    return

def TBDBDisconnect(dbnum=0):
    global __DB

    if __DB[dbnum]:
        try:
            __DB[dbnum].close()
            __DB[dbnum] = None
        except:
            print("Could not close db connection!")
            return False
        pass
    
    return True

def DBQuery(queryPat, querySub = (), asDict = False, dbnum = 0):
    TBDBConnect(dbnum=dbnum)

    if debug:
        print("Executing DB query %s" % (queryPat))

    tries = __dbQueryMaxtries
    while tries:
        if asDict:
            cursor = __DB[dbnum].cursor(MySQLdb.cursors.DictCursor)
        else:
            cursor = __DB[dbnum].cursor()
            pass

        try:
            cursor.execute(queryPat, querySub)
            ret = cursor.fetchall()
            if debug:
                rs = repr(ret)
                if len(rs) > 60:
                    rs = rs[:60] + "..."
                print("Result: %s" % (rs))
                pass
            cursor.close()
            if ret == None:
                return ()
            return ret
        except MySQLdb.MySQLError as e:
            try:
                __DB[dbnum].ping()
            except MySQLdb.MySQLError:
                # Connection is dead; need a reconnect
                try:
                    TBDBReconnect(True,dbnum=dbnum)
                    continue
                except RuntimeError:
                    print("Error: could not reconnect to mysqld!")
                    time.sleep(1)
                    pass
                pass

            tries -= 1
            if tries == 0:
                break
            pass
        pass

    tbmsg  = queryPat % cursor.connection.literal(querySub)
    tbmsg += "\n\n"
    tbmsg += "".join(traceback.format_exception(*sys.exc_info()))
    if __dbMailOnFail:
        SENDMAIL(__dbFailMailAddr,"DB query failed", "DB query failed:\n\n%s" \
                 % tbmsg, __dbFailMailAddr)
    return None

def DBQueryFatal(*args,**kwargs):
    ret = DBQuery(*args,**kwargs)
    if ret == None:
        raise RuntimeError("DBQueryFatal failed")
    return ret

def DBQueryWarn(*args,**kwargs):
    return DBQuery(*args,**kwargs)

def DBQuoteSpecial(str,dbnum=0):
    TBDBConnect(dbnum=dbnum)
    return __DB[dbnum].escape_string(str)


#
# Map UID to DB UID (login). Does a DB check to make sure user is known to
# the DB (user obviously has a regular account), and that account will
# always match what the DB says. Redundant, I know. But consider it a
# sanity (or consistency) check.
#
# usage: UNIX2DBUID(int uid)
#        returns username if the UID is okay.
#        raises a UserError exception if the UID is bogus.
#
class UserError(Exception): pass # XXX: need better suite of exceptions
def UNIX2DBUID (unix_uid):
    qres = \
         DBQueryFatal("select uid from users where unix_uid=%s",
                      (unix_uid))
    if not len(qres):
        raise UserError("*** %s not a valid Emulab user!" % uid)
    pwname = pwd.getpwuid(unix_uid)[0]
    dbuser = qres[0][0]
    if dbuser != pwname:
        raise UserError("*** %s (passwd file) does not match %s (db)" % \
              (pwname, dbuser))
    return dbuser

#
# Helper. Test if numeric. Convert to dbuid if numeric.
#
def MapNumericUID(uid):
    name = ""
    try:
        uid = int(uid)
        name = UNIX2DBUID(uid)
    except ValueError:
        name = uid
        pass
    return name


#
# Return the IDX for a current experiment. 
#
# usage: TBExptIDX(char $pid, char *gid, int \$idx)
#        returns 1 if okay.
#	 returns 0 if error.
#
class UnknownExptID(Exception): pass # XXX: need better suite of exceptions
def TBExptIDX(pid,eid):
    qres = \
         DBQueryWarn("select idx from experiments "
                     "where pid=%s and eid=%s",
                     (pid, eid))

    if not len(qres):
        raise UnknownExptID("Experiment %s/%s unknown!" % (pid,eid))
    
    idx = qres[0][0]
    return int(idx)

#
# Insert a Log entry for a node.
#
# usage: TBSetNodeLogEntry(char *node, char *uid, char *type, char *message)
#        Returns 1 if okay.
#        Returns 0 if failed.
#
def TBSetNodeLogEntry(node, dbuid, etype, message):
    if not TBValidNodeName(node) or not TBValidNodeLogType(etype):
        return 0
    idx = TBMapUIDtoIDX(dbuid)

    if type(idx) == tuple:
        idx = idx[0]
        pass
    return DBQueryWarn("insert into nodelog "
                       "values "
                       "(%s, NULL, %s, %s, %s, %s, now())",
                       (node, etype, dbuid, idx, message))

#
# Validate a node name.
#
# usage: TBValidNodeName(char *name)
#        Returns 1 if the node is valid.
#        Returns 0 if not.
#
def TBValidNodeName(node):
    qres = \
         DBQueryWarn("select node_id from nodes where node_id=%s",
                     (node))
    if len(qres) == 0:
        return 0
    return 1

#
# Validate a node log type.
#
# usage: TBValidNodeLogType(char *type)
#        Returns 1 if the type string is valid.
#        Returns 0 if not.
#
def TBValidNodeLogType(type):
    if type in TB_NODELOGTYPES:
        return 1
    return 0

#
# Mark a Phys node as down. Cannot use next reserve since the pnode is not
# going to go through the free path.
#
# usage: MarkPhysNodeDown(char *nodeid)
#
def MarkPhysNodeDown(pnode):
    pid = NODEDEAD_PID;
    eid = NODEDEAD_EID;
    exptidx = 0

    try:
        exptidx = TBExptIDX(pid, eid)
    except:
        print("*** WARNING: No such experiment %s/%s!" % (pid,eid))
        return

    DBQueryFatal("lock tables reserved write")
    DBQueryFatal("update reserved set "
                 "  exptidx=%s,pid=%s,eid=%s,rsrv_time=now() "
                 "where node_id=%s",
                 (exptidx,pid, eid, pnode))
    DBQueryFatal("unlock tables")
    TBSetNodeHistory(pnode, TB_NODEHISTORY_OP_MOVE, os.getuid(), pid, eid)
    return


def TBSetNodeHistory(nodeid, op, uid, pid, eid):
    exptidx = 0

    try:
        exptidx = TBExptIDX(pid, eid)
    except:
        print("*** WARNING: No such experiment %s/%s!" % (pid,eid))
        return 0

    try:
        uid = int(uid)
        # val = <expr> ? TrueRet : FalseRet
        uid = uid == 0 and "root" or UNIX2DBUID(uid)
        pass
    except ValueError:
        pass

    idx = TBMapUIDtoIDX(uid)
    
    return DBQueryWarn("insert into node_history set "
                       "  history_id=0, node_id=%s, op=%s, "
                       "  uid=%s, uid_idx=%s, stamp=UNIX_TIMESTAMP(now()), "
                       "  exptidx=%s",
                       (nodeid,op,uid,idx,exptidx))


def TBSiteVarExists(name):
    name = DBQuoteSpecial(name)

    qres = DBQueryFatal("select name from sitevariables "
                        "where name=%s", (name,))

    if len(qres) > 0:
        return 1
    else:
        return 0
    pass


def TBGetSiteVar(name):
    name = DBQuoteSpecial(name)

    qres = DBQueryFatal("select value, defaultvalue from sitevariables "
                        "where name=%s", (name,))

    if len(qres) > 0:
        value, defaultvalue = qres[0]

        if value: return value
        elif defaultvalue: return defaultvalue

        pass
    
    raise RuntimeException(
          "*** attempted to fetch unknown site variable name!")

def TBMapUIDtoIDX(uid):
    uid = DBQuoteSpecial(uid)
    
    qres = DBQueryFatal("select uid_idx from users "
                        "where uid=%s and status!='archived' and status!='nonlocal'",
			(uid,))

    if len(qres) == 0:
        return 0

    return qres[0]

