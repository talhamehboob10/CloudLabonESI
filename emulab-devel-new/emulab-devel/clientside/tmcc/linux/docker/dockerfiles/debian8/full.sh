#!/bin/sh

set -x

export DEBIAN_FRONTEND=noninteractive

apt-get install -y --no-install-suggests --no-install-recommends \
    iproute2 bridge-utils vlan less
