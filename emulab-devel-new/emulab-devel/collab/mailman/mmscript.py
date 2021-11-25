#
# Copyright (c) 2004-2010 University of Utah and the Flux Group.
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
from Mailman import mm_cfg
from Mailman import MailList
from Mailman import Utils
from Mailman import Message
from Mailman import Errors
from Mailman import UserDesc
import hashlib
import sys

def addmember(mlist, addr, name, passwd):
    userdesc = UserDesc.UserDesc(address=addr, fullname=name, password=passwd)
    try:
        mlist.ApprovedAddMember(userdesc, 0, 0)
        mlist.Save()
    except Errors.MMAlreadyAMember:
        print 'Already a member:', addr
    except Errors.MMBadEmailError:
        print 'Bad address:', addr
        sys.exit(1);
    except Errors.MMHostileAddress:
        print 'Hostile address:', addr
        sys.exit(1);
    except:
        print 'Error adding name'
        sys.exit(1);
        pass
    pass

def modmember(mlist, oldaddr, newaddr, name, passwd):
    try:
        mlist.setMemberPassword(oldaddr, passwd)
        mlist.setMemberName(oldaddr, name)
        if oldaddr <> newaddr:
            mlist.ApprovedChangeMemberAddress(oldaddr, newaddr, False)
            pass
        mlist.Save()
    except Errors.NotAMemberError:
        print 'Not a member:', oldaddr
        sys.exit(1);
    except:
        print 'Error resetting name/password'
        sys.exit(1);
        pass
    pass

def setadmin(mlist, addr, passwd):
    try:
        mlist.owner = [addr]
        mlist.password = hashlib.sha1(passwd).hexdigest()
        mlist.Save()
    except:
        print 'Error resetting name/password for list'
        sys.exit(1);
        pass
    pass

def findmember(mlist, addr):
    if mlist.isMember(addr):
        print mlist.internal_name();
        pass
    pass

def getcookie(mlist, addr, cookietype):
    # If we want the admin interface, we do not care if the addr is
    # a member of the list, since the caller (boss) already verified
    # the operation was allowed.
    if cookietype == "admin":
        print mlist.MakeCookie(mm_cfg.AuthListAdmin, addr)
        return
    
    # But for a user cookie, must be a member.
    if mlist.isMember(addr):
        print mlist.MakeCookie(mm_cfg.AuthUser, addr)
        pass
    pass
