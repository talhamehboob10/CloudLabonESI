#! /usr/bin/env python
#
# Copyright (c) 2008-2010 University of Utah and the Flux Group.
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
import zlib

execfile( "test-common.py" )

available_key = "geni_available"
compress_key = "geni_compressed"

#
# Get a credential for myself, that allows me to do things at the SA.
#
mycredential = get_self_credential()

#
# Ask manager for its list.
#
version = {}
version['type'] = 'GENI'
version['version'] = '3'
options = {}
options[available_key] = True
options[compress_key] = True
options['geni_rspec_version'] = version
params = [[mycredential], options]


try:
    response = do_method("am/2.0", "ListResources", params,
                         response_handler=geni_am_response_handler)
    if response['code']['geni_code'] == 0:
      if compress_key in options and options[compress_key]:
        # decode and decompress the result
        #
        # response is a string whose content is a base64 encoded
        # representation of a zlib compressed rspec
        print zlib.decompress(response['value'].decode('base64'))
      else:
        print response['value']
    else:
      print response
except xmlrpclib.Fault, e:
    Fatal("Could not get a list of resources: %s" % (str(e)))
