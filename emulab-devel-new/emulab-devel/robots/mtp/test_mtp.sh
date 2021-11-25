#! /bin/sh

#
# Copyright (c) 2005 University of Utah and the Flux Group.
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

## Variables

# The full path of the test case
test_file=$1
# The base name of the test case
test_file_base="test_mtp.sh"

PORT=6050

## Helper functions

check_output() {
    diff -u - ${test_file_base}.tmp
    if test $? -ne 0; then
	echo $1
	exit 1
    fi
}

##

./mtp_recv ${PORT} > ${test_file_base}.tmp 2>&1 &
MTP_RECV_PID=$!

trap 'kill $MTP_RECV_PID' EXIT

sleep 2

../mtp/mtp_send -n localhost -P ${PORT} \
    -r rmc -i 0 -c 0 -m "empty" init -- \
    -r rmc -i 1 request-position

kill $MTP_RECV_PID
trap '' EXIT

check_output "?" <<EOF
Listening for mtp packets on port: 6050
Packet: version 2; role rmc
 opcode:	init
  id:		0
  code:		0
  msg:		empty
Packet: version 2; role rmc
 opcode:	request-position
  id:		1
EOF
