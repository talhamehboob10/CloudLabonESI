#!/bin/sh
#

host=$1
if [ "$host" == "" ]; then
    echo "Must supply a host name"
    exit 1
fi

ssh elabman@${host} 'sudo mkdir -p /usr/testbed/www/mirror/repos.emulab.net && sudo chown -R elabman /usr/testbed/www/mirror && rsync -avz stoller@ops.emulab.net:/z/linux-package-repos/www/powder --exclude=powder/ubuntu/conf /usr/testbed/www/mirror/repos.emulab.net/ && rsync -avz stoller@ops.emulab.net:/z/linux-package-repos/www/powder-endpoints --exclude=powder-endpoints/ubuntu/conf /usr/testbed/www/mirror/repos.emulab.net/ && rsync -avz stoller@ops.emulab.net:/z/linux-package-repos/www/emulab.key /usr/testbed/www/mirror/repos.emulab.net/'
