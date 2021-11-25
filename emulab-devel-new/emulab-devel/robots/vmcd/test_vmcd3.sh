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
test_file_base="test_vmcd3.sh"
# The current test number for shell based tests.
test_num=0

# SRCDIR=@srcdir@
EMC_PORT=6565
VMC1_PORT=6566

## Helper functions

run_test() {
    echo "run_test: $*"
    $* > ${test_file_base}_${test_num}.tmp 2>&1
}

check_output() {
    diff -u - ${test_file_base}_${test_num}.tmp
    if test $? -ne 0; then
	echo $1
	exit 1
    fi
    test_num=`expr ${test_num} \+ 1`
}

##

# Start the daemons vmcd depends on:

../emc/emcd -l `pwd`/test_emcd.log \
    -i `pwd`/test_emcd.pid \
    -p ${EMC_PORT} \
    -s ops \
    -c `realpath ${SRCDIR}/test_emcd3.config`

vmc-client -l `pwd`/test_vmc-client1.log \
    -i `pwd`/test_vmc-client1.pid \
    -p ${VMC1_PORT} \
    -f ${SRCDIR}/test_vmcd3.pos \
    foobar

# Start vmcd:

vmcd -l `pwd`/test_vmcd.log \
    -i `pwd`/test_vmcd.pid \
    -e localhost \
    -p ${EMC_PORT} \
    -c localhost -P ${VMC1_PORT}

cleanup() {
    kill `cat test_vmcd.pid`
    kill `cat test_emcd.pid`
    kill `cat test_vmc-client1.pid`
}

trap 'cleanup' EXIT

sleep 2

newframe() {
    kill -s USR1 `cat test_vmc-client1.pid`
}

newframe

sleep 1

lpc=0
while test $lpc -lt 14; do
    newframe
    sleep 0.1
    lpc=`expr $lpc + 1`
done

run_test ../mtp/mtp_send -n localhost -P ${EMC_PORT} \
    -r emulab -i 1 -c 0 -m "empty" init -- \
    -w -i 1 request-position

check_output "no update?" <<EOF
Packet: version 2; role emc
 opcode:	update-position
  id:		1
  x:		6.000000
  y:		5.280000
  theta:	-1.570796
  status:	-1
  timestamp:	14.000000
EOF
