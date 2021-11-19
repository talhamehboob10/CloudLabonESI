#! /usr/bin/env python
#
# Copyright (c) 2008-2009 University of Utah and the Flux Group.
# 
# {{{GENIPUBLIC-LICENSE
# 
# GENI Public License
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and/or hardware specification (the "Work") to
# deal in the Work without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Work, and to permit persons to whom the Work
# is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Work.
# 
# THE WORK IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE WORK OR THE USE OR OTHER DEALINGS
# IN THE WORK.
# 
# }}}
#

#
#
import sys
import pwd
import getopt
import os
import re
import stat
import xmlrpclib
from M2Crypto import SSL, X509

def RememberCB( c, prompt1 = '', prompt2 = '' ):
    return passphrase

execfile( "test-common.py" )

if os.path.exists( PASSPHRASEFILE ):
    Fatal( "A passphrase has already been stored." )

from M2Crypto.util import passphrase_callback
while True:
    passphrase = passphrase_callback(0)
    if not os.path.exists(CERTIFICATE):
        print >> sys.stderr, "Warning:", CERTIFICATE, "not found; cannot " \
            "verify passphrase."
        break

    try:
        ctx = SSL.Context( "sslv23" )
        ctx.load_cert( CERTIFICATE, CERTIFICATE, RememberCB )
    except M2Crypto.SSL.SSLError, err:
        print >> sys.stderr, "Could not decrypt key.  Please try again."
        continue

    break

f = open( PASSPHRASEFILE, "w" )
os.chmod( PASSPHRASEFILE, stat.S_IRUSR | stat.S_IWUSR )
f.write( passphrase )
