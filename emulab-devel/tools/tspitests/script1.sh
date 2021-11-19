#!/bin/sh
#
# Copyright (c) 2010-2012 University of Utah and the Flux Group.
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

MP=`which modprobe`
KILLALL=`which killall`
TCSD=`which tcsd`
DOQ=`which doquote`
TMCC=`which tmcc`
SLEEPTIME=1

# Error check later
echo "Doing TPM setup ..."
/etc/testbed/rc/rc.tpmsetup

${MP} tpm_tis
${KILLALL} -9 tcsd; sleep ${SLEEPTIME}
${TCSD}

echo "Requesting info for RELOADSETUP quote ..."
QINFO=`${TMCC} quoteprep RELOADSETUP`
if [ -z "$QINFO" ]; then
    echo "*** could not get RELOADSETUP quote info"
    exit 1
fi

echo "Preparing RELOADSETUP quote ..."
SSCRUFT=`echo $QINFO | ${DOQ} RELOADSETUP`
if [ -z "$SSCRUFT" ]; then
    echo "*** could not produce RELOADSETUP quote"
    exit 1
fi

echo "Sending RELOADSETUP quote ..."
RC=`${TMCC} securestate ${SSCRUFT}`
if [ $? -ne 0 -o "$RC" = "FAILED" ]; then
    echo "*** could not transition to RELOADSETUP"
    exit 1
fi

echo "Fetching image-related keys ..."
${KILLALL} -9 tcsd; sleep ${SLEEPTIME}
${TCSD}
${TMCC} -T imagekey > /tmp/secureloadinfo.out

exit $?
