#!/bin/sh

#
# Cleans up *everything* related to the specified vnode, or to all
# vnodes if -a is specified instead of a vnode.
#

usage() {
    if [ -n "$1" ]; then
	echo "ERROR: $1"
    fi
    echo "USAGE: $0 [-h] [-a | vnode... ]"
    echo "  -a         Remove all vnodes"
    echo "  vnode...  A space-separated list of vnodes to remove"
    exit 1
}

cleanupvnode() {
    vnode=$1

    echo "Cleaning up vnode $vnode..."
    /usr/local/etc/emulab/vnodesetup -d -k -j $vnode
    if [ -d /var/emulab/boot/tmcc.$vnode ]; then
	echo "WARNING: /var/emulab/boot/tmcc.$vnode exists; removing!"
    fi
    rm -rf /var/emulab/boot/tmcc.$vnode
}

doall=0
VNODES=""

count="$#"
i=0
if [ "$#" -eq 0 ]; then
    usage "no arguments specified"
fi
while [ $i -lt $count ]; do
    arg="$1"
    case "$arg" in
	-h|--help)
	    usage
	    ;;
	-a)
	    doall=1
	    if [ -n "$VNODES" ]; then
		usage "cannot specify both -a and specific vnodes"
	    fi
	    ;;
	*)
	    if [ $doall -eq 1 ]; then
		usage "cannot specify both specific vnodes and -a ($arg)"
	    fi
	    VNODES="$VNODES $arg"
	    ;;
    esac
    shift
    i=`expr $i + 1`
done

if [ $doall -eq 1 ]; then
    VNODES=`cat /var/emulab/boot/tmcc/vnodelist | sed -e 's/^VNODEID=\([^ ]*\).*/\1/' | sort | xargs`
fi

for vnode in $VNODES; do
    cleanupvnode $vnode
done
