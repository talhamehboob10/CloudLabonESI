#!/bin/sh

set -x

export DEBIAN_FRONTEND=noninteractive

[ ! -f /tmp/apt-updated ] && apt-get update && touch /tmp/apt-updated

exit 0
