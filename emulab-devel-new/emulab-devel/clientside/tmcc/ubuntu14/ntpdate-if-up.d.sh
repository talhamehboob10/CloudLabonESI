#!/bin/sh

#
# We don't want to run the default Debian ntpdate package if-up hook
# (/etc/network/if-up.d/ntpdate); so we overwrite it with this file.
#

exit 0
