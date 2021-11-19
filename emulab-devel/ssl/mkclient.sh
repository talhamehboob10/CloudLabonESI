#!/bin/sh
#
# Copyright (c) 2000-2012 University of Utah and the Flux Group.
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

prefix=$1

#
# Sign the client cert request, creating a client certificate.
#
openssl ca -batch -policy policy_match -config ca.cnf \
	-out ${prefix}.pem \
        -cert emulab.pem -keyfile emulab.key \
	-infiles ${prefix}.req

#
# Combine the key and the certificate into one file which is installed
# on each remote node and used by tmcc. Installed on boss too so
# we can test tmcc there.
#
cat ${prefix}.key >> ${prefix}.pem

exit 0
