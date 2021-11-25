#! /bin/sh

#
# Copyright (c) 2004-2006 University of Utah and the Flux Group.
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
test_file_base="test_multi_path.sh"
# The current test number for shell based tests.
test_num=0

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

run_test ./multi_path -x 1.0 -y 4.9 -u 9.0 -v 4.9

check_output "garcia1 didn't go over the top?" <<EOF
set waypoint(garcia1) 2.00 3.00
set waypoint(garcia1) 2.25 3.00
set waypoint(garcia1) 3.50 3.00
set waypoint(garcia1) 7.00 3.00
set waypoint(garcia1) 8.00 3.00
set waypoint(garcia1) NONE
-reverse-
set waypoint(garcia1) 8.00 3.00
set waypoint(garcia1) 7.00 3.00
set waypoint(garcia1) 3.50 3.00
set waypoint(garcia1) 2.25 3.00
set waypoint(garcia1) NONE
EOF

run_test ./multi_path -x 1.0 -y 3.3 -u 9.0 -v 3.3

check_output "garcia1 went around merged obstacle?" <<EOF
set waypoint(garcia1) 2.25 3.00
set waypoint(garcia1) 3.50 3.00
set waypoint(garcia1) 7.00 3.00
set waypoint(garcia1) 8.00 3.00
set waypoint(garcia1) NONE
-reverse-
set waypoint(garcia1) 8.00 3.00
set waypoint(garcia1) 7.00 3.00
set waypoint(garcia1) 3.50 3.00
set waypoint(garcia1) 2.25 3.00
set waypoint(garcia1) NONE
EOF

run_test ./multi_path -x 2.2 -y 4.0 -u 2.2 -v 9.9

check_output "garcia1 went around merged obstacle (2)?" <<EOF
set waypoint(garcia1) 2.00 4.50
set waypoint(garcia1) 2.00 5.50
set waypoint(garcia1) NONE
-reverse-
set waypoint(garcia1) 2.00 5.50
set waypoint(garcia1) 2.00 4.50
set waypoint(garcia1) NONE
EOF
