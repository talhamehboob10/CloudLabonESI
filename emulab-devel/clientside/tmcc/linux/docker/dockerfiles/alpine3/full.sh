#!/bin/sh

set -x

apk update

# bridge-utils contains brctl command
apk add iproute2 bridge-utils vlan less
