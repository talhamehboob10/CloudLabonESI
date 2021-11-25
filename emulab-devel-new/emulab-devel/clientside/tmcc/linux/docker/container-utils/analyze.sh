#!/bin/sh

#
# This is a simple script that prints out properties of a given Docker
# image.  We attempt to "Emulabize" Docker images so that they can run
# more fully on an Emulab testbed, if the user allows.  Docker images
# usually either run something very specific (i.e. a daemon like httpd;
# a one-shot SSG like jekyll), or nothing specific (i.e. bash).  To run
# in a testbed context, a Docker container is almost always going to
# need to stay up for longer periods, support interactive
# experimentation, etc.  This means the container needs a real init;
# sshd; and syslog at minimum.
#
# Anyway, we cannot learn everything we need to know about the image
# from docker inspect.  So we instantiate the image in a dummy container
# and examine the FS.  We are going to use the image anyway, so this
# work is not wasted, and this method is faster and easier than
# flattening and exporting the image to a tarball and unpacking it, or
# other alternatives.
#
# We look specifically for:
#
#   * an OS we support (Centos/Fedora/RHEL; Ubuntu; Debian); or a
#     packaging mechanism we support (apt-get, yum, dnf).
#
#   * existence of an init we support (we support systemd on dedicated
#     nodes, but not shared; we support runit; we support upstart).
#
#   * existence and enablement of sshd (we will configure openssh to
#     suit our purposes, but not any other kind of sshd).
#

# Docker attach is sometimes racy so give it observer a chance to attach
# before printing output
sleep 4

#
# Find the distro, release number, etc.
#
if [ -r /etc/lsb-release ]; then
    dist=`(. /etc/lsb-release; echo $DISTRIB_ID | tr '[A-Z]' '[a-z]')`
    rel=`(. /etc/lsb-release; echo $DISTRIB_RELEASE)`
    major=`echo $rel | cut -d. -f1`
    minor=`echo $rel | cut -d. -f2`
fi
if [ -z "$dist" -a -r /etc/os-release ]; then
    dist=`(. /etc/os-release ; echo $ID | tr '[A-Z]' '[a-z]')`
    rel=`(. /etc/os-release ; echo $VERSION_ID)`
    major=`echo $rel | cut -d. -f1`
    minor=`echo $rel | cut -d. -f2`
fi
if [ -z "$dist" -a -r /etc/redhat-release ]; then
    trel=`grep 'Red Hat' /etc/redhat-release | sed -e 's/Red Hat Linux release \([0-9]\(\.[0-9]\)\?\).*/\1/'`
    if [ -n "$trel" ]; then
        dist="redhat"
	rel=$trel
    fi
    trel=`grep 'Fedora' /etc/redhat-release | sed -e 's/Fedora .*release \([0-9.]\+\).*/\1/'`
    if [ -n "$trel" ]; then
	dist="fedora"
	rel=$trel
    fi
    trel=`grep 'CentOS' /etc/redhat-release | sed -e 's/CentOS .*release \([0-9.]\+\).*/\1/'`
    if [ -n "$trel" ]; then
	dist="centos"
	rel=$trel
    fi

    if [ -n "$trel" ]; then
	major=$trel
	minor=''
    fi
fi
if [ -r /etc/centos-release ]; then
    trel=`grep 'CentOS' /etc/centos-release | sed -e 's/CentOS .*release \([0-9.]\+\).*/\1/'` 	
    dist="centos"
    rel=$trel
    major=`echo $rel | sed -nre 's/^([0-9]+).*$/\1/p'`
    minor=`echo $rel | sed -nre 's/^[0-9]+\.([0-9]+).*$/\1/p'`
fi

if [ "$dist" = "debian" -a -z "$major" ]; then
    major="S"
    minor="S"
    rel="S"
fi

if [ -n "$dist" -a -z "$tag" ]; then
    tag="${dist}${major}"
    if [ -n "$minor" ]; then
	mintag="${tag}-${minor}"
    else
	mintag=''
    fi
fi

