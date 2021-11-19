#/bin/sh
#
# Copyright (c) 2007 University of Utah and the Flux Group.
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

SCHEDMON="/local/schedmon/schedmon -s 10000 -n 100 -t -l 59 -b"
ACTIVELOG=/tmp/schedmon.log

loop=1
function hup_h () {
  loop=1
}
function term_h () {
  loop=0
}

# just to be safe
killall -w -SIGKILL schedmon > /dev/null 2>&1 

while [ $loop -ne 0 ]
do
  loop=0
  trap hup_h  SIGHUP
  trap term_h SIGTERM

  # run until it dies via a signal
  $SCHEDMON > $ACTIVELOG

  trap '' SIGTERM # to make sure the log gets copied

  ID=`date -u +%Y%m%d%H%M%S`

  # now move and compress the log
  cat $ACTIVELOG | gzip -c > /local/logs/schedmon-$ID.log.gz
  rm $ACTIVELOG
done

exit 0


