#!/bin/sh

##
## Mounts analyze.sh into a container running the given image, and runs
## the analyzer.
##

if [ -z "$1" ]; then
    echo "USAGE: analyze-image.sh <image>"
    exit 1
fi

exec docker run --rm -t -v /etc/emulab/docker/container-utils:/tmp/emulab:ro $1 /tmp/emulab/analyze.sh