#
# Find the package manager.
#
pkgtool=''
if [ -n "$dist" ]; then
    case $dist in
    fedora|centos)
	if [ -z "$pkgtool" -a -f /usr/bin/dnf ]; then
	    pkgtool=/usr/bin/dnf
	fi
	if [ -z "$pkgtool" -a -f /usr/bin/yum ]; then
	    pkgtool=/usr/bin/yum
	fi
	if [ -z "$pkgtool" ]; then
	    pkgtool=`which dnf`
	    if [ ! $? -eq 0 ]; then
		pkgtool=`which yum`
	    fi
	fi
	if [ -n "$pkgtool" ]; then
	    if [ -f /usr/bin/rpm ]; then
		basepkgtool=/usr/bin/rpm
	    else
		basepkgtool=`which rpm`
	    fi
	    basepkgtype='rpm'
	fi
	;;
    ubuntu|debian)
	if [ -z "$pkgtool" -a -f /usr/bin/apt-get ]; then
	    pkgtool=/usr/bin/apt-get
	else
	    pkgtool=`which apt-get`
	fi
	if [ -f /usr/bin/dpkg ]; then
	    basepkgtool=/usr/bin/dpkg
	else
	    basepkgtool=`which dpkg`
	fi
	if [ -n "$pkgtool" ]; then
	    basepkgtype='deb'
	fi
	;;
    alpine)
	if [ -z "$pkgtool" -a -f /sbin/apk ]; then
	    pkgtool=/sbin/apk
	    pkgtool=/sbin/apk
	else
	    pkgtool=`which apk`
	    basepkgtool=`which apk`
	fi
	if [ -n "$pkgtool" ]; then
	    basepkgtype='apk'
	fi
	;;
    *)
	if [ -z "$pkgtool" ]; then 
	    if [ -f /usr/bin/apt-get ]; then
		pkgtool=/usr/bin/apt-get
	    else
		pkgtool=`which apt-get`
	    fi
	    if [ -n "$pkgtool" ]; then
		if [ -f /usr/bin/dpkg ]; then
		    basepkgtool=/usr/bin/dpkg
		else
		    basepkgtool=`which dpkg`
		fi
		if [ -n "$pkgtool" ]; then
		    basepkgtype='deb'
		fi
	    fi
	fi
	if [ -z "$pkgtool" ]; then
	    if [ -f /usr/bin/dnf ]; then
		pkgtool=/usr/bin/dnf
	    fi
	    if [ -z "$pkgtool" -a -f /usr/bin/yum ]; then
		pkgtool=/usr/bin/yum
	    fi
	    if [ -z "$pkgtool" ]; then
		pkgtool=`which dnf`
		if [ ! $? -eq 0 ]; then
		    pkgtool=`which yum`
		fi
	    fi
	    if [ -n "$pkgtool" ]; then
		if [ -f /usr/bin/rpm ]; then
		    basepkgtool=/usr/bin/rpm
		else
		    basepkgtool=`which rpm`
		fi
		basepkgtype='rpm'
	    fi
	fi
	;;
    esac
fi

#
# Figure out the init.
#
if [ -e /sbin/init ]; then
    initpath=`readlink -f /sbin/init`
    initprog=`echo $initpath | sed -rne 's/^.*\/([^\/]*)$/\1/p'`
    if [ "$initprog" = "systemd" ]; then
	initvers=`$initpath --version | sed -nre 's/^systemd\s+([0-9]+)$/\1/p'`
    else
	initvers=`$initpath --version | sed -nre 's/^.*upstart ([0-9\.\-]+).*$/\1/p'`
	if [ $? -eq 0 -a -n "$initvers" ]; then
	    initprog='upstart'
	else
	    initvers=''
	fi
    fi
fi

#
# Figure out the sshd, if any.  Every sane packaging tool automatically
# enables sshd when installing it.
#
HAS_SSHD=0
SSHD_PACKAGE=''
if [ -n "$basepkgtype" -a "$basepkgtype" = "deb" ]; then
    SSHD_PACKAGE=openssh-server
    dpkg -l openssh-server | grep -iq status.\*installed >/dev/null 2>&1
    if [ $? -eq 0 ]; then
	HAS_SSHD=1
	SSHD_PACKAGE=openssh-server
	#find /etc/rc*.d -name \*ssh | grep 
    fi
elif [ -n "$basepkgtype" -a "$basepkgtype" = "rpm" ]; then
    SSHD_PACKAGE=openssh-server
    rpm -q openssh-server >/dev/null 2>&1
    if [ $? -eq 0 ]; then
	HAS_SSHD=1
	#if [ -L /etc/systemd/system/multi-user.target.wants/sshd.service ]; then
	#    SSHD_ENABLED=1
	#fi
    fi
elif [ -n "$basepkgtype" -a "$basepkgtype" = "apk" ]; then
    SSHD_PACKAGE=openssh
    apk info | grep -iq openssh-server >/dev/null 2>&1
    if [ $? -eq 0 ]; then
	HAS_SSHD=1
	SSHD_PACKAGE=openssh-server
    fi
fi

#
# Find a syslogger.
#
HAS_SYSLOG=0
SYSLOG_PACKAGE='rsyslog'
if [ -n "$basepkgtype" -a "$basepkgtype" = "deb" ]; then
    dpkg -l rsyslog | grep -iq status.\*installed >/dev/null 2>&1
    if [ $? -eq 0 ]; then
	SYSLOG_PACKAGE=rsyslog
	HAS_SYSLOG=1
    fi
    if [ $HAS_SYSLOG -eq 0 ]; then
	dpkg -l syslog-ng >/dev/null 2>&1
	if [ $? -eq 0 ]; then
	    SYSLOG_PACKAGE=syslog-ng
	    HAS_SYSLOG=1
	fi
    fi
elif [ -n "$basepkgtype" -a "$basepkgtype" = "rpm" ]; then
    rpm -q rsyslog >/dev/null 2>&1
    if [ $? -eq 0 ]; then
	SYSLOG_PACKAGE=rsyslog
	HAS_SYSLOG=1
    fi
    if [ $HAS_SYSLOG -eq 0 ]; then
	rpm -q syslog-ng >/dev/null 2>&1
	if [ $? -eq 0 ]; then
	    SYSLOG_PACKAGE=syslog-ng
	    HAS_SYSLOG=1
	fi
    fi
elif [ -n "$basepkgtype" -a "$basepkgtype" = "apk" ]; then
    apk info | grep -iq rsyslog >/dev/null 2>&1
    if [ $? -eq 0 ]; then
	SYSLOG_PACKAGE=rsyslog
	HAS_SYSLOG=1
    fi
    if [ $HAS_SYSLOG -eq 0 ]; then
	apk info | grep -iq syslog-ng  >/dev/null 2>&1
	if [ $? -eq 0 ]; then
	    SYSLOG_PACKAGE=syslog-ng
	    HAS_SYSLOG=1
	fi
    fi
fi

#
# Finally, have we done a full Emulab install on this image already?  Or
# have we simply done a basic install?  'clientside' means packages +
# client side.  'minpackages' means init, sshd, syslog.  'packages'
# means minpackages + others.
#
if [ -f /etc/emulab/emulabization-type ]; then
    EMULABIZATION=`cat /etc/emulab/emulabization-type`
fi
if [ -f /etc/emulab/version ]; then
    EMULABVERSION=`cat /etc/emulab/version`
fi

echo "# Result variables:"
echo ""
echo "TAG=$tag"
echo "TAG=$tag"
echo "MINTAG=$mintag"
echo "DIST=$dist"
echo "REL=$rel"
echo "MAJOR=$major"
echo "MINOR=$minor"
echo "PKGTOOL=$pkgtool"
echo "BASEPKGTOOL=$basepkgtool"
echo "BASEPKGTYPE=$basepkgtype"
echo "INITPATH=$initpath"
echo "INITPROG=$initprog"
echo "HAS_SSHD=$HAS_SSHD"
echo "SSHD_PACKAGE=$SSHD_PACKAGE"
echo "HAS_SYSLOG=$HAS_SYSLOG"
echo "SYSLOG_PACKAGE=$SYSLOG_PACKAGE"
echo "EMULABIZATION=$EMULABIZATION"
echo "EMULABVERSION=$EMULABVERSION"

exit 0
